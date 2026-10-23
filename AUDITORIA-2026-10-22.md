# Auditoria do Assistente IA Mac — 22/10/2026

> **Aviso (revisão posterior):** o menu principal foi refeito depois desta auditoria. As opções citadas aqui como “menu 9” estão agora em **7 Ajuda e ajustes → 2 RTK**. O restante da auditoria descreve a versão daquela data; veja `MUDANCAS-E-TESTES.md` para o que mudou depois.

**Origem:** kit v1.0 enviado em `Assistente-IA.zip` (inspeção estática dos scripts, bibliotecas, documentação e regressões).  
**Entrega:** versão 1.0 revisada, preservando a organização existente e incorporando as melhorias da auditoria.

## Resultado

O sistema já implementava a organização pedida. Não era necessário refazer a arquitetura. Foram identificadas três lacunas de observabilidade do RTK: o menu apresentava apenas estado e ganho acumulado; não permitia ver atividade contínua nem consultar o histórico recente e não tinha teste somente-leitura do reescritor. Essas lacunas foram atendidas na revisão identificada como versão 1.0. Os arquivos originais de projeto não são migrados automaticamente nem apagados.

## Arquitetura confirmada no código

- A criação escolhe um destino, seleciona a ferramenta e cria `<destino>/CODEX/<Nome>` **ou** `<destino>/CLAUDE/<Nome>` (sem duplicar o agrupador quando o destino é a pasta da mesma ferramenta).
- Em estrutura organizada, cada projeto contém `INSTRUCOES/PROJETO.md` e `PROMPTS/` com prompts Markdown, `DOCS/` e `ANEXOS/`. Codex cria `AGENTS.md`, Claude cria `CLAUDE.md`; `.assistente-ia/tool` registra o vínculo escolhido.
- O diretório `PROMPTS/` é listado no nível imediato para carregar um **único prompt escolhido** por conversa, sem enviar todos os `.md`. Se quiser organizar prompts em subpastas dentro de PROMPTS, elas **não são listadas automaticamente** no seletor atual; é possível selecionar o arquivo pelo caminho/Finder.
- O sistema mantém seleção recente, configurações por projeto, login conduzido pelas CLIs oficiais, opção de retomada, backups e migração explícita de projetos antigos.
- Há controles de entrada e aspas em caminhos, recusas a symlinks de destinos de gravação, gravações atômicas para preferências e confirmação de alterações globais de RTK. Arquivos de preferências não são executados como código.

## Achados e prioridade

| Prioridade | Achado | Evidência / resolução |
|---|---|---|
| Média | Era difícil confirmar o RTK atuando **durante** uma conversa. | Introduzido monitor oficial `rtk gain --watch` em janela separada, sem processo oculto permanente. |
| Média | Menu não expunha os últimos comandos processados. | Introduzido `rtk gain --history` para inspeção temporal; global, não atribuído a um agente. |
| Baixa | Não havia verificação independente do motor de reescrita. | Introduzido `rtk rewrite 'git status'`, que **não executa Git** nem altera hooks. |
| Baixa / Portabilidade de testes | 4 testes chamavam caminho exclusivo do macOS e falhavam no Linux. | Testes agora ignoram esses casos fora do macOS, preservando execução nativa em macOS. |
| Baixa / Empacotamento | O `.command` original estava com permissão `0644`, podendo não abrir corretamente com dois cliques. | Ajustado no novo ZIP para modo executável `0755`; descompactadores podem preservar ou alterar permissões. |
| Atenção operacional | Histórico e hooks globais não isolam completamente contas, arquivos ou estatísticas por projeto. | Documentado; a separação atual é de organização do projeto e instruções, não de segurança/sandbox. |

Nenhum defeito crítico no fluxo principal foi demonstrado pelos testes disponíveis. Isso não prova ausência de bugs no macOS real.

## Como verificar RTK durante o uso no Mac

1. Inicie o kit e, no menu 7 → 2 (RTK), consulte **2 — Situação dos hooks**. Se necessário, use 3 para ativar somente o agente desejado (com prévia e confirmação) e reinicie esse agente.
2. No menu 7 → 2, escolha **7 — Abrir monitor em outra janela**. O Terminal extra executa `rtk gain --watch`.
3. Na janela principal, abra o Codex ou Claude **no projeto certo**, peça para inspecionar o Git com um comando de terminal normal, como `git status`, e volte ao monitor. Uma atualização é evidência de atividade global do RTK; ela não identifica sozinho qual agente gerou o registro.
4. Confira **8 — Histórico** para encontrar atividade recente e horários; use **9 — Verificação** para testar que o RTK entende a reescrita de `git status` sem executar o comando.
5. Se não houver mudanças, confira o agente/hook configurado, reinicie a CLI e repita com comando compatível. Ferramentas internas de leitura do agente podem não acionar hooks de shell.

### Comandos rápidos

```bash
/bin/bash ASSISTENTE-IA-MAC.command --check
/bin/bash ASSISTENTE-IA-MAC.command --rtk status
/bin/bash ASSISTENTE-IA-MAC.command --rtk historico
/bin/bash ASSISTENTE-IA-MAC.command --rtk verificar
/bin/bash ASSISTENTE-IA-MAC.command --rtk monitor  # execute em outra janela
```

## Segurança e limites

- O kit não modifica `~/.codex` ou `~/.claude` automaticamente, salvo quando o usuário confirma a opção global RTK ou usa os comandos oficiais de login/logout. Ver `lib/rtk.sh`.
- A compressão de saídas pode omitir detalhes; na depuração, peça o comando original ou a saída sem filtro quando necessário.
- Um ZIP de backup completo do projeto pode conter `.env`, chaves ou material privado. Guarde-o em local seguro e não o compartilhe sem revisão.
- Um `AGENTS.md` ou `CLAUDE.md` ancestral/global ainda pode aplicar regras à sessão. Use projetos independentes e verifique instruções carregadas pelo próprio agente.
- Benchmarks de velocidade, RAM, CPU, bateria e economia de tokens de sessões reais **não foram executados**: nada fundamenta alegar limite máximo de eficiência.

## Verificação e compatibilidade

Os testes desta revisão usaram CLIs e RTK simulados; saídas em `tests/resultado-core.txt` e `tests/resultado-rtk.txt`. A alteração é aditiva, preserva nomes de pastas, entradas nativas, identificadores e comandos antigos. O recurso novo de abrir a janela do Terminal depende de `osascript` e de permissão de Automação no macOS; há alternativa de abrir manualmente `rtk gain --watch` em outra janela. Validar esta integração em um macOS real ainda é necessário.

## Fontes externas verificadas

- RTK: https://github.com/rtk-ai/rtk
- Analytics oficiais (`--watch` e `--history`): https://www.rtk-ai.app/docs/analytics/gain/
- Integrações por agente: https://www.rtk-ai.app/docs/getting-started/supported-agents/
- Instalação OSS: https://www.rtk-ai.app/guide/getting-started/installation/
