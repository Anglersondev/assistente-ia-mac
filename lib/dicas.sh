#!/bin/bash
# Dicas de economia de tokens e aviso de conversa longa. Bash 3.2; source, não execute.
# Host: say, warn, header, PROJECT, TOOL. Claude: só tamanho/data. Codex: também confere o início do
# arquivo de sessão para achar o projeto. Nunca imprime nem envia conteúdo de sessões.

TIPS=(
  'Uma conversa nova por tarefa: conversa longa fica mais cara a cada pedido.'
  'No Claude Code, /compact resume a conversa e libera espaço; use antes de ela ficar enorme.'
  'No Claude Code, /clear zera a conversa ao mudar de assunto. No Codex, abra uma conversa nova.'
  'Peça uma busca antes de abrir arquivos inteiros: ler só o trecho certo custa menos.'
  'Cite o caminho exato do arquivo e o trecho: o agente não perde tempo procurando.'
  'Use o modo Planejar antes de mudanças grandes: errar no plano custa menos que errar no código.'
  'Tarefa simples não precisa de raciocínio máximo: escolha esforço menor ao abrir a conversa.'
  'Mantenha INSTRUCOES/PROJETO.md curto e objetivo: ele é lido em toda conversa do projeto.'
  'Guarde pedidos que se repetem em PROMPTS/ e escolha um por tarefa em vez de reescrever.'
  'Registre decisões e próximo passo em DOCS/ANDAMENTO.md: uma conversa nova retoma dali sem reler tudo.'
  'O RTK encurta a saída de comandos (git, testes, listas): entra menos texto na conversa.'
  'Use /model para trocar para um modelo menor em tarefas simples e reservar o maior para as difíceis.'
  'Anexe só o trecho relevante (print recortado, parte do log), não o arquivo ou a tela inteira.'
  'Peça respostas curtas ou só o diff das mudanças quando não precisar de explicação longa.'
  'Peça para o agente rodar os testes e mostrar só as falhas: saída enxuta, resposta mais rápida.'
  'Antes de encerrar uma conversa longa, use Encerrar com resumo (menu 3) e comece a próxima com Continuar o trabalho.'
  'No Claude Code, /context mostra quanto da conversa já foi usado; você também pode pedir ao Claude um /statusline para ver esse uso na barra.'
)
TIPS_EN=(
  'Start a new conversation for each task; long conversations cost more with each request.'
  'In Claude Code, /compact summarizes the conversation and frees context space.'
  'In Claude Code, /clear resets the conversation. In Codex, start a new one.'
  'Search before opening whole files; reading just the relevant part costs less.'
  'Provide the exact file path and excerpt so the agent can find it quickly.'
  'Use Plan mode before large changes; fixing a plan costs less than fixing code.'
  'Simple tasks do not need maximum reasoning; choose a lower effort level.'
  'Keep INSTRUCOES/PROJETO.md short; the agent reads it in every conversation.'
  'Store recurring requests in PROMPTS/ and choose one for each task.'
  'Record decisions and next steps in DOCS/ANDAMENTO.md for easier handoff.'
  'RTK shortens command output so less text enters the conversation.'
  'Use /model to switch to a smaller model for simple tasks.'
  'Attach only the relevant screenshot area or log excerpt.'
  'Ask for a short answer or just the diff when a long explanation is unnecessary.'
  'Ask the agent to run tests and show only failures for concise output.'
  'Before ending a long conversation, use Wrap up with a summary (menu 3).'
  'In Claude Code, /context shows context usage; /statusline can also show it.'
)

tip_of_the_day() {
  local day count index
  day="${TIP_DAY:-$(date +%j)}"
  case "$day" in ''|*[!0-9]*) day=1 ;; esac
  count="${#TIPS[@]}"
  index=$(( 10#$day % count ))
  if [ "$APP_LANG" = en ]; then say "Tip: ${TIPS_EN[$index]}"
  else say "Dica: ${TIPS[$index]}"; fi
  return 0
}

tips_menu() {
  if [ "$APP_LANG" = en ]; then
    header 'Tips for better results with less effort'
    say 'EFFICIENCY'
    say '  • Start a new conversation for each task; long conversations cost more.'
    say '  • Give exact file paths and ask for a search before opening whole files.'
    say '  • Attach only relevant excerpts and ask for short answers or a diff.'
    say '  • Use lower reasoning effort and a smaller model for simple tasks.'
    say '  • RTK (Help and settings → 2) shortens command output. The kit asks'
    say '    whether to enable it when opening a conversation (Enter = yes).'
    say ''
    say 'QUALITY'
    say '  • Use Plan mode before large changes, then request implementation.'
    say '  • State the expected result and how to tell when it is done.'
    say '  • Ask the agent to run tests and verify the actual result.'
    say '  • Larger models and higher effort help with hard problems, not tiny edits.'
    say ''
    say 'LONG CONVERSATIONS'
    say '  • Warning signs: slow replies, forgotten decisions, repeated questions.'
    say '  • In Claude Code, /compact summarizes and continues; /clear restarts.'
    say '  • To switch conversations without losing context, use Wrap up with a'
    say '    summary (menu 3), start a new conversation, then Continue the work.'
    say '  • The kit shows recent conversation size on the main dashboard and'
    say '    project usage dashboard (menu 4).'
    say '  • In Claude Code, /context shows context usage. You can also ask'
    say '    Claude for a /statusline; its contents depend on Claude.'
    say '  • In Codex, use the kit usage notice and start a new conversation'
    say '    when the current one grows long.'
    say ''
    say 'PROJECT'
    say '  • INSTRUCOES/PROJETO.md: short permanent rules read each time.'
    say '  • PROMPTS/: short saved prompts. DOCS/: longer documents and progress.'
    say '  • Check the layout in Project care → 12.'
    say '  • Resume from the main menu with option 1 (or simply Enter).'
    return 0
  fi
  header 'Dicas para render mais com menos esforço'
  say 'ECONOMIA'
  say '  • Uma conversa nova por tarefa; conversa longa fica mais cara.'
  say '  • Cite o caminho exato do arquivo e peça busca antes de abrir'
  say '    arquivos inteiros.'
  say '  • Anexe só o trecho relevante e peça respostas curtas ou só o diff.'
  say '  • Esforço menor e /model com modelo menor para tarefas simples.'
  say '  • O RTK (Ajuda e ajustes → 2) encurta a saída de comandos. Ao abrir'
  say '    uma conversa o kit pergunta se quer ativá-lo (Enter = sim).'
  say ''
  say 'QUALIDADE'
  say '  • Use o modo Planejar antes de mudanças grandes; só então peça a'
  say '    implementação.'
  say '  • Diga o resultado esperado e como saber que está pronto.'
  say '  • Peça para rodar os testes e conferir o resultado real antes de'
  say '    dar por concluído.'
  say '  • Modelo maior e esforço alto valem a pena em problemas difíceis,'
  say '    não em ajustes simples.'
  say ''
  say 'CONVERSAS LONGAS'
  say '  • Sinais de conversa pesada: respostas lentas, o agente esquece'
  say '    decisões ou repete perguntas.'
  say '  • No Claude Code, /compact resume e continua; /clear recomeça do'
  say '    zero no mesmo projeto.'
  say '  • Para trocar de conversa sem perder o fio: use Encerrar com resumo'
  say '    (menu 3, ele atualiza DOCS/ANDAMENTO.md), abra uma conversa nova'
  say '    e escolha Continuar o trabalho.'
  say '  • O kit mostra o tamanho da conversa mais recente no painel e no'
  say '    Painel de uso (menu 4).'
  say '  • No Claude Code, /context mostra quanto da conversa já foi usado.'
  say '  • Sugestão: peça ao Claude um /statusline para ver o uso na barra'
  say '    (o conteúdo da barra depende dele).'
  say '  • No Codex não há comando para isso: use o aviso do kit e abra uma'
  say '    conversa nova quando ficar longa.'
  say ''
  say 'PROJETO'
  say '  • INSTRUCOES/PROJETO.md: regras permanentes, curtas, lidas em'
  say '    toda conversa.'
  say '  • PROMPTS/: pedidos prontos e curtos. DOCS/: documentos longos e'
  say '    ANDAMENTO.md.'
  say '  • Verificar a estrutura: Cuidar do projeto → 12.'
  say '  • Continuar de onde parou: opção 1 do menu principal (ou só Enter).'
}

# Troca todo caractere não alfanumérico por '-' e junta '-' repetidos (para comparar nomes).
session_collapse() {
  printf '%s' "$1" | LC_ALL=C /usr/bin/tr -c 'A-Za-z0-9' '-' | LC_ALL=C /usr/bin/tr -s '-'
}

# Imprime o arquivo de sessão mais recente do Claude para $PROJECT (ou nada).
session_latest_claude() {
  local root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" dir wanted name file n=0
  [ -d "$root" ] && [ ! -L "$root" ] || return 0
  wanted="$(session_collapse "$PROJECT")"
  dir=''
  for name in "$root"/*; do
    [ -d "$name" ] && [ ! -L "$name" ] || continue
    n=$((n+1)); [ "$n" -le 300 ] || break
    if [ "$(session_collapse "$(basename "$name")")" = "$wanted" ]; then dir="$name"; break; fi
  done
  [ -n "$dir" ] || return 0
  n=0
  while IFS= read -r file; do
    n=$((n+1)); [ "$n" -le 5 ] || break
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    printf '%s' "$file"; return 0
  done <<EOF
$(ls -t "$dir"/*.jsonl 2>/dev/null)
EOF
}

# Imprime o arquivo de sessão mais recente do Codex cujo início cita $PROJECT (ou nada).
session_latest_codex() {
  local root="${CODEX_HOME:-$HOME/.codex}/sessions" file n=0
  [ -d "$root" ] && [ ! -L "$root" ] || return 0
  while IFS= read -r file; do
    n=$((n+1)); [ "$n" -le 30 ] || break
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    if head -c 4000 "$file" 2>/dev/null | /usr/bin/grep -Fq -e "\"cwd\":\"$PROJECT\""; then
      printf '%s' "$file"; return 0
    fi
  done <<EOF
$(find "$root" -maxdepth 4 -type f -name 'rollout-*.jsonl' 2>/dev/null | sort -r | head -30)
EOF
}

# Mede a conversa mais recente de $PROJECT/$TOOL. Imprime os bytes; só tamanho, nunca conteúdo.
# Retorna 0 se mediu, 1 se não há sessão, 2 se não foi possível medir.
session_weight_measure() {
  local file='' bytes
  case "${TOOL:-}" in
    claude) file="$(session_latest_claude)" ;;
    codex) file="$(session_latest_codex)" ;;
    *) return 2 ;;
  esac
  [ -n "$file" ] || return 1
  bytes="$(wc -c < "$file" 2>/dev/null | tr -d ' ')"
  case "$bytes" in ''|*[!0-9]*) return 2 ;; esac
  printf '%s' "$bytes"
}

session_weight_mb() {
  local tenths=$(( $1 * 10 / 1048576 ))
  printf '%s,%s' "$((tenths/10))" "$((tenths%10))"
}

# Aviso de conversa pesada. Estimativa pelo tamanho do arquivo; nunca mostra o conteúdo.
session_weight_note() {
  local bytes mb status
  [ -n "${PROJECT:-}" ] && [ -d "$PROJECT" ] || return 0
  case "${TOOL:-}" in claude|codex) ;; *) return 0 ;; esac
  bytes="$(session_weight_measure)"; status=$?
  if [ "$status" -eq 1 ]; then
    [ -z "${SESSION_WEIGHT_DEBUG:-}" ] || say 'Sessão: nenhuma encontrada.'
    return 0
  fi
  [ "$status" -eq 0 ] || return 0
  mb="$(session_weight_mb "$bytes")"
  [ -z "${SESSION_WEIGHT_DEBUG:-}" ] || say "Sessão mais recente: ${bytes} bytes"
  if [ "$bytes" -gt 1500000 ]; then
    say "Atenção: conversa muito longa (~${mb} MB, estimativa)."
    say '  Use Encerrar com resumo (menu 3) e abra uma nova, ou /compact no Claude.'
  elif [ "$bytes" -gt 600000 ]; then
    say "Aviso: a conversa mais recente está ficando grande (~${mb} MB, estimativa)."
    say '  Considere resumir ou abrir uma nova.'
  fi
  return 0
}

# Sempre uma linha curta sobre a conversa mais recente do projeto atual (estimativa pelo tamanho).
session_weight_line() {
  local bytes mb status
  [ -n "${PROJECT:-}" ] && [ -d "$PROJECT" ] || return 0
  if type opt_enabled >/dev/null 2>&1 && ! opt_enabled peso; then
    say 'Medição de uso desligada (Ajuda e ajustes → 4)'; return 0
  fi
  bytes="$(session_weight_measure)"; status=$?
  case "$status" in
    0) ;;
    1) say 'Conversa: nenhuma ainda neste projeto'; return 0 ;;
    *) say 'Conversa: não consegui medir'; return 0 ;;
  esac
  mb="$(session_weight_mb "$bytes")"
  if [ "$bytes" -gt 1500000 ]; then say "Conversa: ⛔ muito longa (${mb} MB) — use Encerrar com resumo"
  elif [ "$bytes" -gt 600000 ]; then say "Conversa: ⚠ ficando longa (${mb} MB) — considere encerrar"
  else say "Conversa: ✓ leve (${mb} MB)"; fi
  return 0
}
