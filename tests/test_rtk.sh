#!/bin/bash
# Regression checks using fake RTK/curl only. No installation or account changes.
set -o pipefail
TEST_PARENT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$TEST_PARENT/ASSISTENTE-IA-MAC.command" ]; then
  TEST_DEFAULT_KIT="$TEST_PARENT"
else
  TEST_DEFAULT_KIT="$TEST_PARENT/outputs/Assistente-IA-Mac-1.0"
fi
TEST_KIT="${1:-$TEST_DEFAULT_KIT}"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/assistente-rtk-test.XXXXXXXX")" || exit 1
trap 'rm -rf "$TEST_TMP"' EXIT
ASSISTENTE_TEST_MODE=1
ASSISTENTE_STATE_DIR="$TEST_TMP/state"
source "$TEST_KIT/ASSISTENTE-IA-MAC.command" || exit 1
TEST_LOG="$TEST_TMP/events.log"
TEST_LATEST_LINE='location: https://github.com/rtk-ai/rtk/releases/tag/v1.0.1'
TEST_BREW_HAS=1 TEST_BIN_PATH=rtk
TEST_PASSES=0 TEST_FAILURES=0 TEST_AVAILABLE=1 TEST_GAIN_FAIL=0 TEST_DRY_FAIL=0 TEST_APPLY_FAIL=0 TEST_CURL_FAIL=0 TEST_SHOW_FAIL=0 TEST_CODEX_SHOW_FAIL=0
TEST_HELP='--global --codex --dry-run --uninstall --show'
log_call() { local item; for item in "$@"; do printf '%s|' "$item" >> "$TEST_LOG"; done; printf '\n' >> "$TEST_LOG"; }
rtk() {
  log_call rtk "$@"
  case "$*" in
    '--version') printf 'rtk 0.40.0\n'; return 0 ;;
    gain) printf 'Ganhos: exemplo simulado\n'; return "$TEST_GAIN_FAIL" ;;
    'gain --history') printf 'Ultimos comandos simulados\n'; return 0 ;;
    'gain --help') printf '%s\n' '--watch --history'; return 0 ;;
    'gain --watch') printf 'Monitor simulado\n'; return 0 ;;
    'rewrite git status') printf 'rtk git status\n'; return 0 ;;
    'init --help') printf '%s\n' "$TEST_HELP"; return 0 ;;
    'init --show') log_call show-context "$(pwd -P)"; printf 'Hooks: exemplo simulado\n'; return "$TEST_SHOW_FAIL" ;;
    'init --codex --show') log_call codex-show-context "$(pwd -P)"; printf 'Hooks Codex: exemplo simulado\n'; return "$TEST_CODEX_SHOW_FAIL" ;;
    *--dry-run*) printf '[dry-run] Nothing written.\n'; return "$TEST_DRY_FAIL" ;;
    init*) return "$TEST_APPLY_FAIL" ;;
  esac
  return 2
}
rtk_present() { [ "$TEST_AVAILABLE" -eq 1 ]; }
rtk_bin_path() { printf '%s\n' "$TEST_BIN_PATH"; }
# Homebrew simulado: nunca executa o brew real da máquina.
brew() { log_call brew "$@"; [ "$1" != list ] || return "$TEST_BREW_HAS"; return 0; }
# Model installation collisions with a disposable file. All installers and
# network calls are simulated; no need to change HOME or touch its files.
rtk_install_target_exists() { [ -e "$TEST_TMP/existing-rtk" ]; }
curl() {
  log_call curl "$@"
  [ "$TEST_CURL_FAIL" -eq 0 ] || return 22
  case " $* " in *' --head '*) printf 'HTTP/2 302\r\n%s\r\n' "$TEST_LATEST_LINE"; return 0 ;; esac
  local previous='' arg dest=''
  for arg in "$@"; do [ "$previous" != --output ] || dest="$arg"; previous="$arg"; done
  [ -n "$dest" ] || return 1
  printf '#!/bin/sh\nexit 0\n' > "$dest"
}
run_foreground() {
  if [ "$1" = env ]; then log_call foreground "$@"; TEST_AVAILABLE=1; return 0; fi
  "$@"
}
# Hide only the program's screen drawing. Queries use the real bounded_capture.
say() { :; }; warn() { :; }; header() { :; }
log_has() {
  local candidate
  [ -f "$TEST_LOG" ] || return 1
  while IFS= read -r candidate; do [ "$candidate" != "$1" ] || return 0; done < "$TEST_LOG"
  return 1
}
log_lacks() { ! log_has "$1"; }
log_prefix() {
  local candidate
  [ -f "$TEST_LOG" ] || return 1
  while IFS= read -r candidate; do case "$candidate" in "$1"*) return 0 ;; esac; done < "$TEST_LOG"
  return 1
}
log_no_prefix() { ! log_prefix "$1"; }
log_prefix_any() { [ -f "$TEST_LOG" ] && case "$(cat "$TEST_LOG")" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
test_not() { ! "$@"; }
log_order() {
  local candidate position=0 first=0 second=0
  while IFS= read -r candidate; do
    position=$((position+1))
    [ "$candidate" != "$1" ] || first="$position"
    [ "$candidate" != "$2" ] || second="$position"
  done < "$TEST_LOG"
  [ "$first" -gt 0 ] && [ "$second" -gt "$first" ]
}
check() {
  local label="$1"; shift
  if "$@"; then TEST_PASSES=$((TEST_PASSES+1)); printf 'PASS %s\n' "$label"
  else TEST_FAILURES=$((TEST_FAILURES+1)); printf 'FAIL %s\n' "$label"; fi
}
: > "$TEST_LOG"
rtk_toggle codex ativar <<< 'ATIVAR'
check 'Codex activation flags' log_has 'rtk|init|--global|--codex|'
check 'Codex preview before application' log_order 'rtk|init|--global|--codex|--dry-run|' 'rtk|init|--global|--codex|'
check 'Codex status consulted after application' log_order 'rtk|init|--global|--codex|' 'rtk|init|--codex|--show|'
check 'Codex verification does not use Claude status' log_lacks 'rtk|init|--show|'
: > "$TEST_LOG"
rtk_toggle claude ativar <<< 'ATIVAR'
check 'Claude activation flags' log_has 'rtk|init|--global|'
check 'Claude status consulted after application' log_order 'rtk|init|--global|' 'rtk|init|--show|'
check 'Claude activation does not use Codex flag' log_lacks 'rtk|init|--global|--codex|'
: > "$TEST_LOG"
rtk_toggle codex desativar <<< 'DESATIVAR'
check 'Codex deactivation flags' log_has 'rtk|init|--global|--codex|--uninstall|'
check 'Codex deactivation preview' log_order 'rtk|init|--global|--codex|--uninstall|--dry-run|' 'rtk|init|--global|--codex|--uninstall|'
: > "$TEST_LOG"
rtk_toggle claude desativar <<< 'DESATIVAR'
check 'Claude deactivation flags' log_has 'rtk|init|--global|--uninstall|'
: > "$TEST_LOG"
rtk_toggle codex ativar <<< 'NAO'
check 'Cancellation never applies integration' log_lacks 'rtk|init|--global|--codex|'
: > "$TEST_LOG"
rtk_toggle codex ativar < /dev/null
check 'EOF never applies integration' log_lacks 'rtk|init|--global|--codex|'
: > "$TEST_LOG"; TEST_DRY_FAIL=1
rtk_toggle codex ativar <<< 'ATIVAR'
check 'Failed preview aborts action' test "$?" -ne 0
check 'Failed preview never applies' log_lacks 'rtk|init|--global|--codex|'
TEST_DRY_FAIL=0; TEST_HELP='--global --dry-run --uninstall --show'; : > "$TEST_LOG"
rtk_toggle codex ativar <<< 'ATIVAR'
check 'Missing Codex flag aborts action' test "$?" -ne 0
check 'Missing flag never applies' log_lacks 'rtk|init|--global|--codex|'
TEST_HELP='--global --codex-other --dry-run --uninstall --show'; : > "$TEST_LOG"
rtk_toggle codex ativar <<< 'ATIVAR'
check 'Similar flag name cannot impersonate Codex support' test "$?" -ne 0
check 'Similar flag never applies' log_lacks 'rtk|init|--global|--codex|'
TEST_HELP='--global --codex --dry-run --uninstall --show'; TEST_GAIN_FAIL=1; : > "$TEST_LOG"
rtk_toggle codex ativar <<< 'ATIVAR'
check 'Wrong binary or failed gain aborts action' test "$?" -ne 0
check 'Failed identity never applies' log_lacks 'rtk|init|--global|--codex|'
TEST_GAIN_FAIL=0; TEST_APPLY_FAIL=1; : > "$TEST_LOG"
rtk_toggle claude ativar <<< 'ATIVAR'
check 'RTK application failure is propagated' test "$?" -ne 0
TEST_APPLY_FAIL=0
rtk_toggle unknown ativar < /dev/null
check 'Unknown tool rejected' test "$?" -ne 0
: > "$TEST_LOG"; TEST_HELP='--global --codex --dry-run --uninstall --show'
rtk_command ganhos
check 'Easy gains command succeeds' test "$?" -eq 0
check 'Easy gains command queries dashboard' log_has 'rtk|gain|'
check 'Easy gains does not query or alter hooks' log_no_prefix 'rtk|init|'
: > "$TEST_LOG"
rtk_command desativar codex <<< 'DESATIVAR'
check 'CLI deactivation dispatches to selected agent' log_has 'rtk|init|--global|--codex|--uninstall|'
: > "$TEST_LOG"; APP_LANG=en
rtk_command enable codex <<< 'ENABLE'
check 'English enable command applies Codex integration' log_has 'rtk|init|--global|--codex|'
: > "$TEST_LOG"
rtk_command disable codex <<< 'DISABLE'
check 'English disable command applies Codex integration' log_has 'rtk|init|--global|--codex|--uninstall|'
APP_LANG=pt-BR
: > "$TEST_LOG"
rtk_command ativar codex --uninstall <<< 'ATIVAR'
check 'Unexpected CLI argument rejected' test "$?" -eq 2
check 'Unexpected CLI argument executes nothing' test ! -s "$TEST_LOG"
rtk_command ativar
check 'CLI requires an agent for changes' test "$?" -eq 2
mkdir -p "$TEST_TMP/project with spaces"
PROJECT="$TEST_TMP/project with spaces"
TEST_SELECTED_CANONICAL="$(cd "$PROJECT" && pwd -P)"
TEST_ORIGINAL_CWD="$PWD"; : > "$TEST_LOG"
rtk_command status
check 'Status succeeds for selected project' test "$?" -eq 0
check 'Status inspects selected project hooks' log_has "show-context|$TEST_SELECTED_CANONICAL|"
check 'Status inspects selected project Codex hooks' log_has "codex-show-context|$TEST_SELECTED_CANONICAL|"
check 'Status queries Codex explicitly' log_has 'rtk|init|--codex|--show|'
check 'Status queries Claude separately' log_has 'rtk|init|--show|'
check 'Status preserves launcher directory' test "$PWD" = "$TEST_ORIGINAL_CWD"
PROJECT=''; TEST_SHOW_FAIL=1
rtk_command status
check 'Status failure propagates' test "$?" -ne 0
TEST_SHOW_FAIL=0; TEST_CODEX_SHOW_FAIL=1; : > "$TEST_LOG"
rtk_command status
check 'Codex status failure propagates' test "$?" -ne 0
check 'Claude queried even when Codex status fails' log_has 'rtk|init|--show|'
TEST_CODEX_SHOW_FAIL=0; TEST_HELP='--global --dry-run --uninstall --show'; : > "$TEST_LOG"
rtk_command status
check 'Unsupported Codex query reports partial status' test "$?" -ne 0
check 'Unsupported Codex query is not executed' log_lacks 'rtk|init|--codex|--show|'
check 'Claude status remains available on old RTK' log_has 'rtk|init|--show|'
TEST_HELP='--global --codex --dry-run --uninstall --show'; TEST_GAIN_FAIL=1; : > "$TEST_LOG"
rtk_command status
check 'Unavailable gains reports partial status' test "$?" -ne 0
check 'Unavailable gains still consults Codex' log_has 'rtk|init|--codex|--show|'
check 'Unavailable gains still consults Claude' log_has 'rtk|init|--show|'
TEST_GAIN_FAIL=0
TEST_HELP='--global --codex --dry-run --uninstall --show'; TEST_AVAILABLE=0; : > "$TEST_LOG"
rtk_command ganhos
check 'Missing RTK returns useful failure' test "$?" -ne 0
check 'Missing RTK never invokes a command' test ! -s "$TEST_LOG"
: > "$TEST_LOG"; TEST_AVAILABLE=1
rtk_install < /dev/null
check 'Existing RTK causes no download' log_no_prefix 'curl|'
# Simulated collision must block installation before any downloader runs.
  TEST_AVAILABLE=0; : > "$TEST_LOG"; : > "$TEST_TMP/existing-rtk"
  rtk_install <<< $'1\nINSTALAR'
  check 'Existing installation target blocks overwrite' test "$?" -ne 0
  check 'Existing installation target prevents download' log_no_prefix 'curl|'
  rm -f "$TEST_TMP/existing-rtk"
  TEST_AVAILABLE=0; : > "$TEST_LOG"
  rtk_install <<< $'1\nCANCELAR'
  check 'Canceled native install has no curl calls' test ! -s "$TEST_LOG"
  TEST_AVAILABLE=0; TEST_CURL_FAIL=1; : > "$TEST_LOG"
  rtk_install <<< $'1\nINSTALAR'
  check 'Download failure propagated' test "$?" -ne 0
  check 'Download failure has no installer execution' log_no_prefix 'foreground|'
  TEST_CURL_FAIL=0; TEST_AVAILABLE=0; : > "$TEST_LOG"
  rtk_install <<< $'1\nINSTALAR'
  check 'Fake native installation completes' test "$?" -eq 0
  # The temp installer argument varies; verify the fixed environment prefix.
  installer_env_ok=0
  while IFS= read -r line; do
    case "$line" in "foreground|env|RTK_EDITION=oss|RTK_INSTALL_DIR=$HOME/.local/bin|RTK_SKIP_CHECKSUM=0|RTK_VERSION=v1.0.1|/bin/sh|"*) installer_env_ok=1 ;; esac
  done < "$TEST_LOG"
  check 'Native installer receives forced checksum and OSS environment' test "$installer_env_ok" -eq 1
  check 'Installation does not activate Codex integration' log_lacks 'rtk|init|--global|--codex|'
  check 'Installation does not activate Claude integration' log_lacks 'rtk|init|--global|'
# Comandos novos: somente leitura; nenhuma alteração de hook ou execução de git.
TEST_AVAILABLE=1; TEST_HELP='--global --codex --dry-run --uninstall --show'; : > "$TEST_LOG"
rtk_command historico
check 'History queries recent RTK commands' log_has 'rtk|gain|--history|'
check 'History never changes hook configuration' log_no_prefix 'rtk|init|'
: > "$TEST_LOG"
rtk_command verificar
check 'Rewrite verification queries only the parser' log_has 'rtk|rewrite|git status|'
check 'Rewrite verification does not execute git' log_no_prefix 'git|'
check 'Rewrite verification does not change hooks' log_no_prefix 'rtk|init|'
: > "$TEST_LOG"
rtk_command monitor
check 'Monitor uses official watch flag' log_has 'rtk|gain|--watch|'
check 'Monitor does not touch hook config' log_no_prefix 'rtk|init|'
: > "$TEST_LOG"
rtk_command monitor codex
check 'Monitor rejects arbitrary extra args' test "$?" -eq 2
check 'Invalid monitor args execute nothing' test ! -s "$TEST_LOG"
TEST_AVAILABLE=0; : > "$TEST_LOG"
rtk_command verificar
check 'Verification fails when RTK missing' test "$?" -ne 0
check 'Missing RTK executes nothing for verification' test ! -s "$TEST_LOG"
TEST_AVAILABLE=1
# --- RTK ligado por padrão: hooks, marcador e autostart ---------------------
CLAUDE_CONFIG_DIR="$TEST_TMP/cfg-claude"; CODEX_HOME="$TEST_TMP/cfg-codex"
mkdir -p "$CLAUDE_CONFIG_DIR" "$CODEX_HOME" "$STATE_DIR"
TOOL=claude
say_real() { printf '%s\n' "$*"; }
state_of() { say() { say_real "$@"; }; local out; out="$(rtk_state_line "$1")"; say() { :; }; printf '%s' "$out"; }
auto_out() { say() { say_real "$@"; }; local out; out="$(rtk_autostart <<< "$1" 2>/dev/null)"; say() { :; }; printf '%s' "$out"; }
rm -f "$STATE_DIR"/rtk-off-*
rtk_hook_active claude; check 'Claude hook inactive without file' test "$?" -ne 0
printf '{"hooks":[{"command":"rtk hook claude"}]}\n' > "$CLAUDE_CONFIG_DIR/settings.json"
printf '{"hooks":[{"command":"rtk hook codex"}]}\n' > "$CODEX_HOME/hooks.json"
rtk_hook_active claude; check 'Claude hook active when configured' test "$?" -eq 0
rtk_hook_active codex; check 'Codex hook active when configured' test "$?" -eq 0
rtk_hook_active other; check 'Unknown tool is never active' test "$?" -ne 0
printf '{"hooks":[]}\n' > "$CODEX_HOME/hooks.json"
rtk_hook_active codex; check 'Codex hook inactive without rtk entry' test "$?" -ne 0
check 'Hook check prints nothing' test "$(rtk_hook_active claude 2>&1)" = ''
mv "$CLAUDE_CONFIG_DIR/settings.json" "$TEST_TMP/real-settings.json"
ln -s "$TEST_TMP/real-settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
rtk_hook_active claude; check 'Symlinked hook file (dotfiles) is recognised read-only' test "$?" -eq 0
rm -f "$CLAUDE_CONFIG_DIR/settings.json"; mv "$TEST_TMP/real-settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
check 'State line active' test "$(state_of claude)" = 'RTK: ativo ✓'
check 'State line installed but inactive' test "$(state_of codex)" = 'RTK: instalado, ainda não ativo neste agente'
TEST_AVAILABLE=0
check 'State line not installed' test "$(state_of claude)" = 'RTK: não instalado'
TEST_AVAILABLE=1
: > "$TEST_LOG"; TOOL=claude
check 'Autostart active shows active' test "$(auto_out '')" = 'RTK: ativo ✓'
check 'Autostart active applies nothing' log_no_prefix 'rtk|init|--global|'
TEST_AVAILABLE=0; : > "$TEST_LOG"
case "$(auto_out '')" in *'menu 7 → 2'*) TEST_RC=0 ;; *) TEST_RC=1 ;; esac
check 'Autostart without RTK points to Ajuda e ajustes → RTK (menu 7 → 2)' test "$TEST_RC" -eq 0
check 'Autostart without RTK runs nothing' test ! -s "$TEST_LOG"
TEST_AVAILABLE=1
TOOL=codex; rtk_mark_off codex; : > "$TEST_LOG"
check 'Marker file created' test -f "$STATE_DIR/rtk-off-codex"
check 'State line off by choice' test "$(state_of codex)" = 'RTK: desligado por você'
case "$(auto_out '')" in *'sua escolha'*) TEST_RC=0 ;; *) TEST_RC=1 ;; esac
check 'Autostart respects marker' test "$TEST_RC" -eq 0
check 'Autostart with marker applies nothing' log_no_prefix 'rtk|init|--global|'
rtk_mark_on codex
check 'Marker removed' test ! -e "$STATE_DIR/rtk-off-codex"
: > "$TEST_LOG"
auto_out '' > /dev/null
check 'Autostart Enter activates (confirmed, no token)' log_has 'rtk|init|--global|--codex|'
check 'Autostart previews silently before applying' log_order 'rtk|init|--global|--codex|--dry-run|' 'rtk|init|--global|--codex|'
check 'Autostart activation leaves no off marker' test ! -e "$STATE_DIR/rtk-off-codex"
: > "$TEST_LOG"
auto_out 'n' > /dev/null
check 'Autostart answer n applies nothing' log_no_prefix 'rtk|init|--global|'
check 'Autostart answer n creates marker' test -f "$STATE_DIR/rtk-off-codex"
rtk_mark_on codex
: > "$TEST_LOG"; TEST_APPLY_FAIL=1
auto_out '' > /dev/null; TEST_RC=$?
TEST_APPLY_FAIL=0
check 'Autostart never fails the launch' test "$TEST_RC" -eq 0
check 'Failed autostart creates no off marker' test ! -e "$STATE_DIR/rtk-off-codex"
: > "$TEST_LOG"
rtk_toggle codex desativar <<< 'DESATIVAR'
check 'Deactivation creates marker' test -f "$STATE_DIR/rtk-off-codex"
rtk_toggle codex ativar <<< 'ATIVAR'
check 'Activation removes marker' test ! -e "$STATE_DIR/rtk-off-codex"
: > "$TEST_LOG"; rtk_toggle claude desativar <<< 'NAO'
check 'Cancelled deactivation creates no marker' test ! -e "$STATE_DIR/rtk-off-claude"
: > "$TEST_LOG"
rtk_toggle claude ativar confirmado < /dev/null
check 'Confirmed toggle applies without token' log_has 'rtk|init|--global|'
check 'Confirmed toggle still previews first' log_order 'rtk|init|--global|--dry-run|' 'rtk|init|--global|'
: > "$TEST_LOG"; TEST_DRY_FAIL=1
rtk_toggle claude ativar confirmado < /dev/null
check 'Confirmed toggle aborts on failed preview' log_lacks 'rtk|init|--global|'
TEST_DRY_FAIL=0
# ---- textos do menu RTK (usabilidade) e respostas não reconhecidas ----
rm -f "$STATE_DIR"/rtk-off-*; TOOL=codex
for answer in '0' 'x' 'talvez'; do
  : > "$TEST_LOG"; auto_out "$answer" > /dev/null
  check "Autostart unrecognised answer '$answer' applies nothing" log_no_prefix 'rtk|init|--global|'
  check "Autostart unrecognised answer '$answer' creates no marker" test ! -e "$STATE_DIR/rtk-off-codex"
done
menu_out() { say() { say_real "$@"; }; local out; out="$(rtk_menu <<< 0 2>/dev/null)"; say() { :; }; printf '%s' "$out"; }
MENU_TEXT="$(menu_out)"
menu_has() { case "$MENU_TEXT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
check 'Menu has plain option 2' menu_has 'Ver se está funcionando e quanto economizou'
check 'Menu has plain option 9' menu_has 'Testar se o RTK entende um comando'
check 'Menu points to Preferências, not option 4' menu_has 'Ajuda e ajustes → 4'
check 'Menu no longer says Desligue em 4' test "${MENU_TEXT#*Desligue em 4}" = "$MENU_TEXT"
check 'Menu has no hook jargon in options' test "${MENU_TEXT#*Situação dos hooks}" = "$MENU_TEXT"
check 'Menu labels are not duplicated (Codex: RTK:)' test "${MENU_TEXT#*Codex:  RTK:}" = "$MENU_TEXT"
check 'Menu agent line has plain label' menu_has 'Codex:  '
rtk_menu_info() { say() { say_real "$@"; }; local out; out="$(rtk_menu <<< $'5\n\n0' 2>/dev/null)"; say() { :; }; printf '%s' "$out"; }
INFO_TEXT="$(rtk_menu_info)"
info_has() { case "$INFO_TEXT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
check 'Entender: options refer to this RTK menu' info_has 'opção 7 deste menu RTK'
check 'Entender: no proxy jargon' test "${INFO_TEXT#*sem proxy}" = "$INFO_TEXT"
check 'Entender: no ambiguous menu 7/8/9' test "${INFO_TEXT#*(menu 8)}" = "$INFO_TEXT"
# ---- atualização: versão publicada, nunca master; consulta sem instalar ----
check 'Newer patch detected' rtk_tag_newer v1.0.2 v1.0.1
check 'Numeric (not text) comparison' rtk_tag_newer v1.10.0 v1.9.9
check 'Same version is not newer' test_not rtk_tag_newer v1.0.1 v1.0.1
check 'Older version is not newer' test_not rtk_tag_newer v0.40.0 v1.0.1
for bad in v1.0 1.0.1 'v1.0.1;x' 'v1.0.1 ' '$(x)' 'v99999.0.0'; do
  check "Invalid tag rejected: $bad" test_not rtk_valid_tag "$bad"
done
: > "$TEST_LOG"; rtk_latest_tag
check 'Latest tag read from release redirect' test "$RTK_LATEST" = v1.0.1
TEST_LATEST_LINE='location: https://github.com/rtk-ai/rtk/releases/tag/v1.0.1$(touch x)'
check 'Malformed redirect is refused' test_not rtk_latest_tag
TEST_LATEST_LINE='location: https://github.com/rtk-ai/rtk/releases/tag/v1.0.1'
rtk_installed_tag
check 'Installed version parsed' test "$RTK_INSTALLED" = v0.40.0
TEST_AVAILABLE=0; TEST_CURL_FAIL=0; : > "$TEST_LOG"
rtk_install <<< $'1\nINSTALAR'
check 'Installer downloaded from release tag' log_prefix_any 'rtk-ai/rtk/v1.0.1/install.sh'
check 'Installer never downloaded from master' test_not log_prefix_any '/master/'
TEST_AVAILABLE=1; TEST_BIN_PATH="$HOME/.local/bin/rtk"; TEST_BREW_HAS=1
TEST_LATEST_LINE='location: https://github.com/rtk-ai/rtk/releases/tag/v0.40.0'; : > "$TEST_LOG"
rtk_update <<< 'ATUALIZAR'
check 'Up-to-date: update succeeds' test "$?" -eq 0
check 'Up-to-date: nothing installed' log_no_prefix 'foreground|'
TEST_LATEST_LINE='location: https://github.com/rtk-ai/rtk/releases/tag/v1.0.1'; : > "$TEST_LOG"
rtk_update <<< 'nao'
check 'Update canceled installs nothing' log_no_prefix 'foreground|'
: > "$TEST_LOG"; rtk_update <<< 'ATUALIZAR'
check 'Native update succeeds' test "$?" -eq 0
check 'Native update pins the new version' log_prefix_any 'RTK_VERSION=v1.0.1|'
check 'Native update keeps checksum forced' log_prefix_any 'RTK_SKIP_CHECKSUM=0|'
check 'Update clears the version cache' test ! -e "$(rtk_update_cache)"
TEST_BREW_HAS=0; : > "$TEST_LOG"; rtk_update <<< 'ATUALIZAR'
check 'Homebrew install updated with brew upgrade' log_has 'brew|upgrade|rtk-ai/tap/rtk-oss|'
check 'Homebrew update skips official installer' log_no_prefix 'foreground|env|'
TEST_BREW_HAS=1; TEST_BIN_PATH=/usr/local/outro/rtk; : > "$TEST_LOG"
rtk_update <<< 'ATUALIZAR'
check 'Unknown install method refuses to overwrite' test "$?" -ne 0
check 'Unknown install method downloads no installer' test_not log_prefix_any 'install.sh'
TEST_BIN_PATH="$HOME/.local/bin/rtk"; TEST_CURL_FAIL=1; : > "$TEST_LOG"
rtk_update <<< 'ATUALIZAR'
check 'Offline update fails without installing' test "$?" -ne 0
check 'Offline update runs nothing' log_no_prefix 'foreground|'
TEST_CURL_FAIL=0; TEST_BIN_PATH=rtk
rm -f "$(rtk_update_cache)" "$STATE_DIR/opt-atualizacao-off"
check 'Daily check stores the result' rtk_check_now
check 'Fresh cache skips another check' rtk_cache_fresh
check 'Panel notice shows new version' test -n "$(rtk_update_notice)"
case "$(rtk_update_notice)" in *'v1.0.1'*'v0.40.0'*'7 → 2 → 10'*) TEST_RC=0 ;; *) TEST_RC=1 ;; esac
check 'Notice names both versions and the menu path' test "$TEST_RC" -eq 0
put "$STATE_DIR/opt-atualizacao-off" off
check 'Preference off hides the notice' test -z "$(rtk_update_notice)"
rm -f "$STATE_DIR/opt-atualizacao-off"
put "$(rtk_update_cache)" 'v0.40.0 v1.0.1 100'
check 'Old cache is stale' test_not rtk_cache_fresh
put "$(rtk_update_cache)" 'v0.40.0 $(touch x) 1'
check 'Corrupt cache is ignored' test -z "$(rtk_update_notice)"
put "$(rtk_update_cache)" 'v1.0.1 v1.0.1 1'
check 'Same version shows no notice' test -z "$(rtk_update_notice)"
: > "$TEST_LOG"; rm -f "$(rtk_update_cache)"; rtk_check_background; sleep 0.2
check 'Background check disabled in test mode' test ! -s "$TEST_LOG"
MENU_TEXT="$(menu_out)"
check 'Menu offers option 10 to update' menu_has '10) Atualizar RTK'
rtk_update() { printf 'ROUTED-update'; return 7; }
TEST_OUT="$(rtk_command atualizar)"; TEST_RC=$?
check 'rtk_command atualizar routes to rtk_update' test "$TEST_OUT:$TEST_RC" = 'ROUTED-update:7'
printf '\n%s PASS; %s FAIL\n' "$TEST_PASSES" "$TEST_FAILURES"
[ "$TEST_FAILURES" -eq 0 ]
