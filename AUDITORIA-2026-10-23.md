# Assistente IA Mac 1.0 — auditoria de 23/10/2026

As três lacunas apontadas eram reais no ZIP recebido. Foram implementadas e verificadas, mantendo o nome e `VERSION='1.0'`. Quatro agentes participaram: implementação de projetos, implementação de Git/servidor, auditoria e regressões, e revisão/integração final.

| Pedido | Estado original | Resultado verificado |
|---|---|---|
| Organizar Claude com `.claude/` real | Bloqueava qualquer presença de `.claude` | Permite diretório real para Claude e preserva seu conteúdo; bloqueia symlink, arquivo e migração para Codex |
| Git e servidor em `CODIGO/` | Só consultavam a raiz | Mantém prioridade da raiz e procura em `CODIGO/`, `CODIGO/*` e subpastas diretas; servidor permite escolher entre vários pacotes |
| Comandos opcionais Claude | Não havia gerador desses comandos | `6 → 9 → 4` cria `/encerrar` e `/resumo`, sem sobrescrever |
| Skills equivalentes Codex | Não havia esses manifests | A mesma opção cria `.agents/skills/{encerrar,resumo}/SKILL.md`, com metadados e referência ao prompt |

`project_profile()` já reconhecia `CLAUDE.md` sem `AGENTS.md` quando `.claude/` existia. Foi acrescentada cobertura, sem alterar esse comportamento. O teste antigo que exige bloqueio de `.claude` usa Codex e continua passando, sem alteração.

## Organização e uso

As pastas `INSTRUCOES/`, `PROMPTS/`, `DOCS/` e `ANEXOS/` continuam com suas funções originais. Não é necessário recriar projetos, mover código ou trocar a numeração dos menus. A opção 9 de Cuidar do projeto agora informa que também oferece atalhos; a opção 4 desse submenu ativa somente os arquivos opcionais da ferramenta do projeto. A criação limpa de projetos permanece inalterada.

Os atalhos reutilizam os prompts existentes, evitando cópias divergentes do conteúdo. Uma skill Claude existente com o mesmo nome é preservada e impede criar um comando concorrente. Arquivos regulares existentes são preservados e identificados na saída. O guia e LEIA-PRIMEIRO foram atualizados com os caminhos e a operação.

## Segurança nas alterações

- Bash 3.2, arrays indexados e argumentos separados; nenhuma entrada de seleção é avaliada como código ou expressão aritmética.
- Nenhum novo `eval` ou `source` de dados/configurações. Os imports existentes de bibliotecas do próprio kit permanecem.
- Validação antecipada dos caminhos dos atalhos e prompts, incluindo symlinks quebrados, tipos inválidos e perfil da ferramenta.
- Escrita de atalhos em diretório temporário privado com `set -o noclobber`; publicação do arquivo completo por link físico exclusivo (`ln -n`), seguida de limpeza. Arquivos existentes não são substituídos. A publicação exige suporte a links físicos no sistema de arquivos; falhas são retornadas.
- O teste de concorrência cobre arquivo criado antes da publicação e troca do destino por symlink de diretório. Isso não é prova formal contra todas as possíveis trocas concorrentes de ancestrais do caminho.
- Descoberta limitada de código ignora pastas ocultas, `node_modules` e symlinks. O caminho do pacote é validado novamente depois da confirmação e antes do npm.

Observação preexistente fora das três alterações: `init_state()` não impõe uma proibição universal de symlinks na árvore de preferências `STATE_DIR`. A proteção dos caminhos gerenciados de projeto não deve ser apresentada como uma sandbox de todo o sistema de arquivos. Essa parte não foi modificada nesta revisão.

## Execução real dos testes

Ambiente: macOS arm64, `/bin/bash` **3.2.57(1)-release**, Python 3.9.6. Resultados completos em `tests/resultado-core.txt`, `tests/resultado-rtk.txt` e `tests/resultado-verificacao.txt`.

| Verificação | Resultado |
|---|---|
| Baseline antes das alterações | 295 testes Python + 115 verificações shell, zero falhas |
| `/bin/bash -n` em todos os `.sh` e `.command` | 8 scripts aprovados, incluindo o teste shell |
| `./ASSISTENTE-IA-MAC.command --check` | Exit 0: kit completo, sintaxe verificada |
| `python3 -I -m unittest discover -s tests -p 'test_*.py' -v` | **327 testes, OK**, 47,668 s reportados pelo unittest |
| `/bin/bash tests/test_rtk.sh` | **115 PASS; 0 FAIL** |
| `skill-creator/scripts/quick_validate.py` nos manifests gerados | `encerrar` e `resumo` válidos |
| Git real em pasta temporária | Status em `CODIGO/App ação`, caminho com espaços/acentos e prioridade da raiz aprovados |

Os **32 testes novos** estão em `tests/test_melhorias.py`. Nenhum arquivo de teste antigo foi alterado. Eles cobrem preservação de `.claude/`, bloqueios, perfil, criação limpa, comandos/skills, idempotência, `noclobber`, falha de gravação e concorrência, Git/servidor na raiz e subpastas, escolha, cancelamento, EOF, entrada inválida e propagação de falha do npm.

## Avaliação e limites

Os três critérios funcionais foram atendidos nos cenários testados. O menu já era amigável por agrupar ações e preservar escolhas; a simplificação desta revisão concentra os atalhos em uma opção e permite localizar código sem mover pastas. Não há evidência suficiente para afirmar **10/10 absoluto** de segurança, usabilidade ou integração.

A suíte usa CLIs simuladas para isolar contas e evitar executar servidores dos projetos reais. Não foram feitos login real, teste visual de Finder/Terminal, inicialização de servidor Node real nem execução de `/encerrar`, `/resumo`, `$encerrar` e `$resumo` em sessões autenticadas. A geração foi testada, os manifests Codex foram validados e os formatos foram conferidos na documentação oficial. Instruções em Markdown dependem do agente e não garantem que todo resultado gerado por ele seja correto.

## Fontes oficiais consultadas

- [Claude Code: comandos existentes continuam funcionando e integram o sistema de skills](https://code.claude.com/docs/en/skills).
- [Codex: manifests SKILL.md e descoberta em .agents/skills](https://learn.chatgpt.com/docs/build-skills).
- [Codex: instruções persistentes com AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
