#!/bin/bash
# Painel de uso por projeto: quanto de contexto a última conversa já ocupa. Bash 3.2; source, não execute.
# Host: say, warn, header, STATE_DIR, PROJECT, TOOL, project_profile (lib/projects.sh).
# Lê só números das sessões (tokens do último registro de uso, contagem de turnos, tamanho e data).
# Nunca imprime nem envia conteúdo de conversas; recusa links simbólicos; varredura com limites.
#
# Formatos confirmados em arquivos reais:
#   Claude: ~/.claude/projects/<caminho com não-alfanuméricos trocados por '-'>/<id>.jsonl; a última linha
#           "type":"assistant" traz usage {input_tokens, cache_creation_input_tokens, cache_read_input_tokens}
#           e o contexto atual é a soma dos três. A janela (200k ou 1M) não consta no arquivo.
#   Claude (fonte principal): arquivo gravado pela barra de status do kit,
#           $STATE_DIR/usage/claude-<K>.txt com K = cksum do caminho do projeto; linhas chave=valor:
#           tokens, window, percent, when (epoch), session. O formato do transcript é interno do Claude
#           Code e pode mudar; por isso o transcript é só o plano B (e, nele, sem usage vira estimativa).
#   Codex:  ~/.codex/sessions/AAAA/MM/DD/rollout-*.jsonl; o início traz "cwd"; eventos token_count trazem
#           "last_token_usage":{"input_tokens":N,...} (N = contexto atual) e "model_context_window":W;
#           cada turno do usuário abre um evento task_started.

PAINEL_LIGHT=80000      # abaixo disto: leve
PAINEL_LONG=200000      # acima disto: muito longa
PAINEL_TAIL=800000      # bytes finais lidos para achar o último registro de uso
PAINEL_COUNT_MAX=80000000   # acima disto não contamos mensagens (só tokens)

USAGE_TOKENS='' USAGE_WINDOW='' USAGE_MSGS='' USAGE_WHEN='' USAGE_STATE='desconhecida'
USAGE_FILE_BYTES='' USAGE_ESTIMATE='' USAGE_FILE='' PAINEL_TOK='' USAGE_PERCENT='' USAGE_SOURCE=''
PAINEL_STATUS_MAX_AGE=2592000   # 30 dias: registro da barra de status mais velho que isto é ignorado

# Número decimal válido: 1 a 9 dígitos. Imprime sem zeros à esquerda; falha se inválido (nunca erra na conta).
painel_num() {
  local digits
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  digits="${1#"${1%%[!0]*}"}"
  [ "${#digits}" -le 9 ] || return 1
  printf '%s' "$((10#$1))"
}

# Hora em segundos desde 1970: 1 a 10 dígitos (vale até o ano 2286). Sem zeros à esquerda.
painel_epoch() {
  local digits
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  digits="${1#"${1%%[!0]*}"}"
  [ "${#digits}" -le 10 ] || return 1
  printf '%s' "$((10#$1))"
}

# Segundos desde 1970 da última modificação do arquivo (vazio se não der para saber).
painel_mtime() {
  local value
  value="$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null)" || return 0
  painel_epoch "$value" 2>/dev/null || true
}

# Remove todas as barras finais, como a barra de status do chat faz.
painel_trim_path() {
  local value="$1"
  while [ "${#value}" -gt 1 ] && [ "${value%/}" != "$value" ]; do value="${value%/}"; done
  [ -n "$value" ] || value=/
  printf '%s' "$value"
}

painel_collapse() {
  printf '%s' "$1" | LC_ALL=C /usr/bin/tr -c 'A-Za-z0-9' '-' | LC_ALL=C /usr/bin/tr -s '-'
}

painel_latest_claude() {
  local project="$1" root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" dir='' wanted entry n=0 file
  [ -d "$root" ] && [ ! -L "$root" ] || return 0
  wanted="$(painel_collapse "$project")"
  for entry in "$root"/*; do
    [ -d "$entry" ] && [ ! -L "$entry" ] || continue
    n=$((n+1)); [ "$n" -le 300 ] || break
    if [ "$(painel_collapse "$(basename "$entry")")" = "$wanted" ]; then dir="$entry"; break; fi
  done
  [ -n "$dir" ] || return 0
  n=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    n=$((n+1)); [ "$n" -le 5 ] || break
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    printf '%s' "$file"; return 0
  done <<EOF
$(ls -t "$dir"/*.jsonl 2>/dev/null)
EOF
}

painel_latest_codex() {
  local project="$1" root="${CODEX_HOME:-$HOME/.codex}/sessions" file n=0
  [ -d "$root" ] && [ ! -L "$root" ] || return 0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    n=$((n+1)); [ "$n" -le 60 ] || break
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    if head -c 4000 "$file" 2>/dev/null | /usr/bin/grep -Fq -e "\"cwd\":\"$project\""; then
      printf '%s' "$file"; return 0
    fi
  done <<EOF
$(find "$root" -maxdepth 4 -type f -name 'rollout-*.jsonl' 2>/dev/null | sort -r | head -60)
EOF
}

# Primeiro número que segue a chave dada na linha recebida em $2 (vazio se não houver).
painel_number() {
  printf '%s' "$2" | /usr/bin/grep -o -e "\"$1\":[0-9]*" | head -1 | cut -d: -f2
}

painel_tokens_claude() {
  local file="$1" line a b c
  line="$(tail -c "$PAINEL_TAIL" "$file" 2>/dev/null | /usr/bin/grep -F -e '"type":"assistant"' | /usr/bin/grep -F -e '"cache_read_input_tokens"' | tail -1)"
  [ -n "$line" ] || return 1
  a="$(painel_number input_tokens "$line")"
  b="$(painel_number cache_creation_input_tokens "$line")"
  c="$(painel_number cache_read_input_tokens "$line")"
  a="$(painel_num "$a")" || return 1
  b="$(painel_num "$b")" || return 1
  c="$(painel_num "$c")" || return 1
  PAINEL_TOK=$((a+b+c))
}

painel_tokens_codex() {
  local file="$1" tail_text line used win
  tail_text="$(tail -c "$PAINEL_TAIL" "$file" 2>/dev/null)"
  line="$(printf '%s\n' "$tail_text" | /usr/bin/grep -F -e '"last_token_usage"' | tail -1)"
  [ -n "$line" ] || return 1
  used="$(printf '%s' "$line" | /usr/bin/grep -o -e '"last_token_usage":{[^}]*}' | tail -1)"
  used="$(painel_number input_tokens "$used")"
  used="$(painel_num "$used")" || return 1
  win="$(printf '%s' "$line" | /usr/bin/grep -o -e '"model_context_window":[0-9]*' | tail -1 | cut -d: -f2)"
  win="$(painel_num "$win")" || win=''
  [ -z "$win" ] || [ "$win" -gt 0 ] || win=''
  USAGE_WINDOW="$win"
  PAINEL_TOK="$used"
}

# Lê $STATE_DIR/usage/claude-<K>.txt (chave=valor, nunca executado). Preenche PAINEL_ST_* e retorna 0
# só se houver tokens numéricos e um 'when' recente.
painel_status_file() {
  local project="$1" key file line k v now
  PAINEL_ST_TOKENS='' PAINEL_ST_WINDOW='' PAINEL_ST_PERCENT='' PAINEL_ST_WHEN='' PAINEL_ST_BAD=''
  project="$(painel_trim_path "$project")"
  key="$(printf '%s' "$project" | cksum | cut -d' ' -f1)"
  file="$STATE_DIR/usage/claude-$key.txt"
  [ -f "$file" ] && [ ! -L "$file" ] && [ ! -L "$STATE_DIR/usage" ] || return 1
  v="$(painel_num "$(wc -c < "$file" 2>/dev/null | tr -d ' ')")" || return 1
  [ "$v" -le 4096 ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    k="${line%%=*}"; v="${line#*=}"
    case "$k" in
      tokens) if [ -n "$v" ]; then
                if v="$(painel_num "$v")"; then PAINEL_ST_TOKENS="$v"; else PAINEL_ST_BAD=1; fi
              fi ;;
      window) v="$(painel_num "$v")" && [ "$v" -gt 0 ] && PAINEL_ST_WINDOW="$v" ;;
      percent) v="${v%%.*}"; v="$(painel_num "$v")" && [ "$v" -le 1000 ] && PAINEL_ST_PERCENT="$v" ;;
      when) v="$(painel_epoch "$v")" && PAINEL_ST_WHEN="$v" ;;
    esac
  done < "$file"
  [ -n "$PAINEL_ST_TOKENS" ] && [ -n "$PAINEL_ST_WHEN" ] || return 1
  now="$(painel_epoch "$(date +%s)")" || return 1
  [ "$PAINEL_ST_WHEN" -le "$((now + 86400))" ] || return 1
  [ "$((now - PAINEL_ST_WHEN))" -lt "$PAINEL_STATUS_MAX_AGE" ] || return 1
  return 0
}

painel_count_msgs() {
  local tool="$1" file="$2" bytes="$3" count
  bytes="$(painel_num "$bytes")" || return 0
  [ "$bytes" -le "$PAINEL_COUNT_MAX" ] || return 0
  if [ "$tool" = claude ]; then
    count="$(/usr/bin/grep -F -e '"type":"user"' "$file" 2>/dev/null | /usr/bin/grep -vc -F -e '"type":"tool_result"')"
  else
    count="$(/usr/bin/grep -c -F -e '"payload":{"type":"task_started"' "$file" 2>/dev/null)"
  fi
  count="$(painel_num "$count")" || return 0
  USAGE_MSGS="$count"
}

# "hoje 14:20", "ontem 09:05" ou "21/10 17:30", a partir da data do arquivo.
painel_when() {
  local file="$1" day now yesterday hour
  day="$(date -r "$file" +%Y%m%d 2>/dev/null)" || return 0
  hour="$(date -r "$file" +%H:%M 2>/dev/null)"
  now="$(date +%Y%m%d)"
  yesterday="$(date -v-1d +%Y%m%d 2>/dev/null || date -d yesterday +%Y%m%d 2>/dev/null)"
  if [ "$day" = "$now" ]; then printf 'hoje %s' "$hour"
  elif [ -n "$yesterday" ] && [ "$day" = "$yesterday" ]; then printf 'ontem %s' "$hour"
  else printf '%s/%s %s' "${day:6:2}" "${day:4:2}" "$hour"; fi
}

# Igual a painel_when, mas a partir de segundos desde 1970.
painel_when_epoch() {
  local epoch="$1" day now yesterday hour
  epoch="$(painel_epoch "$epoch")" || return 0
  day="$(date -r "$epoch" +%Y%m%d 2>/dev/null || date -d "@$epoch" +%Y%m%d 2>/dev/null)" || return 0
  hour="$(date -r "$epoch" +%H:%M 2>/dev/null || date -d "@$epoch" +%H:%M 2>/dev/null)"
  now="$(date +%Y%m%d)"
  yesterday="$(date -v-1d +%Y%m%d 2>/dev/null || date -d yesterday +%Y%m%d 2>/dev/null)"
  if [ "$day" = "$now" ]; then printf 'hoje %s' "$hour"
  elif [ -n "$yesterday" ] && [ "$day" = "$yesterday" ]; then printf 'ontem %s' "$hour"
  else printf '%s/%s %s' "${day:6:2}" "${day:4:2}" "$hour"; fi
}

painel_fmt_tokens() {
  local n tenths
  n="$(painel_num "$1")" || { printf '?'; return 0; }
  if [ "$n" -ge 1000000 ]; then
    tenths=$(( n / 100000 )); printf '%s,%s milhão' "$((tenths/10))" "$((tenths%10))"
  elif [ "$n" -ge 1000 ]; then printf '%s mil' "$(( (n + 500) / 1000 ))"
  else printf '%s' "$n"; fi
}

# Preenche USAGE_* para a conversa mais recente de <ferramenta> em <caminho_do_projeto>. Sempre retorna 0.
usage_measure() {
  local tool="$1" project="$2" file='' tokens=''
  USAGE_TOKENS='' USAGE_WINDOW='' USAGE_MSGS='' USAGE_WHEN='' USAGE_STATE='desconhecida'
  USAGE_FILE_BYTES='' USAGE_ESTIMATE='' USAGE_FILE='' USAGE_PERCENT='' USAGE_SOURCE=''
  local mtime='' usable=0
  PAINEL_ST_BAD=''
  case "$tool" in claude|codex) ;; *) return 0 ;; esac
  [ -n "$project" ] && [ -d "$project" ] || return 0
  project="$(painel_trim_path "$project")"
  if [ "$tool" = claude ]; then file="$(painel_latest_claude "$project")"; else file="$(painel_latest_codex "$project")"; fi
  usable=0
  if [ "$tool" = claude ] && painel_status_file "$project"; then
    usable=1
    # O registro da barra só vale se não for mais velho que a conversa mais recente (tolerância de 5 min).
    if [ -n "$file" ]; then
      mtime="$(painel_mtime "$file")"
      if [ -n "$mtime" ] && [ "$((PAINEL_ST_WHEN + 300))" -lt "$mtime" ]; then usable=0; fi
    fi
  fi
  if [ "$usable" -eq 1 ]; then
    # Fonte principal: número exato gravado pela barra de status do kit.
    USAGE_SOURCE=statusline
    USAGE_TOKENS="$PAINEL_ST_TOKENS" USAGE_WINDOW="$PAINEL_ST_WINDOW" USAGE_PERCENT="$PAINEL_ST_PERCENT"
    USAGE_WHEN="$(painel_when_epoch "$PAINEL_ST_WHEN")"
    if [ -n "$file" ]; then
      USAGE_FILE="$file"
      USAGE_FILE_BYTES="$(painel_num "$(wc -c < "$file" 2>/dev/null | tr -d ' ')")" || USAGE_FILE_BYTES=''
      painel_count_msgs "$tool" "$file" "$USAGE_FILE_BYTES"
    fi
    painel_classify
    return 0
  fi
  if [ -z "$file" ]; then
    # Registro da barra com número inválido e nenhuma conversa para conferir: não dá para medir.
    if [ -n "$PAINEL_ST_BAD" ]; then USAGE_STATE='desconhecida'; else USAGE_STATE='nenhuma'; fi
    return 0
  fi
  USAGE_FILE="$file"
  USAGE_FILE_BYTES="$(painel_num "$(wc -c < "$file" 2>/dev/null | tr -d ' ')")" || { USAGE_FILE_BYTES=''; return 0; }
  USAGE_WHEN="$(painel_when "$file")"
  USAGE_SOURCE=transcript
  PAINEL_TOK=''
  if [ "$tool" = claude ]; then painel_tokens_claude "$file"; else painel_tokens_codex "$file"; fi
  tokens="$PAINEL_TOK"
  if [ -n "$tokens" ]; then USAGE_TOKENS="$tokens"
  else
    # Sem registro de uso: o arquivo guarda muito mais que o contexto; ~10 bytes por token é só uma ordem de grandeza.
    USAGE_TOKENS=$(( USAGE_FILE_BYTES / 10 )); USAGE_ESTIMATE=1
  fi
  painel_count_msgs "$tool" "$file" "$USAGE_FILE_BYTES"
  painel_classify
  return 0
}

painel_classify() {
  USAGE_TOKENS="$(painel_num "$USAGE_TOKENS")" || { USAGE_TOKENS=''; USAGE_STATE='desconhecida'; return 0; }
  if [ "$USAGE_TOKENS" -lt "$PAINEL_LIGHT" ]; then USAGE_STATE='leve'
  elif [ "$USAGE_TOKENS" -le "$PAINEL_LONG" ]; then USAGE_STATE='longa'
  else USAGE_STATE='muito-longa'; fi
}

# Pedaço "~35 mil tokens (14% da janela), 42 mensagens, hoje 14:20" a partir das variáveis USAGE_*.
painel_details() {
  local text pct
  if [ "$USAGE_TOKENS" = 0 ]; then
    text='conversa nova (ainda sem uso)'
    [ -z "$USAGE_WHEN" ] || text="$text, $USAGE_WHEN"
    printf '%s' "$text"; return 0
  fi
  text="~$(painel_fmt_tokens "$USAGE_TOKENS") tokens"
  case "$USAGE_WINDOW" in ''|*[!0-9]*|0)
    case "$USAGE_PERCENT" in ''|*[!0-9]*) ;; *) text="$text ($USAGE_PERCENT% da janela)" ;; esac ;;
  *)
    pct=$(( USAGE_TOKENS * 100 / USAGE_WINDOW )); text="$text ($pct% da janela)" ;;
  esac
  [ -z "$USAGE_ESTIMATE" ] || text="$text (estimativa)"
  { [ -z "$USAGE_MSGS" ] || [ "$USAGE_MSGS" = 0 ]; } || text="$text, $USAGE_MSGS mensagens"
  [ -z "$USAGE_WHEN" ] || text="$text, $USAGE_WHEN"
  printf '%s' "$text"
}

# UMA linha amigável sobre a conversa do projeto atual. Sempre retorna 0.
project_usage_line() {
  local tool="${TOOL:-}" profile=''
  [ -n "${PROJECT:-}" ] && [ -d "$PROJECT" ] || return 0
  if painel_off; then say 'Medição de uso desligada (Ajuda e ajustes → 4)'; return 0; fi
  case "$tool" in claude|codex) ;; *)
    profile="$(project_profile 2>/dev/null)" || profile=''
    tool="$profile" ;;
  esac
  usage_measure "$tool" "$PROJECT"
  case "$USAGE_STATE" in
    nenhuma) say 'Conversa: nenhuma ainda neste projeto' ;;
    leve) say "Conversa: ✓ leve — $(painel_details)" ;;
    longa) say "Conversa: ⚠ ficando longa — $(painel_details) — termine a tarefa e use Encerrar com resumo" ;;
    muito-longa) say "Conversa: ⛔ muito longa — $(painel_details) — use Encerrar com resumo" ;;
    *) say 'Conversa: não consegui medir' ;;
  esac
  return 0
}

# A chave "peso" do menu Preferências desliga toda a medição (nenhuma sessão é lida).
painel_off() { type opt_enabled >/dev/null 2>&1 && ! opt_enabled peso; }

painel_project_tool() {
  local path="$1" file="$path/.assistente-ia/tool" value='' saved="${PROJECT:-}"
  if [ -f "$file" ] && [ ! -L "$file" ] && [ ! -L "$path/.assistente-ia" ]; then
    IFS= read -r value < "$file"
    case "$value" in codex|claude) printf '%s' "$value"; return 0 ;; esac
  fi
  PROJECT="$path"
  value="$(project_profile 2>/dev/null)" || value=''
  PROJECT="$saved"
  printf '%s' "$value"
}

usage_panel() {
  local path tool name rows='' key mark text count=0 file="$STATE_DIR/recents"
  header_ui 'Painel de uso dos projetos' 'Project usage dashboard'
  if painel_off; then say_ui 'Medição de uso desligada (Ajuda e ajustes → 4)' 'Usage measurement is off (Help and settings → 4)'; return 0; fi
  if [ ! -f "$file" ]; then
    say_ui 'Ainda não há projetos recentes. Crie ou abra um projeto e volte aqui.' 'No recent projects yet. Create or open one and return here.'
    return 0
  fi
  while IFS= read -r path; do
    [ -n "$path" ] && [ -d "$path" ] && [ ! -L "$path" ] || continue
    count=$((count+1)); [ "$count" -le 12 ] || break
    tool="$(painel_project_tool "$path")"
    name="$(basename "$path")"
    key=0
    if [ -z "$tool" ]; then mark='·'; text="$name — $(ui 'sem ferramenta definida (use Cuidar do projeto → Verificar)' 'no agent selected (use Project care → Check)')"
    else
      usage_measure "$tool" "$path"
      case "$USAGE_STATE" in
        leve) mark='✓'; text="$name — $tool — $(painel_details)"; key="$USAGE_TOKENS" ;;
        longa) mark='⚠'; text="$name — $tool — $(painel_details)"; key="$USAGE_TOKENS" ;;
        muito-longa) mark='⛔'; text="$name — $tool — $(painel_details)"; key="$USAGE_TOKENS" ;;
        nenhuma) mark='·'; text="$name — $tool — $(ui 'nenhuma conversa ainda' 'no conversation yet')" ;;
        *) mark='·'; text="$name — $tool — $(ui 'não consegui medir' 'could not measure')" ;;
      esac
    fi
    rows="${rows}$(printf '%012d' "$key")|  $mark $text"$'\n'
  done < "$file"
  if [ -z "$rows" ]; then
    say_ui 'Ainda não há projetos recentes. Crie ou abra um projeto e volte aqui.' 'No recent projects yet. Create or open one and return here.'
    return 0
  fi
  printf '%s' "$rows" | LC_ALL=C sort -t'|' -k1,1r | cut -d'|' -f2-
  say ''
  say_ui 'Legenda (uso da conversa, em mil tokens):' 'Legend (conversation usage, in thousands of tokens):'
  say_ui '  ✓ leve: até ~80 mil     ⚠ ficando longa: 80 a 200 mil' '  ✓ light: up to ~80k     ⚠ getting long: 80k to 200k'
  say_ui '  ⛔ muito longa: acima de 200 mil' '  ⛔ very long: over 200k'
  say_ui 'O que fazer:' 'What to do:'
  say_ui '  ✓  continue normalmente.' '  ✓  continue as usual.'
  say_ui '  ⚠  termine a tarefa em andamento e use "Encerrar com resumo".' '  ⚠  finish the current task and use Wrap up with a summary.'
  say_ui '  ⛔  encerre agora. Depois escolha Começar uma conversa nova →' '  ⛔  wrap up now. Then choose Start a new conversation →'
  say_ui '      Continuar o trabalho.' '      Continue the work.'
  say_ui 'Os números vêm do último registro de uso da conversa; as mensagens' 'Numbers come from the latest conversation usage record; message counts'
  say_ui 'são aproximadas. O kit só conta e soma números nos arquivos de' 'are approximate. The kit only counts numbers in session files;'
  say_ui 'sessão; nada é exibido nem enviado.' 'session content is neither displayed nor sent.'
  return 0
}
