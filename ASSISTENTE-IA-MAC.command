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
COMMAND=()
COLOR='' RESET='' DIM=''
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then COLOR=$'\033[1;36m'; RESET=$'\033[0m'; DIM=$'\033[2m'; fi
say() { printf '%s\n' "$*"; }
warn() { printf '\nAtenção: %s\n' "$*" >&2; }
ask() { printf '%s' "$1" >&2; IFS= LC_ALL=C read -r REPLY; }
pause() { ask $'\nEnter para voltar... ' || return 1; }
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
  [ -z "$PROJECT" ] || [ -n "${HIDE_PROJECT_HEADER:-}" ] || printf '  Projeto atual: %s\n' "$PROJECT"
  if [ -n "$PROJECT" ] && [ -z "${HIDE_PROJECT_HEADER:-}" ] && type project_profile >/dev/null 2>&1; then
    local profile
    profile="$(project_profile)"
    [ -z "$profile" ] || printf '  Ferramenta do projeto: %s\n' "$profile"
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
    rm -f "$temporary"; warn 'Não consegui salvar a preferência. Confira espaço e permissão da pasta.'; return 1
  fi
}
get() { [ ! -f "$1" ] || IFS= read -r REPLY < "$1"; printf '%s' "${REPLY:-}"; }
read_value() { REPLY=''; get "$1"; }
init_state() {
  umask 077
  mkdir -p "$STATE_DIR/projects" || { warn "Não consegui abrir as preferências: $STATE_DIR"; return 1; }
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
  single_line "$value" || { warn 'Use um caminho sem tabulação ou quebra de linha.'; return 1; }
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
  say '1) Escolher no Finder'
  say '2) Colar ou digitar o caminho'
  say '0) Voltar'
  while ask 'Como escolher a pasta? [1]: '; do
    mode="${REPLY:-1}"
    case "$mode" in
      0) return 1 ;;
      1)
        if command -v osascript >/dev/null 2>&1; then
          chosen="$(osascript -e "POSIX path of (choose folder with prompt \"$dialog\")" 2>/dev/null)"
          if [ -n "$chosen" ]; then
            CHOSEN_FOLDER="$(normalize_path "$chosen")" && return 0
          fi
          say 'Seleção cancelada ou Finder indisponível. Você também pode usar 2.'
        else say 'Finder indisponível. Escolha 2 para informar o caminho.'; fi
        ;;
      2)
        ask 'Caminho da pasta existente (Enter cancela): ' || return 1
        [ -n "$REPLY" ] || return 1
        chosen="$REPLY"
        CHOSEN_FOLDER="$(normalize_path "$chosen")" && return 0
        ;;
      *) say 'Digite 1, 2 ou 0.' ;;
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
  header 'Abrir projeto existente'
  say 'Selecione a pasta que contém o projeto. Seus arquivos serão preservados.'
  choose_folder || return 1
  set_project "$CHOSEN_FOLDER" || return 1
  say "Projeto selecionado: $PROJECT"
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
  header 'Projetos recentes'
  if [ -f "$STATE_DIR/recents" ]; then
    while IFS= read -r line; do
      [ -d "$line" ] || continue
      paths[${#paths[@]}]="$line"
      label="$(folder_tool_label "$line")"
      i=$((i+1)); printf '%2s) %s%s — %s\n' "$i" "$(basename "$line")" "${label:+ ($label)}" "$line"
    done < "$STATE_DIR/recents"
  fi
  [ "$i" -gt 0 ] || { say 'Nenhum projeto recente ainda. Volte e escolha 1 (Criar) ou 2 (Abrir pasta).'; return 1; }
  say '0) Voltar'
  while ask 'Projeto: '; do
    pick="$REPLY"
    case "$pick" in 0|'') return 1 ;; *[!0-9]*) say 'Digite o número do projeto.'; continue ;; esac
    [ "${#pick}" -le 2 ] || continue
    pick=$((10#$pick))
    if [ "$pick" -ge 1 ] && [ "$pick" -le "$i" ]; then set_project "${paths[$((pick-1))]}"; return $?; fi
    say 'Número fora da lista.'
  done
  return 1
}
ensure_project() {
  [ -d "$PROJECT" ] && return 0
  say 'Primeiro escolha o projeto.'
  say '1) Criar novo  2) Abrir existente  3) Recentes  0) Voltar'
  ask 'Escolha: ' || return 1
  case "$REPLY" in 1) create_project ;; 2) select_project ;; 3) recent_projects ;; *) return 1 ;; esac
}
choose_tool() {
  say '1) Codex — conta ChatGPT/OpenAI'
  say '2) Claude Code — conta Claude/Anthropic'
  say '0) Voltar'
  while ask 'Ferramenta: '; do
    case "$REPLY" in 1) TOOL=codex; return 0 ;; 2) TOOL=claude; return 0 ;; 0|'') return 1 ;; *) say 'Escolha 1, 2 ou 0.' ;; esac
  done
  return 1
}
require_tool() {
  command -v "$TOOL" >/dev/null 2>&1 && return 0
  warn "$TOOL não está instalado ou não está no PATH."
  say 'O aplicativo de desktop e a ferramenta de terminal são instalações diferentes.'
  ask 'Abrir opções de instalação? [s/N]: ' || return 1
  case "$REPLY" in s|S) install_tool ;; *) return 1 ;; esac
  command -v "$TOOL" >/dev/null 2>&1
}
logged_in() {
  if [ "$TOOL" = codex ]; then bounded_capture 8 codex login status
  else bounded_capture 8 claude auth status; fi
}
login_tool() {
  local choice status force="${1:-}"
  require_tool || return 1
  header "Entrar no $TOOL"
  if [ "$force" != force ] && logged_in; then
    if [ -n "${IN_ACCOUNTS:-}" ]; then say 'Login reconhecido. Para mudar de conta, escolha 3 (Trocar de conta) aqui mesmo.'
    else say 'Login reconhecido. Para mudar de conta: Ajuda e ajustes (7) → 1 → Trocar de conta.'; fi
    return 0
  fi
  if [ "$TOOL" = codex ]; then
    say '1) Entrar com ChatGPT pelo navegador'
    say '2) Código de dispositivo — alternativa se o navegador/localhost falhar'
    say '0) Voltar'
    ask 'Método [1]: ' || return 1
    choice="${REPLY:-1}"
    case "$choice" in
      1) run_foreground codex login ;;
      2) run_foreground codex login --device-auth ;;
      *) return 1 ;;
    esac
    status=$?
  else
    say '1) Assinatura/conta Claude — login normal'
    say '2) Anthropic Console — API com cobrança por consumo'
    say '0) Voltar'
    ask 'Método [1]: ' || return 1
    choice="${REPLY:-1}"
    case "$choice" in
      1) run_foreground claude auth login ;;
      2) run_foreground claude auth login --console ;;
      *) return 1 ;;
    esac
    status=$?
  fi
  if [ "$status" -eq 0 ] && logged_in; then say 'Login confirmado. Agora você pode escolher o modelo.'; return 0; fi
  warn 'Login não confirmado. Veja a mensagem acima. Você pode tentar novamente em Contas.'
  return 1
}
ensure_login() {
  require_tool || return 1
  if logged_in; then say "$TOOL: login reconhecido."; return 0; fi
  login_tool
}
show_auth() {
  if ! command -v "$TOOL" >/dev/null 2>&1; then say "$TOOL: não instalado."; return 1; fi
  if [ "$TOOL" = codex ]; then
    bounded_capture 8 codex login status
  else bounded_capture 8 claude auth status --text; fi
  local status=$?
  say "${CAPTURE:-Status indisponível.}"
  return "$status"
}
switch_account() {
  require_tool || return 1
  header "Trocar conta · $TOOL"
  show_auth || true
  api_environment_notice
  say 'Vou sair da conta atual e abrir o login oficial para outra conta.'
  say 'Isso pode afetar outras interfaces que compartilham esse login.'
  say 'No navegador, escolha a outra conta; se preciso, use a opção de trocar conta lá.'
  say 'Os arquivos do projeto continuam na pasta. Históricos dependem da ferramenta/conta.'
  ask 'Digite TROCAR para continuar (Enter cancela): ' || return 1
  [ "$REPLY" = TROCAR ] || { say 'Troca cancelada.'; return 1; }
  if [ "$TOOL" = codex ]; then run_foreground codex logout; else run_foreground claude auth logout; fi
  [ "$?" -eq 0 ] || { warn 'O logout falhou. Não iniciei outro login.'; return 1; }
  if [ -n "$PREF_DIR" ]; then put "$PREF_DIR/$TOOL.model" ''; put "$PREF_DIR/$TOOL.effort" ''; fi
  MODEL='' EFFORT=''
  say 'Sessão encerrada. Escolha o método de entrada para a nova conta.'
  login_tool force
}
accounts_menu() {
  local choice profile=''
  header 'Contas e login'
  [ -z "$PROJECT" ] || profile="$(project_profile 2>/dev/null)" || profile=''
  if [ -n "$profile" ]; then TOOL="$profile"; say "Ferramenta do projeto: $TOOL"
  else choose_tool || return 1; fi
  IN_ACCOUNTS=1
  while :; do
    header "Conta · $TOOL"
    say '1) Ver situação do login'
    say '2) Entrar / concluir login'
    say '3) Trocar de conta'
    say '4) Sair da conta atual'
    say '0) Voltar'
    ask 'Escolha: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) show_auth; pause || return 1 ;;
      2) login_tool; pause || return 1 ;;
      3) switch_account; pause || return 1 ;;
      4)
        if ! require_tool; then pause || return 1; continue; fi
        ask 'Digite SAIR para deslogar (Enter cancela): ' || return 1
        if [ "$REPLY" = SAIR ]; then
          if [ "$TOOL" = codex ]; then run_foreground codex logout; else run_foreground claude auth logout; fi
        fi
        pause || return 1 ;;
      0) IN_ACCOUNTS=''; return 0 ;;
      *) say 'Opção inválida.' ;;
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
  header "Passo 2 de 4 · Escolher modelo · $TOOL"
  say 'Modelo = qual IA responde. Se não souber, aperte Enter.'
  say ''
  say 'Enter) Manter a preferência deste projeto'
  say "        ${MODEL:-Padrão da ferramenta (dá para trocar depois com /model)}"
  say '1) Padrão da ferramenta — na conversa, /model mostra a lista oficial'
  if [ "$TOOL" = codex ]; then
    load_catalog
    if [ "${#MODEL_IDS[@]}" -gt 0 ]; then
      say 'Catálogo local do Codex (pode estar desatualizado; acesso depende da conta):'
      i=0
      while [ "$i" -lt "${#MODEL_IDS[@]}" ]; do
        printf '%2s) %s [%s]\n' "$((i+2))" "${MODEL_LABELS[$i]}" "${MODEL_IDS[$i]}"
        i=$((i+1))
      done
    else say 'O cache ainda não está disponível. Você pode escolher no próprio Codex com /model.'; fi
  else
    say '2) Sonnet — opção para trabalho diário'
    say '3) Opus — raciocínio complexo'
    say '4) Haiku — tarefas simples e rápidas'
  fi
  say 'm) Digitar identificador/alias exato'
  say '0) Voltar'
  while ask 'Modelo [Enter mantém]: '; do
    pick="$REPLY"
    case "$pick" in
      '') return 0 ;;
      0) return 1 ;;
      1) MODEL=''; EFFORT=''; return 0 ;;
      m|M)
        ask 'Identificador do modelo (Enter cancela): ' || return 1
        candidate="$REPLY"
        valid_model "$candidate" || { say 'Identificador inválido. Use somente letras, números, -, _, ., /, : ou colchetes.'; continue; }
        MODEL="$candidate"; EFFORT=''; return 0 ;;
      *[!0-9]*) say 'Escolha uma opção da lista.'; continue ;;
      *)
        [ "${#pick}" -le 2 ] || continue
        pick=$((10#$pick))
        if [ "$TOOL" = claude ]; then
          case "$pick" in 2) MODEL=sonnet ;; 3) MODEL=opus ;; 4) MODEL=haiku ;; *) say 'Número fora da lista.'; continue ;; esac
        else
          selected=$((pick-2))
          if [ "$selected" -lt 0 ] || [ "$selected" -ge "${#MODEL_IDS[@]}" ]; then say 'Número fora da lista.'; continue; fi
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
  header "Passo 2 de 4 · Esforço de raciocínio · $TOOL"
  say 'Esforço = quanto a IA pensa antes de responder. O automático costuma bastar.'
  say ''
  say '1) Automático / padrão do modelo (recomendado)'
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
    say 'Ajustes disponíveis variam por modelo. Para outros níveis, use /model dentro do agente.'
  fi
  say 'Enter) Manter o atual'
  say "        ${EFFORT:-automático}"
  say '0) Voltar'
  while ask 'Esforço [Enter mantém]: '; do
    pick="$REPLY"
    case "$pick" in '') return 0 ;; 0) return 1 ;; 1) EFFORT=''; return 0 ;; *[!0-9]*) say 'Opção inválida.'; continue ;; esac
    [ "${#pick}" -le 2 ] || continue
    pick=$((10#$pick-2))
    if [ "$pick" -ge 0 ] && [ "$pick" -lt "${#choices[@]}" ]; then EFFORT="${choices[$pick]}"; return 0; fi
    say 'Número fora da lista.'
  done
  return 1
}
select_workmode() {
  say '1) Trabalhar — conversar e implementar na pasta do projeto'
  say '2) Planejar — analisar antes de implementar'
  say '0) Voltar'
  ask "Modo [Enter mantém $WORKMODE]: " || return 1
  case "$REPLY" in '') return 0 ;; 1) WORKMODE=trabalhar ;; 2) WORKMODE=planejar ;; *) return 1 ;; esac
}
load_prompt_file() {
  local file="$1" ext
  case "$file" in *.md|*.txt|*.MD|*.TXT) ;; *) warn 'Escolha um arquivo .md ou .txt.'; return 1 ;; esac
  [ -f "$file" ] && [ -r "$file" ] || { warn 'Arquivo não encontrado ou sem acesso.'; return 1; }
  [ "$(wc -c < "$file" | tr -d ' ')" -le 60000 ] || { warn 'Arquivo maior que 60 KB. Peça ao agente para ler o arquivo dentro do projeto.'; return 1; }
  INITIAL_PROMPT="$(cat "$file")"
  text_has_content "$INITIAL_PROMPT" || { warn 'O pedido está vazio. Edite o arquivo antes de usá-lo.'; return 1; }
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
    case "$pick" in 0|'') return 1 ;; *[!0-9]*) say 'Digite o número ao lado do pedido.'; continue ;; esac
    [ "${#pick}" -le 6 ] || continue
    pick=$((10#$pick))
    if [ "$pick" -ge 1 ] && [ "$pick" -le "${#prompt_files[@]}" ]; then
      load_prompt_file "${prompt_files[$((pick-1))]}" && return 0
      return 1
    fi
    say 'Número fora da lista.'
  done
}
# Há andamento de verdade em DOCS/ANDAMENTO.md (além dos títulos e do texto do modelo)?
has_real_progress() {
  local file="$PROJECT/DOCS/ANDAMENTO.md"
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  LC_ALL=C /usr/bin/grep -v '^[[:space:]]*$' "$file" | LC_ALL=C /usr/bin/grep -v '^#' | LC_ALL=C /usr/bin/grep -Fv 'Registre fatos confirmados' | LC_ALL=C /usr/bin/grep -q .
}
choose_prompt() {
  local choice line file default=2
  INITIAL_PROMPT='' IMAGE=''
  say "Projeto: $PROJECT"
  if [ -f "$PROJECT/PROMPTS/CONTINUAR.md" ]; then
    if has_real_progress; then default=1
    else say 'Projeto novo: ainda não há andamento para continuar.'; fi
  fi
  say 'Como você quer começar?'
  if [ -f "$PROJECT/PROMPTS/CONTINUAR.md" ] && ! has_real_progress; then
    say '1) Continuar o trabalho (ainda sem andamento registrado)'
  elif [ -f "$PROJECT/PROMPTS/CONTINUAR.md" ]; then
    say '1) Continuar o trabalho (o agente lê o andamento do projeto)'
  else
    say '1) Continuar o trabalho (indisponível: falta PROMPTS/CONTINUAR.md)'
  fi
  say '2) Escrever um pedido novo (várias linhas)'
  say '3) Escolher um pedido pronto salvo (pasta PROMPTS/)'
  say '4) Começar sem pedido e escrever dentro do agente'
  say '5) Usar um arquivo .md/.txt de outra pasta'
  say '6) Começar com uma imagem (Codex)'
  say '0) Voltar'
  ask "Escolha [$default]: " || return 1
  choice="${REPLY:-$default}"
  case "$choice" in
    1)
      [ -f "$PROJECT/PROMPTS/CONTINUAR.md" ] || { warn 'Este projeto não tem PROMPTS/CONTINUAR.md (Cuidar do projeto → 12 cria os pedidos prontos padrão).'; return 1; }
      load_prompt_file "$PROJECT/PROMPTS/CONTINUAR.md" ;;
    2)
      say 'Escreva o pedido. Quando terminar, digite FIM numa linha sozinha (CANCELAR sozinho volta).'
      while ask '> '; do
        line="$REPLY"
        case "$line" in FIM) return 0 ;; CANCELAR) return 1 ;; esac
        INITIAL_PROMPT="${INITIAL_PROMPT}${line}"$'\n'
        [ "${#INITIAL_PROMPT}" -le 60000 ] || { warn 'Pedido muito longo. Use um arquivo no projeto.'; return 1; }
      done
      return 1 ;;
    3) choose_saved_prompt ;;
    4) return 0 ;;
    5)
      say 'Selecione o arquivo .md ou .txt que contém seu pedido.'
      choose_local_file || return 1
      file="$CHOSEN_FILE"
      load_prompt_file "$file" ;;
    6)
      [ "$TOOL" = codex ] || { say 'Para Claude, salve a imagem em ANEXOS e peça para analisá-la na conversa.'; return 1; }
      choose_local_file || return 1
      IMAGE="$CHOSEN_FILE"
      [ -f "$IMAGE" ] || { warn 'Imagem não encontrada.'; return 1; }
      case "$IMAGE" in *.png|*.jpg|*.jpeg|*.webp|*.PNG|*.JPG|*.JPEG|*.WEBP) ;; *) warn 'Use PNG, JPG ou WEBP.'; return 1 ;; esac
      ask 'O que fazer com a imagem? [Analisar a imagem]: ' || return 1
      INITIAL_PROMPT="${REPLY:-Analise a imagem e me ajude a trabalhar neste projeto.}" ;;
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
  header 'Passo 1 de 4 · Ferramenta'
  choose_project_tool || return 1
  ensure_login || return 1
  load_preferences
  rtk_preflight
  if [ -f "$PREF_DIR/$TOOL.mode" ]; then use_saved_settings && skip=0
  else first_time_settings && skip=0; fi
  if [ "$skip" -ne 0 ]; then
    select_model || return 1
    select_effort || return 1
    header 'Passo 2 de 4 · Como trabalhar'
    select_workmode || return 1
  fi
  INITIAL_PROMPT='' IMAGE=''
  if [ "$mode" = novo ]; then
    header 'Passo 3 de 4 · Seu pedido'
    choose_prompt || return 1
  fi
  header 'Passo 4 de 4 · Pronto para começar'
  say "Ferramenta: $TOOL"
  say "Conversa: $mode"
  say "Modelo: ${MODEL:-padrão da ferramenta — /model troca durante a conversa}"
  say "Esforço: ${EFFORT:-automático}"
  say "Modo: $WORKMODE"
  if [ -f "$PROJECT/INSTRUCOES/PROJETO.md" ]; then
    say 'Instruções permanentes: INSTRUCOES/PROJETO.md (menu 6 → 9 para editar)'
  fi
  type rtk_state_line >/dev/null 2>&1 && say "$(rtk_state_line "$TOOL")"
  type project_quick_warnings >/dev/null 2>&1 && project_quick_warnings
  launch_extras
  [ -z "$INITIAL_PROMPT" ] || printf '\nSeu pedido:\n%s\n' "$INITIAL_PROMPT"
  [ -z "$IMAGE" ] || say "Imagem: $IMAGE"
  say ''
  say 'Dentro da conversa: /model escolhe outra IA para responder; /status mostra o estado da sessão.'
  say 'Para voltar ao menu: use /exit. Ctrl+C interrompe uma ação.'
  say 'Na primeira abertura, a própria ferramenta pode pedir confiança na pasta.'
  ask 'Enter para começar; 0 para cancelar: ' || return 1
  case "$REPLY" in ''|s|S) ;; *) say 'Conversa cancelada.'; return 1 ;; esac
  save_preferences || return 1
  build_command "$TOOL" "$mode"
  (
    cd "$PROJECT" || exit 1
    run_foreground "${COMMAND[@]}"
  )
  status=$?
  say ''
  if [ "$status" -eq 0 ]; then say 'Conversa encerrada. Você voltou ao assistente.'
  elif [ "$status" -eq 130 ]; then say 'Conversa interrompida. Você voltou ao assistente.'
  else
    warn "$TOOL terminou com código $status. A mensagem original está acima."
    say 'Se o modelo não estiver disponível, inicie outra vez e escolha 1 (padrão da ferramenta).'
    say 'Se a versão não reconhecer um comando, use Ajuda e ajustes → Instalação e diagnóstico.'
  fi
  return "$status"
}
# Chaves de controle: cada recurso automático pode ser desligado (arquivo opt-<nome>-off).
opt_enabled() { [ ! -e "$STATE_DIR/opt-$1-off" ]; }
opt_flip() {
  if opt_enabled "$1"; then put "$STATE_DIR/opt-$1-off" off >/dev/null 2>&1
  else rm -f "$STATE_DIR/opt-$1-off"; fi
}
opt_label() { if opt_enabled "$1"; then printf 'LIGADO   '; else printf 'desligado'; fi; }
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
    header 'Preferências e controle'
    say "1) $(opt_label rtk)  Conferir RTK ao abrir a conversa (pergunta antes; Enter = ativar)"
    say "2) $(opt_label dicas)  Mostrar uma dica de economia ao abrir a conversa"
    say "3) $(opt_label peso)  Medir o uso da conversa e avisar quando estiver longa"
    say "4) $(opt_label atalho)  Enter no menu principal = continuar de onde parei"
    say "5) $(opt_label atualizacao)  Verificar 1x por dia se há RTK novo (só consulta; nunca instala sozinho)"
    say '6) Ver o que o assistente faz sozinho'
    say '0) Voltar'
    ask 'Escolha para ligar/desligar: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) opt_flip rtk ;; 2) opt_flip dicas ;; 3) opt_flip peso ;; 4) opt_flip atalho ;;
      5) opt_flip atualizacao ;;
      6) transparency; pause || return 1 ;;
      0|'') return 0 ;;
      *) say 'Opção inválida.' ;;
    esac
  done
}
# Primeira conversa do projeto: segue com o padrão, a menos que a pessoa queira ajustar.
first_time_settings() {
  say ''
  say 'Passo 2 de 4 · Modelo e modo de trabalho'
  say 'Primeira conversa deste projeto: vou usar a configuração padrão.'
  say 'Modelo = qual IA responde. Se não souber, aperte Enter.'
  say "Modo: $WORKMODE"
  ask 'Ajustar modelo e esforço? [s/N]: ' || return 1
  case "$REPLY" in s|S) return 1 ;; esac
  return 0
}
use_saved_settings() {
  say ''
  say "Configurações salvas deste projeto: modelo ${MODEL:-padrão da ferramenta} · esforço ${EFFORT:-automático} · modo $WORKMODE"
  ask 'Usar essas configurações? [S/n]: ' || return 1
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
  header 'Continuar de onde parei'
  choose_project_tool || return 1
  ensure_login || return 1
  load_preferences
  rtk_preflight
  say ''
  say "Ferramenta: $TOOL · modelo ${MODEL:-padrão da ferramenta} · esforço ${EFFORT:-automático} · modo $WORKMODE"
  type project_quick_warnings >/dev/null 2>&1 && project_quick_warnings
  launch_extras
  INITIAL_PROMPT='' IMAGE=''
  ask 'Enter para continuar a última conversa; 0 cancela: ' || return 1
  case "$REPLY" in ''|s|S) ;; *) say 'Cancelado.'; return 1 ;; esac
  save_preferences || return 1
  started=$SECONDS
  run_agent_session recente; status=$?
  # Só uma saída imediata com erro indica que não havia conversa para retomar.
  if [ "$status" -ne 0 ] && [ "$status" -ne 130 ] && [ $((SECONDS-started)) -lt 8 ]; then
    warn "Não consegui retomar (talvez ainda não exista conversa anterior neste projeto)."
    ask 'Abrir uma conversa nova com as mesmas configurações? [s/N]: ' || return 1
    case "$REPLY" in s|S) ;; *) return "$status" ;; esac
    run_agent_session novo; status=$?
  fi
  say ''
  [ "$status" -eq 0 ] && say 'Conversa encerrada. Você voltou ao assistente.'
  return "$status"
}
# Continua a última conversa e pede o resumo que atualiza DOCS/ANDAMENTO.md.
quick_close() {
  local status started file
  ensure_project || return 1
  header 'Encerrar com resumo'
  choose_project_tool || return 1
  file="$PROJECT/PROMPTS/ENCERRAR-SESSAO.md"
  if [ ! -f "$file" ]; then
    say 'Este projeto ainda não tem o pedido pronto PROMPTS/ENCERRAR-SESSAO.md.'
    ask 'Criar os pedidos prontos padrão agora (sem sobrescrever nada)? [S/n]: ' || return 1
    case "$REPLY" in n|N|0) return 1 ;; esac
    type create_missing_default_prompts >/dev/null 2>&1 && create_missing_default_prompts || return 1
    [ -f "$file" ] || { warn 'Não consegui criar o pedido de encerramento.'; return 1; }
  fi
  ensure_login || return 1
  load_preferences
  rtk_preflight
  say ''
  say 'O que vai acontecer:'
  say '  1. A última conversa deste projeto abre e recebe o pedido de resumo.'
  say '  2. O agente atualiza DOCS/ANDAMENTO.md (curto, só fatos confirmados).'
  say '  3. Depois feche com /exit. Na próxima vez, use “Começar uma conversa nova” → Continuar o trabalho.'
  if [ "$TOOL" = codex ]; then
    say 'Se o Codex abrir sem o pedido, digite: leia PROMPTS/ENCERRAR-SESSAO.md e siga.'
  fi
  load_prompt_file "$file" || return 1
  IMAGE=''
  ask 'Enter para encerrar com resumo; 0 cancela: ' || return 1
  case "$REPLY" in ''|s|S) ;; *) say 'Cancelado.'; INITIAL_PROMPT=''; return 1 ;; esac
  save_preferences || return 1
  started=$SECONDS
  run_agent_session recente; status=$?
  INITIAL_PROMPT=''
  if [ "$status" -ne 0 ] && [ "$status" -ne 130 ] && [ $((SECONDS-started)) -lt 8 ]; then
    warn 'Não consegui abrir a última conversa (talvez ainda não exista uma neste projeto).'
    say 'Abra “Começar uma conversa nova” e, no fim, use Encerrar com resumo.'
  else
    say ''
    say 'Conversa encerrada. Confira DOCS/ANDAMENTO.md e use “Continuar o trabalho” na próxima vez.'
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
    say 'Para usar só uma assinatura, abra um terminal sem essas variáveis ou ajuste sua configuração.'
  fi
}
install_tool() {
  local method url tempdir file status=0
  header "Instalar / atualizar · $TOOL"
  say '1) Instalador nativo oficial — não exige Node.js nem Homebrew'
  say '2) Homebrew já instalado'
  [ "$TOOL" != codex ] || say '3) npm já instalado (alternativa para Codex)'
  say '0) Voltar'
  ask 'Método [1]: ' || return 1
  method="${REPLY:-1}"
  case "$method" in
    1)
      if [ "$TOOL" = codex ]; then url='https://chatgpt.com/codex/install.sh'
      else url='https://claude.ai/install.sh'; fi
      say "Origem: $url"
      say 'O script oficial será baixado e executado. O fornecedor mantém seu instalador.'
      ask 'Digite INSTALAR para continuar: ' || return 1
      [ "$REPLY" = INSTALAR ] || { say 'Instalação cancelada.'; return 1; }
      tempdir="$(mktemp -d "${TMPDIR:-/tmp}/assistente-instalar.XXXXXXXX")" || return 1
      file="$tempdir/install.sh"
      if curl --fail --location --silent --show-error --connect-timeout 15 --max-time 120 --proto '=https' --proto-redir '=https' --tlsv1.2 "$url" --output "$file" && /bin/bash -n "$file"; then
        run_foreground /bin/bash "$file"; status=$?
      else status=1; warn 'O download ou a verificação de sintaxe falhou. Instalador não executado.'; fi
      rm -f "$file"; rmdir "$tempdir" 2>/dev/null
      ;;
    2)
      command -v brew >/dev/null 2>&1 || { warn 'Homebrew não encontrado. Use o instalador nativo (1).'; return 1; }
      local package='codex'
      [ "$TOOL" != claude ] || package='claude-code'
      say "Comando: brew install --cask $package (ou upgrade se já instalado)"
      ask 'Digite INSTALAR para continuar: ' || return 1
      [ "$REPLY" = INSTALAR ] || return 1
      if brew list --cask "$package" >/dev/null 2>&1; then run_foreground brew upgrade --cask "$package"
      else run_foreground brew install --cask "$package"; fi
      status=$? ;;
    3)
      [ "$TOOL" = codex ] || return 1
      command -v npm >/dev/null 2>&1 || { warn 'npm não encontrado. Use o instalador nativo (1).'; return 1; }
      say 'Comando: npm install -g @openai/codex@latest'
      ask 'Digite INSTALAR para continuar: ' || return 1
      [ "$REPLY" = INSTALAR ] || return 1
      run_foreground npm install -g @openai/codex@latest; status=$? ;;
    *) return 1 ;;
  esac
  [ "$status" -eq 0 ] || { warn "Instalador terminou com código $status. Veja a mensagem acima."; return "$status"; }
  hash -r
  if command -v "$TOOL" >/dev/null 2>&1; then
    say "Ferramenta encontrada: $(command -v "$TOOL")"
    bounded_capture 8 "$TOOL" --version; say "$CAPTURE"
  else warn 'Instalador terminou, mas o comando ainda não foi encontrado. Reabra o Terminal e confira o PATH.'; return 1; fi
}
diagnostics() {
  local app status
  header 'Diagnóstico · consultas locais'
  say "Sistema: $(uname -s) / $(uname -m)"
  say "Bash: $BASH_VERSION"
  say "Preferências: $STATE_DIR"
  say "Projeto: ${PROJECT:-nenhum}"
  for app in codex claude rtk; do
    say ''
    if command -v "$app" >/dev/null 2>&1; then
      say "$app: $(command -v "$app")"
      if bounded_capture 8 "$app" --version; then say "$CAPTURE"; else say 'Não foi possível consultar a versão (erro ou tempo esgotado).'; fi
    else say "$app: não encontrado no PATH."; fi
  done
  say ''
  local previous_tool="$TOOL"
  TOOL=codex; show_auth || true
  TOOL=claude; show_auth || true
  TOOL="$previous_tool"
  say ''
  api_environment_notice
  say ''
  say 'Este diagnóstico não exibe arquivos de credenciais ou valores de variáveis.'
  say 'Se pedir suporte, copie apenas o erro. O status oficial pode mostrar seu e-mail.'
}
installation_menu() {
  local choice
  while :; do
    header 'Instalação e diagnóstico'
    say '1) Instalar / atualizar o Codex'
    say '2) Instalar / atualizar Claude Code'
    say '3) Diagnóstico: versões, caminhos e login'
    say '4) Documentação oficial'
    say '0) Voltar'
    ask 'Escolha: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) TOOL=codex; install_tool; pause || return 1 ;;
      2) TOOL=claude; install_tool; pause || return 1 ;;
      3) diagnostics; pause || return 1 ;;
      4) say 'Codex: https://developers.openai.com/codex/cli/'
         say 'Claude: https://code.claude.com/docs/en/setup'; pause || return 1 ;;
      0) return 0 ;;
      *) say 'Opção inválida.' ;;
    esac
  done
}
choose_local_file() {
  local method file
  say '1) Escolher arquivo no Finder  2) Digitar caminho  0) Voltar'
  ask 'Método [1]: ' || return 1
  method="${REPLY:-1}"
  case "$method" in
    1) file="$(osascript -e 'POSIX path of (choose file with prompt "Selecione o arquivo para copiar ao projeto")' 2>/dev/null)" || return 1 ;;
    2) ask 'Caminho completo do arquivo: ' || return 1
       file="$(expand_path "$REPLY")" || return 1 ;;
    *) return 1 ;;
  esac
  single_line "$file" && [ -f "$file" ] && [ -r "$file" ] || { warn 'Arquivo não encontrado ou sem acesso.'; return 1; }
  CHOSEN_FILE="$file"
}
copy_attachment() {
  local file name dest
  choose_local_file || return 1
  file="$CHOSEN_FILE"; name="$(basename "$file")"; dest="$PROJECT/ANEXOS/$name"
  safe_project_path "ANEXOS/$name" || return 1
  if [ -e "$PROJECT/ANEXOS" ] && [ ! -d "$PROJECT/ANEXOS" ]; then warn 'ANEXOS existe mas não é uma pasta.'; return 1; fi
  [ ! -e "$dest" ] && [ ! -L "$dest" ] || { warn 'Já existe um arquivo com esse nome. Nada foi sobrescrito.'; return 1; }
  say "Copiar: $file"
  say "Para: $dest"
  ask 'Enter para copiar; 0 para cancelar: ' || return 1
  [ -z "$REPLY" ] || return 1
  mkdir -p "$PROJECT/ANEXOS" || return 1
  cp -pn "$file" "$dest" || return 1
  say "Copiado. Na conversa, peça para analisar: ANEXOS/$name"
}
save_prompt() {
  local name dest line content=''
  say "Este pedido pronto será salvo só neste projeto: $PROJECT/PROMPTS/"
  ask 'Nome do pedido (sem extensão, Enter cancela): ' || return 1
  name="$REPLY"
  [ -n "$name" ] || { say 'Cancelado.'; return 1; }
  valid_name "$name" || { warn 'Nome inválido. Use até 120 caracteres, sem / \ : e sem ponto no começo.'; return 1; }
  dest="$PROJECT/PROMPTS/$name.md"
  safe_project_path "PROMPTS/$name.md" || return 1
  [ ! -e "$dest" ] && [ ! -L "$dest" ] || { warn 'Esse pedido já existe. Nada foi alterado.'; return 1; }
  say 'Escreva o pedido. Quando terminar, digite FIM numa linha sozinha (CANCELAR sozinho volta).'
  while ask '> '; do
    line="$REPLY"
    case "$line" in
      FIM)
        text_has_content "$content" || { warn 'O pedido está vazio; nada foi salvo.'; return 1; }
        [ "$(printf '%s' "$content" | wc -c | tr -d ' ')" -le 60000 ] || { warn 'Limite de 60 KB atingido.'; return 1; }
        mkdir -p "$PROJECT/PROMPTS" || return 1
        (set -o noclobber; printf '%s' "$content" > "$dest") || return 1
        say "Pedido salvo: $dest"; return 0 ;;
      CANCELAR) return 1 ;;
    esac
    content="${content}${line}"$'\n'
    [ "${#content}" -le 60000 ] || { warn 'Limite de 60 KB atingido.'; return 1; }
  done
  warn 'A entrada terminou antes do FIM; nada foi salvo.'
  return 1
}
backup_project() {
  local parent name dest status
  say 'Escolha onde salvar uma cópia ZIP do projeto inteiro.'
  say 'O ZIP inclui arquivos ocultos e pode conter .env e outros dados privados.'
  choose_folder 'Escolha a pasta onde salvar a cópia ZIP' || return 1
  parent="$CHOSEN_FOLDER"
  case "$parent/" in "$PROJECT/"*) warn 'Escolha um destino fora do projeto para não incluir o ZIP em si mesmo.'; return 1 ;; esac
  name="$(basename "$PROJECT")-$(date '+%Y%m%d-%H%M%S').zip"
  dest="$parent/$name"
  [ ! -e "$dest" ] || { warn 'Já existe uma cópia com esse nome.'; return 1; }
  say "Destino: $dest"
  ask 'Enter para criar a cópia; 0 para cancelar: ' || return 1
  [ -z "$REPLY" ] || return 1
  run_foreground /usr/bin/ditto -c -k --keepParent "$PROJECT" "$dest"; status=$?
  [ "$status" -eq 0 ] && say "Cópia criada: $dest" || warn 'Cópia não concluída. Confira a mensagem acima e o arquivo de destino.'
  return "$status"
}
open_site() {
  local target
  ask 'Endereço local (ex.: http://localhost:3000) ou caminho de um arquivo HTML: ' || return 1
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
    [ "${#packages[@]}" -gt 0 ] || { warn 'Não existe package.json nesta pasta.'; return 1; }
    if [ "${#packages[@]}" -eq 1 ]; then
      target="${packages[0]}"
    else
      say 'Qual projeto deseja iniciar?'
      i=1
      for dir in "${packages[@]}"; do
        printf '%s) %s\n' "$i" "${dir#"$PROJECT"/}"
        i=$((i+1))
      done
      say '0) Cancelar'
      while ask 'Escolha: '; do
        choice="$REPLY"
        [ "$choice" != 0 ] || return 1
        i=1
        for dir in "${packages[@]}"; do
          if [ "$choice" = "$i" ]; then target="$dir"; break; fi
          i=$((i+1))
        done
        [ -z "$target" ] || break
        say 'Opção inválida. Escolha um número da lista ou 0 para cancelar.'
      done
      [ -n "$target" ] || return 1
    fi
    say "Pasta: ${target#"$PROJECT"/}"
  fi
  command -v npm >/dev/null 2>&1 || { warn 'npm não encontrado. Instale Node.js para executar este projeto.'; return 1; }
  say 'Executar: npm run dev'
  say 'Esse comando executa o script dev definido pelo projeto. Ctrl+C encerra o servidor.'
  ask 'Enter para executar; 0 para cancelar: ' || return 1
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
    say 'O Git ainda não está disponível neste Mac: faltam as ferramentas de linha de comando da Apple.'
    say 'Para instalar, digite no Terminal: xcode-select --install'
    return 0
  fi
  command -v git >/dev/null 2>&1 || { say 'O Git não foi encontrado neste Mac.'; return 0; }
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
  [ "$found" -ne 0 ] || say 'Esta pasta não usa Git; não há alterações para mostrar.'
  return "$status"
}
project_tools() {
  local choice file skip
  ensure_project || return 1
  while :; do
    header 'Cuidar do projeto'
    say 'INSTRUÇÕES E PEDIDOS PRONTOS'
    say ' 3) Criar um pedido pronto novo'
    say ' 9) Editar as instruções permanentes (e atalhos de Claude/Codex)'
    say '10) Abrir a pasta de pedidos prontos (para colar arquivos .md)'
    say '11) Organizar um projeto antigo (com backup)'
    say '12) Verificar se a pasta está organizada'
    say ''
    say 'ARQUIVOS'
    say ' 1) Abrir a pasta no Finder'
    say ' 2) Copiar um anexo para ANEXOS (imagem, PDF, documento)'
    say ' 4) Capturar parte da tela para ANEXOS'
    say ''
    say 'OUTROS'
    say ' 5) Ver alterações do Git'
    say ' 6) Criar uma cópia ZIP do projeto'
    say ' 7) Abrir o site local no Safari'
    say ' 8) Iniciar o servidor do site (npm run dev)'
    say ''
    say ' 0) Voltar ao menu'
    ask 'Escolha: ' || return 1
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
        [ ! -s "$file" ] || say "Captura salva: $file" ;;
      5) git_changes ;;
      6) backup_project ;;
      7) open_site ;;
      8) start_dev_server ;;
      9) instructions_menu ;;
      10) safe_project_path PROMPTS && mkdir -p "$PROJECT/PROMPTS" && open "$PROJECT/PROMPTS"; skip=1 ;;
      11) organize_project ;;
      12) if type project_doctor >/dev/null 2>&1; then project_doctor; else warn 'Biblioteca de projetos ausente.'; fi ;;
      0) return 0 ;;
      *) say 'Opção inválida.'; skip=1 ;;
    esac
    [ -n "$skip" ] || pause || return 1
  done
}
show_guide() {
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
  say '1) Continuar a última conversa deste projeto'
  say '2) Escolher uma conversa no seletor oficial'
  say '0) Voltar'
  ask 'Retomar: ' || return 1
  case "$REPLY" in 1) launch_agent recente ;; 2) launch_agent escolher ;; ''|0) return 0 ;; *) return 1 ;; esac
}
# Painel do topo: sempre mostra onde você está, em linguagem simples.
panel_usage_line() {
  local line=''
  if ! opt_enabled peso; then printf 'medição desligada (Ajuda e ajustes → 4)'; return 0; fi
  if type project_usage_line >/dev/null 2>&1; then line="$(project_usage_line 2>/dev/null)"
  elif type session_weight_line >/dev/null 2>&1; then line="$(session_weight_line 2>/dev/null)"; fi
  line="${line#Conversa: }"
  [ -z "$line" ] || printf '%s' "$line"
}
panel() {
  local profile tool_name rtk usage sl_line rtk_new
  if [ -z "$PROJECT" ] || [ ! -d "$PROJECT" ]; then
    say '  Vamos começar: crie um projeto novo ou abra uma pasta (opção 5).'
    say '  Primeira vez? Veja o guia em Ajuda e ajustes (7) → 6.'
    return 0
  fi
  profile="$(project_profile)"
  case "$profile" in codex) tool_name='Codex' ;; claude) tool_name='Claude Code' ;; *) tool_name='a escolher ao abrir' ;; esac
  printf '  Projeto:     %s\n' "$(basename "$PROJECT")"
  printf '  Pasta:       %s\n' "$PROJECT"
  printf '  Ferramenta:  %s\n' "$tool_name"
  if [ -n "$profile" ] && type rtk_state_line >/dev/null 2>&1; then
    rtk="$(rtk_state_line "$profile")"; printf '  RTK:         %s\n' "${rtk#RTK: }"
  fi
  if type rtk_update_notice >/dev/null 2>&1; then
    rtk_new="$(rtk_update_notice)"; [ -z "$rtk_new" ] || printf '  Atualização: %s\n' "$rtk_new"
  fi
  if [ "$profile" = claude ] && type statusline_state_line >/dev/null 2>&1; then
    sl_line="$(statusline_state_line 2>/dev/null | sed 's/^Barra no chat: //')"
    case "$sl_line" in 'não instalada') sl_line="não instalada (Ajuda e ajustes → 7 → 7)" ;; esac
    printf '  Aviso no chat: %s\n' "$sl_line"
  fi
  usage="$(panel_usage_line)"
  [ -z "$usage" ] || printf '  Conversa:    %s\n' "$usage"
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
  say 'Primeiro escolha ou crie um projeto.'
  projects_menu choose || true
  [ -n "$PROJECT" ] && [ -d "$PROJECT" ]
}
projects_menu() {
  local mode="${1:-launch}" choice done_pick=1
  while :; do
    header 'Projetos: trocar, abrir ou criar'
    say '1) Criar um projeto novo'
    say '2) Abrir a pasta de um projeto que já existe'
    say '3) Escolher entre os projetos recentes'
    say '0) Voltar ao menu'
    ask 'Escolha: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) HIDE_PROJECT_HEADER=1 create_project && done_pick=0 ;;
      2) HIDE_PROJECT_HEADER=1 select_project && done_pick=0 ;;
      3) HIDE_PROJECT_HEADER=1 recent_projects && done_pick=0 ;;
      0|'') return 0 ;;
      *) say 'Escolha 1, 2, 3 ou 0.'; continue ;;
    esac
    if [ "$done_pick" -eq 0 ]; then
      if [ "$mode" = launch ]; then
        ask 'Começar uma conversa agora? [S/n]: ' || return 1
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
    header 'Ajuda e ajustes'
    say '1) Contas e login'
    say '2) RTK: economia na saída de comandos'
    say '3) Dicas para economizar uso da conversa'
    say '4) Preferências: ligar ou desligar o que é automático'
    say '5) Instalação e diagnóstico'
    say '6) Como funciona em 4 passos (guia)'
    say '7) Aviso de uso dentro do chat do Claude'
    say '0) Voltar ao menu'
    ask 'Escolha: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) accounts_menu ;;
      2) if type rtk_menu >/dev/null 2>&1; then rtk_menu; else warn 'Biblioteca RTK ausente. Descompacte o kit completo.'; fi ;;
      3) if type tips_menu >/dev/null 2>&1; then tips_menu; else warn 'Biblioteca de dicas ausente. Descompacte o kit completo.'; fi; pause || return 1 ;;
      4) control_menu ;;
      5) installation_menu ;;
      6) show_guide; pause || return 1 ;;
      7) if type statusline_menu >/dev/null 2>&1; then statusline_menu; else say 'Recurso ainda não instalado neste kit.'; fi; pause || return 1 ;;
      0|'') return 0 ;;
      *) say 'Escolha uma opção de 0 a 7.' ;;
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
  ask 'Sua conversa está muito longa. Encerrar com resumo primeiro? [S/n]: ' || return 1
  case "$REPLY" in n|N|0) return 0 ;; esac
  quick_close
  return 2
}
main() {
  local choice prompt_text pause_after gate
  init_state || return 1
  if type rtk_check_background >/dev/null 2>&1; then rtk_check_background; fi
  trap 'printf "\nOperação interrompida. Você pode voltar ao menu.\n"' INT
  while :; do
    screen_title 'Painel'
    panel
    printf '\n  O QUE VOCÊ QUER FAZER?\n'
    say ' 1) Continuar de onde parei'
    say ' 2) Começar uma conversa nova'
    say ' 3) Encerrar com resumo (guarda o andamento)'
    say ' 4) Painel de uso dos projetos (quando encerrar)'
    say ' 5) Projetos: trocar, abrir ou criar'
    say ' 6) Cuidar do projeto: instruções, pedidos prontos, anexos, verificar'
    say ' 7) Ajuda e ajustes: contas, RTK, dicas, preferências'
    say ' 8) Escolher uma conversa antiga (lista oficial da ferramenta)'
    say ' 0) Sair'
    prompt_text=$'\nEscolha: '
    if [ -n "$PROJECT" ] && opt_enabled atalho; then prompt_text=$'\nEscolha (Enter = continuar): '; fi
    ask "$prompt_text" || { say $'\nAté a próxima!'; return 0; }
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
      0) say 'Até a próxima!'; return 0 ;;
      *) say 'Escolha uma opção de 0 a 8.'; pause_after='' ;;
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
  case "${1:-}" in
    --help|-h)
      printf 'Assistente IA Mac %s\n\nAbra com dois cliques ou execute: /bin/bash ASSISTENTE-IA-MAC.command\n\n--check         Confere arquivos e sintaxe sem alterar preferências\n--diagnostico   Mostra versões e situação do login (somente leitura)\n--rtk          Abre o menu RTK\n--rtk status   Mostra instalação e integrações\n--rtk ganhos   Mostra economia estimada\n--rtk historico   Exibe últimas operações registradas\n--rtk verificar   Testa o mecanismo de reescrita sem executar comandos\n--rtk monitor    Abre monitor ao vivo neste terminal\n--rtk atualizar  Procura versão nova do RTK e atualiza, após confirmação\n--rtk ativar codex|claude       Configura integração, após confirmação\n--rtk desativar codex|claude    Remove integração, após confirmação\n' "$VERSION"
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
      [ "$result" -ne 0 ] || say 'Kit completo. Sintaxe Bash verificada.'
      exit "$result" ;;
    --diagnostico) diagnostics; exit 0 ;;
    --rtk) shift; rtk_command "$@"; exit $? ;;
    '') main ;;
    *) warn 'Argumento desconhecido. Use --help.'; exit 2 ;;
  esac
fi
