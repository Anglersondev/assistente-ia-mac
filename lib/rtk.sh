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
    warn 'RTK ainda não está instalado. Use a opção Instalar RTK deste menu.'
    return 1
  fi
  if ! bounded_capture 10 rtk --version; then
    warn 'O comando rtk foi encontrado, mas não respondeu corretamente.'
    return 1
  fi
  say "$CAPTURE"
}

rtk_identity() {
  rtk_version || return 1
  if ! bounded_capture 10 rtk gain; then
    warn 'rtk gain falhou: pode ser outro programa chamado rtk ou uma instalação com problema.'
    say 'Confira o diagnóstico abaixo. O kit não vai substituir esse executável.'
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
  warn "Esta versão do RTK não anuncia $rtk_required. Atualize o RTK antes desta ação."
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
  say "Integração $rtk_tool:"
  rtk_help_supports --show || return 1
  case "$rtk_tool" in
    codex)
      rtk_help_supports --codex || { say 'Estado do Codex não consultado nesta versão.'; return 1; }
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
  warn "Não foi possível consultar a integração $rtk_tool; seu estado não foi confirmado."
  return 1
}

rtk_gains() {
  header 'RTK · economia registrada'
  rtk_identity || return 1
  say "$CAPTURE"
  say ''
  say 'Os números (tokens) são estimativas do texto de comandos que o RTK encurtou.'
  say 'Essa economia não representa todo o consumo ou o custo da conversa.'
  say 'Comando direto no Terminal: rtk gain'
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
    ativar|desativar)
      if [ "$#" -eq 2 ]; then rtk_toggle "$2" "$1"; return $?; fi ;;
  esac
  warn 'Uso: --rtk [menu|status|ganhos|historico|verificar|monitor|atualizar|ativar codex|ativar claude|desativar codex|desativar claude]'
  return 2
}

# Somente leitura. O histórico é global e não identifica necessariamente qual
# agente gerou cada comando. Nunca limpe as estatísticas automaticamente.
rtk_history() {
  header 'RTK · últimos comandos registrados'
  rtk_identity || return 1
  if ! bounded_capture 10 rtk gain --history; then
    say "$CAPTURE"
    warn 'Esta versão do RTK não forneceu o histórico. Confira rtk gain --help.'
    return 1
  fi
  say "$CAPTURE"
  say 'O histórico é global. Compare horários e atividade no agente'
  say 'para identificar o uso.'
  say 'Comandos internos Read/Grep/Glob do agente podem não aparecer aqui.'
}

# Testa o reescritor SEM executar o comando git e SEM modificar hooks.
# Passar no teste significa que o binário reconhece um comando de exemplo;
# NÃO confirma que o hook foi acionado durante uma conversa real.
rtk_verify() {
  header 'RTK · testar se ele entende um comando (sem executar git)'
  rtk_identity || return 1
  if ! bounded_capture 10 rtk rewrite 'git status'; then
    say "$CAPTURE"
    warn 'rtk rewrite falhou; atualize o RTK ou examine rtk --help.'
    return 1
  fi
  say "Reescrita retornada: $CAPTURE"
  case "$CAPTURE" in
    *rtk*git*status*)
      say 'O RTK entendeu o comando. Isso não prova que a ligação com o Codex'
      say 'ou o Claude esteja ativa.'
      say 'Para conferir de verdade: ative a ligação, reinicie o agente, use um'
      say 'comando Git e abra a opção 8 (histórico) deste menu RTK.'
      return 0 ;;
    *) warn 'A resposta não corresponde à reescrita esperada; confira a versão do RTK.'; return 1 ;;
  esac
}

# Use em uma SEGUNDA janela enquanto o agente continua trabalhando na primeira.
# Esta função deixa o terminal ocupado intencionalmente até Ctrl+C.
rtk_monitor() {
  header 'RTK · monitor ao vivo'
  rtk_identity || return 1
  if ! bounded_capture 10 rtk gain --help; then
    warn 'Não foi possível consultar os recursos do RTK instalado.'
    return 1
  fi
  case "$CAPTURE" in
    *--watch*) ;;
    *) warn 'Sua versão do RTK não anuncia --watch. Atualize o RTK para usar o monitor.'; return 1 ;;
  esac
  say 'Monitor iniciado. Para fechar, pressione Ctrl+C.'
  say 'As estatísticas são globais e medem a economia estimada nas saídas,'
  say 'não a conta total da IA.'
  run_foreground rtk gain --watch
}

# Abre uma janela separada do Terminal, sem alterar preferências ou hooks.
# O executável é passado por variável de ambiente e citado pelo AppleScript,
# evitando que espaços ou caracteres especiais sejam avaliados como shell.
rtk_open_monitor() {
  local rtk_bin
  header 'RTK · monitor em outra janela do Terminal'
  rtk_identity || return 1
  if ! bounded_capture 10 rtk gain --help; then
    warn 'Não foi possível conferir --watch nesta versão.'
    return 1
  fi
  case "$CAPTURE" in
    *--watch*) ;;
    *) warn 'Sua versão do RTK não suporta --watch.'; return 1 ;;
  esac
  rtk_bin="$(command -v rtk)"
  # Se a CLI for uma função shell em vez de um executável, não crie sessão falsa.
  [ -f "$rtk_bin" ] && [ -x "$rtk_bin" ] || {
    warn 'Não identifiquei o executável do RTK. Abra outro Terminal e execute: rtk gain --watch'
    return 1
  }
  if ! command -v osascript >/dev/null 2>&1; then
    warn 'AppleScript indisponível. Abra outro Terminal e execute: rtk gain --watch'
    return 1
  fi
  if RTK_MONITOR_BIN="$rtk_bin" osascript \
      -e 'set rtkExecutable to system attribute "RTK_MONITOR_BIN"' \
      -e 'tell application "Terminal"' \
      -e 'activate' \
      -e 'do script ((quoted form of rtkExecutable) & " gain --watch")' \
      -e 'end tell' >/dev/null; then
    say 'Janela do Terminal solicitada com o monitor RTK.'
    say 'Deixe-a aberta e utilize Codex ou Claude na janela do assistente.'
    say 'Para ver quais comandos chegaram ao RTK: opção 8 (histórico) do menu RTK.'
  else
    warn 'O macOS não abriu a janela (verifique permissões de Automação).'
    say 'Alternativa: abra outra janela do Terminal e execute: rtk gain --watch'
    return 1
  fi
}

rtk_status() {
  local RTK_INIT_HELP='' rtk_status_rc=0
  header 'RTK · situação e economia'
  rtk_version || return 1
  say "Executável: $(command -v rtk)"
  say ''
  say 'Ganhos registrados pelo próprio RTK:'
  if ! bounded_capture 10 rtk gain; then
    warn 'Economia indisponível. Vou consultar as integrações separadamente.'
    rtk_status_rc=1
  fi
  say "$CAPTURE"
  say ''
  say 'Integrações informadas pelo RTK:'
  [ -z "${PROJECT:-}" ] || say "Contexto local: $PROJECT"
  if ! bounded_capture 10 rtk init --help; then
    say "$CAPTURE"
    warn 'Não consegui conferir os comandos desta versão do RTK.'
    return 1
  fi
  RTK_INIT_HELP="$CAPTURE"
  rtk_show_agent codex || rtk_status_rc=1
  say ''
  rtk_show_agent claude || rtk_status_rc=1
  say ''
  say 'Instalado e ligado ao agente são coisas diferentes. Leia a situação acima.'
  say 'A economia depende dos comandos usados; não é todo o consumo do agente.'
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
  printf 'RTK %s disponível (você tem %s) → menu 7 → 2 → 10\n' "$RTK_CACHED_LATEST" "$RTK_CACHED_INSTALLED"
}

# Instalador oficial DA VERSÃO indicada; o próprio script confere o SHA-256.
rtk_run_installer() {
  local rtk_tag="$1" rtk_tmp='' rtk_script='' rtk_rc=0
  rtk_valid_tag "$rtk_tag" || { warn 'Versão do RTK inválida; nada foi baixado.'; return 1; }
  rtk_tmp="$(mktemp -d "${TMPDIR:-/tmp}/assistente-rtk.XXXXXXXX")" || return 1
  rtk_script="$rtk_tmp/install.sh"
  if ! curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
      --tlsv1.2 --connect-timeout 15 --max-time 60 \
      "https://raw.githubusercontent.com/rtk-ai/rtk/$rtk_tag/install.sh" \
      --output "$rtk_script"; then
    warn 'Não foi possível baixar o instalador. Verifique a internet.'
    rtk_rc=1
  elif ! /bin/sh -n "$rtk_script"; then
    warn 'O instalador baixado não passou na verificação de sintaxe.'
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
  local rtk_bin=''
  header 'RTK · verificar e instalar atualização'
  rtk_identity || return 1
  rtk_installed_tag || { warn 'Não consegui ler a versão instalada do RTK.'; return 1; }
  say 'Consultando a última versão publicada no GitHub do RTK...'
  rtk_latest_tag || { warn 'Não consegui consultar agora (internet ou GitHub indisponível).'; return 1; }
  put "$(rtk_update_cache)" "$RTK_INSTALLED $RTK_LATEST $(date +%s)" >/dev/null 2>&1
  if ! rtk_tag_newer "$RTK_LATEST" "$RTK_INSTALLED"; then
    say "Você já está na versão mais recente ($RTK_INSTALLED)."
    return 0
  fi
  say "Versão nova: $RTK_LATEST (você tem $RTK_INSTALLED)."
  rtk_bin="$(rtk_bin_path)"
  if command -v brew >/dev/null 2>&1 && bounded_capture 20 brew list --versions rtk-oss; then
    say 'Instalado pelo Homebrew. Comando: brew upgrade rtk-ai/tap/rtk-oss'
    ask 'Digite ATUALIZAR para continuar: ' || return 1
    [ "$REPLY" = ATUALIZAR ] || { say 'Atualização cancelada.'; return 0; }
    run_foreground brew upgrade rtk-ai/tap/rtk-oss || return $?
  elif [ "$rtk_bin" = "$HOME/.local/bin/rtk" ]; then
    say "Instalado pelo instalador oficial. Vou usar o instalador da versão $RTK_LATEST."
    say 'O instalador confere o SHA-256 do programa antes de substituir.'
    ask 'Digite ATUALIZAR para continuar: ' || return 1
    [ "$REPLY" = ATUALIZAR ] || { say 'Atualização cancelada.'; return 0; }
    rtk_run_installer "$RTK_LATEST" || return $?
  else
    warn "O rtk em $rtk_bin foi instalado de outro jeito. Atualize pelo mesmo método."
    return 1
  fi
  rm -f "$(rtk_update_cache)"
  say ''
  say 'Atualização concluída. Versão agora:'
  rtk_version || return 1
  say 'Reinicie as conversas do agente para usar a versão nova.'
}

rtk_install() {
  local rtk_method=''
  header 'Instalar RTK OSS'
  if rtk_present; then
    say "Já existe rtk em: $(command -v rtk)"
    rtk_identity || return 1
    say 'RTK identificado. Para atualizar: opção 10 deste menu RTK.'
    say 'Para usar no agente, escolha Ativar integração neste menu.'
    return 0
  fi
  if rtk_install_target_exists; then
    warn 'Já existe ~/.local/bin/rtk fora do PATH ou sem permissão de execução.'
    say 'Confira esse arquivo antes de instalar. O kit não vai sobrescrevê-lo.'
    return 1
  fi
  say 'RTK reduz a saída de comandos enviados ao agente. Não é modelo nem login.'
  say 'Edição aberta (OSS): filtros e ligações sob Apache-2.0; sem o motor BUSL.'
  say ''
  say '  1) Instalador oficial · sem precisar de Homebrew'
  say '  2) Homebrew · se já estiver instalado'
  say '  3) Ver documentação oficial'
  say '  0) Voltar'
  ask 'Escolha [1]: ' || return 1
  rtk_method="${REPLY:-1}"
  case "$rtk_method" in
    0) return 0 ;;
    3)
      say 'https://www.rtk-ai.app/docs/getting-started/installation/'
      return 0 ;;
    1)
      command -v curl >/dev/null 2>&1 || { warn 'curl não encontrado.'; return 1; }
      if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
        warn 'Falta um utilitário SHA-256. A instalação foi cancelada.'
        return 1
      fi
      say 'Origem: instalador oficial da última versão publicada (não da branch master).'
      say 'Destino: ~/.local/bin/rtk · edição OSS · sem sudo.'
      say 'O script oficial verifica o SHA-256 do binário baixado.'
      ask 'Digite INSTALAR para baixar e executar o instalador oficial: ' || return 1
      [ "$REPLY" = INSTALAR ] || { say 'Instalação cancelada.'; return 0; }
      rtk_latest_tag || { warn 'Não consegui consultar a última versão. Verifique a internet.'; return 1; }
      say "Versão: $RTK_LATEST"
      rtk_run_installer "$RTK_LATEST" || return $?
      ;;
    2)
      command -v brew >/dev/null 2>&1 || { warn 'Homebrew não encontrado. Use o instalador oficial (1).'; return 1; }
      say 'Comando: brew install rtk-ai/tap/rtk-oss'
      ask 'Digite INSTALAR para continuar: ' || return 1
      [ "$REPLY" = INSTALAR ] || { say 'Instalação cancelada.'; return 0; }
      run_foreground brew install rtk-ai/tap/rtk-oss || return $?
      ;;
    *) warn 'Escolha uma das opções mostradas.'; return 1 ;;
  esac
  hash -r 2>/dev/null || true
  if rtk_identity; then
    say 'RTK instalado e identificado. A instalação não ligou o RTK aos agentes.'
    say 'Próximo passo: Ativar integração para Codex ou Claude neste menu.'
  else
    warn 'O instalador terminou, mas não foi possível confirmar o RTK.'
    say 'Reabra o Terminal e confira rtk --version e rtk gain.'
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
  if ! rtk_present; then say 'RTK: não instalado'; return 0; fi
  if rtk_hook_active "$rtk_tool"; then say 'RTK: ativo ✓'
  elif rtk_is_off "$rtk_tool"; then say 'RTK: desligado por você'
  else say 'RTK: instalado, ainda não ativo neste agente'; fi
}

# Nunca bloqueia nem falha o lançamento do agente.
rtk_autostart() {
  if ! rtk_present; then
    say 'RTK: não instalado (menu 7 → 2 instala; opcional).'
    return 0
  fi
  if rtk_hook_active "$TOOL"; then say 'RTK: ativo ✓'; return 0; fi
  if rtk_is_off "$TOOL"; then
    say 'RTK: desligado por sua escolha (menu 7 → 2 → 3 religa).'
    return 0
  fi
  say "RTK não está ativo no $TOOL."
  ask 'Ativar agora (muda a configuração global do agente)? [S/n, Enter = sim]: ' || return 0
  case "$REPLY" in
    ''|s|S|sim|Sim|SIM) ;;
    n|N|nao|não|NAO|NÃO|Nao|Não) rtk_mark_off "$TOOL"; say 'Ok. Não vou perguntar de novo (menu 7 → 2 → 3 religa).'; return 0 ;;
    *) say 'Resposta não reconhecida: não ativei agora. Vou perguntar de novo na próxima conversa.'; return 0 ;;
  esac
  if rtk_toggle "$TOOL" ativar confirmado; then say 'RTK: ativo ✓'
  else warn 'Não consegui ativar o RTK agora; seguindo sem ele (menu 7 → 2 para tentar de novo).'; fi
  return 0
}

rtk_toggle() {
  local rtk_tool="$1" rtk_action="$2" rtk_confirmed="${3:-}" rtk_token='' rtk_rc=0
  local RTK_INIT_HELP=''
  local -a rtk_args
  rtk_args=(init --global)
  case "$rtk_tool" in
    codex) rtk_args+=(--codex) ;;
    claude) ;;
    *) warn 'Ferramenta inválida para a integração RTK.'; return 1 ;;
  esac
  case "$rtk_action" in
    ativar) rtk_token=ATIVAR ;;
    desativar) rtk_args+=(--uninstall); rtk_token=DESATIVAR ;;
    *) warn 'Ação inválida para a integração RTK.'; return 1 ;;
  esac
  [ "$rtk_confirmed" != confirmado ] && header "RTK · $rtk_action no $rtk_tool"
  rtk_identity || return 1
  if ! bounded_capture 10 rtk init --help; then
    say "$CAPTURE"
    warn 'Não foi possível conferir os comandos desta versão do RTK.'
    return 1
  fi
  RTK_INIT_HELP="$CAPTURE"
  rtk_help_supports --global || return 1
  rtk_help_supports --dry-run || return 1
  rtk_help_supports --show || return 1
  [ "$rtk_tool" != codex ] || rtk_help_supports --codex || return 1
  [ "$rtk_action" != desativar ] || rtk_help_supports --uninstall || return 1
  if [ "$rtk_confirmed" != confirmado ]; then
    say 'Escopo GLOBAL: esta alteração também vale fora deste kit.'
    say 'Feche as conversas do agente e abra novamente depois da alteração.'
    say 'A ferramenta mantém as verificações de permissão do próprio agente.'
    say 'Se o RTK oferecer recursos opcionais, leia cada pergunta antes de aceitar.'
    say ''
    say 'Prévia oficial das alterações:'
  fi
  if ! bounded_capture 15 rtk "${rtk_args[@]}" --dry-run; then
    say "$CAPTURE"
    warn 'A prévia falhou. Nenhuma aplicação foi iniciada pelo kit.'
    return 1
  fi
  if [ "$rtk_confirmed" != confirmado ]; then
    say "$CAPTURE"
    say ''
    ask "Digite $rtk_token para aplicar esta alteração global: " || return 1
    [ "$REPLY" = "$rtk_token" ] || { say 'Alteração cancelada.'; return 0; }
  fi
  run_foreground rtk "${rtk_args[@]}" || rtk_rc=$?
  if [ "$rtk_rc" -ne 0 ]; then
    warn 'O RTK informou um erro. Confira a saída acima antes de tentar novamente.'
    return "$rtk_rc"
  fi
  if [ "$rtk_action" = desativar ]; then rtk_mark_off "$rtk_tool"; else rtk_mark_on "$rtk_tool"; fi
  say ''
  say 'Comando concluído. Confira os avisos e a situação da ligação abaixo:'
  if ! rtk_show_agent "$rtk_tool"; then
    warn 'Não foi possível confirmar a ligação. Use a opção 2 deste menu RTK.'
    return 1
  fi
  say 'Reinicie o agente para aplicar. Projetos com ligação própria não mudam.'
  say 'Desativar a integração mantém o programa rtk instalado para uso manual.'
}

rtk_menu() {
  local rtk_choice='' rtk_tool='' rtk_line_codex='' rtk_line_claude='' rtk_notice=''
  while :; do
    header 'RTK · saída compacta para seus agentes'
    if rtk_present; then
      say "RTK encontrado em: $(command -v rtk)"
    else
      say 'RTK: ainda não instalado.'
    fi
    rtk_line_codex="$(rtk_state_line codex)"; rtk_line_claude="$(rtk_state_line claude)"
    say "  Codex:  ${rtk_line_codex#RTK: }"
    say "  Claude: ${rtk_line_claude#RTK: }"
    rtk_notice="$(rtk_update_notice)"
    [ -z "$rtk_notice" ] || say "  Atualização: ${rtk_notice%% →*} → opção 10"
    say 'O padrão é RTK ligado: o kit oferece ativar ao abrir uma conversa.'
    say 'Para parar de ser perguntado: volte e abra Ajuda e ajustes → 4.'
    say 'A integração automática é configurada separadamente para cada agente.'
    say ''
    say '  1) Instalar RTK OSS'
    say '  2) Ver se está funcionando e quanto economizou'
    say '  3) Ativar integração em um agente'
    say '  4) Desativar integração em um agente'
    say '  5) Entender o RTK'
    say '  6) Ver somente a economia (rtk gain)'
    say '  7) Abrir monitor RTK ao vivo em outra janela'
    say '  8) Ver últimos comandos RTK (histórico)'
    say '  9) Testar se o RTK entende um comando (não executa git)'
    say ' 10) Atualizar RTK (verifica se há versão nova)'
    say '  0) Voltar'
    ask 'Escolha: ' || return 1
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
        say 'O RTK encurta a saída de comandos do agente (textos repetitivos).'
        say 'Exemplo: um git status é executado como rtk git status.'
        say 'Use os agentes normalmente depois de instalar e ativar o RTK.'
        say 'Ele não muda sua conta nem escolhe modelos, e não garante uma'
        say 'economia fixa.'
        say 'Ele funciona sem nenhum programa rodando em segundo plano no macOS.'
        say 'Monitor em outra janela: opção 7 deste menu RTK, ou rtk gain --watch'
        say 'em um Terminal separado.'
        say 'Uso real: rtk gain --history (opção 8 deste menu RTK); teste de'
        say 'entendimento do comando: opção 9.'
        say 'Economia: rtk gain · situação Codex: rtk init --codex --show'
        say 'Situação Claude: rtk init --show'
        say 'Se uma saída compactada esconder um detalhe, confira a saída original.'
        say 'Documentação: https://www.rtk-ai.app/docs/getting-started/quick-start/'
        pause || return 1
        ;;
      *) warn 'Escolha uma das opções mostradas.'; pause || return 1 ;;
    esac
  done
}
