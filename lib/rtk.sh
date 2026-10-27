#!/bin/bash
# RTK integration for Assistente IA Mac 1.0. Bash 3.2; source, do not execute.
# Host helpers: ask (REPLY), say, warn, pause, header, choose_tool (TOOL),
# run_foreground, bounded_capture (CAPTURE + exit status).
# No credential files are read, copied, printed or written by this library.

rtk_present() {
  command -v rtk >/dev/null 2>&1
}

rtk_version() {
  if ! rtk_present; then
    warn "$(ui 'RTK ainda não está instalado. Use a opção Instalar RTK deste menu.' 'RTK is not installed yet. Use Install RTK in this menu.')"
    return 1
  fi
  if ! bounded_capture 10 rtk --version; then
    warn "$(ui 'O comando rtk foi encontrado, mas não respondeu corretamente.' 'The rtk command was found but did not respond correctly.')"
    return 1
  fi
  say "$CAPTURE"
}

rtk_identity() {
  rtk_version || return 1
  if ! bounded_capture 10 rtk gain; then
    warn "$(ui 'rtk gain falhou: pode ser outro programa chamado rtk ou uma instalação com problema.' 'rtk gain failed: this may be another program named rtk or a broken installation.')"
    say_ui 'Confira o diagnóstico abaixo. O kit não vai substituir esse executável.' 'Check the diagnostics below. The toolkit will not replace this executable.'
    say "$CAPTURE"
    return 1
  fi
  return 0
}

rtk_help_supports() {
  # A missing flag in an old CLI must never silently become a different action.
  local rtk_required="$1"
  local rtk_pattern="(^|[[:space:],])${rtk_required}([[:space:],=<]|$)"
  [[ "$RTK_INIT_HELP" =~ $rtk_pattern ]] && return 0
  warn "$(ui "Esta versão do RTK não anuncia $rtk_required. Atualize o RTK antes desta ação." "This RTK version does not support $rtk_required. Update RTK before this action.")"
  return 1
}

rtk_in_project() (
  # --show includes local integration state: inspect the selected project,
  # not the directory from which Finder happened to launch this kit.
  if [ -n "${PROJECT:-}" ]; then
    cd -- "$PROJECT" || return 1
  fi
  rtk "$@"
)

rtk_show_agent() {
  local rtk_tool="$1"
  local -a rtk_show_args
  rtk_show_args=(init)
  say "$(ui 'Integração' 'Integration') $rtk_tool:"
  rtk_help_supports --show || return 1
  case "$rtk_tool" in
    codex)
      rtk_help_supports --codex || { say_ui 'Estado do Codex não consultado nesta versão.' 'Codex integration status is unavailable in this version.'; return 1; }
      rtk_show_args+=(--codex) ;;
    claude) ;;
    *) return 1 ;;
  esac
  rtk_show_args+=(--show)
  if bounded_capture 10 rtk_in_project "${rtk_show_args[@]}"; then
    say "$CAPTURE"
    return 0
  fi
  say "$CAPTURE"
  warn "$(ui "Não foi possível consultar a integração $rtk_tool; seu estado não foi confirmado." "Could not check the $rtk_tool integration; its status is unconfirmed.")"
  return 1
}

rtk_gains() {
  header_ui 'RTK · economia registrada' 'RTK · recorded savings'
  rtk_identity || return 1
  say "$CAPTURE"
  say ''
  say_ui 'Os números (tokens) são estimativas do texto de comandos que o RTK encurtou.' 'The token numbers estimate the command output shortened by RTK.'
  say_ui 'Essa economia não representa todo o consumo ou o custo da conversa.' 'These savings do not represent total conversation usage or cost.'
  say_ui 'Comando direto no Terminal: rtk gain' 'Direct Terminal command: rtk gain'
}

rtk_command() {
  # Public dispatcher for the launcher. Never forward arbitrary init flags.
  case "${1:-menu}" in
    menu) [ "$#" -le 1 ] && { rtk_menu; return $?; } ;;
    status) [ "$#" -eq 1 ] && { rtk_status; return $?; } ;;
    ganhos|gain) [ "$#" -eq 1 ] && { rtk_gains; return $?; } ;;
    historico|history) [ "$#" -eq 1 ] && { rtk_history; return $?; } ;;
    verificar|verify) [ "$#" -eq 1 ] && { rtk_verify; return $?; } ;;
    monitor|watch) [ "$#" -eq 1 ] && { rtk_monitor; return $?; } ;;
    atualizar|update) [ "$#" -eq 1 ] && { rtk_update; return $?; } ;;
    ativar|enable)
      if [ "$#" -eq 2 ]; then rtk_toggle "$2" ativar; return $?; fi ;;
    desativar|disable)
      if [ "$#" -eq 2 ]; then rtk_toggle "$2" desativar; return $?; fi ;;
  esac
  warn "$(ui 'Uso: --rtk [menu|status|ganhos|historico|verificar|monitor|atualizar|ativar codex|claude|desativar codex|claude]' 'Usage: --rtk [menu|status|gain|history|verify|monitor|update|enable codex|claude|disable codex|claude]')"
  return 2
}

# Somente leitura. O histórico é global e não identifica necessariamente qual
# agente gerou cada comando. Nunca limpe as estatísticas automaticamente.
rtk_history() {
  header_ui 'RTK · últimos comandos registrados' 'RTK · recent recorded commands'
  rtk_identity || return 1
  if ! bounded_capture 10 rtk gain --history; then
    say "$CAPTURE"
    warn "$(ui 'Esta versão do RTK não forneceu o histórico. Confira rtk gain --help.' 'This RTK version did not provide history. Check rtk gain --help.')"
    return 1
  fi
  say "$CAPTURE"
  say_ui 'O histórico é global. Compare horários e atividade no agente' 'History is global. Compare timestamps with agent activity'
  say_ui 'para identificar o uso.' 'to identify usage.'
  say_ui 'Comandos internos Read/Grep/Glob do agente podem não aparecer aqui.' 'Internal Read/Grep/Glob agent commands may not appear here.'
}

# Testa o reescritor SEM executar o comando git e SEM modificar hooks.
# Passar no teste significa que o binário reconhece um comando de exemplo;
# NÃO confirma que o hook foi acionado durante uma conversa real.
rtk_verify() {
  header_ui 'RTK · testar se ele entende um comando (sem executar git)' 'RTK · test command rewriting (without running git)'
  rtk_identity || return 1
  if ! bounded_capture 10 rtk rewrite 'git status'; then
    say "$CAPTURE"
    warn "$(ui 'rtk rewrite falhou; atualize o RTK ou examine rtk --help.' 'rtk rewrite failed; update RTK or check rtk --help.')"
    return 1
  fi
  say "$(ui 'Reescrita retornada' 'Rewritten command'): $CAPTURE"
  case "$CAPTURE" in
    *rtk*git*status*)
      say_ui 'O RTK entendeu o comando. Isso não prova que a ligação com o Codex' 'RTK understood the command. This does not prove that its integration'
      say_ui 'ou o Claude esteja ativa.' 'with Codex or Claude is active.'
      say_ui 'Para conferir de verdade: ative a ligação, reinicie o agente, use um' 'To verify it, enable the integration, restart the agent, run a Git'
      say_ui 'comando Git e abra a opção 8 (histórico) deste menu RTK.' 'command, and open option 8 (history) in this RTK menu.'
      return 0 ;;
    *) warn "$(ui 'A resposta não corresponde à reescrita esperada; confira a versão do RTK.' 'The response does not match the expected rewrite; check the RTK version.')"; return 1 ;;
  esac
}

# Use em uma SEGUNDA janela enquanto o agente continua trabalhando na primeira.
# Esta função deixa o terminal ocupado intencionalmente até Ctrl+C.
rtk_monitor() {
  header_ui 'RTK · monitor ao vivo' 'RTK · live monitor'
  rtk_identity || return 1
  if ! bounded_capture 10 rtk gain --help; then
    warn "$(ui 'Não foi possível consultar os recursos do RTK instalado.' 'Could not check the installed RTK features.')"
    return 1
  fi
  case "$CAPTURE" in
    *--watch*) ;;
    *) warn "$(ui 'Sua versão do RTK não anuncia --watch. Atualize o RTK para usar o monitor.' 'Your RTK version does not support --watch. Update RTK to use the monitor.')"; return 1 ;;
  esac
  say_ui 'Monitor iniciado. Para fechar, pressione Ctrl+C.' 'Monitor started. Press Ctrl+C to close it.'
  say_ui 'As estatísticas são globais e medem a economia estimada nas saídas,' 'Statistics are global and estimate savings in command output,'
  say_ui 'não a conta total da IA.' 'not total AI usage.'
  run_foreground rtk gain --watch
}

# Abre uma janela separada do Terminal, sem alterar preferências ou hooks.
# O executável é passado por variável de ambiente e citado pelo AppleScript,
# evitando que espaços ou caracteres especiais sejam avaliados como shell.
rtk_open_monitor() {
  local rtk_bin
  header_ui 'RTK · monitor em outra janela do Terminal' 'RTK · monitor in another Terminal window'
  rtk_identity || return 1
  if ! bounded_capture 10 rtk gain --help; then
    warn "$(ui 'Não foi possível conferir --watch nesta versão.' 'Could not check --watch support in this version.')"
    return 1
  fi
  case "$CAPTURE" in
    *--watch*) ;;
    *) warn "$(ui 'Sua versão do RTK não suporta --watch.' 'Your RTK version does not support --watch.')"; return 1 ;;
  esac
  rtk_bin="$(command -v rtk)"
  # Se a CLI for uma função shell em vez de um executável, não crie sessão falsa.
  [ -f "$rtk_bin" ] && [ -x "$rtk_bin" ] || {
    warn "$(ui 'Não identifiquei o executável do RTK. Abra outro Terminal e execute: rtk gain --watch' 'Could not identify the RTK executable. Open another Terminal and run: rtk gain --watch')"
    return 1
  }
  if ! command -v osascript >/dev/null 2>&1; then
    warn "$(ui 'AppleScript indisponível. Abra outro Terminal e execute: rtk gain --watch' 'AppleScript is unavailable. Open another Terminal and run: rtk gain --watch')"
    return 1
  fi
  if RTK_MONITOR_BIN="$rtk_bin" osascript \
      -e 'set rtkExecutable to system attribute "RTK_MONITOR_BIN"' \
      -e 'tell application "Terminal"' \
      -e 'activate' \
      -e 'do script ((quoted form of rtkExecutable) & " gain --watch")' \
      -e 'end tell' >/dev/null; then
    say_ui 'Janela do Terminal solicitada com o monitor RTK.' 'Opened a Terminal window for the RTK monitor.'
    say_ui 'Deixe-a aberta e utilize Codex ou Claude na janela do assistente.' 'Leave it open and use Codex or Claude in the assistant window.'
    say_ui 'Para ver quais comandos chegaram ao RTK: opção 8 (histórico) do menu RTK.' 'To see commands received by RTK, open option 8 (history) in the RTK menu.'
  else
    warn "$(ui 'O macOS não abriu a janela (verifique permissões de Automação).' 'macOS did not open the window (check Automation permissions).')"
    say_ui 'Alternativa: abra outra janela do Terminal e execute: rtk gain --watch' 'Alternatively, open another Terminal window and run: rtk gain --watch'
    return 1
  fi
}

rtk_status() {
  local RTK_INIT_HELP='' rtk_status_rc=0
  header_ui 'RTK · situação e economia' 'RTK · status and savings'
  rtk_version || return 1
  say "$(ui 'Executável' 'Executable'): $(command -v rtk)"
  say ''
  say_ui 'Ganhos registrados pelo próprio RTK:' 'Savings recorded by RTK:'
  if ! bounded_capture 10 rtk gain; then
    warn "$(ui 'Economia indisponível. Vou consultar as integrações separadamente.' 'Savings unavailable. Checking integrations separately.')"
    rtk_status_rc=1
  fi
  say "$CAPTURE"
  say ''
  say_ui 'Integrações informadas pelo RTK:' 'Integrations reported by RTK:'
  [ -z "${PROJECT:-}" ] || say "$(ui 'Contexto local' 'Local context'): $PROJECT"
  if ! bounded_capture 10 rtk init --help; then
    say "$CAPTURE"
    warn "$(ui 'Não consegui conferir os comandos desta versão do RTK.' 'Could not check the commands supported by this RTK version.')"
    return 1
  fi
  RTK_INIT_HELP="$CAPTURE"
  rtk_show_agent codex || rtk_status_rc=1
  say ''
  rtk_show_agent claude || rtk_status_rc=1
  say ''
  say_ui 'Instalado e ligado ao agente são coisas diferentes. Leia a situação acima.' 'Installed and connected to an agent are different states. Read the status above.'
  say_ui 'A economia depende dos comandos usados; não é todo o consumo do agente.' 'Savings depend on the commands used; they are not total agent usage.'
  return "$rtk_status_rc"
}

rtk_install_target_exists() {
  [ -e "$HOME/.local/bin/rtk" ] || [ -L "$HOME/.local/bin/rtk" ]
}

# Atualizações: só CONSULTA a última versão publicada; instalar sempre pede
# confirmação. O instalador vem da tag dessa versão, nunca da branch master.
RTK_RELEASES_URL='https://github.com/rtk-ai/rtk/releases/latest'
RTK_CHECK_INTERVAL=86400

rtk_bin_path() { command -v rtk; }
rtk_valid_tag() { [[ "$1" =~ ^v[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$ ]]; }

# Lê a versão pelo redirecionamento de /releases/latest (sem API, sem limite).
rtk_latest_tag() {
  local rtk_line rtk_tag=''
  RTK_LATEST=''
  command -v curl >/dev/null 2>&1 || return 1
  bounded_capture 10 curl --silent --show-error --head --proto '=https' --tlsv1.2 \
    --connect-timeout 5 --max-time 8 "$RTK_RELEASES_URL" || return 1
  while IFS= read -r rtk_line; do
    case "$rtk_line" in [Ll]ocation:*/tag/*) rtk_tag="${rtk_line##*/tag/}"; rtk_tag="${rtk_tag%$'\r'}" ;; esac
  done <<< "$CAPTURE"
  rtk_valid_tag "$rtk_tag" || return 1
  RTK_LATEST="$rtk_tag"
}

# Versão instalada no formato vX.Y.Z em RTK_INSTALLED.
rtk_installed_tag() {
  RTK_INSTALLED=''
  rtk_present || return 1
  bounded_capture 10 rtk --version || return 1
  [[ "$CAPTURE" =~ ([0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}) ]] || return 1
  RTK_INSTALLED="v${BASH_REMATCH[1]}"
}

# Verdadeiro se $1 for mais nova que $2 (as duas validadas antes da comparação).
rtk_tag_newer() {
  local rtk_i
  local -a rtk_a rtk_b
  rtk_valid_tag "$1" && rtk_valid_tag "$2" || return 1
  IFS=. read -r -a rtk_a <<< "${1#v}"
  IFS=. read -r -a rtk_b <<< "${2#v}"
  for rtk_i in 0 1 2; do
    [ "${rtk_a[rtk_i]}" -gt "${rtk_b[rtk_i]}" ] && return 0
    [ "${rtk_a[rtk_i]}" -lt "${rtk_b[rtk_i]}" ] && return 1
  done
  return 1
}

# Cache: uma linha "instalada nova horário", lida só como dados.
rtk_update_cache() { printf '%s' "$STATE_DIR/rtk-atualizacao"; }
rtk_read_cache() {
  local rtk_line='' rtk_i='' rtk_l='' rtk_t=''
  RTK_CACHED_INSTALLED='' RTK_CACHED_LATEST='' RTK_CACHED_AT=''
  [ -f "$(rtk_update_cache)" ] && [ ! -L "$(rtk_update_cache)" ] || return 1
  IFS= read -r rtk_line < "$(rtk_update_cache)" || [ -n "$rtk_line" ] || return 1
  read -r rtk_i rtk_l rtk_t <<< "$rtk_line"
  rtk_valid_tag "$rtk_i" && rtk_valid_tag "$rtk_l" && [[ "$rtk_t" =~ ^[0-9]{1,12}$ ]] || return 1
  RTK_CACHED_INSTALLED="$rtk_i" RTK_CACHED_LATEST="$rtk_l" RTK_CACHED_AT="$rtk_t"
}
rtk_cache_fresh() {
  local rtk_now
  rtk_read_cache || return 1
  rtk_now="$(date +%s)"
  [ "$RTK_CACHED_AT" -le "$rtk_now" ] && [ "$((rtk_now - RTK_CACHED_AT))" -lt "$RTK_CHECK_INTERVAL" ]
}
rtk_check_now() {
  rtk_installed_tag || return 1
  rtk_latest_tag || return 1
  put "$(rtk_update_cache)" "$RTK_INSTALLED $RTK_LATEST $(date +%s)" >/dev/null 2>&1
}

# Ao abrir o assistente: no máximo uma consulta por dia, em segundo plano,
# sem atrasar o menu. Desligável em Ajuda e ajustes → Preferências.
rtk_check_background() {
  [ "${ASSISTENTE_TEST_MODE:-}" != 1 ] || return 0
  opt_enabled atualizacao || return 0
  rtk_present || return 0
  ! rtk_cache_fresh || return 0
  ( rtk_check_now ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
  return 0
}

# Texto curto quando a última consulta achou versão nova; vazio caso contrário.
rtk_update_notice() {
  opt_enabled atualizacao || return 0
  rtk_present || return 0
  rtk_read_cache || return 0
  # Programa trocado depois da consulta (atualizado por fora): aguarda a próxima.
  [ ! "$(rtk_bin_path)" -nt "$(rtk_update_cache)" ] || return 0
  rtk_tag_newer "$RTK_CACHED_LATEST" "$RTK_CACHED_INSTALLED" || return 0
  printf '%s\n' "$(ui "RTK $RTK_CACHED_LATEST disponível (você tem $RTK_CACHED_INSTALLED) → menu 7 → 2 → 10" "RTK $RTK_CACHED_LATEST available (installed: $RTK_CACHED_INSTALLED) → menu 7 → 2 → 10")"
}

# Instalador oficial DA VERSÃO indicada; o próprio script confere o SHA-256.
rtk_run_installer() {
  local rtk_tag="$1" rtk_tmp='' rtk_script='' rtk_rc=0
  rtk_valid_tag "$rtk_tag" || { warn "$(ui 'Versão do RTK inválida; nada foi baixado.' 'Invalid RTK version; nothing was downloaded.')"; return 1; }
  rtk_tmp="$(mktemp -d "${TMPDIR:-/tmp}/assistente-rtk.XXXXXXXX")" || return 1
  rtk_script="$rtk_tmp/install.sh"
  if ! curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
      --tlsv1.2 --connect-timeout 15 --max-time 60 \
      "https://raw.githubusercontent.com/rtk-ai/rtk/$rtk_tag/install.sh" \
      --output "$rtk_script"; then
    warn "$(ui 'Não foi possível baixar o instalador. Verifique a internet.' 'Could not download the installer. Check your internet connection.')"
    rtk_rc=1
  elif ! /bin/sh -n "$rtk_script"; then
    warn "$(ui 'O instalador baixado não passou na verificação de sintaxe.' 'The downloaded installer failed the syntax check.')"
    rtk_rc=1
  else
    # Never inherit a checksum bypass from the invoking shell.
    run_foreground env RTK_EDITION=oss RTK_INSTALL_DIR="$HOME/.local/bin" \
      RTK_SKIP_CHECKSUM=0 RTK_VERSION="$rtk_tag" /bin/sh "$rtk_script" || rtk_rc=$?
  fi
  rm -f "$rtk_script"
  rmdir "$rtk_tmp" 2>/dev/null || true
  return "$rtk_rc"
}

rtk_update() {
  local rtk_bin='' rtk_token
  rtk_token="$(ui ATUALIZAR UPDATE)"
  header_ui 'RTK · verificar e instalar atualização' 'RTK · check for and install an update'
  rtk_identity || return 1
  rtk_installed_tag || { warn "$(ui 'Não consegui ler a versão instalada do RTK.' 'Could not read the installed RTK version.')"; return 1; }
  say_ui 'Consultando a última versão publicada no GitHub do RTK...' 'Checking the latest RTK release on GitHub...'
  rtk_latest_tag || { warn "$(ui 'Não consegui consultar agora (internet ou GitHub indisponível).' 'Could not check now (internet or GitHub unavailable).')"; return 1; }
  put "$(rtk_update_cache)" "$RTK_INSTALLED $RTK_LATEST $(date +%s)" >/dev/null 2>&1
  if ! rtk_tag_newer "$RTK_LATEST" "$RTK_INSTALLED"; then
    say "$(ui "Você já está na versão mais recente ($RTK_INSTALLED)." "You already have the latest version ($RTK_INSTALLED).")"
    return 0
  fi
  say "$(ui "Versão nova: $RTK_LATEST (você tem $RTK_INSTALLED)." "New version: $RTK_LATEST (installed: $RTK_INSTALLED).")"
  rtk_bin="$(rtk_bin_path)"
  if command -v brew >/dev/null 2>&1 && bounded_capture 20 brew list --versions rtk-oss; then
    say_ui 'Instalado pelo Homebrew. Comando: brew upgrade rtk-ai/tap/rtk-oss' 'Installed with Homebrew. Command: brew upgrade rtk-ai/tap/rtk-oss'
    ask "$(ui "Digite $rtk_token para continuar: " "Type $rtk_token to continue: ")" || return 1
    [ "$REPLY" = "$rtk_token" ] || { say_ui 'Atualização cancelada.' 'Update canceled.'; return 0; }
    run_foreground brew upgrade rtk-ai/tap/rtk-oss || return $?
  elif [ "$rtk_bin" = "$HOME/.local/bin/rtk" ]; then
    say "$(ui "Instalado pelo instalador oficial. Vou usar o instalador da versão $RTK_LATEST." "Installed with the official installer. I will use the installer for $RTK_LATEST.")"
    say_ui 'O instalador confere o SHA-256 do programa antes de substituir.' 'The installer checks the program SHA-256 before replacing it.'
    ask "$(ui "Digite $rtk_token para continuar: " "Type $rtk_token to continue: ")" || return 1
    [ "$REPLY" = "$rtk_token" ] || { say_ui 'Atualização cancelada.' 'Update canceled.'; return 0; }
    rtk_run_installer "$RTK_LATEST" || return $?
  else
    warn "$(ui "O rtk em $rtk_bin foi instalado de outro jeito. Atualize pelo mesmo método." "rtk at $rtk_bin was installed another way. Update it with the same method.")"
    return 1
  fi
  rm -f "$(rtk_update_cache)"
  say ''
  say_ui 'Atualização concluída. Versão agora:' 'Update complete. Current version:'
  rtk_version || return 1
  say_ui 'Reinicie as conversas do agente para usar a versão nova.' 'Restart agent conversations to use the new version.'
}

rtk_install() {
  local rtk_method='' rtk_token
  rtk_token="$(ui INSTALAR INSTALL)"
  header_ui 'Instalar RTK OSS' 'Install RTK OSS'
  if rtk_present; then
    say "$(ui 'Já existe rtk em' 'rtk already exists at'): $(command -v rtk)"
    rtk_identity || return 1
    say_ui 'RTK identificado. Para atualizar: opção 10 deste menu RTK.' 'RTK found. To update, use option 10 in this RTK menu.'
    say_ui 'Para usar no agente, escolha Ativar integração neste menu.' 'To use it with an agent, choose Enable integration in this menu.'
    return 0
  fi
  if rtk_install_target_exists; then
    warn "$(ui 'Já existe ~/.local/bin/rtk fora do PATH ou sem permissão de execução.' '~/.local/bin/rtk already exists outside PATH or is not executable.')"
    say_ui 'Confira esse arquivo antes de instalar. O kit não vai sobrescrevê-lo.' 'Check that file before installing. The toolkit will not overwrite it.'
    return 1
  fi
  say_ui 'RTK reduz a saída de comandos enviados ao agente. Não é modelo nem login.' 'RTK shortens command output sent to an agent. It is not a model or login.'
  say_ui 'Edição aberta (OSS): filtros e ligações sob Apache-2.0; sem o motor BUSL.' 'Open source edition: filters and integrations under Apache-2.0, without the BUSL engine.'
  say ''
  say_ui '  1) Instalador oficial · sem precisar de Homebrew' '  1) Official installer · no Homebrew needed'
  say_ui '  2) Homebrew · se já estiver instalado' '  2) Homebrew · if already installed'
  say_ui '  3) Ver documentação oficial' '  3) View official documentation'
  say_ui '  0) Voltar' '  0) Back'
  ask_ui 'Escolha [1]: ' 'Choose [1]: ' || return 1
  rtk_method="${REPLY:-1}"
  case "$rtk_method" in
    0) return 0 ;;
    3)
      say 'https://www.rtk-ai.app/docs/getting-started/installation/'
      return 0 ;;
    1)
      command -v curl >/dev/null 2>&1 || { warn "$(ui 'curl não encontrado.' 'curl was not found.')"; return 1; }
      if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
        warn "$(ui 'Falta um utilitário SHA-256. A instalação foi cancelada.' 'No SHA-256 utility was found. Installation canceled.')"
        return 1
      fi
      say_ui 'Origem: instalador oficial da última versão publicada (não da branch master).' 'Source: official installer from the latest release (not the master branch).'
      say_ui 'Destino: ~/.local/bin/rtk · edição OSS · sem sudo.' 'Destination: ~/.local/bin/rtk · OSS edition · no sudo.'
      say_ui 'O script oficial verifica o SHA-256 do binário baixado.' 'The official script verifies the downloaded binary SHA-256.'
      ask "$(ui "Digite $rtk_token para baixar e executar o instalador oficial: " "Type $rtk_token to download and run the official installer: ")" || return 1
      [ "$REPLY" = "$rtk_token" ] || { say_ui 'Instalação cancelada.' 'Installation canceled.'; return 0; }
      rtk_latest_tag || { warn "$(ui 'Não consegui consultar a última versão. Verifique a internet.' 'Could not check the latest version. Check your internet connection.')"; return 1; }
      say "$(ui 'Versão' 'Version'): $RTK_LATEST"
      rtk_run_installer "$RTK_LATEST" || return $?
      ;;
    2)
      command -v brew >/dev/null 2>&1 || { warn "$(ui 'Homebrew não encontrado. Use o instalador oficial (1).' 'Homebrew was not found. Use the official installer (1).')"; return 1; }
      say_ui 'Comando: brew install rtk-ai/tap/rtk-oss' 'Command: brew install rtk-ai/tap/rtk-oss'
      ask "$(ui "Digite $rtk_token para continuar: " "Type $rtk_token to continue: ")" || return 1
      [ "$REPLY" = "$rtk_token" ] || { say_ui 'Instalação cancelada.' 'Installation canceled.'; return 0; }
      run_foreground brew install rtk-ai/tap/rtk-oss || return $?
      ;;
    *) warn "$(ui 'Escolha uma das opções mostradas.' 'Choose one of the displayed options.')"; return 1 ;;
  esac
  hash -r 2>/dev/null || true
  if rtk_identity; then
    say_ui 'RTK instalado e identificado. A instalação não ligou o RTK aos agentes.' 'RTK is installed and verified. Installation did not connect it to agents.'
    say_ui 'Próximo passo: Ativar integração para Codex ou Claude neste menu.' 'Next: Enable integration for Codex or Claude in this menu.'
  else
    warn "$(ui 'O instalador terminou, mas não foi possível confirmar o RTK.' 'The installer finished, but RTK could not be verified.')"
    say_ui 'Reabra o Terminal e confira rtk --version e rtk gain.' 'Reopen Terminal and check rtk --version and rtk gain.'
    return 1
  fi
}

# --- RTK ligado por padrão -------------------------------------------------
# O estado é lido só com grep -q (nada é impresso). Symlinks são recusados.
rtk_hook_file() {
  case "$1" in
    claude) printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" ;;
    codex) printf '%s' "${CODEX_HOME:-$HOME/.codex}/hooks.json" ;;
    *) return 1 ;;
  esac
}

rtk_hook_active() {
  local rtk_file
  rtk_file="$(rtk_hook_file "$1")" || return 1
  # Só leitura: um link de dotfiles continua sendo uma configuração válida.
  [ -f "$rtk_file" ] || return 1
  /usr/bin/grep -Fq "rtk hook $1" "$rtk_file" 2>/dev/null
}

rtk_off_marker() { printf '%s' "$STATE_DIR/rtk-off-$1"; }
rtk_is_off() { [ -f "$(rtk_off_marker "$1")" ]; }
rtk_mark_off() {
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  put "$(rtk_off_marker "$1")" off >/dev/null 2>&1 || true
}
rtk_mark_on() { rm -f "$(rtk_off_marker "$1")" 2>/dev/null; return 0; }

rtk_state_line() {
  local rtk_tool="${1:-$TOOL}"
  if ! rtk_present; then say_ui 'RTK: não instalado' 'RTK: not installed'; return 0; fi
  if rtk_hook_active "$rtk_tool"; then say_ui 'RTK: ativo ✓' 'RTK: active ✓'
  elif rtk_is_off "$rtk_tool"; then say_ui 'RTK: desligado por você' 'RTK: disabled by you'
  else say_ui 'RTK: instalado, ainda não ativo neste agente' 'RTK: installed, not yet active for this agent'; fi
}

# Nunca bloqueia nem falha o lançamento do agente.
rtk_autostart() {
  if ! rtk_present; then
    say_ui 'RTK: não instalado (menu 7 → 2 instala; opcional).' 'RTK: not installed (menu 7 → 2 installs it; optional).'
    return 0
  fi
  if rtk_hook_active "$TOOL"; then say_ui 'RTK: ativo ✓' 'RTK: active ✓'; return 0; fi
  if rtk_is_off "$TOOL"; then
    say_ui 'RTK: desligado por sua escolha (menu 7 → 2 → 3 religa).' 'RTK: disabled by you (menu 7 → 2 → 3 enables it again).'
    return 0
  fi
  say "$(ui 'RTK não está ativo no' 'RTK is not active for') $TOOL."
  ask_ui 'Ativar agora (muda a configuração global do agente)? [S/n, Enter = sim]: ' 'Enable it now (changes global agent settings)? [Y/n, Enter = yes]: ' || return 0
  case "$REPLY" in
    ''|s|S|sim|Sim|SIM|y|Y|yes|Yes|YES) ;;
    n|N|no|No|NO|nao|não|NAO|NÃO|Nao|Não) rtk_mark_off "$TOOL"; say_ui 'Ok. Não vou perguntar de novo (menu 7 → 2 → 3 religa).' 'OK. I will not ask again (menu 7 → 2 → 3 enables it again).'; return 0 ;;
    *) say_ui 'Resposta não reconhecida: não ativei agora. Vou perguntar de novo na próxima conversa.' 'Unrecognized answer: RTK was not enabled. I will ask again next time.'; return 0 ;;
  esac
  if rtk_toggle "$TOOL" ativar confirmado; then say_ui 'RTK: ativo ✓' 'RTK: active ✓'
  else warn "$(ui 'Não consegui ativar o RTK agora; seguindo sem ele (menu 7 → 2 para tentar de novo).' 'Could not enable RTK now; continuing without it (menu 7 → 2 to retry).')"; fi
  return 0
}

rtk_toggle() {
  local rtk_tool="$1" rtk_action="$2" rtk_confirmed="${3:-}" rtk_token='' rtk_action_en='' rtk_rc=0
  local RTK_INIT_HELP=''
  local -a rtk_args
  rtk_args=(init --global)
  case "$rtk_tool" in
    codex) rtk_args+=(--codex) ;;
    claude) ;;
    *) warn "$(ui 'Ferramenta inválida para a integração RTK.' 'Invalid agent for RTK integration.')"; return 1 ;;
  esac
  case "$rtk_action" in
    ativar) rtk_token="$(ui ATIVAR ENABLE)"; rtk_action_en=enable ;;
    desativar) rtk_args+=(--uninstall); rtk_token="$(ui DESATIVAR DISABLE)"; rtk_action_en=disable ;;
    *) warn "$(ui 'Ação inválida para a integração RTK.' 'Invalid RTK integration action.')"; return 1 ;;
  esac
  [ "$rtk_confirmed" != confirmado ] && header "RTK · $(ui "$rtk_action" "$rtk_action_en") $(ui 'no' 'for') $rtk_tool"
  rtk_identity || return 1
  if ! bounded_capture 10 rtk init --help; then
    say "$CAPTURE"
    warn "$(ui 'Não foi possível conferir os comandos desta versão do RTK.' 'Could not check the commands supported by this RTK version.')"
    return 1
  fi
  RTK_INIT_HELP="$CAPTURE"
  rtk_help_supports --global || return 1
  rtk_help_supports --dry-run || return 1
  rtk_help_supports --show || return 1
  [ "$rtk_tool" != codex ] || rtk_help_supports --codex || return 1
  [ "$rtk_action" != desativar ] || rtk_help_supports --uninstall || return 1
  if [ "$rtk_confirmed" != confirmado ]; then
    say_ui 'Escopo GLOBAL: esta alteração também vale fora deste kit.' 'GLOBAL scope: this change also applies outside this toolkit.'
    say_ui 'Feche as conversas do agente e abra novamente depois da alteração.' 'Close and reopen agent conversations after the change.'
    say_ui 'A ferramenta mantém as verificações de permissão do próprio agente.' 'The agent keeps its own permission checks.'
    say_ui 'Se o RTK oferecer recursos opcionais, leia cada pergunta antes de aceitar.' 'If RTK offers optional features, read each prompt before accepting.'
    say ''
    say_ui 'Prévia oficial das alterações:' 'Official preview of changes:'
  fi
  if ! bounded_capture 15 rtk "${rtk_args[@]}" --dry-run; then
    say "$CAPTURE"
    warn "$(ui 'A prévia falhou. Nenhuma aplicação foi iniciada pelo kit.' 'The preview failed. The toolkit did not apply any changes.')"
    return 1
  fi
  if [ "$rtk_confirmed" != confirmado ]; then
    say "$CAPTURE"
    say ''
    ask "$(ui "Digite $rtk_token para aplicar esta alteração global: " "Type $rtk_token to apply this global change: ")" || return 1
    [ "$REPLY" = "$rtk_token" ] || { say_ui 'Alteração cancelada.' 'Change canceled.'; return 0; }
  fi
  run_foreground rtk "${rtk_args[@]}" || rtk_rc=$?
  if [ "$rtk_rc" -ne 0 ]; then
    warn "$(ui 'O RTK informou um erro. Confira a saída acima antes de tentar novamente.' 'RTK reported an error. Check the output above before retrying.')"
    return "$rtk_rc"
  fi
  if [ "$rtk_action" = desativar ]; then rtk_mark_off "$rtk_tool"; else rtk_mark_on "$rtk_tool"; fi
  say ''
  say_ui 'Comando concluído. Confira os avisos e a situação da ligação abaixo:' 'Command completed. Check the notices and integration status below:'
  if ! rtk_show_agent "$rtk_tool"; then
    warn "$(ui 'Não foi possível confirmar a ligação. Use a opção 2 deste menu RTK.' 'Could not confirm the integration. Use option 2 in this RTK menu.')"
    return 1
  fi
  say_ui 'Reinicie o agente para aplicar. Projetos com ligação própria não mudam.' 'Restart the agent to apply. Projects with their own integration are unchanged.'
  say_ui 'Desativar a integração mantém o programa rtk instalado para uso manual.' 'Disabling integration leaves the rtk program installed for manual use.'
}

rtk_menu() {
  local rtk_choice='' rtk_tool='' rtk_line_codex='' rtk_line_claude='' rtk_notice=''
  while :; do
    header_ui 'RTK · saída compacta para seus agentes' 'RTK · compact output for your agents'
    if rtk_present; then
      say "$(ui 'RTK encontrado em' 'RTK found at'): $(command -v rtk)"
    else
      say_ui 'RTK: ainda não instalado.' 'RTK: not installed yet.'
    fi
    rtk_line_codex="$(rtk_state_line codex)"; rtk_line_claude="$(rtk_state_line claude)"
    say "  Codex:  ${rtk_line_codex#RTK: }"
    say "  Claude: ${rtk_line_claude#RTK: }"
    rtk_notice="$(rtk_update_notice)"
    [ -z "$rtk_notice" ] || say "  $(ui 'Atualização' 'Update'): ${rtk_notice%% →*} → $(ui 'opção' 'option') 10"
    say_ui 'O padrão é RTK ligado: o kit oferece ativar ao abrir uma conversa.' 'RTK is on by default: the kit offers to enable it when opening a conversation.'
    say_ui 'Para parar de ser perguntado: volte e abra Ajuda e ajustes → 4.' 'To stop being asked, go back to Help and settings → 4.'
    say_ui 'A integração automática é configurada separadamente para cada agente.' 'Automatic integration is configured separately for each agent.'
    say ''
    say_ui '  1) Instalar RTK OSS' '  1) Install RTK OSS'
    say_ui '  2) Ver se está funcionando e quanto economizou' '  2) Check status and savings'
    say_ui '  3) Ativar integração em um agente' '  3) Enable integration for an agent'
    say_ui '  4) Desativar integração em um agente' '  4) Disable integration for an agent'
    say_ui '  5) Entender o RTK' '  5) Understand RTK'
    say_ui '  6) Ver somente a economia (rtk gain)' '  6) View savings only (rtk gain)'
    say_ui '  7) Abrir monitor RTK ao vivo em outra janela' '  7) Open live RTK monitor in another window'
    say_ui '  8) Ver últimos comandos RTK (histórico)' '  8) View recent RTK commands (history)'
    say_ui '  9) Testar se o RTK entende um comando (não executa git)' '  9) Test whether RTK understands a command (does not run git)'
    say_ui ' 10) Atualizar RTK (verifica se há versão nova)' ' 10) Update RTK (check for a new version)'
    say_ui '  0) Voltar' '  0) Back'
    ask_ui 'Escolha: ' 'Choose: ' || return 1
    rtk_choice="$REPLY"
    case "$rtk_choice" in
      0|'') return 0 ;;
      1) rtk_install; pause || return 1 ;;
      2) rtk_status; pause || return 1 ;;
      6) rtk_gains; pause || return 1 ;;
      7) rtk_open_monitor; pause || return 1 ;;
      8) rtk_history; pause || return 1 ;;
      9) rtk_verify; pause || return 1 ;;
      10) rtk_update; pause || return 1 ;;
      3|4)
        choose_tool || continue
        rtk_tool="$TOOL"
        if [ "$rtk_choice" = 3 ]; then rtk_toggle "$rtk_tool" ativar
        else rtk_toggle "$rtk_tool" desativar; fi
        pause || return 1
        ;;
      5)
        say ''
        say_ui 'O RTK encurta a saída de comandos do agente (textos repetitivos).' 'RTK shortens repetitive agent command output.'
        say_ui 'Exemplo: um git status é executado como rtk git status.' 'Example: git status is run as rtk git status.'
        say_ui 'Use os agentes normalmente depois de instalar e ativar o RTK.' 'Use the agents normally after installing and enabling RTK.'
        say_ui 'Ele não muda sua conta nem escolhe modelos, e não garante uma' 'It does not change your account or choose models, and it cannot'
        say_ui 'economia fixa.' 'guarantee a fixed saving.'
        say_ui 'Ele funciona sem nenhum programa rodando em segundo plano no macOS.' 'It runs without a macOS background service.'
        say_ui 'Monitor em outra janela: opção 7 deste menu RTK, ou rtk gain --watch' 'Monitor in another window: option 7 here, or rtk gain --watch'
        say_ui 'em um Terminal separado.' 'in a separate Terminal.'
        say_ui 'Uso real: rtk gain --history (opção 8 deste menu RTK); teste de' 'Actual usage: rtk gain --history (option 8 here); test command'
        say_ui 'entendimento do comando: opção 9.' 'rewriting with option 9.'
        say_ui 'Economia: rtk gain · situação Codex: rtk init --codex --show' 'Savings: rtk gain · Codex status: rtk init --codex --show'
        say_ui 'Situação Claude: rtk init --show' 'Claude status: rtk init --show'
        say_ui 'Se uma saída compactada esconder um detalhe, confira a saída original.' 'If compact output hides detail, check the original output.'
        say_ui 'Documentação: https://www.rtk-ai.app/docs/getting-started/quick-start/' 'Documentation: https://www.rtk-ai.app/docs/getting-started/quick-start/'
        pause || return 1
        ;;
      *) warn 'Escolha uma das opções mostradas.'; pause || return 1 ;;
    esac
  done
}
