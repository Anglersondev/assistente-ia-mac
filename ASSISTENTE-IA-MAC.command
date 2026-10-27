#!/bin/bash
# Assistente IA Mac 1.0 — compatível com o Bash 3.2 do macOS.
# Arquivos de preferências são dados, nunca código. Os CLIs conservam o terminal.
VERSION='1.0'
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ "${ASSISTENTE_TEST_MODE:-}" != 1 ]; then
  export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
fi
STATE_DIR="${ASSISTENTE_STATE_DIR:-$HOME/Library/Application Support/Assistente IA Mac}"
PROJECT='' PREF_DIR='' TOOL='' MODEL='' EFFORT='' WORKMODE='trabalhar' INITIAL_PROMPT='' IMAGE=''
REPLY='' CAPTURE='' SESSIONMODE='novo'
APP_LANG='pt-BR'
COMMAND=()
COLOR='' RESET='' DIM=''
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then COLOR=$'\033[1;36m'; RESET=$'\033[0m'; DIM=$'\033[2m'; fi
say() { printf '%s\n' "$*"; }
warn() { printf '\n%s: %s\n' "$(ui 'Atenção' 'Notice')" "$*" >&2; }
ask() { printf '%s' "$1" >&2; IFS= LC_ALL=C read -r REPLY; }
pause() { ask "$(ui $'\nEnter para voltar... ' $'\nPress Enter to go back... ')" || return 1; }
ui() { if [ "$APP_LANG" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
say_ui() { say "$(ui "$1" "$2")"; }
ask_ui() { ask "$(ui "$1" "$2")"; }
header_ui() { header "$(ui "$1" "$2")"; }
detect_system_language() {
  local languages=''
  if command -v defaults >/dev/null 2>&1; then
    languages="$(defaults read -g AppleLanguages 2>/dev/null)" || languages=''
    [ -n "$languages" ] || languages="$(defaults read -g AppleLocale 2>/dev/null)" || languages=''
  fi
  if [[ "$languages" =~ [A-Za-z][A-Za-z] ]]; then
    case "${BASH_REMATCH[0]}" in
      en|EN|En|eN) APP_LANG=en; return ;;
    esac
  fi
  APP_LANG='pt-BR'
}
load_language() {
  local saved=''
  if [ -n "${ASSISTENTE_LANG:-}" ]; then saved="$ASSISTENTE_LANG"
  elif [ -f "$STATE_DIR/language" ] && [ ! -L "$STATE_DIR/language" ]; then IFS= read -r saved < "$STATE_DIR/language"; fi
  case "$saved" in en|pt-BR) APP_LANG="$saved" ;; *) detect_system_language ;; esac
}
language_menu() {
  local choice
  header_ui 'Idioma do programa' 'Application language'
  say_ui '1) Português (Brasil)' '1) Português (Brasil)'
  say_ui '2) English' '2) English'
  say_ui '0) Voltar' '0) Back'
  ask_ui 'Idioma: ' 'Language: ' || return 1
  choice="$REPLY"
  case "$choice" in 1) APP_LANG='pt-BR' ;; 2) APP_LANG=en ;; 0|'') return 0 ;; *) say_ui 'Escolha 1, 2 ou 0.' 'Choose 1, 2, or 0.'; return 1 ;; esac
  put "$STATE_DIR/language" "$APP_LANG" || return 1
  say_ui 'Idioma salvo: português do Brasil.' 'Language saved: English.'
}
# Largura do terminal limitada a 56–76 colunas, para régua e textos não quebrarem no meio.
term_cols() {
  local c
  c="$(tput cols 2>/dev/null)" || c=''
  case "$c" in ''|*[!0-9]*) c=60 ;; esac
  [ "$c" -ge 56 ] || c=56
  [ "$c" -le 76 ] || c=76
  printf '%s' "$c"
}
rule() {
  local n i=0 line=''
  n=$(( $(term_cols) - 4 ))
  while [ "$i" -lt "$n" ]; do line="${line}─"; i=$((i+1)); done
  printf '  %s\n' "$line"
}
# Texto corrido que quebra em palavras inteiras na largura do terminal.
wrap() { printf '%s\n' "$*" | fold -s -w "$(( $(term_cols) - 6 ))" | awk 'NR == 1 { print; next } { print "    " $0 }'; }
header() {
  if [ -t 1 ] && [ "${ASSISTENTE_TEST_MODE:-}" != 1 ]; then printf '\033[2J\033[H'; fi
  printf '\n%s  ASSISTENTE IA · MAC %s%s\n' "$COLOR" "$VERSION" "$RESET"
  printf '  %s\n' "$1"
  rule
  [ -z "$PROJECT" ] || [ -n "${HIDE_PROJECT_HEADER:-}" ] || printf '  %s: %s\n' "$(ui 'Projeto atual' 'Current project')" "$PROJECT"
  if [ -n "$PROJECT" ] && [ -z "${HIDE_PROJECT_HEADER:-}" ] && type project_profile >/dev/null 2>&1; then
    local profile
    profile="$(project_profile)"
    [ -z "$profile" ] || printf '  %s: %s\n' "$(ui 'Ferramenta do projeto' 'Project agent')" "$profile"
  fi
  printf '\n'
}
# Captura só consultas curtas. Não é usada para conversa, login ou instaladores.
bounded_capture() {
  local seconds="$1" target resultfile status deadline timedout=0
  shift
  CAPTURE=''
  resultfile="$(mktemp "${TMPDIR:-/tmp}/assistente-consulta.XXXXXXXX")" || return 1
  "$@" >"$resultfile" 2>&1 & target=$!
  deadline=$((SECONDS+seconds))
  while kill -0 "$target" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      timedout=1
      kill -TERM "$target" 2>/dev/null
      sleep 0.1
      kill -KILL "$target" 2>/dev/null
      break
    fi
    sleep 0.05
  done
  wait "$target" 2>/dev/null; status=$?
  CAPTURE="$(cat "$resultfile")"
  rm -f "$resultfile"
  [ "$timedout" -eq 0 ] || return 124
  return "$status"
}
run_foreground() { "$@"; }
# Gravação atômica no mesmo diretório; não usa source/eval nas preferências.
put() {
  local file="$1" value="$2" temporary
  temporary="$(mktemp "${file}.XXXXXXXX")" || return 1
  if ! printf '%s\n' "$value" > "$temporary" || ! mv -f "$temporary" "$file"; then
    rm -f "$temporary"; warn "$(ui 'Não consegui salvar a preferência. Confira espaço e permissão da pasta.' 'Could not save the preference. Check available space and folder permissions.')"; return 1
  fi
}
get() { [ ! -f "$1" ] || IFS= read -r REPLY < "$1"; printf '%s' "${REPLY:-}"; }
read_value() { REPLY=''; get "$1"; }
init_state() {
  umask 077
  mkdir -p "$STATE_DIR/projects" || { warn "Não consegui abrir as preferências: $STATE_DIR"; return 1; }
  load_language
  PROJECT="$(read_value "$STATE_DIR/current")"
  [ -d "$PROJECT" ] || PROJECT=''
  [ -z "$PROJECT" ] || set_project "$PROJECT"
}
single_line() { case "$1" in *$'\n'*|*$'\r'*|*$'\t'*|*$'\033'*) return 1 ;; esac; }
valid_name() {
  single_line "$1" || return 1
  case "$1" in ''|.|..|.*|-*|*/*|*:*|*\\*) return 1 ;; esac
  [ "${#1}" -le 120 ]
}
expand_path() {
  local value="$1"
  # Aspas externas são dados do caminho, não sintaxe a executar.
  case "$value" in \"*\") value="${value#\"}"; value="${value%\"}" ;; \'*\') value="${value#\'}"; value="${value%\'}" ;; esac
  case "$value" in '~') value="$HOME" ;; '~/'*) value="$HOME/${value#\~/}" ;; esac
  single_line "$value" || { warn "$(ui 'Use um caminho sem tabulação ou quebra de linha.' 'Use a path without tabs or line breaks.')"; return 1; }
  printf '%s\n' "$value"
}
normalize_path() {
  local value
  value="$(expand_path "$1")" || return 1
  [ -d "$value" ] || { warn "Pasta não encontrada: $value"; return 1; }
  (cd "$value" && pwd -P)
}
choose_folder() {
  local mode chosen dialog="${1:-Escolha a pasta do seu projeto ou a pasta onde deseja criá-lo}"
  [ "$APP_LANG" != en ] || dialog='Choose your project folder or the folder where you want to create it'
  say_ui '1) Escolher no Finder' '1) Choose in Finder'
  say_ui '2) Colar ou digitar o caminho' '2) Paste or type the path'
  say_ui '0) Voltar' '0) Back'
  while ask_ui 'Como escolher a pasta? [1]: ' 'How would you like to choose the folder? [1]: '; do
    mode="${REPLY:-1}"
    case "$mode" in
      0) return 1 ;;
      1)
        if command -v osascript >/dev/null 2>&1; then
          chosen="$(osascript -e "POSIX path of (choose folder with prompt \"$dialog\")" 2>/dev/null)"
          if [ -n "$chosen" ]; then
            CHOSEN_FOLDER="$(normalize_path "$chosen")" && return 0
          fi
          say_ui 'Seleção cancelada ou Finder indisponível. Você também pode usar 2.' 'Selection canceled or Finder unavailable. You can also use option 2.'
        else say_ui 'Finder indisponível. Escolha 2 para informar o caminho.' 'Finder unavailable. Choose option 2 to enter the path.'; fi
        ;;
      2)
        ask_ui 'Caminho da pasta existente (Enter cancela): ' 'Existing folder path (Enter cancels): ' || return 1
        [ -n "$REPLY" ] || return 1
        chosen="$REPLY"
        CHOSEN_FOLDER="$(normalize_path "$chosen")" && return 0
        ;;
      *) say_ui 'Digite 1, 2 ou 0.' 'Enter 1, 2, or 0.' ;;
    esac
  done
  return 1
}
set_project() {
  local canonical key old line temporary count=0
  canonical="$(normalize_path "$1")" || return 1
  key="$(printf '%s' "$canonical" | shasum -a 256)" || return 1
  key="${key%% *}"
  PREF_DIR="$STATE_DIR/projects/$key"
  mkdir -p "$PREF_DIR" || return 1
  put "$STATE_DIR/current" "$canonical" || return 1
  put "$PREF_DIR/path" "$canonical" || return 1
  temporary="$(mktemp "$STATE_DIR/recents.XXXXXXXX")" || return 1
  printf '%s\n' "$canonical" > "$temporary"
  if [ -f "$STATE_DIR/recents" ]; then
    while IFS= read -r line; do
      [ "$line" != "$canonical" ] && [ -d "$line" ] || continue
      printf '%s\n' "$line" >> "$temporary"
      count=$((count+1)); [ "$count" -lt 19 ] || break
    done < "$STATE_DIR/recents"
  fi
  mv -f "$temporary" "$STATE_DIR/recents" || return 1
  PROJECT="$canonical"
}
select_project() {
  header_ui 'Abrir projeto existente' 'Open an existing project'
  say_ui 'Selecione a pasta que contém o projeto. Seus arquivos serão preservados.' 'Select the folder containing your project. Your files will be preserved.'
  choose_folder || return 1
  set_project "$CHOSEN_FOLDER" || return 1
  say "$(ui 'Projeto selecionado' 'Selected project'): $PROJECT"
}
# Nome legível da ferramenta de uma pasta, lido do perfil do projeto (sem executar nada).
folder_tool_label() {
  local file="$1/.assistente-ia/tool" value=''
  [ -f "$file" ] && [ ! -L "$file" ] && [ ! -L "$1/.assistente-ia" ] || return 0
  IFS= read -r value < "$file"
  case "$value" in codex) printf 'Codex' ;; claude) printf 'Claude Code' ;; esac
}
recent_projects() {
  local paths=() line pick i=0 label
  header_ui 'Projetos recentes' 'Recent projects'
  if [ -f "$STATE_DIR/recents" ]; then
    while IFS= read -r line; do
      [ -d "$line" ] || continue
      paths[${#paths[@]}]="$line"
      label="$(folder_tool_label "$line")"
      i=$((i+1)); printf '%2s) %s%s — %s\n' "$i" "$(basename "$line")" "${label:+ ($label)}" "$line"
    done < "$STATE_DIR/recents"
  fi
  [ "$i" -gt 0 ] || { say_ui 'Nenhum projeto recente ainda. Volte e escolha 1 (Criar) ou 2 (Abrir pasta).' 'No recent projects yet. Go back and choose 1 (Create) or 2 (Open folder).'; return 1; }
  say_ui '0) Voltar' '0) Back'
  while ask_ui 'Projeto: ' 'Project: '; do
    pick="$REPLY"
    case "$pick" in 0|'') return 1 ;; *[!0-9]*) say_ui 'Digite o número do projeto.' 'Enter the project number.'; continue ;; esac
    [ "${#pick}" -le 2 ] || continue
    pick=$((10#$pick))
    if [ "$pick" -ge 1 ] && [ "$pick" -le "$i" ]; then set_project "${paths[$((pick-1))]}"; return $?; fi
    say_ui 'Número fora da lista.' 'Number not in the list.'
  done
  return 1
}
ensure_project() {
  [ -d "$PROJECT" ] && return 0
  say_ui 'Primeiro escolha o projeto.' 'Choose a project first.'
  say_ui '1) Criar novo  2) Abrir existente  3) Recentes  0) Voltar' '1) Create new  2) Open existing  3) Recent  0) Back'
  ask_ui 'Escolha: ' 'Choose: ' || return 1
  case "$REPLY" in 1) create_project ;; 2) select_project ;; 3) recent_projects ;; *) return 1 ;; esac
}
choose_tool() {
  say_ui '1) Codex — conta ChatGPT/OpenAI' '1) Codex — ChatGPT/OpenAI account'
  say_ui '2) Claude Code — conta Claude/Anthropic' '2) Claude Code — Claude/Anthropic account'
  say_ui '0) Voltar' '0) Back'
  while ask_ui 'Ferramenta: ' 'Agent: '; do
    case "$REPLY" in 1) TOOL=codex; return 0 ;; 2) TOOL=claude; return 0 ;; 0|'') return 1 ;; *) say_ui 'Escolha 1, 2 ou 0.' 'Choose 1, 2, or 0.' ;; esac
  done
  return 1
}
require_tool() {
  command -v "$TOOL" >/dev/null 2>&1 && return 0
  warn "$TOOL $(ui 'não está instalado ou não está no PATH.' 'is not installed or is not in PATH.')"
  say_ui 'O aplicativo de desktop e a ferramenta de terminal são instalações diferentes.' 'The desktop app and command-line agent are separate installations.'
  ask_ui 'Abrir opções de instalação? [s/N]: ' 'Open installation options? [y/N]: ' || return 1
  case "$REPLY" in s|S|y|Y) install_tool ;; *) return 1 ;; esac
  command -v "$TOOL" >/dev/null 2>&1
}
logged_in() {
  if [ "$TOOL" = codex ]; then bounded_capture 8 codex login status
  else bounded_capture 8 claude auth status; fi
}
login_tool() {
  local choice status force="${1:-}"
  require_tool || return 1
  header "$(ui 'Entrar no' 'Sign in to') $TOOL"
  if [ "$force" != force ] && logged_in; then
    if [ -n "${IN_ACCOUNTS:-}" ]; then say_ui 'Login reconhecido. Para mudar de conta, escolha 3 (Trocar de conta) aqui mesmo.' 'Signed in. To switch accounts, choose 3 (Switch account) here.'
    else say_ui 'Login reconhecido. Para mudar de conta: Ajuda e ajustes (7) → 1 → Trocar de conta.' 'Signed in. To switch accounts: Help and settings (7) → 1 → Switch account.'; fi
    return 0
  fi
  if [ "$TOOL" = codex ]; then
    say_ui '1) Entrar com ChatGPT pelo navegador' '1) Sign in with ChatGPT in the browser'
    say_ui '2) Código de dispositivo — alternativa se o navegador/localhost falhar' '2) Device code — if the browser or localhost flow fails'
    say_ui '0) Voltar' '0) Back'
    ask_ui 'Método [1]: ' 'Method [1]: ' || return 1
    choice="${REPLY:-1}"
    case "$choice" in
      1) run_foreground codex login ;;
      2) run_foreground codex login --device-auth ;;
      *) return 1 ;;
    esac
    status=$?
  else
    say_ui '1) Assinatura/conta Claude — login normal' '1) Claude subscription/account — normal sign-in'
    say_ui '2) Anthropic Console — API com cobrança por consumo' '2) Anthropic Console — usage-based API billing'
    say_ui '0) Voltar' '0) Back'
    ask_ui 'Método [1]: ' 'Method [1]: ' || return 1
    choice="${REPLY:-1}"
    case "$choice" in
      1) run_foreground claude auth login ;;
      2) run_foreground claude auth login --console ;;
      *) return 1 ;;
    esac
    status=$?
  fi
  if [ "$status" -eq 0 ] && logged_in; then say_ui 'Login confirmado. Agora você pode escolher o modelo.' 'Sign-in confirmed. You can now choose a model.'; return 0; fi
  warn "$(ui 'Login não confirmado. Veja a mensagem acima. Você pode tentar novamente em Contas.' 'Sign-in could not be confirmed. Check the message above and try again under Accounts.')"
  return 1
}
ensure_login() {
  require_tool || return 1
  if logged_in; then say "$TOOL: $(ui 'login reconhecido.' 'signed in.')"; return 0; fi
  login_tool
}
show_auth() {
  if ! command -v "$TOOL" >/dev/null 2>&1; then say "$TOOL: $(ui 'não instalado.' 'not installed.')"; return 1; fi
  if [ "$TOOL" = codex ]; then
    bounded_capture 8 codex login status
  else bounded_capture 8 claude auth status --text; fi
  local status=$?
  say "${CAPTURE:-$(ui 'Status indisponível.' 'Status unavailable.')}"
  return "$status"
}
switch_account() {
  require_tool || return 1
  header "$(ui 'Trocar conta' 'Switch account') · $TOOL"
  show_auth || true
  api_environment_notice
  say_ui 'Vou sair da conta atual e abrir o login oficial para outra conta.' 'I will sign out and open the official sign-in for another account.'
  say_ui 'Isso pode afetar outras interfaces que compartilham esse login.' 'This can affect other interfaces using the same sign-in.'
  say_ui 'No navegador, escolha a outra conta; se preciso, use a opção de trocar conta lá.' 'Choose the other account in the browser; use its account switcher if needed.'
  say_ui 'Os arquivos do projeto continuam na pasta. Históricos dependem da ferramenta/conta.' 'Project files stay in the folder. History depends on the agent and account.'
  ask_ui 'Digite TROCAR para continuar (Enter cancela): ' 'Type SWITCH to continue (Enter cancels): ' || return 1
  [ "$REPLY" = TROCAR ] || [ "$REPLY" = SWITCH ] || { say_ui 'Troca cancelada.' 'Account switch canceled.'; return 1; }
  if [ "$TOOL" = codex ]; then run_foreground codex logout; else run_foreground claude auth logout; fi
  [ "$?" -eq 0 ] || { warn "$(ui 'O logout falhou. Não iniciei outro login.' 'Sign-out failed. I did not start another sign-in.')"; return 1; }
  if [ -n "$PREF_DIR" ]; then put "$PREF_DIR/$TOOL.model" ''; put "$PREF_DIR/$TOOL.effort" ''; fi
  MODEL='' EFFORT=''
  say_ui 'Sessão encerrada. Escolha o método de entrada para a nova conta.' 'Signed out. Choose a sign-in method for the new account.'
  login_tool force
}
accounts_menu() {
  local choice profile=''
  header_ui 'Contas e login' 'Accounts and sign-in'
  [ -z "$PROJECT" ] || profile="$(project_profile 2>/dev/null)" || profile=''
  if [ -n "$profile" ]; then TOOL="$profile"; say "$(ui 'Ferramenta do projeto' 'Project agent'): $TOOL"
  else choose_tool || return 1; fi
  IN_ACCOUNTS=1
  while :; do
    header "$(ui 'Conta' 'Account') · $TOOL"
    say_ui '1) Ver situação do login' '1) Check sign-in status'
    say_ui '2) Entrar / concluir login' '2) Sign in / complete sign-in'
    say_ui '3) Trocar de conta' '3) Switch account'
    say_ui '4) Sair da conta atual' '4) Sign out of the current account'
    say_ui '0) Voltar' '0) Back'
    ask_ui 'Escolha: ' 'Choose: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) show_auth; pause || return 1 ;;
      2) login_tool; pause || return 1 ;;
      3) switch_account; pause || return 1 ;;
      4)
        if ! require_tool; then pause || return 1; continue; fi
        ask_ui 'Digite SAIR para deslogar (Enter cancela): ' 'Type SIGNOUT to sign out (Enter cancels): ' || return 1
        if [ "$REPLY" = SAIR ] || [ "$REPLY" = SIGNOUT ]; then
          if [ "$TOOL" = codex ]; then run_foreground codex logout; else run_foreground claude auth logout; fi
        fi
        pause || return 1 ;;
      0) IN_ACCOUNTS=''; return 0 ;;
      *) say_ui 'Opção inválida.' 'Invalid option.' ;;
    esac
  done
}
# Catálogo de conveniência lido do cache do CLI. Nunca lê auth.json ou tokens.
load_catalog() {
  local rows row slug label levels
  MODEL_IDS=(); MODEL_LABELS=(); MODEL_LEVELS=()
  [ -f "$BASE_DIR/lib/catalog.js" ] && command -v osascript >/dev/null 2>&1 || return 0
  bounded_capture 5 osascript -l JavaScript "$BASE_DIR/lib/catalog.js" "${CODEX_HOME:-$HOME/.codex}/models_cache.json" || return 0
  rows="$CAPTURE"
  while IFS=$'\t' read -r slug label levels; do
    [ -n "$slug" ] && valid_model "$slug" || continue
    MODEL_IDS[${#MODEL_IDS[@]}]="$slug"
    MODEL_LABELS[${#MODEL_LABELS[@]}]="$label"
    MODEL_LEVELS[${#MODEL_LEVELS[@]}]="$levels"
  done <<EOF
$rows
EOF
}
valid_model() { case "$1" in ''|-*|*[!a-zA-Z0-9_./:\[\]-]*) return 1 ;; esac; }
load_preferences() {
  MODEL="$(read_value "$PREF_DIR/$TOOL.model")"
  EFFORT="$(read_value "$PREF_DIR/$TOOL.effort")"
  WORKMODE="$(read_value "$PREF_DIR/$TOOL.mode")"
  [ -z "$MODEL" ] || valid_model "$MODEL" || MODEL=''
  case "$EFFORT" in ''|low|medium|high|xhigh|max|ultra|ultracode) ;; *) EFFORT='' ;; esac
  case "$WORKMODE" in trabalhar|planejar) ;; *) WORKMODE=trabalhar ;; esac
}
select_model() {
  local pick i levels selected=-1 candidate current="$MODEL"
  header "$(ui 'Passo 2 de 4 · Escolher modelo' 'Step 2 of 4 · Choose a model') · $TOOL"
  say_ui 'Modelo = qual IA responde. Se não souber, aperte Enter.' 'The model is the AI that responds. If unsure, press Enter.'
  say ''
  say_ui 'Enter) Manter a preferência deste projeto' 'Enter) Keep this project preference'
  say "        ${MODEL:-$(ui 'Padrão da ferramenta (dá para trocar depois com /model)' 'Agent default (you can change it later with /model)')}"
  say_ui '1) Padrão da ferramenta — na conversa, /model mostra a lista oficial' '1) Agent default — /model shows the official list in the conversation'
  if [ "$TOOL" = codex ]; then
    load_catalog
    if [ "${#MODEL_IDS[@]}" -gt 0 ]; then
      say_ui 'Catálogo local do Codex (pode estar desatualizado; acesso depende da conta):' 'Local Codex catalog (may be outdated; access depends on your account):'
      i=0
      while [ "$i" -lt "${#MODEL_IDS[@]}" ]; do
        printf '%2s) %s [%s]\n' "$((i+2))" "${MODEL_LABELS[$i]}" "${MODEL_IDS[$i]}"
        i=$((i+1))
      done
    else say_ui 'O cache ainda não está disponível. Você pode escolher no próprio Codex com /model.' 'The cache is unavailable. You can choose in Codex with /model.'; fi
  else
    say_ui '2) Sonnet — opção para trabalho diário' '2) Sonnet — everyday work'
    say_ui '3) Opus — raciocínio complexo' '3) Opus — complex reasoning'
    say_ui '4) Haiku — tarefas simples e rápidas' '4) Haiku — simple, quick tasks'
  fi
  say_ui 'm) Digitar identificador/alias exato' 'm) Enter an exact model ID or alias'
  say_ui '0) Voltar' '0) Back'
  while ask_ui 'Modelo [Enter mantém]: ' 'Model [Enter keeps current]: '; do
    pick="$REPLY"
    case "$pick" in
      '') return 0 ;;
      0) return 1 ;;
      1) MODEL=''; EFFORT=''; return 0 ;;
      m|M)
        ask_ui 'Identificador do modelo (Enter cancela): ' 'Model ID (Enter cancels): ' || return 1
        candidate="$REPLY"
        valid_model "$candidate" || { say_ui 'Identificador inválido. Use somente letras, números, -, _, ., /, : ou colchetes.' 'Invalid ID. Use only letters, numbers, -, _, ., /, :, or brackets.'; continue; }
        MODEL="$candidate"; EFFORT=''; return 0 ;;
      *[!0-9]*) say_ui 'Escolha uma opção da lista.' 'Choose an option from the list.'; continue ;;
      *)
        [ "${#pick}" -le 2 ] || continue
        pick=$((10#$pick))
        if [ "$TOOL" = claude ]; then
          case "$pick" in 2) MODEL=sonnet ;; 3) MODEL=opus ;; 4) MODEL=haiku ;; *) say_ui 'Número fora da lista.' 'Number not in the list.'; continue ;; esac
        else
          selected=$((pick-2))
          if [ "$selected" -lt 0 ] || [ "$selected" -ge "${#MODEL_IDS[@]}" ]; then say_ui 'Número fora da lista.' 'Number not in the list.'; continue; fi
          MODEL="${MODEL_IDS[$selected]}"
        fi
        [ "$MODEL" = "$current" ] || EFFORT=''
        return 0 ;;
    esac
  done
  return 1
}
select_effort() {
  local i=0 j=0 levels='' pick level choices=()
  header "$(ui 'Passo 2 de 4 · Esforço de raciocínio' 'Step 2 of 4 · Reasoning effort') · $TOOL"
  say_ui 'Esforço = quanto a IA pensa antes de responder. O automático costuma bastar.' 'Effort controls how long the AI thinks before responding. Automatic is usually enough.'
  say ''
  say_ui '1) Automático / padrão do modelo (recomendado)' '1) Automatic / model default (recommended)'
  if [ "$TOOL" = codex ] && [ -n "$MODEL" ]; then
    load_catalog
    while [ "$i" -lt "${#MODEL_IDS[@]}" ]; do
      [ "${MODEL_IDS[$i]}" != "$MODEL" ] || levels="${MODEL_LEVELS[$i]}"
      i=$((i+1))
    done
    if [ -n "$levels" ]; then
      local oldifs="$IFS"; IFS=','; read -r -a choices <<< "$levels"; IFS="$oldifs"
      for level in "${choices[@]}"; do
        case "$level" in low|medium|high|xhigh|max|ultra) printf '%s) %s\n' "$((j+2))" "$level"; j=$((j+1)) ;; *) choices=(); break ;; esac
      done
    fi
  fi
  if [ "${#choices[@]}" -eq 0 ]; then
    say_ui 'Ajustes disponíveis variam por modelo. Para outros níveis, use /model dentro do agente.' 'Available settings vary by model. Use /model inside the agent for other levels.'
  fi
  say_ui 'Enter) Manter o atual' 'Enter) Keep current setting'
  say "        ${EFFORT:-$(ui 'automático' 'automatic')}"
  say_ui '0) Voltar' '0) Back'
  while ask_ui 'Esforço [Enter mantém]: ' 'Effort [Enter keeps current]: '; do
    pick="$REPLY"
    case "$pick" in '') return 0 ;; 0) return 1 ;; 1) EFFORT=''; return 0 ;; *[!0-9]*) say_ui 'Opção inválida.' 'Invalid option.'; continue ;; esac
    [ "${#pick}" -le 2 ] || continue
    pick=$((10#$pick-2))
    if [ "$pick" -ge 0 ] && [ "$pick" -lt "${#choices[@]}" ]; then EFFORT="${choices[$pick]}"; return 0; fi
    say_ui 'Número fora da lista.' 'Number not in the list.'
  done
  return 1
}
select_workmode() {
  say_ui '1) Trabalhar — conversar e implementar na pasta do projeto' '1) Work — discuss and implement in the project folder'
  say_ui '2) Planejar — analisar antes de implementar' '2) Plan — analyze before implementing'
  say_ui '0) Voltar' '0) Back'
  ask "$(ui 'Modo' 'Mode') [$(ui 'Enter mantém' 'Enter keeps') $(ui "$WORKMODE" "$([ "$WORKMODE" = planejar ] && printf plan || printf work)")]: " || return 1
  case "$REPLY" in '') return 0 ;; 1) WORKMODE=trabalhar ;; 2) WORKMODE=planejar ;; *) return 1 ;; esac
}
load_prompt_file() {
  local file="$1" ext
  case "$file" in *.md|*.txt|*.MD|*.TXT) ;; *) warn 'Escolha um arquivo .md ou .txt.'; return 1 ;; esac
  [ -f "$file" ] && [ -r "$file" ] || { warn "$(ui 'Arquivo não encontrado ou sem acesso.' 'File not found or unreadable.')"; return 1; }
  [ "$(wc -c < "$file" | tr -d ' ')" -le 60000 ] || { warn "$(ui 'Arquivo maior que 60 KB. Peça ao agente para ler o arquivo dentro do projeto.' 'File exceeds 60 KB. Ask the agent to read it inside the project.')"; return 1; }
  INITIAL_PROMPT="$(cat "$file")"
  text_has_content "$INITIAL_PROMPT" || { warn "$(ui 'O pedido está vazio. Edite o arquivo antes de usá-lo.' 'The prompt is empty. Edit the file before using it.')"; return 1; }
}
choose_saved_prompt() {
  local file pick i=0
  local -a prompt_files=()
  while :; do
    prompt_files=()
    if [ -d "$PROJECT/PROMPTS" ]; then
      for file in "$PROJECT"/PROMPTS/*.md "$PROJECT"/PROMPTS/*.txt "$PROJECT"/PROMPTS/*.MD "$PROJECT"/PROMPTS/*.TXT; do
        [ -f "$file" ] || continue
        prompt_files[${#prompt_files[@]}]="$file"
      done
    fi
    if [ "${#prompt_files[@]}" -eq 0 ]; then
      say "Ainda não há pedidos prontos em $PROJECT/PROMPTS/."
      ask 'Quer criar um pedido pronto para esta pasta agora? [s/N]: ' || return 1
      case "$REPLY" in s|S) save_prompt || return 1; continue ;; *) return 1 ;; esac
    fi
    say "Pedidos prontos deste projeto · $PROJECT/PROMPTS/"
    i=0
    while [ "$i" -lt "${#prompt_files[@]}" ]; do
      file="${prompt_files[$i]}"
      printf '%2s) %s%s\n' "$((i+1))" "$(basename "$file")" "$(type prompt_size_note >/dev/null 2>&1 && prompt_size_note "$file")"
      i=$((i+1))
    done
    say '0) Voltar'
    ask 'Qual pedido quer usar? ' || return 1
    pick="$REPLY"
    case "$pick" in 0|'') return 1 ;; *[!0-9]*) say_ui 'Digite o número ao lado do pedido.' 'Enter the number beside the prompt.'; continue ;; esac
    [ "${#pick}" -le 6 ] || continue
    pick=$((10#$pick))
    if [ "$pick" -ge 1 ] && [ "$pick" -le "${#prompt_files[@]}" ]; then
      load_prompt_file "${prompt_files[$((pick-1))]}" && return 0
      return 1
    fi
    say_ui 'Número fora da lista.' 'Number not in the list.'
  done
}
# Há andamento de verdade em DOCS/ANDAMENTO.md (além dos títulos e do texto do modelo)?
has_real_progress() {
  local file="$PROJECT/DOCS/ANDAMENTO.md"
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  LC_ALL=C /usr/bin/grep -v '^[[:space:]]*$' "$file" | LC_ALL=C /usr/bin/grep -v '^#' | LC_ALL=C /usr/bin/grep -Fv 'Registre fatos confirmados' | LC_ALL=C /usr/bin/grep -Fv 'Record confirmed facts' | LC_ALL=C /usr/bin/grep -q .
}
choose_prompt() {
  local choice line file default=2
  INITIAL_PROMPT='' IMAGE=''
  say "$(ui 'Projeto' 'Project'): $PROJECT"
  if [ -f "$PROJECT/PROMPTS/CONTINUAR.md" ]; then
    if has_real_progress; then default=1
    else say_ui 'Projeto novo: ainda não há andamento para continuar.' 'New project: there is no saved progress to continue yet.'; fi
  fi
  say_ui 'Como você quer começar?' 'How would you like to start?'
  if [ -f "$PROJECT/PROMPTS/CONTINUAR.md" ] && ! has_real_progress; then
    say_ui '1) Continuar o trabalho (ainda sem andamento registrado)' '1) Continue the work (no progress recorded yet)'
  elif [ -f "$PROJECT/PROMPTS/CONTINUAR.md" ]; then
    say_ui '1) Continuar o trabalho (o agente lê o andamento do projeto)' '1) Continue the work (the agent reads project progress)'
  else
    say_ui '1) Continuar o trabalho (indisponível: falta PROMPTS/CONTINUAR.md)' '1) Continue the work (unavailable: PROMPTS/CONTINUAR.md is missing)'
  fi
  say_ui '2) Escrever um pedido novo (várias linhas)' '2) Write a new prompt (multiple lines)'
  say_ui '3) Escolher um pedido pronto salvo (pasta PROMPTS/)' '3) Choose a saved prompt (PROMPTS/ folder)'
  say_ui '4) Começar sem pedido e escrever dentro do agente' '4) Start without a prompt and write inside the agent'
  say_ui '5) Usar um arquivo .md/.txt de outra pasta' '5) Use an .md/.txt file from another folder'
  say_ui '6) Começar com uma imagem (Codex)' '6) Start with an image (Codex)'
  say_ui '0) Voltar' '0) Back'
  ask "$(ui 'Escolha' 'Choose') [$default]: " || return 1
  choice="${REPLY:-$default}"
  case "$choice" in
    1)
      [ -f "$PROJECT/PROMPTS/CONTINUAR.md" ] || { warn "$(ui 'Este projeto não tem PROMPTS/CONTINUAR.md (Cuidar do projeto → 12 cria os pedidos prontos padrão).' 'This project lacks PROMPTS/CONTINUAR.md (Project care → 12 creates default prompts).')"; return 1; }
      load_prompt_file "$PROJECT/PROMPTS/CONTINUAR.md" ;;
    2)
      say_ui 'Escreva o pedido. Quando terminar, digite FIM numa linha sozinha (CANCELAR sozinho volta).' 'Write your prompt. Type DONE on its own line to finish, or CANCEL to go back.'
      while ask '> '; do
        line="$REPLY"
        case "$line" in FIM|DONE) return 0 ;; CANCELAR|CANCEL) return 1 ;; esac
        INITIAL_PROMPT="${INITIAL_PROMPT}${line}"$'\n'
        [ "${#INITIAL_PROMPT}" -le 60000 ] || { warn 'Pedido muito longo. Use um arquivo no projeto.'; return 1; }
      done
      return 1 ;;
    3) choose_saved_prompt ;;
    4) return 0 ;;
    5)
      say_ui 'Selecione o arquivo .md ou .txt que contém seu pedido.' 'Select the .md or .txt file containing your prompt.'
      choose_local_file || return 1
      file="$CHOSEN_FILE"
      load_prompt_file "$file" ;;
    6)
      [ "$TOOL" = codex ] || { say_ui 'Para Claude, salve a imagem em ANEXOS e peça para analisá-la na conversa.' 'For Claude, save the image in ANEXOS and ask the agent to analyze it in the conversation.'; return 1; }
      choose_local_file || return 1
      IMAGE="$CHOSEN_FILE"
      [ -f "$IMAGE" ] || { warn "$(ui 'Imagem não encontrada.' 'Image not found.')"; return 1; }
      case "$IMAGE" in *.png|*.jpg|*.jpeg|*.webp|*.PNG|*.JPG|*.JPEG|*.WEBP) ;; *) warn 'Use PNG, JPG ou WEBP.'; return 1 ;; esac
      ask_ui 'O que fazer com a imagem? [Analisar a imagem]: ' 'What should the agent do with the image? [Analyze it]: ' || return 1
      INITIAL_PROMPT="${REPLY:-$(ui 'Analise a imagem e me ajude a trabalhar neste projeto.' 'Analyze the image and help me work on this project.')}" ;;
    *) return 1 ;;
  esac
}
build_command() {
  local tool="${1:-$TOOL}" mode="${2:-novo}"
  COMMAND=("$tool")
  if [ "$tool" = codex ]; then
    case "$mode" in recente) COMMAND+=(resume --last) ;; escolher) COMMAND+=(resume) ;; esac
    COMMAND+=(--cd "$PROJECT" --ask-for-approval on-request)
    if [ "$WORKMODE" = planejar ]; then COMMAND+=(--sandbox read-only); else COMMAND+=(--sandbox workspace-write); fi
    [ -z "$MODEL" ] || COMMAND+=(--model "$MODEL")
    [ -z "$EFFORT" ] || COMMAND+=(-c "model_reasoning_effort=\"$EFFORT\"")
    [ -z "$IMAGE" ] || COMMAND+=(--image "$IMAGE")
  else
    case "$mode" in recente) COMMAND+=(--continue) ;; escolher) COMMAND+=(--resume) ;; esac
    if [ "$WORKMODE" = planejar ]; then COMMAND+=(--permission-mode plan); else COMMAND+=(--permission-mode default); fi
    [ -z "$MODEL" ] || COMMAND+=(--model "$MODEL")
    [ -z "$EFFORT" ] || COMMAND+=(--effort "$EFFORT")
  fi
  [ -z "$INITIAL_PROMPT" ] || COMMAND+=(-- "$INITIAL_PROMPT")
}
save_preferences() {
  put "$PREF_DIR/$TOOL.model" "$MODEL" && put "$PREF_DIR/$TOOL.effort" "$EFFORT" && put "$PREF_DIR/$TOOL.mode" "$WORKMODE" && put "$PREF_DIR/tool" "$TOOL"
}
launch_agent() {
  local mode="${1:-novo}" status confirm skip=1
  ensure_project || return 1
  header_ui 'Passo 1 de 4 · Ferramenta' 'Step 1 of 4 · Agent'
  choose_project_tool || return 1
  ensure_login || return 1
  load_preferences
  rtk_preflight
  if [ -f "$PREF_DIR/$TOOL.mode" ]; then use_saved_settings && skip=0
  else first_time_settings && skip=0; fi
  if [ "$skip" -ne 0 ]; then
    select_model || return 1
    select_effort || return 1
    header_ui 'Passo 2 de 4 · Como trabalhar' 'Step 2 of 4 · How to work'
    select_workmode || return 1
  fi
  INITIAL_PROMPT='' IMAGE=''
  if [ "$mode" = novo ]; then
    header_ui 'Passo 3 de 4 · Seu pedido' 'Step 3 of 4 · Your prompt'
    choose_prompt || return 1
  fi
  header_ui 'Passo 4 de 4 · Pronto para começar' 'Step 4 of 4 · Ready to start'
  say "$(ui 'Ferramenta' 'Agent'): $TOOL"
  say "$(ui 'Conversa' 'Conversation'): $(ui "$mode" "$([ "$mode" = novo ] && printf new || printf "$mode")")"
  say "$(ui 'Modelo' 'Model'): ${MODEL:-$(ui 'padrão da ferramenta — /model troca durante a conversa' 'agent default — change with /model during the conversation')}"
  say "$(ui 'Esforço' 'Effort'): ${EFFORT:-$(ui 'automático' 'automatic')}"
  say "$(ui 'Modo' 'Mode'): $(ui "$WORKMODE" "$([ "$WORKMODE" = planejar ] && printf plan || printf work)")"
  if [ -f "$PROJECT/INSTRUCOES/PROJETO.md" ]; then
    say_ui 'Instruções permanentes: INSTRUCOES/PROJETO.md (menu 6 → 9 para editar)' 'Permanent instructions: INSTRUCOES/PROJETO.md (menu 6 → 9 to edit)'
  fi
  type rtk_state_line >/dev/null 2>&1 && say "$(rtk_state_line "$TOOL")"
  type project_quick_warnings >/dev/null 2>&1 && project_quick_warnings
  launch_extras
  [ -z "$INITIAL_PROMPT" ] || printf '\n%s:\n%s\n' "$(ui 'Seu pedido' 'Your prompt')" "$INITIAL_PROMPT"
  [ -z "$IMAGE" ] || say "$(ui 'Imagem' 'Image'): $IMAGE"
  say ''
  say_ui 'Dentro da conversa: /model escolhe outra IA para responder; /status mostra o estado da sessão.' 'In the conversation: /model changes the model; /status shows session status.'
  say_ui 'Para voltar ao menu: use /exit. Ctrl+C interrompe uma ação.' 'Use /exit to return to the menu. Ctrl+C interrupts an action.'
  say_ui 'Na primeira abertura, a própria ferramenta pode pedir confiança na pasta.' 'On first launch, the agent may ask you to trust this folder.'
  ask_ui 'Enter para começar; 0 para cancelar: ' 'Press Enter to start; 0 to cancel: ' || return 1
  case "$REPLY" in ''|s|S) ;; *) say_ui 'Conversa cancelada.' 'Conversation canceled.'; return 1 ;; esac
  save_preferences || return 1
  build_command "$TOOL" "$mode"
  (
    cd "$PROJECT" || exit 1
    run_foreground "${COMMAND[@]}"
  )
  status=$?
  say ''
  if [ "$status" -eq 0 ]; then say_ui 'Conversa encerrada. Você voltou ao assistente.' 'Conversation ended. You are back in the assistant.'
  elif [ "$status" -eq 130 ]; then say_ui 'Conversa interrompida. Você voltou ao assistente.' 'Conversation interrupted. You are back in the assistant.'
  else
    warn "$TOOL terminou com código $status. A mensagem original está acima."
    say_ui 'Se o modelo não estiver disponível, inicie outra vez e escolha 1 (padrão da ferramenta).' 'If the model is unavailable, start again and choose 1 (agent default).'
    say_ui 'Se a versão não reconhecer um comando, use Ajuda e ajustes → Instalação e diagnóstico.' 'If the agent does not recognize a command, use Help and settings → Installation and diagnostics.'
  fi
  return "$status"
}
# Chaves de controle: cada recurso automático pode ser desligado (arquivo opt-<nome>-off).
opt_enabled() { [ ! -e "$STATE_DIR/opt-$1-off" ]; }
opt_flip() {
  if opt_enabled "$1"; then put "$STATE_DIR/opt-$1-off" off >/dev/null 2>&1
  else rm -f "$STATE_DIR/opt-$1-off"; fi
}
opt_label() { if opt_enabled "$1"; then ui 'LIGADO   ' 'ON       '; else ui 'desligado' 'off      '; fi; }
# Avisos e dicas ao abrir a conversa; nunca gravam nada e nunca bloqueiam.
launch_extras() {
  if opt_enabled dicas && type tip_of_the_day >/dev/null 2>&1; then tip_of_the_day; fi
  if opt_enabled peso && type session_weight_note >/dev/null 2>&1; then session_weight_note; fi
  return 0
}
rtk_preflight() {
  if opt_enabled rtk && type rtk_autostart >/dev/null 2>&1; then rtk_autostart
  elif type rtk_state_line >/dev/null 2>&1; then say "$(rtk_state_line "$TOOL") (verificação automática desligada: menu 7 → 4)"; fi
  return 0
}
transparency() {
  if [ "$APP_LANG" = en ]; then
    header 'What this assistant does on its own'
    wrap 'WRITES ONLY WITH YOUR CONFIRMATION:'
    wrap '  • Projects, saved prompts, attachments, and instructions: it asks first and backs up your text when changing it. It never overwrites what you wrote.'
    wrap '  • Claude in-chat usage bar (menu 7 → 7): edits only statusLine in ~/.claude/settings.json, after a preview, typed INSTALAR confirmation, and backup. It also creates the bar script and backups in the assistant folder.'
    wrap '  • RTK: when opening a conversation, the kit asks [Y/n]. Enter means yes; n turns off future prompts. Global agent settings change only if you answer yes.'
    wrap 'WRITES WITHOUT ASKING (in Library/Application Support/Assistente IA Mac):'
    wrap '  • Current and recent projects, model and mode preferences, menu 7 → 4 switches, and the last RTK version checked.'
    wrap '  • After installation, the in-chat bar records usage numbers in usage/claude-<K>.txt on each update, even outside this assistant, until you remove the bar.'
    wrap 'READS WITHOUT DISPLAYING OR SENDING CONTENT:'
    wrap '  • Agent session size, date, approximate message count, and usage numbers. For Codex, it also checks the start of the session file to find the project.'
    wrap '  • Sign-in status using the official command, and names only of configured environment keys.'
    wrap '  • RTK integration status by text search in agent settings.'
    wrap '  • PROJETO.md, README.md, and the current project prompts folder for launch notices.'
    wrap 'DOES NOT:'
    wrap '  • Display or send passwords, keys, or .env files. Sign-in uses only the official agent program.'
    wrap '  • Delete your files (only temporary files and the assistant own preference keys).'
    wrap '  • Access the internet on its own, except for an optional daily public RTK latest-release check when RTK is installed. It sends no personal data and never installs by itself. Other network access occurs through installations you confirm and the Codex or Claude programs.'
    wrap 'AGENT: Work mode asks for approval when needed; Plan mode reads only. You choose the mode before launch.'
    wrap 'Turn off items 1 to 5 under Help and settings → Preferences (menu 7 → 4).'
    return 0
  fi
  header 'O que este assistente faz sozinho'
  wrap 'GRAVA, SÓ COM A SUA CONFIRMAÇÃO:'
  wrap '  • projetos, pedidos prontos, anexos e instruções: sempre com pergunta e, quando altera um texto seu, com cópia de segurança; nunca sobrescreve o que você escreveu;'
  wrap '  • a barra de aviso no chat (menu 7 → 7): edita só a chave statusLine do arquivo ~/.claude/settings.json, com cópia de segurança e depois de você digitar INSTALAR; cria também o script da barra e as cópias na pasta do assistente;'
  wrap '  • RTK: ao abrir uma conversa o kit PERGUNTA [S/n]. Enter vale como sim; n desliga e não pergunta mais. A configuração global do agente só muda se a resposta for sim.'
  wrap 'GRAVA SEM PERGUNTAR (pasta de preferências do assistente: Biblioteca/Application Support/Assistente IA Mac):'
  wrap '  • projeto atual, projetos recentes, modelo, modo, as chaves do menu 7 → 4 e o número da última versão do RTK consultada;'
  wrap '  • depois de instalada, a barra no chat grava sozinha, a cada atualização, só números de uso (arquivos usage/claude-<K>.txt), mesmo fora do assistente. Isso para quando você remover a barra.'
  wrap 'LÊ, SEM MOSTRAR NEM ENVIAR:'
  wrap '  • nas sessões do agente: tamanho, data, contagem aproximada de mensagens e números de uso; no Codex, confere também o início do arquivo para achar o projeto;'
  wrap '  • se o login está ativo (comando oficial de status) e se existem chaves configuradas no ambiente (só os nomes);'
  wrap '  • se a ligação do RTK existe, por uma busca de texto nas configurações do agente;'
  wrap '  • PROJETO.md, README.md e a pasta de pedidos prontos do projeto atual, para os avisos ao abrir.'
  wrap 'NÃO FAZ:'
  wrap '  • não mostra nem envia senhas, chaves ou arquivos .env; o login é feito só pelo programa oficial;'
  wrap '  • não apaga arquivos seus (só temporários e as chaves do próprio assistente);'
  wrap '  • não usa a internet por conta própria, com uma exceção desligável: se o RTK estiver instalado, consulta no máximo 1x por dia o endereço público github.com/rtk-ai/rtk/releases/latest para saber o número da versão mais nova. Não envia dados seus e nunca instala sozinho. Fora isso, só instalações que você confirmar e os próprios programas Codex e Claude.'
  wrap 'AGENTE: o modo Trabalhar pede aprovação sob demanda; o modo Planejar só lê. Você escolhe o modo antes de abrir.'
  wrap 'Em Ajuda e ajustes → Preferências (menu 7 → 4) você desliga os itens 1 a 5.'
}
control_menu() {
  local choice
  while :; do
    header_ui 'Preferências e controle' 'Preferences and control'
    say "1) $(opt_label rtk)  $(ui 'Conferir RTK ao abrir a conversa (pergunta antes; Enter = ativar)' 'Check RTK when opening a conversation (asks first; Enter = enable)')"
    say "2) $(opt_label dicas)  $(ui 'Mostrar uma dica de economia ao abrir a conversa' 'Show an efficiency tip when opening a conversation')"
    say "3) $(opt_label peso)  $(ui 'Medir o uso da conversa e avisar quando estiver longa' 'Measure conversation usage and warn when it grows long')"
    say "4) $(opt_label atalho)  $(ui 'Enter no menu principal = continuar de onde parei' 'Enter on the main menu = resume where I left off')"
    say "5) $(opt_label atualizacao)  $(ui 'Verificar 1x por dia se há RTK novo (só consulta; nunca instala sozinho)' 'Check once a day for a new RTK release (read-only; never auto-installs)')"
    say_ui '6) Ver o que o assistente faz sozinho' '6) See what the assistant does on its own'
    say_ui '0) Voltar' '0) Back'
    ask_ui 'Escolha para ligar/desligar: ' 'Choose a setting to toggle: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) opt_flip rtk ;; 2) opt_flip dicas ;; 3) opt_flip peso ;; 4) opt_flip atalho ;;
      5) opt_flip atualizacao ;;
      6) transparency; pause || return 1 ;;
      0|'') return 0 ;;
      *) say_ui 'Opção inválida.' 'Invalid option.' ;;
    esac
  done
}
# Primeira conversa do projeto: segue com o padrão, a menos que a pessoa queira ajustar.
first_time_settings() {
  say ''
  say_ui 'Passo 2 de 4 · Modelo e modo de trabalho' 'Step 2 of 4 · Model and work mode'
  say_ui 'Primeira conversa deste projeto: vou usar a configuração padrão.' 'First conversation in this project: using default settings.'
  say_ui 'Modelo = qual IA responde. Se não souber, aperte Enter.' 'The model is the AI that responds. If unsure, press Enter.'
  say "$(ui 'Modo' 'Mode'): $(ui "$WORKMODE" "$([ "$WORKMODE" = planejar ] && printf plan || printf work)")"
  ask_ui 'Ajustar modelo e esforço? [s/N]: ' 'Adjust model and effort? [y/N]: ' || return 1
  case "$REPLY" in s|S|y|Y) return 1 ;; esac
  return 0
}
use_saved_settings() {
  say ''
  say "$(ui 'Configurações salvas deste projeto' 'Saved project settings'): $(ui 'modelo' 'model') ${MODEL:-$(ui 'padrão da ferramenta' 'agent default')} · $(ui 'esforço' 'effort') ${EFFORT:-$(ui 'automático' 'automatic')} · $(ui 'modo' 'mode') $(ui "$WORKMODE" "$([ "$WORKMODE" = planejar ] && printf plan || printf work)")"
  ask_ui 'Usar essas configurações? [S/n]: ' 'Use these settings? [Y/n]: ' || return 1
  case "$REPLY" in n|N|0) return 1 ;; esac
  return 0
}
run_agent_session() {
  local mode="$1" status
  build_command "$TOOL" "$mode"
  (
    cd "$PROJECT" || exit 1
    run_foreground "${COMMAND[@]}"
  )
  status=$?
  return "$status"
}
# Retoma a última conversa do projeto com a ferramenta e as preferências já salvas.
quick_resume() {
  local status started
  ensure_project || return 1
  header_ui 'Continuar de onde parei' 'Resume where I left off'
  choose_project_tool || return 1
  ensure_login || return 1
  load_preferences
  rtk_preflight
  say ''
  say "$(ui 'Ferramenta' 'Agent'): $TOOL · $(ui 'modelo' 'model') ${MODEL:-$(ui 'padrão da ferramenta' 'agent default')} · $(ui 'esforço' 'effort') ${EFFORT:-$(ui 'automático' 'automatic')} · $(ui 'modo' 'mode') $(ui "$WORKMODE" "$([ "$WORKMODE" = planejar ] && printf plan || printf work)")"
  type project_quick_warnings >/dev/null 2>&1 && project_quick_warnings
  launch_extras
  INITIAL_PROMPT='' IMAGE=''
  ask_ui 'Enter para continuar a última conversa; 0 cancela: ' 'Press Enter to resume the latest conversation; 0 cancels: ' || return 1
  case "$REPLY" in ''|s|S) ;; *) say_ui 'Cancelado.' 'Canceled.'; return 1 ;; esac
  save_preferences || return 1
  started=$SECONDS
  run_agent_session recente; status=$?
  # Só uma saída imediata com erro indica que não havia conversa para retomar.
  if [ "$status" -ne 0 ] && [ "$status" -ne 130 ] && [ $((SECONDS-started)) -lt 8 ]; then
    warn "$(ui 'Não consegui retomar (talvez ainda não exista conversa anterior neste projeto).' 'Could not resume (there may be no previous conversation in this project).')"
    ask_ui 'Abrir uma conversa nova com as mesmas configurações? [s/N]: ' 'Start a new conversation with the same settings? [y/N]: ' || return 1
    case "$REPLY" in s|S|y|Y) ;; *) return "$status" ;; esac
    run_agent_session novo; status=$?
  fi
  say ''
  [ "$status" -eq 0 ] && say_ui 'Conversa encerrada. Você voltou ao assistente.' 'Conversation ended. You are back in the assistant.'
  return "$status"
}
# Continua a última conversa e pede o resumo que atualiza DOCS/ANDAMENTO.md.
quick_close() {
  local status started file
  ensure_project || return 1
  header_ui 'Encerrar com resumo' 'Wrap up with a summary'
  choose_project_tool || return 1
  file="$PROJECT/PROMPTS/ENCERRAR-SESSAO.md"
  if [ ! -f "$file" ]; then
    say_ui 'Este projeto ainda não tem o pedido pronto PROMPTS/ENCERRAR-SESSAO.md.' 'This project does not yet have PROMPTS/ENCERRAR-SESSAO.md.'
    ask_ui 'Criar os pedidos prontos padrão agora (sem sobrescrever nada)? [S/n]: ' 'Create the default saved prompts now (without overwriting anything)? [Y/n]: ' || return 1
    case "$REPLY" in n|N|0) return 1 ;; esac
    type create_missing_default_prompts >/dev/null 2>&1 && create_missing_default_prompts || return 1
    [ -f "$file" ] || { warn "$(ui 'Não consegui criar o pedido de encerramento.' 'Could not create the wrap-up prompt.')"; return 1; }
  fi
  ensure_login || return 1
  load_preferences
  rtk_preflight
  say ''
  say_ui 'O que vai acontecer:' 'What happens next:'
  say_ui '  1. A última conversa deste projeto abre e recebe o pedido de resumo.' '  1. The latest conversation opens and receives the summary request.'
  say_ui '  2. O agente atualiza DOCS/ANDAMENTO.md (curto, só fatos confirmados).' '  2. The agent updates DOCS/ANDAMENTO.md (short, confirmed facts only).'
  say_ui '  3. Depois feche com /exit. Na próxima vez, use “Começar uma conversa nova” → Continuar o trabalho.' '  3. Exit with /exit. Next time, choose Start a new conversation → Continue the work.'
  if [ "$TOOL" = codex ]; then
    say_ui 'Se o Codex abrir sem o pedido, digite: leia PROMPTS/ENCERRAR-SESSAO.md e siga.' 'If Codex opens without the prompt, type: read and follow PROMPTS/ENCERRAR-SESSAO.md.'
  fi
  load_prompt_file "$file" || return 1
  IMAGE=''
  ask_ui 'Enter para encerrar com resumo; 0 cancela: ' 'Press Enter to wrap up with a summary; 0 cancels: ' || return 1
  case "$REPLY" in ''|s|S) ;; *) say_ui 'Cancelado.' 'Canceled.'; INITIAL_PROMPT=''; return 1 ;; esac
  save_preferences || return 1
  started=$SECONDS
  run_agent_session recente; status=$?
  INITIAL_PROMPT=''
  if [ "$status" -ne 0 ] && [ "$status" -ne 130 ] && [ $((SECONDS-started)) -lt 8 ]; then
    warn "$(ui 'Não consegui abrir a última conversa (talvez ainda não exista uma neste projeto).' 'Could not open the latest conversation (there may not be one yet).')"
    say_ui 'Abra “Começar uma conversa nova” e, no fim, use Encerrar com resumo.' 'Start a new conversation, then use Wrap up with a summary when done.'
  else
    say ''
    say_ui 'Conversa encerrada. Confira DOCS/ANDAMENTO.md e use “Continuar o trabalho” na próxima vez.' 'Conversation ended. Check DOCS/ANDAMENTO.md and choose Continue the work next time.'
  fi
  return "$status"
}
api_environment_notice() {
  local name found=0
  for name in OPENAI_API_KEY CODEX_API_KEY CODEX_ACCESS_TOKEN ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_BASE_URL; do
    if printenv "$name" >/dev/null 2>&1; then
      printf '  Variável configurada: %s (valor oculto)\n' "$name"; found=1
    fi
  done
  if [ "$found" -eq 1 ]; then
    say 'Chaves de acesso configuradas no ambiente podem valer mais que o login do navegador.'
    say_ui 'Para usar só uma assinatura, abra um terminal sem essas variáveis ou ajuste sua configuração.' 'To use only a subscription, open a Terminal without these variables or adjust your configuration.'
  fi
}
install_tool() {
  local method url tempdir file status=0
  header "$(ui 'Instalar / atualizar' 'Install / update') · $TOOL"
  say_ui '1) Instalador nativo oficial — não exige Node.js nem Homebrew' '1) Official native installer — no Node.js or Homebrew needed'
  say_ui '2) Homebrew já instalado' '2) Homebrew already installed'
  [ "$TOOL" != codex ] || say_ui '3) npm já instalado (alternativa para Codex)' '3) npm already installed (Codex alternative)'
  say_ui '0) Voltar' '0) Back'
  ask_ui 'Método [1]: ' 'Method [1]: ' || return 1
  method="${REPLY:-1}"
  case "$method" in
    1)
      if [ "$TOOL" = codex ]; then url='https://chatgpt.com/codex/install.sh'
      else url='https://claude.ai/install.sh'; fi
      say "$(ui 'Origem' 'Source'): $url"
      say_ui 'O script oficial será baixado e executado. O fornecedor mantém seu instalador.' 'The official script will be downloaded and run. The vendor maintains this installer.'
      ask_ui 'Digite INSTALAR para continuar: ' 'Type INSTALL to continue: ' || return 1
      [ "$REPLY" = INSTALAR ] || [ "$REPLY" = INSTALL ] || { say_ui 'Instalação cancelada.' 'Installation canceled.'; return 1; }
      tempdir="$(mktemp -d "${TMPDIR:-/tmp}/assistente-instalar.XXXXXXXX")" || return 1
      file="$tempdir/install.sh"
      if curl --fail --location --silent --show-error --connect-timeout 15 --max-time 120 --proto '=https' --proto-redir '=https' --tlsv1.2 "$url" --output "$file" && /bin/bash -n "$file"; then
        run_foreground /bin/bash "$file"; status=$?
      else status=1; warn "$(ui 'O download ou a verificação de sintaxe falhou. Instalador não executado.' 'Download or syntax verification failed. Installer was not run.')"; fi
      rm -f "$file"; rmdir "$tempdir" 2>/dev/null
      ;;
    2)
      command -v brew >/dev/null 2>&1 || { warn "$(ui 'Homebrew não encontrado. Use o instalador nativo (1).' 'Homebrew not found. Use the native installer (1).')"; return 1; }
      local package='codex'
      [ "$TOOL" != claude ] || package='claude-code'
      say "Comando: brew install --cask $package (ou upgrade se já instalado)"
      ask_ui 'Digite INSTALAR para continuar: ' 'Type INSTALL to continue: ' || return 1
      [ "$REPLY" = INSTALAR ] || [ "$REPLY" = INSTALL ] || return 1
      if brew list --cask "$package" >/dev/null 2>&1; then run_foreground brew upgrade --cask "$package"
      else run_foreground brew install --cask "$package"; fi
      status=$? ;;
    3)
      [ "$TOOL" = codex ] || return 1
      command -v npm >/dev/null 2>&1 || { warn "$(ui 'npm não encontrado. Use o instalador nativo (1).' 'npm not found. Use the native installer (1).')"; return 1; }
      say 'Comando: npm install -g @openai/codex@latest'
      ask_ui 'Digite INSTALAR para continuar: ' 'Type INSTALL to continue: ' || return 1
      [ "$REPLY" = INSTALAR ] || [ "$REPLY" = INSTALL ] || return 1
      run_foreground npm install -g @openai/codex@latest; status=$? ;;
    *) return 1 ;;
  esac
  [ "$status" -eq 0 ] || { warn "Instalador terminou com código $status. Veja a mensagem acima."; return "$status"; }
  hash -r
  if command -v "$TOOL" >/dev/null 2>&1; then
    say "$(ui 'Ferramenta encontrada' 'Agent found'): $(command -v "$TOOL")"
    bounded_capture 8 "$TOOL" --version; say "$CAPTURE"
  else warn "$(ui 'Instalador terminou, mas o comando ainda não foi encontrado. Reabra o Terminal e confira o PATH.' 'Installer finished, but the command is still missing. Reopen Terminal and check PATH.')"; return 1; fi
}
diagnostics() {
  local app status
  header_ui 'Diagnóstico · consultas locais' 'Diagnostics · local checks'
  say "$(ui 'Sistema' 'System'): $(uname -s) / $(uname -m)"
  say "Bash: $BASH_VERSION"
  say "$(ui 'Preferências' 'Preferences'): $STATE_DIR"
  say "$(ui 'Projeto' 'Project'): ${PROJECT:-$(ui 'nenhum' 'none')}"
  for app in codex claude rtk; do
    say ''
    if command -v "$app" >/dev/null 2>&1; then
      say "$app: $(command -v "$app")"
      if bounded_capture 8 "$app" --version; then say "$CAPTURE"; else say_ui 'Não foi possível consultar a versão (erro ou tempo esgotado).' 'Could not check the version (error or timeout).'; fi
    else say "$app: $(ui 'não encontrado no PATH.' 'not found in PATH.')"; fi
  done
  say ''
  local previous_tool="$TOOL"
  TOOL=codex; show_auth || true
  TOOL=claude; show_auth || true
  TOOL="$previous_tool"
  say ''
  api_environment_notice
  say ''
  say_ui 'Este diagnóstico não exibe arquivos de credenciais ou valores de variáveis.' 'These diagnostics do not show credential files or environment variable values.'
  say_ui 'Se pedir suporte, copie apenas o erro. O status oficial pode mostrar seu e-mail.' 'If asking for support, copy only the error. Official status may show your email.'
}
installation_menu() {
  local choice
  while :; do
    header_ui 'Instalação e diagnóstico' 'Installation and diagnostics'
    say_ui '1) Instalar / atualizar o Codex' '1) Install / update Codex'
    say_ui '2) Instalar / atualizar Claude Code' '2) Install / update Claude Code'
    say_ui '3) Diagnóstico: versões, caminhos e login' '3) Diagnostics: versions, paths, and sign-in'
    say_ui '4) Documentação oficial' '4) Official documentation'
    say_ui '0) Voltar' '0) Back'
    ask_ui 'Escolha: ' 'Choose: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) TOOL=codex; install_tool; pause || return 1 ;;
      2) TOOL=claude; install_tool; pause || return 1 ;;
      3) diagnostics; pause || return 1 ;;
      4) say 'Codex: https://developers.openai.com/codex/cli/'
         say 'Claude: https://code.claude.com/docs/en/setup'; pause || return 1 ;;
      0) return 0 ;;
      *) say_ui 'Opção inválida.' 'Invalid option.' ;;
    esac
  done
}
choose_local_file() {
  local method file
  say_ui '1) Escolher arquivo no Finder  2) Digitar caminho  0) Voltar' '1) Choose a file in Finder  2) Enter a path  0) Back'
  ask_ui 'Método [1]: ' 'Method [1]: ' || return 1
  method="${REPLY:-1}"
  case "$method" in
    1) file="$(osascript -e 'POSIX path of (choose file with prompt "Selecione o arquivo para copiar ao projeto")' 2>/dev/null)" || return 1 ;;
    2) ask_ui 'Caminho completo do arquivo: ' 'Full file path: ' || return 1
       file="$(expand_path "$REPLY")" || return 1 ;;
    *) return 1 ;;
  esac
  single_line "$file" && [ -f "$file" ] && [ -r "$file" ] || { warn "$(ui 'Arquivo não encontrado ou sem acesso.' 'File not found or unreadable.')"; return 1; }
  CHOSEN_FILE="$file"
}
copy_attachment() {
  local file name dest
  choose_local_file || return 1
  file="$CHOSEN_FILE"; name="$(basename "$file")"; dest="$PROJECT/ANEXOS/$name"
  safe_project_path "ANEXOS/$name" || return 1
  if [ -e "$PROJECT/ANEXOS" ] && [ ! -d "$PROJECT/ANEXOS" ]; then warn "$(ui 'ANEXOS existe mas não é uma pasta.' 'ANEXOS exists but is not a folder.')"; return 1; fi
  [ ! -e "$dest" ] && [ ! -L "$dest" ] || { warn "$(ui 'Já existe um arquivo com esse nome. Nada foi sobrescrito.' 'A file with that name already exists. Nothing was overwritten.')"; return 1; }
  say "$(ui 'Copiar' 'Copy'): $file"
  say "$(ui 'Para' 'To'): $dest"
  ask_ui 'Enter para copiar; 0 para cancelar: ' 'Press Enter to copy; 0 to cancel: ' || return 1
  [ -z "$REPLY" ] || return 1
  mkdir -p "$PROJECT/ANEXOS" || return 1
  cp -pn "$file" "$dest" || return 1
  say "$(ui 'Copiado. Na conversa, peça para analisar' 'Copied. In the conversation, ask the agent to analyze'): ANEXOS/$name"
}
save_prompt() {
  local name dest line content=''
  say "$(ui 'Este pedido pronto será salvo só neste projeto' 'This saved prompt will belong only to this project'): $PROJECT/PROMPTS/"
  ask_ui 'Nome do pedido (sem extensão, Enter cancela): ' 'Prompt name (without extension; Enter cancels): ' || return 1
  name="$REPLY"
  [ -n "$name" ] || { say_ui 'Cancelado.' 'Canceled.'; return 1; }
  valid_name "$name" || { warn "$(ui 'Nome inválido. Use até 120 caracteres, sem / \ : e sem ponto no começo.' 'Invalid name. Use up to 120 characters without /, backslash, :, or a leading dot.')"; return 1; }
  dest="$PROJECT/PROMPTS/$name.md"
  safe_project_path "PROMPTS/$name.md" || return 1
  [ ! -e "$dest" ] && [ ! -L "$dest" ] || { warn "$(ui 'Esse pedido já existe. Nada foi alterado.' 'This prompt already exists. Nothing changed.')"; return 1; }
  say_ui 'Escreva o pedido. Quando terminar, digite FIM numa linha sozinha (CANCELAR sozinho volta).' 'Write the prompt. Type DONE on its own line to save, or CANCEL to go back.'
  while ask '> '; do
    line="$REPLY"
    case "$line" in
      FIM|DONE)
        text_has_content "$content" || { warn "$(ui 'O pedido está vazio; nada foi salvo.' 'The prompt is empty; nothing was saved.')"; return 1; }
        [ "$(printf '%s' "$content" | wc -c | tr -d ' ')" -le 60000 ] || { warn 'Limite de 60 KB atingido.'; return 1; }
        mkdir -p "$PROJECT/PROMPTS" || return 1
        (set -o noclobber; printf '%s' "$content" > "$dest") || return 1
        say "$(ui 'Pedido salvo' 'Prompt saved'): $dest"; return 0 ;;
      CANCELAR|CANCEL) return 1 ;;
    esac
    content="${content}${line}"$'\n'
    [ "${#content}" -le 60000 ] || { warn 'Limite de 60 KB atingido.'; return 1; }
  done
  warn "$(ui 'A entrada terminou antes do FIM; nada foi salvo.' 'Input ended before DONE; nothing was saved.')"
  return 1
}
backup_project() {
  local parent name dest status
  say_ui 'Escolha onde salvar uma cópia ZIP do projeto inteiro.' 'Choose where to save a ZIP backup of the entire project.'
  say_ui 'O ZIP inclui arquivos ocultos e pode conter .env e outros dados privados.' 'The ZIP includes hidden files and may contain .env and other private data.'
  choose_folder 'Escolha a pasta onde salvar a cópia ZIP' || return 1
  parent="$CHOSEN_FOLDER"
  case "$parent/" in "$PROJECT/"*) warn "$(ui 'Escolha um destino fora do projeto para não incluir o ZIP em si mesmo.' 'Choose a destination outside the project so the ZIP does not include itself.')"; return 1 ;; esac
  name="$(basename "$PROJECT")-$(date '+%Y%m%d-%H%M%S').zip"
  dest="$parent/$name"
  [ ! -e "$dest" ] || { warn "$(ui 'Já existe uma cópia com esse nome.' 'A backup with that name already exists.')"; return 1; }
  say "$(ui 'Destino' 'Destination'): $dest"
  ask_ui 'Enter para criar a cópia; 0 para cancelar: ' 'Press Enter to create the backup; 0 to cancel: ' || return 1
  [ -z "$REPLY" ] || return 1
  run_foreground /usr/bin/ditto -c -k --keepParent "$PROJECT" "$dest"; status=$?
  [ "$status" -eq 0 ] && say "$(ui 'Cópia criada' 'Backup created'): $dest" || warn "$(ui 'Cópia não concluída. Confira a mensagem acima e o arquivo de destino.' 'Backup failed. Check the message above and the destination file.')"
  return "$status"
}
open_site() {
  local target
  ask_ui 'Endereço local (ex.: http://localhost:3000) ou caminho de um arquivo HTML: ' 'Local address (for example, http://localhost:3000) or HTML file path: ' || return 1
  target="$REPLY"
  case "$target" in
    http://localhost:*|http://127.0.0.1:*|https://localhost:*) open -a Safari "$target" ;;
    *)
      [ -f "$target" ] || { warn 'Informe um HTML existente ou a URL local exibida pelo seu servidor.'; return 1; }
      case "$target" in *.html|*.htm|*.HTML|*.HTM) open -a Safari "$target" ;; *) warn 'Escolha um arquivo HTML.'; return 1 ;; esac ;;
  esac
}
# Descoberta limitada à pasta CODIGO e a um nível de subpastas, sem seguir links.
# Os chamadores declaram PROJECT_CODE_DIRS local para não guardar estado entre ações.
project_code_directories() {
  local dir relative candidates=()
  PROJECT_CODE_DIRS=()
  [ -n "$PROJECT" ] && [ -d "$PROJECT" ] && [ ! -L "$PROJECT" ] || return 1
  for dir in "$PROJECT"/*; do candidates[${#candidates[@]}]="$dir"; done
  if [ -d "$PROJECT/CODIGO" ] && [ ! -L "$PROJECT/CODIGO" ]; then
    for dir in "$PROJECT/CODIGO"/*; do candidates[${#candidates[@]}]="$dir"; done
  fi
  for dir in "${candidates[@]}"; do
    [ -d "$dir" ] && [ ! -L "$dir" ] || continue
    relative="${dir#"$PROJECT"/}"
    case "$relative" in .*|*/.*|node_modules|*/node_modules) continue ;; esac
    single_line "$relative" || continue
    safe_project_path "$relative" || continue
    PROJECT_CODE_DIRS[${#PROJECT_CODE_DIRS[@]}]="$dir"
  done
}
start_dev_server() {
  local dir target='' relative i choice PROJECT_CODE_DIRS=() packages=()
  [ -n "$PROJECT" ] && [ -d "$PROJECT" ] && [ ! -L "$PROJECT" ] || return 1
  if [ -f "$PROJECT/package.json" ] && [ ! -L "$PROJECT/package.json" ]; then
    safe_project_path package.json || return 1
    target="$PROJECT"
  else
    project_code_directories || return 1
    for dir in "${PROJECT_CODE_DIRS[@]}"; do
      [ -f "$dir/package.json" ] && [ ! -L "$dir/package.json" ] || continue
      packages[${#packages[@]}]="$dir"
    done
    [ "${#packages[@]}" -gt 0 ] || { warn "$(ui 'Não existe package.json nesta pasta.' 'There is no package.json in this folder.')"; return 1; }
    if [ "${#packages[@]}" -eq 1 ]; then
      target="${packages[0]}"
    else
      say_ui 'Qual projeto deseja iniciar?' 'Which project would you like to start?'
      i=1
      for dir in "${packages[@]}"; do
        printf '%s) %s\n' "$i" "${dir#"$PROJECT"/}"
        i=$((i+1))
      done
      say_ui '0) Cancelar' '0) Cancel'
      while ask_ui 'Escolha: ' 'Choose: '; do
        choice="$REPLY"
        [ "$choice" != 0 ] || return 1
        i=1
        for dir in "${packages[@]}"; do
          if [ "$choice" = "$i" ]; then target="$dir"; break; fi
          i=$((i+1))
        done
        [ -z "$target" ] || break
        say_ui 'Opção inválida. Escolha um número da lista ou 0 para cancelar.' 'Invalid option. Choose a number from the list or 0 to cancel.'
      done
      [ -n "$target" ] || return 1
    fi
    say "$(ui 'Pasta' 'Folder'): ${target#"$PROJECT"/}"
  fi
  command -v npm >/dev/null 2>&1 || { warn "$(ui 'npm não encontrado. Instale Node.js para executar este projeto.' 'npm not found. Install Node.js to run this project.')"; return 1; }
  say_ui 'Executar: npm run dev' 'Run: npm run dev'
  say_ui 'Esse comando executa o script dev definido pelo projeto. Ctrl+C encerra o servidor.' 'This runs the dev script defined by the project. Ctrl+C stops the server.'
  ask_ui 'Enter para executar; 0 para cancelar: ' 'Press Enter to run; 0 to cancel: ' || return 1
  [ -z "$REPLY" ] || return 1
  relative="${target#"$PROJECT"/}"
  [ "$target" != "$PROJECT" ] || relative='.'
  [ ! -L "$PROJECT" ] && safe_project_path "$relative/package.json" || return 1
  [ -f "$target/package.json" ] || return 1
  (cd "$target" && run_foreground npm run dev)
}
git_changes() {
  local dir relative found=0 status=0 PROJECT_CODE_DIRS=()
  [ -n "$PROJECT" ] && [ -d "$PROJECT" ] && [ ! -L "$PROJECT" ] || return 1
  if [ "$(uname -s)" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
    say_ui 'O Git ainda não está disponível neste Mac: faltam as ferramentas de linha de comando da Apple.' 'Git is unavailable on this Mac: Apple command-line tools are missing.'
    say 'Para instalar, digite no Terminal: xcode-select --install'
    return 0
  fi
  command -v git >/dev/null 2>&1 || { say_ui 'O Git não foi encontrado neste Mac.' 'Git was not found on this Mac.'; return 0; }
  if [ ! -L "$PROJECT/.git" ] && git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    (cd "$PROJECT" && git status --short --branch)
    return $?
  fi
  project_code_directories || return 1
  for dir in "${PROJECT_CODE_DIRS[@]}"; do
    [ -e "$dir/.git" ] && [ ! -L "$dir/.git" ] || continue
    relative="${dir#"$PROJECT"/}"
    safe_project_path "$relative/.git" || continue
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
    found=1
    say "Repositório: $relative"
    git -C "$dir" status --short --branch || status=$?
  done
  [ "$found" -ne 0 ] || say_ui 'Esta pasta não usa Git; não há alterações para mostrar.' 'This folder does not use Git; there are no changes to show.'
  return "$status"
}
project_tools() {
  local choice file skip
  ensure_project || return 1
  while :; do
    header_ui 'Cuidar do projeto' 'Project care'
    say_ui 'INSTRUÇÕES E PEDIDOS PRONTOS' 'INSTRUCTIONS AND SAVED PROMPTS'
    say_ui ' 3) Criar um pedido pronto novo' ' 3) Create a new saved prompt'
    say_ui ' 9) Editar as instruções permanentes (e atalhos de Claude/Codex)' ' 9) Edit permanent instructions (and Claude/Codex shortcuts)'
    say_ui '10) Abrir a pasta de pedidos prontos (para colar arquivos .md)' '10) Open saved prompts folder (to add .md files)'
    say_ui '11) Organizar um projeto antigo (com backup)' '11) Organize an existing project (with backup)'
    say_ui '12) Verificar se a pasta está organizada' '12) Check project organization'
    say ''
    say_ui 'ARQUIVOS' 'FILES'
    say_ui ' 1) Abrir a pasta no Finder' ' 1) Open folder in Finder'
    say_ui ' 2) Copiar um anexo para ANEXOS (imagem, PDF, documento)' ' 2) Copy an attachment to ANEXOS (image, PDF, document)'
    say_ui ' 4) Capturar parte da tela para ANEXOS' ' 4) Capture part of the screen to ANEXOS'
    say ''
    say_ui 'OUTROS' 'OTHER'
    say_ui ' 5) Ver alterações do Git' ' 5) View Git changes'
    say_ui ' 6) Criar uma cópia ZIP do projeto' ' 6) Create a ZIP backup of the project'
    say_ui ' 7) Abrir o site local no Safari' ' 7) Open local site in Safari'
    say_ui ' 8) Iniciar o servidor do site (npm run dev)' ' 8) Start the site server (npm run dev)'
    say ''
    say_ui ' 0) Voltar ao menu' ' 0) Back to main menu'
    ask_ui 'Escolha: ' 'Choose: ' || return 1
    choice="$REPLY"
    skip=''
    case "$choice" in
      1) open "$PROJECT"; skip=1 ;;
      2) copy_attachment ;;
      3) save_prompt ;;
      4)
        safe_project_path ANEXOS || return 1
        mkdir -p "$PROJECT/ANEXOS" || return 1
        file="$PROJECT/ANEXOS/captura-$(date '+%Y%m%d-%H%M%S')-$RANDOM.png"
        screencapture -i "$file"
        [ ! -s "$file" ] || say "$(ui 'Captura salva' 'Screenshot saved'): $file" ;;
      5) git_changes ;;
      6) backup_project ;;
      7) open_site ;;
      8) start_dev_server ;;
      9) instructions_menu ;;
      10) safe_project_path PROMPTS && mkdir -p "$PROJECT/PROMPTS" && open "$PROJECT/PROMPTS"; skip=1 ;;
      11) organize_project ;;
      12) if type project_doctor >/dev/null 2>&1; then project_doctor; else warn 'Biblioteca de projetos ausente.'; fi ;;
      0) return 0 ;;
      *) say_ui 'Opção inválida.' 'Invalid option.'; skip=1 ;;
    esac
    [ -n "$skip" ] || pause || return 1
  done
}
show_guide() {
  if [ "$APP_LANG" = en ]; then
    header 'How it works in 4 steps'
    say '1. Choose a project: menu 5 (create, open a folder, or recent projects).'
    say '2. Start: menu 2 opens a new conversation; menu 1 resumes the previous one.'
    say '3. Done with a task? Menu 3 saves a summary of project progress.'
    say '4. Next time, menu 2 → Continue the work starts with a concise summary.'
    say ''
    say 'Menu 4 shows usage for each project and helps you decide when to wrap up.'
    say 'Project rules are in INSTRUCOES/PROJETO.md; PROMPTS/ stores ready-to-use requests.'
    say 'Manage automatic behavior in Help and settings → Preferences (menu 7 → 4).'
    say ''
    say "Full guide (Portuguese): $BASE_DIR/GUIA-DE-USO.md"
    ask 'Open the full guide in TextEdit? [y/N]: ' || return 1
    case "$REPLY" in y|Y) open -a TextEdit "$BASE_DIR/GUIA-DE-USO.md" ;; esac
    return 0
  fi
  header 'Como funciona em 4 passos'
  say '1. Escolha o projeto: menu 5 (criar, abrir uma pasta ou projetos recentes).'
  say '2. Comece: menu 2 abre uma conversa nova; menu 1 continua de onde parou.'
  say '3. Terminou uma tarefa? Menu 3 (Encerrar com resumo) guarda o andamento do projeto.'
  say '4. Na próxima vez, menu 2 → “Continuar o trabalho”: a conversa começa leve e já sabe o que foi feito.'
  say ''
  say 'O menu 4 mostra o uso de cada projeto e avisa quando vale encerrar.'
  say 'As regras do projeto ficam em INSTRUCOES/PROJETO.md; PROMPTS/ guarda pedidos prontos.'
  say 'Você controla o que é automático em Ajuda e ajustes → Preferências (menu 7 → 4).'
  say ''
  say "Guia completo: $BASE_DIR/GUIA-DE-USO.md"
  ask 'Abrir o guia completo no TextEdit? [s/N]: ' || return 1
  case "$REPLY" in s|S) open -a TextEdit "$BASE_DIR/GUIA-DE-USO.md" ;; esac
}
resume_menu() {
  say_ui '1) Continuar a última conversa deste projeto' '1) Resume the latest conversation in this project'
  say_ui '2) Escolher uma conversa no seletor oficial' '2) Choose a conversation in the official selector'
  say_ui '0) Voltar' '0) Back'
  ask_ui 'Retomar: ' 'Resume: ' || return 1
  case "$REPLY" in 1) launch_agent recente ;; 2) launch_agent escolher ;; ''|0) return 0 ;; *) return 1 ;; esac
}
# Painel do topo: sempre mostra onde você está, em linguagem simples.
panel_usage_line() {
  local line=''
  if ! opt_enabled peso; then ui 'medição desligada (Ajuda e ajustes → 4)' 'measurement off (Help and settings → 4)'; return 0; fi
  if type project_usage_line >/dev/null 2>&1; then line="$(project_usage_line 2>/dev/null)"
  elif type session_weight_line >/dev/null 2>&1; then line="$(session_weight_line 2>/dev/null)"; fi
  line="${line#Conversa: }"
  [ -z "$line" ] || printf '%s' "$line"
}
panel() {
  local profile tool_name rtk usage sl_line rtk_new
  if [ -z "$PROJECT" ] || [ ! -d "$PROJECT" ]; then
    say_ui '  Vamos começar: crie um projeto novo ou abra uma pasta (opção 5).' '  Get started: create a project or open a folder (option 5).'
    say_ui '  Primeira vez? Veja o guia em Ajuda e ajustes (7) → 6.' '  First time? See the guide in Help and settings (7) → 6.'
    return 0
  fi
  profile="$(project_profile)"
  case "$profile" in codex) tool_name='Codex' ;; claude) tool_name='Claude Code' ;; *) tool_name="$(ui 'a escolher ao abrir' 'choose when opening')" ;; esac
  printf '  %-12s %s\n' "$(ui 'Projeto:' 'Project:')" "$(basename "$PROJECT")"
  printf '  %-12s %s\n' "$(ui 'Pasta:' 'Folder:')" "$PROJECT"
  printf '  %-12s %s\n' "$(ui 'Ferramenta:' 'Agent:')" "$tool_name"
  if [ -n "$profile" ] && type rtk_state_line >/dev/null 2>&1; then
    rtk="$(rtk_state_line "$profile")"; printf '  RTK:         %s\n' "${rtk#RTK: }"
  fi
  if type rtk_update_notice >/dev/null 2>&1; then
    rtk_new="$(rtk_update_notice)"; [ -z "$rtk_new" ] || printf '  %s: %s\n' "$(ui 'Atualização' 'Update')" "$rtk_new"
  fi
  if [ "$profile" = claude ] && type statusline_state_line >/dev/null 2>&1; then
    sl_line="$(statusline_state_line 2>/dev/null | sed 's/^Barra no chat: //')"
    case "$sl_line" in 'não instalada') sl_line="não instalada (Ajuda e ajustes → 7 → 7)" ;; esac
    printf '  %s: %s\n' "$(ui 'Aviso no chat' 'In-chat notice')" "$sl_line"
  fi
  usage="$(panel_usage_line)"
  [ -z "$usage" ] || printf '  %-12s %s\n' "$(ui 'Conversa:' 'Conversation:')" "$usage"
}
screen_title() {
  if [ -t 1 ] && [ "${ASSISTENTE_TEST_MODE:-}" != 1 ]; then printf '\033[2J\033[H'; fi
  printf '\n%s  ASSISTENTE IA · MAC %s%s\n' "$COLOR" "$VERSION" "$RESET"
  printf '  %s\n' "$1"
  rule
}
# Itens que dependem de um projeto: se não houver, leva direto para escolher um.
need_project() {
  [ -n "$PROJECT" ] && [ -d "$PROJECT" ] && return 0
  say_ui 'Primeiro escolha ou crie um projeto.' 'Choose or create a project first.'
  projects_menu choose || true
  [ -n "$PROJECT" ] && [ -d "$PROJECT" ]
}
projects_menu() {
  local mode="${1:-launch}" choice done_pick=1
  while :; do
    header_ui 'Projetos: trocar, abrir ou criar' 'Projects: switch, open, or create'
    say_ui '1) Criar um projeto novo' '1) Create a new project'
    say_ui '2) Abrir a pasta de um projeto que já existe' '2) Open an existing project folder'
    say_ui '3) Escolher entre os projetos recentes' '3) Choose a recent project'
    say_ui '0) Voltar ao menu' '0) Back to main menu'
    ask_ui 'Escolha: ' 'Choose: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) HIDE_PROJECT_HEADER=1 create_project && done_pick=0 ;;
      2) HIDE_PROJECT_HEADER=1 select_project && done_pick=0 ;;
      3) HIDE_PROJECT_HEADER=1 recent_projects && done_pick=0 ;;
      0|'') return 0 ;;
      *) say_ui 'Escolha 1, 2, 3 ou 0.' 'Choose 1, 2, 3, or 0.'; continue ;;
    esac
    if [ "$done_pick" -eq 0 ]; then
      if [ "$mode" = launch ]; then
        ask_ui 'Começar uma conversa agora? [S/n]: ' 'Start a conversation now? [Y/n]: ' || return 1
        case "$REPLY" in n|N|0) return 0 ;; esac
        launch_agent novo
        pause || return 1
      fi
      return 0
    fi
    pause || return 1
  done
}
settings_menu() {
  local choice
  while :; do
    header_ui 'Ajuda e ajustes' 'Help and settings'
    say_ui '1) Contas e login' '1) Accounts and sign-in'
    say_ui '2) RTK: economia na saída de comandos' '2) RTK: reduce command output'
    say_ui '3) Dicas para economizar uso da conversa' '3) Tips for efficient conversations'
    say_ui '4) Preferências: ligar ou desligar o que é automático' '4) Preferences: automatic features'
    say_ui '5) Instalação e diagnóstico' '5) Installation and diagnostics'
    say_ui '6) Como funciona em 4 passos (guia)' '6) Four-step guide'
    say_ui '7) Aviso de uso dentro do chat do Claude' '7) Claude in-chat usage notice'
    say_ui '8) Idioma / Language' '8) Language / Idioma'
    say_ui '0) Voltar ao menu' '0) Back to main menu'
    ask_ui 'Escolha: ' 'Choose: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) accounts_menu ;;
      2) if type rtk_menu >/dev/null 2>&1; then rtk_menu; else warn 'Biblioteca RTK ausente. Descompacte o kit completo.'; fi ;;
      3) if type tips_menu >/dev/null 2>&1; then tips_menu; else warn 'Biblioteca de dicas ausente. Descompacte o kit completo.'; fi; pause || return 1 ;;
      4) control_menu ;;
      5) installation_menu ;;
      6) show_guide; pause || return 1 ;;
      7) if type statusline_menu >/dev/null 2>&1; then statusline_menu; else say 'Recurso ainda não instalado neste kit.'; fi; pause || return 1 ;;
      8) language_menu; pause || return 1 ;;
      0|'') return 0 ;;
      *) say_ui 'Escolha uma opção de 0 a 8.' 'Choose an option from 0 to 8.' ;;
    esac
  done
}
# Conversa muito longa: sugere encerrar com resumo antes de continuar (devolve 2 se já tratou).
long_conversation_gate() {
  local profile
  opt_enabled peso && type usage_measure >/dev/null 2>&1 || return 0
  profile="$(project_profile 2>/dev/null)" || return 0
  [ -n "$profile" ] || return 0
  usage_measure "$profile" "$PROJECT" >/dev/null 2>&1
  [ "${USAGE_STATE:-}" = muito-longa ] || return 0
  ask_ui 'Sua conversa está muito longa. Encerrar com resumo primeiro? [S/n]: ' 'Your conversation is very long. Wrap up with a summary first? [Y/n]: ' || return 1
  case "$REPLY" in n|N|0) return 0 ;; esac
  quick_close
  return 2
}
main() {
  local choice prompt_text pause_after gate
  init_state || return 1
  if type rtk_check_background >/dev/null 2>&1; then rtk_check_background; fi
  trap 'printf "\n%s\n" "$(ui "Operação interrompida. Você pode voltar ao menu." "Operation interrupted. You can return to the menu.")"' INT
  while :; do
    screen_title "$(ui 'Painel' 'Dashboard')"
    panel
    printf '\n  %s\n' "$(ui 'O QUE VOCÊ QUER FAZER?' 'WHAT WOULD YOU LIKE TO DO?')"
    say_ui ' 1) Continuar de onde parei' ' 1) Resume where I left off'
    say_ui ' 2) Começar uma conversa nova' ' 2) Start a new conversation'
    say_ui ' 3) Encerrar com resumo (guarda o andamento)' ' 3) Wrap up with a summary (save progress)'
    say_ui ' 4) Painel de uso dos projetos (quando encerrar)' ' 4) Project usage dashboard (when to wrap up)'
    say_ui ' 5) Projetos: trocar, abrir ou criar' ' 5) Projects: switch, open, or create'
    say_ui ' 6) Cuidar do projeto: instruções, pedidos prontos, anexos, verificar' ' 6) Project care: instructions, prompts, files, checks'
    say_ui ' 7) Ajuda e ajustes: contas, RTK, dicas, preferências' ' 7) Help and settings: accounts, RTK, tips, preferences'
    say_ui ' 8) Escolher uma conversa antiga (lista oficial da ferramenta)' ' 8) Choose an older conversation (official agent list)'
    say_ui ' 0) Sair' ' 0) Exit'
    prompt_text="$(ui $'\nEscolha: ' $'\nChoose: ')"
    if [ -n "$PROJECT" ] && opt_enabled atalho; then prompt_text="$(ui $'\nEscolha (Enter = continuar): ' $'\nChoose (Enter = resume): ')"; fi
    ask "$prompt_text" || { say "$(ui $'\nAté a próxima!' $'\nSee you next time!')"; return 0; }
    choice="$REPLY"
    [ -n "$choice" ] || [ -z "$PROJECT" ] || ! opt_enabled atalho || choice=1
    pause_after=1
    case "$choice" in
      1) if need_project; then long_conversation_gate; gate=$?; [ "$gate" -ne 0 ] || quick_resume; fi ;;
      2) need_project && launch_agent novo ;;
      3) need_project && quick_close ;;
      4) if need_project; then
           if ! opt_enabled peso; then say 'A medição do uso está desligada. Para ligar: Ajuda e ajustes (7) → 4 → item 3.'
           elif type usage_panel >/dev/null 2>&1; then usage_panel
           else warn 'Painel de uso ainda não instalado neste kit.'; fi
         fi ;;
      5) projects_menu launch; pause_after='' ;;
      6) need_project && project_tools; pause_after='' ;;
      7) settings_menu; pause_after='' ;;
      8) need_project && resume_menu ;;
      0) say_ui 'Até a próxima!' 'See you next time!'; return 0 ;;
      *) say_ui 'Escolha uma opção de 0 a 8.' 'Choose an option from 0 to 8.'; pause_after='' ;;
    esac
    if [ -n "$pause_after" ]; then pause || return 0; fi
  done
}
if [ -f "$BASE_DIR/lib/projects.sh" ]; then . "$BASE_DIR/lib/projects.sh"; fi
if [ -f "$BASE_DIR/lib/rtk.sh" ]; then . "$BASE_DIR/lib/rtk.sh"; fi
if [ -f "$BASE_DIR/lib/dicas.sh" ]; then . "$BASE_DIR/lib/dicas.sh"; fi
if [ -f "$BASE_DIR/lib/painel.sh" ]; then . "$BASE_DIR/lib/painel.sh"; fi
if [ -f "$BASE_DIR/lib/statusline.sh" ]; then . "$BASE_DIR/lib/statusline.sh"; fi
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  load_language
  case "${1:-}" in
    --help|-h)
      if [ "$APP_LANG" = en ]; then
        printf 'Assistente IA Mac %s\n\nDouble-click the launcher or run: /bin/bash ASSISTENTE-IA-MAC.command\n\n--check         Check files and syntax without changing preferences\n--diagnostics   Show versions and sign-in status (read-only)\n--rtk          Open the RTK menu\n--rtk status   Show installation and integrations\n--rtk gain     Show estimated savings\n--rtk history  Show recent recorded operations\n--rtk verify   Test command rewriting without running commands\n--rtk monitor  Open the live monitor in this Terminal\n--rtk update   Check for a new RTK version and update after confirmation\n--rtk enable codex|claude     Configure integration after confirmation\n--rtk disable codex|claude    Remove integration after confirmation\n' "$VERSION"
      else
        printf 'Assistente IA Mac %s\n\nAbra com dois cliques ou execute: /bin/bash ASSISTENTE-IA-MAC.command\n\n--check         Confere arquivos e sintaxe sem alterar preferências\n--diagnostico   Mostra versões e situação do login (somente leitura)\n--rtk          Abre o menu RTK\n--rtk status   Mostra instalação e integrações\n--rtk ganhos   Mostra economia estimada\n--rtk historico   Exibe últimas operações registradas\n--rtk verificar   Testa o mecanismo de reescrita sem executar comandos\n--rtk monitor    Abre monitor ao vivo neste terminal\n--rtk atualizar  Procura versão nova do RTK e atualiza, após confirmação\n--rtk ativar codex|claude       Configura integração, após confirmação\n--rtk desativar codex|claude    Remove integração, após confirmação\n' "$VERSION"
      fi
      exit 0 ;;
    --check)
      result=0
      /bin/bash -n "$BASE_DIR/ASSISTENTE-IA-MAC.command" || result=1
      for required in lib/rtk.sh lib/projects.sh lib/dicas.sh lib/painel.sh lib/statusline.sh lib/statusline-claude.sh lib/catalog.js GUIA-DE-USO.md LEIA-PRIMEIRO.txt; do
        [ -s "$BASE_DIR/$required" ] || { warn "Arquivo ausente: $required"; result=1; }
      done
      [ ! -f "$BASE_DIR/lib/rtk.sh" ] || /bin/bash -n "$BASE_DIR/lib/rtk.sh" || result=1
      [ ! -f "$BASE_DIR/lib/projects.sh" ] || /bin/bash -n "$BASE_DIR/lib/projects.sh" || result=1
      [ ! -f "$BASE_DIR/lib/dicas.sh" ] || /bin/bash -n "$BASE_DIR/lib/dicas.sh" || result=1
      for extra in lib/painel.sh lib/statusline.sh lib/statusline-claude.sh; do
        [ ! -f "$BASE_DIR/$extra" ] || /bin/bash -n "$BASE_DIR/$extra" || result=1
      done
      [ "$result" -ne 0 ] || say_ui 'Kit completo. Sintaxe Bash verificada.' 'Kit complete. Bash syntax verified.'
      exit "$result" ;;
    --diagnostico|--diagnostics) diagnostics; exit 0 ;;
    --rtk) shift; rtk_command "$@"; exit $? ;;
    '') main ;;
    *) warn "$(ui 'Argumento desconhecido. Use --help.' 'Unknown argument. Use --help.')"; exit 2 ;;
  esac
fi
