#!/bin/bash
# Aviso dentro do chat do Claude Code (barra de status). Bash 3.2; source, não execute.
# Host: say, warn, ask (REPLY), pause, header, STATE_DIR, BASE_DIR.
# Nada em ~/.claude muda sem prévia, confirmação digitada e backup. O JSON de settings.json
# só é editado com Python (nunca sed) e o conteúdo dele nunca é impresso.

sl_settings_file() { printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"; }
sl_script_path() { printf '%s' "$STATE_DIR/statusline.sh"; }
# O comando de statusline roda em um shell: o caminho vai entre aspas simples (há espaços).
sl_command_string() { printf "'%s'" "$(sl_script_path)"; }
sl_path_safe() { case "$1" in *\'*|*\"*|*\\*|*$'\n'*) return 1 ;; esac; return 0; }

# Python só se existir de verdade; o atalho /usr/bin/python3 sem as ferramentas do Xcode abriria um instalador.
sl_python() {
  local candidate
  if [ "${ASSISTENTE_PYTHON+x}" = x ]; then
    candidate="$ASSISTENTE_PYTHON"
    [ -n "$candidate" ] && [ -x "$candidate" ] || return 1
    printf '%s' "$candidate"; return 0
  fi
  candidate="$(command -v python3 2>/dev/null)" || return 1
  if [ "$candidate" = /usr/bin/python3 ] && ! xcode-select -p >/dev/null 2>&1; then return 1; fi
  printf '%s' "$candidate"
}

sl_has_key() { [ -f "$1" ] && /usr/bin/grep -q '"statusLine"' "$1" 2>/dev/null; }
# A barra é "nossa" se o comando da statusLine cita o nosso script, em qualquer formato
# ('caminho', "caminho", bash caminho, sh -c '...'). Com Python lê o JSON; sem ele, procura nas linhas "command".
sl_is_ours() {
  local file="$1" py
  sl_has_key "$file" || return 1
  py="$(sl_python)" || py=''
  if [ -n "$py" ]; then
    sl_edit_settings "$py" check "$file" "$(sl_script_path)"
    return $?
  fi
  /usr/bin/grep -o -E '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' "$file" 2>/dev/null | /usr/bin/grep -Fq -e "$(sl_script_path)"
}

statusline_state_line() {
  local file
  file="$(sl_settings_file)"
  if sl_is_ours "$file"; then say 'Barra no chat: instalada ✓'
  elif sl_has_key "$file"; then say 'Barra no chat: outra barra já configurada (o kit não altera)'
  else say 'Barra no chat: não instalada'; fi
  return 0
}

# Copia o script para a pasta do kit; fixa a pasta de preferências usada para gravar o registro de uso.
sl_install_script() {
  local source_file="$BASE_DIR/lib/statusline-claude.sh" target temporary
  target="$(sl_script_path)"
  [ -f "$source_file" ] || { warn 'Arquivo lib/statusline-claude.sh ausente. Descompacte o kit completo.'; return 1; }
  sl_path_safe "$STATE_DIR" || { warn 'A pasta de preferências tem aspas ou barra invertida no nome; use a instalação manual.'; return 1; }
  [ ! -L "$STATE_DIR" ] && [ ! -L "$target" ] || { warn 'Link simbólico encontrado; não vou gravar o script.'; return 1; }
  mkdir -p "$STATE_DIR" || return 1
  temporary="$(mktemp "$STATE_DIR/statusline.XXXXXXXX")" || return 1
  if { printf '#!/bin/bash\n'; printf ": \${ASSISTENTE_STATE_DIR:='%s'}\n" "$STATE_DIR"; sed '1d' "$source_file"; } > "$temporary" &&
     chmod 700 "$temporary" && mv -f "$temporary" "$target"; then return 0; fi
  rm -f "$temporary"; return 1
}

sl_backup_settings() {
  local file="$1" stamp copy
  [ -f "$file" ] || return 0
  stamp="$(date '+%Y%m%d-%H%M%S')"
  mkdir -p "$STATE_DIR/backups" || return 1
  copy="$(mktemp "$STATE_DIR/backups/settings.json.$stamp.XXXXXX")" || return 1
  cp -p "$file" "$copy" || { rm -f "$copy"; return 1; }
  say "Backup: $copy"
}

# Edita só a chave statusLine. Ações: install (4º argumento = comando), remove e check (4º = caminho do
# nosso script), validate (só confere o JSON). Saídas: 0 ok · 3 JSON ilegível · 4 conflito/não é nossa · 5 erro ao gravar.
sl_edit_settings() {
  local py="$1" action="$2" file="$3" command="$4" code=''
  IFS= read -r -d '' code <<'PY' || true
import json, os, sys, tempfile
action, path, command = sys.argv[1:4]
path = os.path.realpath(path)
try:
    raw = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    data = json.loads(raw) if raw.strip() else {}
    if not isinstance(data, dict):
        raise ValueError
except Exception:
    sys.exit(3)
def ours(needle):
    current = data.get("statusLine")
    text = current.get("command") if isinstance(current, dict) else None
    return isinstance(text, str) and needle in text
if action == "validate":
    sys.exit(0)
if action == "check":
    sys.exit(0 if ours(command) else 4)
if action == "install":
    if "statusLine" in data:
        sys.exit(4)
    data["statusLine"] = {"type": "command", "command": command, "padding": 2}
elif action == "remove":
    if not ours(command):
        sys.exit(4)
    del data["statusLine"]
else:
    sys.exit(2)
try:
    mode = (os.stat(path).st_mode & 0o777) if os.path.exists(path) else 0o600
    fd, temporary = tempfile.mkstemp(dir=os.path.dirname(path) or ".", prefix=".settings-")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.chmod(temporary, mode)
    os.replace(temporary, path)
except Exception:
    sys.exit(5)
PY
  "$py" -I -c "$code" "$action" "$file" "$command" 2>/dev/null
}

sl_manual_instructions() {
  say 'Instalação manual (você mantém o controle):'
  say "  1) O script está em: $(sl_script_path)"
  say '  2) No Claude Code, digite:  /statusline use o script '"$(sl_command_string)"
  say '     O Claude escreve a configuração e pede a sua aprovação.'
  [ "${1:-}" != existente ] || return 0
  say '  Ou adicione ao ~/.claude/settings.json:'
  say '    "statusLine": { "type": "command", "command": "'"$(sl_command_string)"'", "padding": 2 }'
}

sl_preview() {
  header 'Como ficará a barra'
  local tmp line json label
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/assistente-barra.XXXXXXXX")" || return 1
  say 'Exemplos reais do script (nada é gravado nas suas preferências):'
  say ''
  for label in leve longa muito; do
    case "$label" in
      leve) json='{"workspace":{"project_dir":"/exemplo/Meu Projeto"},"model":{"display_name":"Sonnet"},"context_window":{"total_input_tokens":35000,"context_window_size":200000,"used_percentage":17.5}}' ;;
      longa) json='{"workspace":{"project_dir":"/exemplo/Meu Projeto"},"model":{"display_name":"Sonnet"},"context_window":{"total_input_tokens":120000,"context_window_size":1000000,"used_percentage":12}}' ;;
      *) json='{"workspace":{"project_dir":"/exemplo/Meu Projeto"},"model":{"display_name":"Sonnet"},"context_window":{"total_input_tokens":250000,"context_window_size":1000000,"used_percentage":25}}' ;;
    esac
    line="$(printf '%s' "$json" | ASSISTENTE_STATE_DIR="$tmp" /bin/bash "$BASE_DIR/lib/statusline-claude.sh")"
    say "  $line"
  done
  rm -rf "$tmp"
  say ''
  say 'Verde: leve (menos de 80 mil tokens). Amarelo: ficando longa (80–200 mil).'
  say 'Vermelho: muito longa (mais de 200 mil, ou 80% da janela):'
  say 'hora de encerrar com resumo.'
}

sl_install() {
  local file command py status
  file="$(sl_settings_file)"
  command="$(sl_command_string)"
  header 'Instalar a barra no Claude Code'
  sl_path_safe "$STATE_DIR" || { warn 'A pasta de preferências tem aspas ou barra invertida; use a instalação manual.'; return 1; }
  if sl_is_ours "$file"; then
    say 'A barra já está instalada. Vou apenas atualizar o script.'
    sl_install_script && say 'Script atualizado.'
    return 0
  fi
  if sl_has_key "$file"; then
    say 'Você já tem uma barra de status configurada. O kit não sobrescreve.'
    ask 'Copiar o script do kit para usar com /statusline? [S/n]: ' || return 1
    case "$REPLY" in n|N) say 'Nada foi alterado.'; return 0 ;; esac
    sl_install_script || return 1
    sl_manual_instructions existente
    return 0
  fi
  py="$(sl_python)" || py=''
  if [ -z "$py" ]; then
    say 'Não encontrei o Python para editar o settings.json com segurança.'
    ask 'Copiar o script para a pasta do kit e mostrar a instalação manual? [S/n]: ' || return 1
    case "$REPLY" in n|N) say 'Nada foi alterado.'; return 0 ;; esac
    sl_install_script || return 1
    sl_manual_instructions
    return 0
  fi
  if [ -f "$file" ]; then
    # Confere o JSON ANTES de criar backup ou copiar o script: em caso de recusa não sobra nada.
    sl_edit_settings "$py" validate "$file" ''; status=$?
    if [ "$status" -ne 0 ]; then
      warn 'Não consegui ler o settings.json (JSON inválido?). Nada foi alterado.'
      return 1
    fi
  fi
  say "Arquivo: $file"
  if [ -f "$file" ]; then say 'Ele será regravado com recuo de 2 espaços; suas outras configurações ficam como estão.'
  else say 'O arquivo ainda não existe; será criado.'; fi
  say 'Será ADICIONADO:'
  say '  "statusLine": {'
  say '    "type": "command",'
  say "    \"command\": \"$command\","
  say '    "padding": 2'
  say '  }'
  say "Também será criado o script: $(sl_script_path)"
  say 'Só funciona no Claude Code. Um backup do settings.json é feito antes.'
  ask 'Digite INSTALAR para aplicar (Enter cancela): ' || return 1
  [ "$REPLY" = INSTALAR ] || { say 'Cancelado. Nada foi alterado.'; return 0; }
  sl_backup_settings "$file" || { warn 'Não consegui fazer o backup; nada foi alterado.'; return 1; }
  sl_install_script || { warn 'Não consegui criar o script; o settings.json não foi alterado.'; return 1; }
  mkdir -p "$(dirname "$file")" || return 1
  sl_edit_settings "$py" install "$file" "$command"; status=$?
  case "$status" in
    0) ;;
    3) warn 'Não consegui ler o settings.json (JSON inválido?). Nada foi alterado.'; return 1 ;;
    4) warn 'Já existe uma barra configurada. Nada foi alterado.'; return 1 ;;
    *) warn 'Não consegui gravar o settings.json. Restaure o backup acima se necessário.'; return 1 ;;
  esac
  if sl_is_ours "$file"; then
    say 'Barra instalada ✓. Abra uma conversa nova no Claude Code para vê-la.'
  else
    warn 'Gravei, mas não consegui confirmar. Confira o settings.json.'; return 1
  fi
}

sl_remove() {
  local file py status
  file="$(sl_settings_file)"
  header 'Remover a barra do Claude Code'
  if ! sl_is_ours "$file"; then
    say 'A barra deste kit não está configurada. Não vou mexer em outra barra.'
    say 'Para remover outra barra, digite /statusline delete no Claude Code.'
    return 0
  fi
  py="$(sl_python)" || py=''
  if [ -z "$py" ]; then
    say 'Não encontrei o Python para editar o settings.json com segurança.'
    say 'No Claude Code, digite /statusline delete (ou apague o campo'
    say 'statusLine do settings.json).'
    return 0
  fi
  say "Será REMOVIDA só a chave statusLine de: $file"
  say 'Um backup é feito antes. O script do kit continua na pasta do kit.'
  ask 'Digite REMOVER para aplicar (Enter cancela): ' || return 1
  [ "$REPLY" = REMOVER ] || { say 'Cancelado. Nada foi alterado.'; return 0; }
  sl_backup_settings "$file" || { warn 'Não consegui fazer o backup; nada foi alterado.'; return 1; }
  sl_edit_settings "$py" remove "$file" "$(sl_script_path)"; status=$?
  case "$status" in
    0) say 'Barra removida ✓. Ela some na próxima conversa.' ;;
    3) warn 'Não consegui ler o settings.json. Nada foi alterado.'; return 1 ;;
    4) warn 'A configuração atual não é a do kit. Nada foi alterado.'; return 1 ;;
    *) warn 'Não consegui gravar o settings.json. Restaure o backup acima se necessário.'; return 1 ;;
  esac
}

sl_without_install() {
  header 'Ver o uso sem instalar a barra'
  say 'Claude Code:'
  say '  • /context mostra quanto da conversa já foi usado.'
  say '  • /compact resume a conversa sem sair dela; /clear começa do zero.'
  say 'Codex:'
  say '  • /status mostra a sessão. Não há barra equivalente à do Claude.'
  say '  • Use o Painel de uso do kit antes de abrir a conversa.'
  say 'A barra do kit só funciona no Claude Code.'
}

statusline_menu() {
  local choice
  while :; do
    header 'Aviso dentro do chat (Claude Code)'
    if [ -n "${PROJECT:-}" ] && type project_profile >/dev/null 2>&1 && [ "$(project_profile 2>/dev/null)" = codex ]; then
      say 'Atenção: o projeto atual usa o Codex. Esta barra só funciona no Claude Code.'
    fi
    say 'A barra mostra, embaixo do chat, quanto contexto a conversa já usa.'
    say 'Fica verde enquanto está leve, amarela quando está ficando longa e'
    say 'vermelha quando é hora de encerrar com resumo.'
    say 'É opcional e só funciona no Claude Code (o Codex não tem barra).'
    say 'Nada é alterado sem prévia, sua confirmação digitada e backup.'
    say ''
    statusline_state_line
    say ''
    say '1) Ver como ficará'
    say '2) Instalar a barra'
    say '3) Remover a barra'
    say '4) Como ver o uso sem instalar'
    say '0) Voltar'
    ask 'Escolha: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) sl_preview; pause || return 1 ;;
      2) sl_install; pause || return 1 ;;
      3) sl_remove; pause || return 1 ;;
      4) sl_without_install; pause || return 1 ;;
      0|'') return 0 ;;
      *) say 'Opção inválida.' ;;
    esac
  done
}
