#!/bin/bash
# Barra de status do Claude Code (Assistente IA Mac 1.0). Bash 3.2, sem jq/python.
# Lê o JSON que o Claude Code envia no stdin e imprime UMA linha curta.
# Grava só números (tokens, janela, %, hora, sessão) em <preferências>/usage/claude-<K>.txt;
# nunca grava nem imprime conteúdo de conversas. Sempre termina com status 0.

sl_json_raw() {
  # Primeiro valor (sem aspas) da chave $1 dentro do texto $2; vazio se ausente.
  local key="$1" text="$2" found
  found="$(printf '%s' "$text" | /usr/bin/grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}[:space:]][^,}]*" 2>/dev/null | head -n 1)"
  found="${found#*:}"
  found="${found#"${found%%[![:space:]]*}"}"
  found="${found%"${found##*[![:space:]]}"}"
  printf '%s' "$found"
}

sl_json_string() {
  local key="$1" text="$2" found
  found="$(printf '%s' "$text" | /usr/bin/grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" 2>/dev/null | head -n 1)"
  found="${found#*:}"
  found="${found#"${found%%[![:space:]]*}"}"
  found="${found#\"}"; found="${found%\"}"
  printf '%s' "$found" | sed 's#\\/#/#g'
}

# Número decimal válido: 1 a 9 dígitos (maior que isso é tratado como dado inválido, nunca como "leve").
sl_number() {
  local digits
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  digits="${1#"${1%%[!0]*}"}"
  [ "${#digits}" -le 9 ]
}

sl_main() {
  local input flat seg tokens window percent project name model pct_int
  local cin ccr ccc sum state mark color reset='' label k state_dir dir file tmp when session raw bad=''
  input="$(cat 2>/dev/null)"
  flat="$(printf '%s' "$input" | tr '\n\r\t' '   ')"

  project="$(sl_json_string project_dir "$flat")"
  [ -n "$project" ] || project="$(sl_json_string cwd "$flat")"
  while [ "${#project}" -gt 1 ] && [ "${project%/}" != "$project" ]; do project="${project%/}"; done
  name="${project##*/}"
  [ -n "$name" ] || name="${project:-projeto}"
  model="$(sl_json_string display_name "$flat")"
  session="$(sl_json_string session_id "$flat")"

  # Só o trecho do context_window: evita confundir com used_percentage de rate_limits.
  case "$flat" in *'"context_window"'*) seg="${flat#*\"context_window\"}" ;; *) seg='' ;; esac
  tokens="$(sl_json_raw total_input_tokens "$seg")"
  window="$(sl_json_raw context_window_size "$seg")"
  percent="$(sl_json_raw used_percentage "$seg")"
  raw="$tokens"
  if sl_number "$tokens"; then
    tokens=$((10#$tokens))
  else
    cin="$(sl_json_raw input_tokens "${seg#*current_usage}")"
    ccc="$(sl_json_raw cache_creation_input_tokens "${seg#*current_usage}")"
    ccr="$(sl_json_raw cache_read_input_tokens "${seg#*current_usage}")"
    tokens=''
    sum=0
    for k in "$cin" "$ccc" "$ccr"; do
      if sl_number "$k"; then sum=$((sum+10#$k)); tokens="$sum"
      elif [ -n "$k" ] && [ "$k" != null ]; then bad=1; fi
    done
    [ -z "$bad" ] || tokens=''
    if [ -z "$tokens" ] && [ -n "$raw" ] && [ "$raw" != null ]; then bad=1; fi
  fi
  if sl_number "$window"; then window=$((10#$window)); [ "$window" -gt 0 ] || window=''; else window=''; fi
  pct_int="${percent%%.*}"
  if sl_number "$pct_int"; then pct_int=$((10#$pct_int)); [ "$pct_int" -le 1000 ] || pct_int=''; else pct_int=''; fi
  if [ -z "$pct_int" ] && [ -n "$tokens" ] && [ -n "$window" ]; then
    pct_int=$((tokens*100/window))
  fi
  percent="$pct_int"

  [ -n "${NO_COLOR:-}" ] || reset=$'\033[0m'

  if [ -z "$tokens" ] && [ -n "$bad" ]; then
    state=invalido; mark=''; label='contexto: número inválido'; color=$'\033[2m'
  elif [ -z "$tokens" ]; then
    state=aguardando; mark=''; label='contexto: aguardando 1ª resposta'; color=$'\033[2m'
  else
    state=leve
    if [ "$tokens" -gt 200000 ] || { [ -n "$pct_int" ] && [ "$pct_int" -ge 80 ]; }; then state=muito
    elif [ "$tokens" -ge 80000 ] || { [ -n "$pct_int" ] && [ "$pct_int" -ge 40 ]; }; then state=longa; fi
    if [ "$tokens" -ge 1000 ]; then label="contexto $((tokens/1000)) mil tokens"; else label="contexto $tokens tokens"; fi
    [ -z "$pct_int" ] || label="$label (${pct_int}%)"
    case "$state" in
      leve) color=$'\033[32m'; mark='✓ leve' ;;
      longa) color=$'\033[33m'; mark='⚠ ficando longa' ;;
      *) color=$'\033[31m'; mark='⛔ encerre: use Encerrar com resumo' ;;
    esac
  fi
  [ -n "${NO_COLOR:-}" ] && color=''
  printf '%s%s · %s%s%s%s\n' "${name:-projeto}" "${model:+ · $model}" "$color" "$label" "${mark:+ · $mark}" "$reset"

  # Registro numérico para o Painel de uso (atômico, sem seguir links simbólicos).
  [ -n "$project" ] || return 0
if [ "$(uname -s)" = Linux ]; then default_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/assistente-ia"
else default_state_dir="$HOME/Library/Application Support/Assistente IA Mac"; fi
state_dir="${ASSISTENTE_STATE_DIR:-$default_state_dir}"
  k="$(printf '%s' "$project" | cksum | cut -d' ' -f1)"
  dir="$state_dir/usage"
  file="$dir/claude-$k.txt"
  umask 077
  [ ! -L "$state_dir" ] && [ ! -L "$dir" ] || return 0
  mkdir -p "$dir" 2>/dev/null || return 0
  [ ! -L "$file" ] || return 0
  tmp="$(mktemp "$dir/.claude-$k.XXXXXXXX" 2>/dev/null)" || return 0
  when="$(date +%s 2>/dev/null)"
  session="$(printf '%s' "$session" | tr -cd 'A-Za-z0-9._-')"
  printf 'tokens=%s\nwindow=%s\npercent=%s\nwhen=%s\nsession=%s\n' "$tokens" "$window" "$percent" "$when" "$session" > "$tmp" 2>/dev/null &&
    mv -f "$tmp" "$file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  return 0
}

sl_main 2>/dev/null
exit 0
