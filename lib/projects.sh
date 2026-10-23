#!/bin/bash
# Projetos e instruções persistentes. Compatível com Bash 3.2.

text_has_content() { LC_ALL=C /usr/bin/grep -q '[^[:space:]]' <<< "$1"; }

project_profile() {
  local value=''
  if [ -L "$PROJECT/.assistente-ia" ] || [ -L "$PROJECT/.assistente-ia/tool" ]; then return 1; fi
  if [ -e "$PROJECT/.assistente-ia/tool" ]; then
    [ -f "$PROJECT/.assistente-ia/tool" ] || return 1
    IFS= read -r value < "$PROJECT/.assistente-ia/tool"
    case "$value" in codex|claude) printf '%s' "$value"; return 0 ;; *) return 1 ;; esac
  fi
  if [ -f "$PROJECT/AGENTS.md" ] && [ ! -e "$PROJECT/CLAUDE.md" ] && [ ! -d "$PROJECT/.claude" ]; then
    printf codex
  elif [ -f "$PROJECT/CLAUDE.md" ] && [ ! -e "$PROJECT/AGENTS.md" ]; then
    printf claude
  else return 1; fi
}

choose_project_tool() {
  local profile
  profile="$(project_profile)"
  if [ -n "$profile" ]; then
    TOOL="$profile"
    say "Ferramenta deste projeto: $TOOL"
    if [ -f "$PROJECT/AGENTS.md" ] && [ -f "$PROJECT/CLAUDE.md" ]; then
      warn 'Também há instruções da outra ferramenta na raiz. Use menu 6 → 11 para organizar com backup.'
    fi
    return 0
  fi
  if [ -e "$PROJECT/.assistente-ia/tool" ] || [ -L "$PROJECT/.assistente-ia/tool" ] || [ -L "$PROJECT/.assistente-ia" ]; then
    warn 'Perfil do projeto inválido. Confira .assistente-ia/tool antes de continuar.'
    return 1
  fi
  if [ -f "$PROJECT/AGENTS.md" ] && [ -f "$PROJECT/CLAUDE.md" ]; then
    warn 'Este projeto antigo tem instruções das duas ferramentas. Use menu 6 → 11 para organizar com backup.'
  fi
  choose_tool
}

# Não atravessa links simbólicos ao gravar arquivos gerenciados pelo assistente.
safe_project_path() {
  local relative="$1" component current="$PROJECT" parts=()
  [ -n "$PROJECT" ] && [ -d "$PROJECT" ] || { warn 'Escolha o projeto antes de gravar arquivos.'; return 1; }
  case "$relative" in ''|/*|../*|*/../*|*/..) return 1 ;; esac
  local IFS='/'
  read -r -a parts <<< "$relative"
  for component in "${parts[@]}"; do
    current="$current/$component"
    if [ -L "$current" ]; then warn "Caminho é um link simbólico; arquivo preservado: $relative"; return 1; fi
  done
}

write_new_file() {
  local relative="$1"
  safe_project_path "$relative" || return 1
  if [ -e "$PROJECT/$relative" ]; then
    [ -f "$PROJECT/$relative" ] || { warn "$relative existe mas não é arquivo."; return 1; }
    cat >/dev/null
    return 0
  fi
  (set -o noclobber; cat > "$PROJECT/$relative")
}

instruction_entry() {
  printf '\n<!-- assistente-ia: instrucoes-do-projeto -->\n'
  if [ "$TOOL" = claude ]; then
    printf '@INSTRUCOES/PROJETO.md\n'
  else
    printf 'Antes de trabalhar, leia e siga INSTRUCOES/PROJETO.md, relativo à raiz deste projeto.\n'
  fi
  printf 'Consulte outros arquivos de INSTRUCOES/, DOCS/ e ANEXOS/ quando forem relevantes ou citados.\n'
  printf 'PROMPTS/ contém pedidos reutilizáveis: execute apenas o prompt escolhido pelo usuário.\n'
}

efficiency_section() {
  cat <<'EOF'
## Eficiência (economia de tokens)
- Leia só o necessário: busque (grep/lista) antes de abrir arquivos inteiros e não releia o que já viu na conversa.
- Responda curto e direto: sem repetir o pedido e sem despejar código inteiro quando um trecho ou diff basta.
- Em tarefas grandes, planeje primeiro e divida em etapas.
- Registre o andamento em DOCS/ANDAMENTO.md (máx. ~40 linhas; condense, não acumule).
EOF
}

prompt_encerrar_text() {
  cat <<'EOF'
Vamos encerrar esta sessão. Responda em poucas linhas: o que foi concluído, decisões, comandos úteis, pendências e a próxima tarefa.
Depois atualize DOCS/ANDAMENTO.md condensando o conteúdo antigo: no máximo ~40 linhas, só fatos confirmados.
Não repita código nem trechos longos.
EOF
}

prompt_resumo_text() {
  cat <<'EOF'
Esta conversa ficou longa. Gere um resumo de contexto de até 15 linhas para eu colar numa conversa nova: objetivo, estado atual, decisões e próxima tarefa.
Liste também os arquivos-chave que a nova conversa deve ler. Não inclua código.
EOF
}

instructions_template_text() {
  cat <<'EOF'
# Instruções permanentes deste projeto

## Objetivo e contexto
- Objetivo: preencha o que deseja construir e para quem.
- Contexto: descreva o negócio, público e referências importantes.

## Preferências de trabalho
- Responda em português, com explicações claras.
- Leia os arquivos relevantes e preserve o trabalho existente.
- Antes de mudanças extensas, apresente um plano curto.
- Não exponha senhas, chaves, tokens ou arquivos .env.
- Ao concluir, informe mudanças, verificações realmente feitas e pendências.
- Atualize DOCS/ANDAMENTO.md ao concluir etapas relevantes.

## Requisitos específicos
- Preencha tecnologias, estilo, limites e critérios de sucesso deste projeto.
- Consulte outros documentos quando relevantes; não carregue todos os anexos a cada pedido.

EOF
}

prepare_project_files() {
  local folder native
  case "$TOOL" in codex) native=AGENTS.md ;; claude) native=CLAUDE.md ;; *) return 1 ;; esac
  for folder in .assistente-ia INSTRUCOES PROMPTS DOCS ANEXOS; do
    safe_project_path "$folder" || return 1
    mkdir -p "$PROJECT/$folder" || return 1
  done
  { instructions_template_text; efficiency_section; } | write_new_file INSTRUCOES/PROJETO.md || return 1
  write_new_file DOCS/ANDAMENTO.md <<'EOF' || return 1
# Andamento do projeto

## O que funciona

## Decisões importantes

## Próximo passo

## Como executar e verificar

Registre fatos confirmados e pendências. Este arquivo não substitui o histórico da conversa.
EOF
  write_new_file PROMPTS/COMECE-AQUI.md <<'EOF' || return 1
Leia INSTRUCOES/PROJETO.md e os arquivos relevantes para o pedido abaixo.
Objetivo desta tarefa: [substitua pelo resultado desejado].
Critérios para considerar pronto: [descreva o que precisa funcionar].
Use ANEXOS/ e DOCS/ quando forem citados. Preserve arquivos existentes.
Implemente a tarefa, faça as verificações necessárias e explique o resultado em português.
EOF
  write_new_file PROMPTS/PLANEJAR.md <<'EOF' || return 1
Leia INSTRUCOES/PROJETO.md e analise os arquivos relevantes.
Quero planejar: [descreva a mudança].
Apresente uma proposta curta com etapas, decisões e dúvidas que impedem a execução.
Aguarde meu pedido para implementar.
EOF
  write_new_file PROMPTS/CONTINUAR.md <<'EOF' || return 1
Leia INSTRUCOES/PROJETO.md e DOCS/ANDAMENTO.md.
Confira o estado real dos arquivos e identifique a próxima tarefa registrada.
Continue essa tarefa se o escopo estiver definido; caso contrário, esclareça o que falta.
Ao terminar, atualize o andamento com o que foi realmente concluído.
EOF
  prompt_encerrar_text | write_new_file PROMPTS/ENCERRAR-SESSAO.md || return 1
  prompt_resumo_text | write_new_file PROMPTS/RESUMO-RAPIDO.md || return 1
  safe_project_path "$native" || return 1
  if [ ! -e "$PROJECT/$native" ]; then
    { printf '# Orientações do projeto — %s\n' "$TOOL"; instruction_entry; } | write_new_file "$native" || return 1
  fi
  safe_project_path .assistente-ia/tool || return 1
  put "$PROJECT/.assistente-ia/tool" "$TOOL"
}

scaffold_project() {
  local target="$1" name="$2" kind="$3" previous="$PROJECT" status=0
  case "$TOOL" in codex|claude) ;; *) warn 'Escolha a ferramenta antes de criar o projeto.'; return 1 ;; esac
  PROJECT="$target"
  if [ "$kind" = 2 ]; then
    prepare_project_files || status=1
    if [ "$status" -eq 0 ]; then
      printf '# %s\n\n## Objetivo\n\nDescreva a finalidade do projeto.\n\n## Organização\n\n- Ferramenta: %s\n- INSTRUCOES/PROJETO.md: regras permanentes que você pode editar.\n- PROMPTS/: pedidos reutilizáveis; selecione um ao iniciar a conversa.\n- DOCS/: decisões e andamento.\n- ANEXOS/: imagens, PDFs e referências.\n- Código: nesta raiz ou nas pastas que o projeto precisar.\n\nUse o menu 6 do Assistente para editar instruções e criar prompts.\nDepois de mudar instruções permanentes, inicie uma nova conversa.\n' "$name" "$TOOL" | write_new_file README.md || status=1
      write_new_file .gitignore <<'EOF' || status=1
.DS_Store
.env
.env.*
!.env.example
node_modules/
.next/
dist/
build/
.venv/
__pycache__/
*.pem
*.key
DOCS/LEGADO/
DOCS/BACKUPS-INSTRUCOES/
EOF
    fi
  else
    mkdir "$PROJECT/.assistente-ia" && put "$PROJECT/.assistente-ia/tool" "$TOOL" || status=1
  fi
  PROJECT="$previous"
  return "$status"
}

create_project() {
  local parent name target kind group
  header 'Criar projeto · 1 de 4: local'
  say 'Escolha onde guardar seus projetos. Vou separá-los em CODEX/ ou CLAUDE/.'
  choose_folder || return 1
  parent="$CHOSEN_FOLDER"
  header 'Criar projeto · 2 de 4: nome'
  while ask 'Nome do projeto (Enter cancela): '; do
    name="$REPLY"
    [ -n "$name" ] || return 1
    valid_name "$name" && break
    say 'Use até 120 caracteres, sem /, \\, :, ponto inicial ou quebras de linha.'
  done
  [ -n "$name" ] && valid_name "$name" || return 1
  header 'Criar projeto · 3 de 4: ferramenta e estrutura'
  choose_tool || return 1
  case "$TOOL" in codex) group=CODEX ;; claude) group=CLAUDE ;; esac
  if [ "$(basename "$parent")" != "$group" ]; then parent="$parent/$group"; fi
  [ ! -L "$parent" ] || { warn 'O agrupador é um link simbólico. Escolha sua pasta de destino diretamente.'; return 1; }
  target="$parent/$name"
  [ ! -e "$target" ] && [ ! -L "$target" ] || { warn 'Essa pasta já existe. Abra o projeto existente; nada foi sobrescrito.'; return 1; }
  say '1) Mínimo — pasta do projeto e identificação da ferramenta'
  say '2) Organizado — instruções, prompts, documentos e anexos (recomendado)'
  say '0) Cancelar'
  while ask 'Estrutura [2]: '; do
    kind="${REPLY:-2}"
    case "$kind" in 1|2) break ;; 0) return 1 ;; *) say 'Escolha 1, 2 ou 0.' ;; esac
  done
  case "$kind" in 1|2) ;; *) return 1 ;; esac
  header 'Criar projeto · 4 de 4: conferir'
  say "Nova pasta: $target"
  say "Ferramenta: $TOOL"
  say "Estrutura: $([ "$kind" = 2 ] && printf organizada || printf mínima)"
  ask 'Enter para criar; 0 para cancelar: ' || return 1
  case "$REPLY" in ''|s|S) ;; *) say 'Criação cancelada.'; return 1 ;; esac
  mkdir -p "$parent" && mkdir "$target" || return 1
  if ! scaffold_project "$target" "$name" "$kind"; then warn "Estrutura incompleta em $target. Confira permissões e espaço."; return 1; fi
  set_project "$target" || return 1
  say "Projeto pronto: $PROJECT"
  if [ "$kind" = 2 ]; then ask_project_objective || true; fi
}

organize_project_files() {
  local native opposite path archive content
  case "$TOOL" in codex) native=AGENTS.md; opposite=CLAUDE.md ;; claude) native=CLAUDE.md; opposite=AGENTS.md ;; *) return 1 ;; esac
  for path in AGENTS.md CLAUDE.md .assistente-ia/tool INSTRUCOES/PROJETO.md DOCS/LEGADO PROMPTS ANEXOS; do
    safe_project_path "$path" || return 1
    if [ -e "$PROJECT/$path" ]; then
      case "$path" in *.md|*/tool) [ -f "$PROJECT/$path" ] || return 1 ;; *) [ -d "$PROJECT/$path" ] || return 1 ;; esac
    fi
  done
  # Configurações avançadas podem carregar outras regras; não fazer uma migração parcial.
  for path in AGENTS.override.md CLAUDE.local.md; do
    if [ -e "$PROJECT/$path" ] || [ -L "$PROJECT/$path" ]; then
      warn "Projeto tem $path. A organização automática exige revisão desse arquivo/pasta; nada foi alterado."
      return 1
    fi
  done
  if [ -L "$PROJECT/.claude" ] || { [ -e "$PROJECT/.claude" ] && [ ! -d "$PROJECT/.claude" ]; } ||
     { [ "$TOOL" = codex ] && [ -e "$PROJECT/.claude" ]; }; then
    warn 'Projeto tem .claude. A organização automática exige revisão desse arquivo/pasta; nada foi alterado.'
    return 1
  fi
  for path in "$native" INSTRUCOES/PROJETO.md; do
    if [ -f "$PROJECT/$path" ] && /usr/bin/grep -Fq "$opposite" "$PROJECT/$path"; then
      warn "$path referencia $opposite. Revise essa dependência antes de arquivar a entrada; nada foi alterado."
      return 1
    fi
  done
  mkdir -p "$PROJECT/DOCS/LEGADO" || return 1
  archive="$(mktemp -d "$PROJECT/DOCS/LEGADO/organizacao-XXXXXXXX")" || return 1
  for path in "$native" "$opposite" .assistente-ia/tool; do
    [ ! -f "$PROJECT/$path" ] || cp -p "$PROJECT/$path" "$archive/$(basename "$path").original" || return 1
  done
  prepare_project_files || { warn "Organização incompleta. Originais preservados em $archive"; return 1; }
  if ! entry_references_instructions "$PROJECT/$native"; then
    content="$(cat "$PROJECT/$native"; instruction_entry)"
    put "$PROJECT/$native" "$content" || return 1
  fi
  if [ -f "$PROJECT/$opposite" ]; then
    mv "$PROJECT/$opposite" "$archive/$opposite.arquivado" || return 1
  fi
  printf 'Ferramenta escolhida: %s\nOriginais: arquivos .original; arquivo da outra ferramenta: .arquivado.\nPROMPTS e documentos preexistentes foram preservados.\n' "$TOOL" > "$archive/LEIA-ME.txt"
  say "Organizado para $TOOL. Originais preservados em: $archive"
  say 'Abra uma nova conversa para carregar as instruções atualizadas.'
}

organize_project() {
  header 'Organizar projeto existente · com backup'
  say 'Escolha a ferramenta que será usada neste projeto.'
  choose_tool || return 1
  say "Projeto: $PROJECT"
  say "Ferramenta: $TOOL"
  say 'Vou criar INSTRUCOES/ e o perfil; manter prompts e documentos existentes.'
  say 'O arquivo de entrada da ferramenta oposta será arquivado em DOCS/LEGADO/.'
  say 'O arquivo da ferramenta escolhida será preservado e receberá a referência às instruções.'
  say 'Os originais ficarão guardados no backup. Configurações avançadas exigem revisão manual.'
  ask 'Digite ORGANIZAR para aplicar; Enter cancela: ' || return 1
  [ "$REPLY" = ORGANIZAR ] || return 1
  organize_project_files
}

ensure_instruction_setup() {
  local native
  choose_project_tool || return 1
  case "$TOOL" in codex) native=AGENTS.md ;; claude) native=CLAUDE.md ;; esac
  if [ -f "$PROJECT/$native" ] && [ -f "$PROJECT/INSTRUCOES/PROJETO.md" ] && entry_references_instructions "$PROJECT/$native"; then return 0; fi
  say 'Este projeto ainda não tem as instruções organizadas e conectadas ao agente.'
  organize_project || return 1
}

edit_instructions_terminal() {
  local line content='' archive
  safe_project_path INSTRUCOES/PROJETO.md && safe_project_path DOCS/BACKUPS-INSTRUCOES || return 1
  say 'Cole as instruções completas. FIM salva; CANCELAR preserva o arquivo atual.'
  while ask '> '; do
    line="$REPLY"
    case "$line" in
      CANCELAR) return 1 ;;
      FIM)
        text_has_content "$content" || { warn 'Instruções vazias; arquivo preservado.'; return 1; }
        [ "$(printf '%s' "$content" | wc -c | tr -d ' ')" -le 30000 ] || { warn 'Use até 30 KB nas instruções principais.'; return 1; }
        mkdir -p "$PROJECT/DOCS/BACKUPS-INSTRUCOES" || return 1
        archive="$(mktemp "$PROJECT/DOCS/BACKUPS-INSTRUCOES/PROJETO.md.XXXXXXXX")" || return 1
        cp -p "$PROJECT/INSTRUCOES/PROJETO.md" "$archive" || return 1
        put "$PROJECT/INSTRUCOES/PROJETO.md" "$content" || return 1
        say "Instruções salvas. Backup: $archive"
        say 'Inicie uma nova conversa para usar as novas instruções.'
        return 0 ;;
    esac
    content="${content}${line}"$'\n'
    [ "${#content}" -le 30000 ] || { warn 'Instruções longas demais; arquivo preservado.'; return 1; }
  done
  return 1
}

instructions_menu() {
  local choice
  ensure_instruction_setup || return 1
  while :; do
    header 'Instruções permanentes deste projeto'
    say 'Arquivo principal: INSTRUCOES/PROJETO.md'
    say '1) Editar no TextEdit'
    say '2) Substituir pelo terminal (com backup)'
    say '3) Abrir pasta INSTRUCOES no Finder'
    say '4) Criar atalhos de encerrar sessão e resumo (opcional)'
    say '0) Voltar'
    ask 'Escolha: ' || return 1
    choice="$REPLY"
    case "$choice" in
      1) safe_project_path INSTRUCOES/PROJETO.md || return 1
         say 'Salve como texto simples, mantendo a extensão .md. Depois inicie uma nova conversa.'
         open -a TextEdit "$PROJECT/INSTRUCOES/PROJETO.md" ;;
      2) edit_instructions_terminal ;;
      3) open "$PROJECT/INSTRUCOES" ;;
      4) create_project_shortcuts ;;
      0) return 0 ;;
      *) say 'Escolha 1, 2, 3, 4 ou 0.' ;;
    esac
  done
}

# Publica o arquivo completo com um hard link exclusivo, sem sobrescrever.
# O temporário nasce em pasta privada; noclobber protege sua primeira gravação.
write_new_file_atomic() {
  local relative="$1" directory temporary_dir temporary
  [ ! -L "$PROJECT" ] || { warn 'A pasta do projeto é um link simbólico. Nada foi criado.'; return 1; }
  safe_project_path "$relative" || return 1
  if [ -e "$PROJECT/$relative" ]; then
    [ -f "$PROJECT/$relative" ] || { warn "$relative existe mas não é arquivo."; return 1; }
    cat >/dev/null
    return 0
  fi
  directory="${relative%/*}"
  [ "$directory" != "$relative" ] || directory=.
  temporary_dir="$(mktemp -d "$PROJECT/$directory/.assistente-comando.XXXXXXXX")" || return 1
  temporary="$temporary_dir/novo.md"
  if ! (set -o noclobber; cat > "$temporary") || ! safe_project_path "$relative"; then
    rm -f "$temporary"; rmdir "$temporary_dir"; return 1
  fi
  # -n impede seguir um destino que virou symlink de diretório (BSD/macOS e GNU).
  if ! ln -n "$temporary" "$PROJECT/$relative"; then
    rm -f "$temporary"; rmdir "$temporary_dir"; return 1
  fi
  rm -f "$temporary"
  rmdir "$temporary_dir" || return 1
  safe_project_path "$relative" && [ -f "$PROJECT/$relative" ]
}

create_project_shortcuts() {
  local path name profile root relative prompt description dirs=() files=()
  [ ! -L "$PROJECT" ] || { warn 'A pasta do projeto é um link simbólico. Nada foi criado.'; return 1; }
  case "$TOOL" in
    claude)
      root=.claude/commands
      dirs=(.claude .claude/commands)
      files=(.claude/commands/encerrar.md .claude/commands/resumo.md) ;;
    codex)
      root=.agents/skills
      dirs=(.agents .agents/skills .agents/skills/encerrar .agents/skills/resumo)
      files=(.agents/skills/encerrar/SKILL.md .agents/skills/resumo/SKILL.md) ;;
    *) return 1 ;;
  esac
  profile="$(project_profile)" || return 1
  [ "$profile" = "$TOOL" ] || return 1
  # Valida tudo antes de criar pastas; não segue links nem substitui configurações.
  for path in "${dirs[@]}"; do
    safe_project_path "$path" || return 1
    if [ -e "$PROJECT/$path" ] && [ ! -d "$PROJECT/$path" ]; then
      warn "$path existe mas não é uma pasta. Nada foi criado."; return 1
    fi
  done
  for path in "${files[@]}"; do
    safe_project_path "$path" || return 1
    if [ -e "$PROJECT/$path" ] && [ ! -f "$PROJECT/$path" ]; then
      warn "$path existe mas não é arquivo. Nada foi criado."; return 1
    fi
  done
  if [ "$TOOL" = claude ]; then
    for name in encerrar resumo; do safe_project_path ".claude/skills/$name" || return 1; done
  fi
  for path in PROMPTS/ENCERRAR-SESSAO.md PROMPTS/RESUMO-RAPIDO.md; do
    safe_project_path "$path" || return 1
    [ -f "$PROJECT/$path" ] || { warn "Falta $path. Organize o projeto antes de criar os comandos."; return 1; }
  done
  for path in "${dirs[@]}"; do
    safe_project_path "$path" && mkdir -p "$PROJECT/$path" || return 1
  done
  for name in encerrar resumo; do
    if [ "$TOOL" = claude ]; then
      relative="$root/$name.md"
      if [ -e "$PROJECT/.claude/skills/$name" ]; then
        warn "Já existe a skill .claude/skills/$name; o comando /$name não foi criado para evitar conflito."
        continue
      fi
    else relative="$root/$name/SKILL.md"; fi
    if [ -e "$PROJECT/$relative" ]; then
      say "Preservado $relative (já existe)."
      continue
    fi
    case "$name" in
      encerrar) prompt=PROMPTS/ENCERRAR-SESSAO.md; description='Encerrar a sessão e registrar o andamento quando o usuário pedir para encerrar o trabalho.' ;;
      resumo) prompt=PROMPTS/RESUMO-RAPIDO.md; description='Resumir o contexto da conversa quando o usuário pedir um resumo para continuar em outra sessão.' ;;
    esac
    if [ "$TOOL" = claude ]; then
      printf '@%s\n' "$prompt" | write_new_file_atomic "$relative" || return 1
    else
      printf '%s\n' '---' "name: $name" "description: $description" '---' '' \
        'Use esta skill somente quando o usuário pedir esta ação.' \
        "Leia $prompt a partir da raiz deste projeto e execute o pedido desse arquivo." \
        'Preserve o trabalho existente e registre apenas fatos confirmados.' | write_new_file_atomic "$relative" || return 1
    fi
    say "Criado $relative."
  done
  if [ "$TOOL" = claude ]; then
    say 'Abra uma nova sessão do Claude Code neste projeto; use /encerrar ou /resumo se o atalho estiver disponível.'
  else say 'Abra uma nova sessão do Codex neste projeto; use $encerrar ou $resumo.'; fi
}

create_claude_commands() {
  [ "$TOOL" = claude ] || { warn 'Os comandos rápidos desta opção são do Claude Code.'; return 1; }
  create_project_shortcuts
}

# --- Verificação da estrutura do projeto -----------------------------------
PROMPT_LARGE_BYTES=8000
INSTRUCTION_MARKER='<!-- assistente-ia: instrucoes-do-projeto -->'

file_bytes() { wc -c < "$1" | tr -d ' '; }

# Imprime ' (grande — ...)' quando o arquivo parece documento, não prompt.
prompt_size_note() {
  [ -f "$1" ] && [ -r "$1" ] || return 0
  [ "$(file_bytes "$1")" -le "$PROMPT_LARGE_BYTES" ] || printf ' (grande — parece documento; melhor em DOCS/)'
}

# Lista (um por linha) os .md/.txt grandes diretamente em PROMPTS/.
large_prompt_files() {
  local file
  [ -d "$PROJECT/PROMPTS" ] && [ ! -L "$PROJECT/PROMPTS" ] || return 0
  for file in "$PROJECT"/PROMPTS/*.md "$PROJECT"/PROMPTS/*.txt "$PROJECT"/PROMPTS/*.MD "$PROJECT"/PROMPTS/*.TXT; do
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    [ "$(file_bytes "$file")" -le "$PROMPT_LARGE_BYTES" ] || printf '%s\n' "$file"
  done
}

project_native_entry() {
  local tool
  tool="$(project_profile)" || return 1
  case "$tool" in codex) printf AGENTS.md ;; claude) printf CLAUDE.md ;; *) return 1 ;; esac
}

# Aviso forte: o objetivo ainda é o texto-modelo.
instructions_unfilled() {
  local file="$PROJECT/INSTRUCOES/PROJETO.md"
  [ -f "$file" ] && [ ! -L "$file" ] && LC_ALL=C /usr/bin/grep -Fxq -e "$OBJECTIVE_PLACEHOLDER" "$file"
}

# Aviso leve: objetivo escrito, mas restam trechos do modelo (contexto/requisitos).
instructions_details_pending() {
  local file="$PROJECT/INSTRUCOES/PROJETO.md"
  [ -f "$file" ] && [ ! -L "$file" ] && ! instructions_unfilled &&
    LC_ALL=C /usr/bin/grep -Eq '[Pp]reencha|[Dd]escreva o neg' "$file"
}

# Arquivo sem nenhuma linha fora do modelo (e da seção Eficiência): não há texto do usuário a proteger.
instructions_pristine() {
  local file="$PROJECT/INSTRUCOES/PROJETO.md" template extra
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  template="$(mktemp "${TMPDIR:-/tmp}/assistente-modelo.XXXXXXXX")" || return 1
  { instructions_template_text; efficiency_section; } > "$template"
  extra="$(LC_ALL=C /usr/bin/grep -vxF -f "$template" "$file" | LC_ALL=C /usr/bin/grep -c '[^[:space:]]')"
  rm -f "$template"
  [ "${extra:-1}" = 0 ]
}

# Rótulo amigável do peso (bytes/4 ≈ tokens).
weight_label() {
  local tokens=$(( $1 / 4 ))
  if [ "$tokens" -ge 1000 ]; then printf '~%s,%s mil tokens' "$((tokens/1000))" "$(((tokens%1000)/100))"
  else printf '~%s tokens' "$tokens"; fi
}

# Aceita o marcador do kit ou qualquer referência direta (ex.: @INSTRUCOES/PROJETO.md).
entry_references_instructions() {
  /usr/bin/grep -Fq "$INSTRUCTION_MARKER" "$1" 2>/dev/null || /usr/bin/grep -Fq 'INSTRUCOES/PROJETO.md' "$1" 2>/dev/null
}
entry_connected() {
  local native="$1"
  [ -n "$native" ] && [ -f "$PROJECT/$native" ] && [ ! -L "$PROJECT/$native" ] &&
    entry_references_instructions "$PROJECT/$native"
}

FIXED_WEIGHT_WARN_BYTES=12000
ANDAMENTO_WARN_BYTES=8000

# Bytes lidos em toda conversa: arquivo de entrada + INSTRUCOES/PROJETO.md.
fixed_weight_bytes() {
  local total=0 file native bytes
  native="$(project_native_entry)" || native=''
  for file in "$native" INSTRUCOES/PROJETO.md; do
    [ -n "$file" ] && [ -f "$PROJECT/$file" ] && [ ! -L "$PROJECT/$file" ] || continue
    bytes="$(file_bytes "$PROJECT/$file")" || continue
    total=$((total+bytes))
  done
  printf '%s' "$total"
}

andamento_bytes() {
  local file="$PROJECT/DOCS/ANDAMENTO.md"
  [ -f "$file" ] && [ ! -L "$file" ] || { printf 0; return 0; }
  file_bytes "$file"
}

has_efficiency_section() {
  [ -f "$PROJECT/INSTRUCOES/PROJETO.md" ] && [ ! -L "$PROJECT/INSTRUCOES/PROJETO.md" ] &&
    /usr/bin/grep -Fq -e '## Eficiência' "$PROJECT/INSTRUCOES/PROJETO.md"
}

missing_default_prompts() {
  local name
  for name in ENCERRAR-SESSAO.md RESUMO-RAPIDO.md; do
    [ -e "$PROJECT/PROMPTS/$name" ] || [ -L "$PROJECT/PROMPTS/$name" ] || printf '%s\n' "$name"
  done
}

append_efficiency_section() {
  local file="$PROJECT/INSTRUCOES/PROJETO.md" archive temporary
  safe_project_path INSTRUCOES/PROJETO.md && safe_project_path DOCS/BACKUPS-INSTRUCOES || return 1
  [ -f "$file" ] || return 1
  mkdir -p "$PROJECT/DOCS/BACKUPS-INSTRUCOES" || return 1
  archive="$(mktemp "$PROJECT/DOCS/BACKUPS-INSTRUCOES/PROJETO.md.XXXXXXXX")" || return 1
  cp -p "$file" "$archive" || return 1
  temporary="$(mktemp "$file.XXXXXXXX")" || return 1
  keep_file_mode "$file" "$temporary"
  if ! { cat "$file"; printf '\n'; efficiency_section; } > "$temporary" || ! mv -f "$temporary" "$file"; then
    rm -f "$temporary"; return 1
  fi
  say "Seção Eficiência adicionada. Backup: $archive"
}

create_missing_default_prompts() {
  local name
  safe_project_path PROMPTS || return 1
  mkdir -p "$PROJECT/PROMPTS" || return 1
  for name in ENCERRAR-SESSAO.md RESUMO-RAPIDO.md; do
    [ ! -e "$PROJECT/PROMPTS/$name" ] && [ ! -L "$PROJECT/PROMPTS/$name" ] || continue
    case "$name" in
      ENCERRAR-SESSAO.md) prompt_encerrar_text | write_new_file "PROMPTS/$name" || return 1 ;;
      RESUMO-RAPIDO.md) prompt_resumo_text | write_new_file "PROMPTS/$name" || return 1 ;;
    esac
    say "Criado PROMPTS/$name"
  done
}

# Avisos curtos e sem perguntas (no máximo 3 linhas), por prioridade.
project_quick_warnings() {
  local native count=0 file shown=0 weight
  [ -n "$PROJECT" ] && [ -d "$PROJECT" ] || return 0
  if instructions_unfilled; then
    say 'Aviso: INSTRUCOES/PROJETO.md ainda é o modelo. Escreva o objetivo e as regras (menu 6 → 9).'
    shown=$((shown+1))
  elif instructions_details_pending; then
    say 'Aviso leve: faltam detalhes em INSTRUCOES/PROJETO.md (contexto e requisitos). Não é obrigatório para começar.'
    shown=$((shown+1))
  fi
  while IFS= read -r file; do
    [ -n "$file" ] && count=$((count+1))
  done <<EOF
$(large_prompt_files)
EOF
  if [ "$count" -gt 0 ] && [ "$shown" -lt 3 ]; then
    say "Aviso: $count arquivo(s) grande(s) em PROMPTS/ parecem documentos; mova para DOCS/ (menu 6 → 12)."
    shown=$((shown+1))
  fi
  native="$(project_native_entry)" || native=''
  if ! entry_connected "$native" && [ "$shown" -lt 3 ]; then
    say 'Aviso: a entrada da ferramenta (AGENTS.md/CLAUDE.md) não aponta para as instruções (menu 6 → 11).'
    shown=$((shown+1))
  fi
  weight="$(fixed_weight_bytes)"
  if [ "$weight" -gt "$FIXED_WEIGHT_WARN_BYTES" ] && [ "$shown" -lt 3 ]; then
    say "Aviso: instruções fixas pesadas ($(weight_label "$weight") por conversa); enxugue INSTRUCOES/PROJETO.md."
    shown=$((shown+1))
  fi
  if [ "$(andamento_bytes)" -gt "$ANDAMENTO_WARN_BYTES" ] && [ "$shown" -lt 3 ]; then
    say 'Aviso: DOCS/ANDAMENTO.md está grande; condense com o prompt ENCERRAR-SESSAO.'
    shown=$((shown+1))
  fi
  return 0
}

doctor_line() {
  if [ "$1" = ok ]; then printf '  ✓ %s\n' "$2"; else printf '  ! %s\n' "$2"; fi
}

move_prompt_to_docs() {
  local file="$1" name
  name="$(basename "$file")"
  safe_project_path "PROMPTS/$name" && safe_project_path DOCS || return 1
  if [ -e "$PROJECT/DOCS/$name" ] || [ -L "$PROJECT/DOCS/$name" ]; then
    warn "Já existe DOCS/$name. Nada foi movido."
    return 1
  fi
  mkdir -p "$PROJECT/DOCS" || return 1
  safe_project_path "DOCS/$name" || return 1
  mv -n "$file" "$PROJECT/DOCS/$name" || return 1
  [ ! -e "$file" ] || { warn "Não consegui mover $name."; return 1; }
  say "Movido para DOCS/$name"
}

# Objetivo em uma frase: preenche só as linhas ainda em modelo (nunca sobrescreve texto seu).
OBJECTIVE_PLACEHOLDER='- Objetivo: preencha o que deseja construir e para quem.'
README_PLACEHOLDER='Descreva a finalidade do projeto.'

# Mantém as permissões do arquivo original ao regravá-lo (stat do macOS, com alternativa GNU).
keep_file_mode() {
  local mode
  mode="$(stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1" 2>/dev/null)" || return 0
  case "$mode" in [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) chmod "$mode" "$2" 2>/dev/null ;; esac
  return 0
}

replace_first_line() {
  local file="$1" old="$2" new="$3" temporary line found=1
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  temporary="$(mktemp "$file.XXXXXXXX")" || return 1
  keep_file_mode "$file" "$temporary"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$found" -ne 0 ] && [ "$line" = "$old" ]; then printf '%s\n' "$new"; found=0
    else printf '%s\n' "$line"; fi
  done < "$file" > "$temporary"
  if [ "$found" -ne 0 ] || ! mv -f "$temporary" "$file"; then rm -f "$temporary"; return 1; fi
}

objective_pending() {
  [ -f "$PROJECT/INSTRUCOES/PROJETO.md" ] && [ ! -L "$PROJECT/INSTRUCOES/PROJETO.md" ] &&
    /usr/bin/grep -Fxq -e "$OBJECTIVE_PLACEHOLDER" "$PROJECT/INSTRUCOES/PROJETO.md" && return 0
  [ -f "$PROJECT/README.md" ] && [ ! -L "$PROJECT/README.md" ] &&
    /usr/bin/grep -Fxq -e "$README_PLACEHOLDER" "$PROJECT/README.md"
}

fill_project_objective() {
  local text="$1" archive done_files=''
  safe_project_path INSTRUCOES/PROJETO.md && safe_project_path README.md && safe_project_path DOCS/BACKUPS-INSTRUCOES || return 1
  if [ -f "$PROJECT/INSTRUCOES/PROJETO.md" ] && /usr/bin/grep -Fxq -e "$OBJECTIVE_PLACEHOLDER" "$PROJECT/INSTRUCOES/PROJETO.md"; then
    # Arquivo ainda igual ao modelo: nada do usuário a proteger, então sem backup.
    if ! instructions_pristine; then
      mkdir -p "$PROJECT/DOCS/BACKUPS-INSTRUCOES" || return 1
      archive="$(mktemp "$PROJECT/DOCS/BACKUPS-INSTRUCOES/PROJETO.md.XXXXXXXX")" || return 1
      cp -p "$PROJECT/INSTRUCOES/PROJETO.md" "$archive" || return 1
    fi
    replace_first_line "$PROJECT/INSTRUCOES/PROJETO.md" "$OBJECTIVE_PLACEHOLDER" "- Objetivo: $text" && done_files='INSTRUCOES/PROJETO.md'
  fi
  if replace_first_line "$PROJECT/README.md" "$README_PLACEHOLDER" "$text"; then
    done_files="${done_files:+$done_files e }README.md"
  fi
  [ -n "$done_files" ] || { say 'Nada a preencher: o objetivo já foi escrito.'; return 0; }
  say "Objetivo registrado em $done_files."
  [ -z "$archive" ] || say "Backup do PROJETO.md: $archive"
  say 'Quando quiser, complete o contexto e os requisitos em Cuidar do projeto → 9.'
  say 'Depois de editar as instruções, comece uma conversa nova.'
}

ask_project_objective() {
  local text
  say 'Em uma frase, para que serve este projeto? (Enter pula. Depois você preenche em Cuidar do projeto → 9, Editar as instruções.)'
  ask '> ' || return 1
  text="$REPLY"
  text="${text#"${text%%[![:space:]]*}"}"; text="${text%"${text##*[![:space:]]}"}"
  text_has_content "$text" || return 0
  single_line "$text" || { warn 'Use uma linha só, sem tabulação.'; return 1; }
  [ "${#text}" -le 300 ] || { warn 'Use até 300 caracteres; detalhes vão em INSTRUCOES/PROJETO.md.'; return 1; }
  fill_project_objective "$text"
}

project_doctor() {
  local folder native profile file name issues=0 large=() weight missing
  ensure_project || return 1
  header 'Verificar estrutura do projeto'
  for folder in INSTRUCOES PROMPTS DOCS ANEXOS; do
    if [ -d "$PROJECT/$folder" ] && [ ! -L "$PROJECT/$folder" ]; then doctor_line ok "Pasta $folder/"
    else doctor_line warn "Pasta $folder/ ausente ou inválida (menu 6 → 11 cria a estrutura)"; issues=$((issues+1)); fi
  done
  profile="$(project_profile)" || profile=''
  if [ -n "$profile" ]; then doctor_line ok "Perfil da ferramenta: $profile"
  else doctor_line warn 'Perfil da ferramenta indefinido (.assistente-ia/tool)'; issues=$((issues+1)); fi
  native="$(project_native_entry)" || native=''
  if entry_connected "$native"; then doctor_line ok "$native aponta para INSTRUCOES/PROJETO.md"
  else doctor_line warn 'Arquivo de entrada ausente ou sem referência às instruções (menu 6 → 11)'; issues=$((issues+1)); fi
  if [ ! -f "$PROJECT/INSTRUCOES/PROJETO.md" ]; then
    doctor_line warn 'INSTRUCOES/PROJETO.md não existe'; issues=$((issues+1))
  elif instructions_unfilled; then
    doctor_line warn 'INSTRUCOES/PROJETO.md ainda é o modelo; escreva o objetivo (abaixo) e as regras (menu 6 → 9)'; issues=$((issues+1))
  elif instructions_details_pending; then
    doctor_line ok 'INSTRUCOES/PROJETO.md com objetivo escrito'
    say '  → Faltam detalhes em INSTRUCOES/PROJETO.md (contexto e requisitos). Não é obrigatório para começar.'
  else doctor_line ok 'INSTRUCOES/PROJETO.md preenchido'; fi
  if [ -e "$PROJECT/AGENTS.md" ] && [ -e "$PROJECT/CLAUDE.md" ]; then
    doctor_line warn 'AGENTS.md e CLAUDE.md juntos na raiz; use menu 6 → 11 para organizar'; issues=$((issues+1))
  fi
  while IFS= read -r file; do
    [ -n "$file" ] && large[${#large[@]}]="$file"
  done <<EOF
$(large_prompt_files)
EOF
  if [ "${#large[@]}" -eq 0 ]; then doctor_line ok 'PROMPTS/ só tem pedidos curtos'
  else
    for file in "${large[@]}"; do
      name="$(basename "$file")"
      doctor_line warn "PROMPTS/$name é grande (~$(( $(file_bytes "$file") / 1024 )) KB); parece documento"
      issues=$((issues+1))
    done
    say ''
    for file in "${large[@]}"; do
      name="$(basename "$file")"
      ask "Mover \"$name\" para DOCS/? [s/N]: " || return 1
      case "$REPLY" in s|S) move_prompt_to_docs "$file" || true ;; *) say 'Mantido em PROMPTS/.' ;; esac
    done
  fi
  weight="$(fixed_weight_bytes)"
  if [ "$weight" -gt "$FIXED_WEIGHT_WARN_BYTES" ]; then
    doctor_line warn "Instruções fixas pesadas ($(weight_label "$weight") em toda conversa); enxugue"; issues=$((issues+1))
  else doctor_line ok "Instruções fixas leves ($(weight_label "$weight") por conversa)"; fi
  if [ "$(andamento_bytes)" -gt "$ANDAMENTO_WARN_BYTES" ]; then
    doctor_line warn 'DOCS/ANDAMENTO.md está grande (mais de 8 KB); condense com o pedido pronto ENCERRAR-SESSAO'; issues=$((issues+1))
  fi
  if [ -f "$PROJECT/INSTRUCOES/PROJETO.md" ] && ! has_efficiency_section; then
    say '  → Dica: PROJETO.md sem a seção Eficiência (economia de tokens).'
    ask 'Adicionar a seção ao final (com backup)? [s/N]: ' || REPLY=''
    case "$REPLY" in s|S) append_efficiency_section || true ;; *) say 'Mantido como está.' ;; esac
  fi
  missing="$(missing_default_prompts)"
  if [ -n "$missing" ]; then
    say "  → Dica: faltam pedidos prontos (prompts) em PROMPTS/: $(printf '%s' "$missing" | tr '\n' ' ')"
    ask 'Criar os pedidos prontos que faltam (sem sobrescrever)? [s/N]: ' || REPLY=''
    case "$REPLY" in s|S) create_missing_default_prompts || true ;; *) say 'Nada criado.' ;; esac
  fi
  say ''
  if objective_pending; then
    doctor_line warn 'O objetivo do projeto ainda está em modelo (INSTRUCOES/PROJETO.md e README.md)'
    issues=$((issues+1))
    ask_project_objective || true
    say ''
  fi
  if [ "$issues" -eq 0 ]; then say 'Tudo certo com a estrutura.'; fi
  say 'Instruções permanentes ficam em INSTRUCOES/PROJETO.md.'
  say 'PROMPTS/ é só para pedidos reutilizáveis escolhidos um a um; requisitos e referências ficam em DOCS/.'
}
