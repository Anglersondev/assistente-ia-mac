# Assistente IA Mac 1.0 — Alterações e verificações (23/10/2026)

A versão continua **1.0**. Abaixo, o que mudou em cada rodada e o que foi realmente verificado.

## Rodada 1 — auditoria do RTK

- Estrutura `CODEX/Nome` e `CLAUDE/Nome`, com `PROMPTS/`, `INSTRUCOES/`, `DOCS/`, `ANEXOS/` e `.assistente-ia/tool`, mantida.
- Menu RTK ganhou **7 = monitor em outra janela** (`rtk gain --watch`), **8 = histórico** (`rtk gain --history`) e **9 = verificar o reescritor** sem executar Git. Atalhos `--rtk monitor`, `--rtk historico` e `--rtk verificar`.
- Instalação, hook configurado, capacidade de reescrita e uso real são evidências diferentes; o histórico do RTK é global.
- `ASSISTENTE-IA-MAC.command` empacotado com permissão `0755`; testes do catálogo JavaScript passam a ser ignorados fora do macOS.

## Rodada 2 — continuar fácil, RTK por padrão, estrutura do projeto

- **Continuar de onde parou** com a ferramenta e as preferências salvas; se não houver conversa, oferece uma nova (Ctrl+C não oferece).
- **“Usar essas configurações? [S/n]”** ao abrir conversa nova pula modelo, esforço e modo.
- **RTK ao abrir:** o kit confere o hook (só busca de texto), **pergunta** [S/n] (Enter = ativar), respeita o `n` e nunca bloqueia a abertura. Qualquer resposta não reconhecida não altera nada.
- **Verificador de pasta e avisos ao abrir:** instruções ainda em modelo, documentos grandes em `PROMPTS/`, entrada do agente sem referência a `PROJETO.md`; mover para `DOCS/` só com confirmação, sem sobrescrever.
- **Objetivo em uma frase** (criação e verificador, Codex e Claude): preenche só as linhas ainda em modelo, com backup; texto especial é gravado literalmente e as permissões do arquivo são preservadas.
- **Economia de tokens:** modelo de `PROJETO.md` com seção Eficiência; prompts `ENCERRAR-SESSAO` e `RESUMO-RAPIDO`; peso das instruções fixas e `ANDAMENTO.md` grande no verificador.
- **Dicas** (uma ao abrir a conversa, mais no menu de dicas) e **aviso de conversa longa** por tamanho/data da sessão.
- **Controle total:** chaves liga/desliga (RTK ao abrir, dicas, aviso de conversa longa, Enter = continuar) e a tela “O que o assistente faz sozinho”, revisada para refletir exatamente o código.
- Revisor independente: achados corrigidos (aviso falso com `@INSTRUCOES/PROJETO.md`, fallback de retomada só para saída imediata com erro, textos de transparência, objetivo em branco, mensagens por arquivo).

## Rodada 3 — menu refeito, painel de uso e aviso dentro do chat

- **Menu principal novo**, com painel no topo (projeto, pasta, ferramenta, RTK, aviso no chat, conversa) e opções: Continuar, Nova conversa, Encerrar com resumo, Painel de uso, Projetos, Cuidar do projeto, Ajuda e ajustes e **8) Escolher uma conversa antiga** (lista oficial da ferramenta). Referências de menu nos textos renumeradas (RTK = `7 → 2`, preferências = `7 → 4`, dicas = `7 → 3`).
- **Encerrar com resumo:** abre a última conversa e envia `ENCERRAR-SESSAO`; se o arquivo faltar, oferece criá-lo.
- **“Como você quer começar?”** passa a oferecer “Continuar o trabalho” (prompt `CONTINUAR`) como padrão.
- **Painel de uso dos projetos:** tokens, mensagens aproximadas e última atividade por projeto, do mais pesado ao mais leve (✓ leve até ~80 mil, ⚠ longa de 80 a 200 mil, ⛔ muito longa acima de 200 mil tokens). Codex: registro de uso da sessão (com janela de contexto). Claude: números exatos da barra do chat, quando instalada; senão, estimativa pelos arquivos de sessão.
- **Barra de status no Claude Code (opcional):** prévia, instalação com confirmação `INSTALAR` e backup do `settings.json`, remoção só da barra do kit (`REMOVER`), instrução manual por `/statusline` quando já existe outra barra ou não há Python. O Codex não tem recurso equivalente conhecido.

## Rodada 4 — refinamentos de uso

- Etapas de abrir conversa numeradas (**Passo 1 a 4 de 4**). Na 1ª conversa de um projeto o kit usa modelo/esforço padrão e só pergunta “Ajustar modelo e esforço? [s/N]”; projeto novo sem andamento começa por “Escrever um pedido novo”.
- **Continuar** com conversa muito longa pergunta “Encerrar com resumo primeiro? [S/n]”.
- A chave de preferências “**Medir o uso da conversa e avisar quando estiver longa**” agora desliga de fato a medição no painel inicial, no menu 4, no aviso ao abrir e na pergunta acima.
- Verificador separa **objetivo em modelo** (aviso forte) de **faltam detalhes de contexto/requisitos** (leve, não obrigatório); a pergunta do objetivo aponta para Cuidar do projeto → 12 / 9.
- Barra do Claude reconhecida em qualquer formato de comando; seu registro só vale se for tão recente quanto a conversa; a instalação valida o JSON antes de criar o backup.
- Tela “O que este assistente faz sozinho” passa a descrever a leitura de tokens e a contagem de mensagens, e que a edição do `settings.json` é só da chave `statusLine`.

## Rodada 5 — Claude, código em subpastas e atalhos opcionais (23/10/2026)

- Organização para Claude permite e preserva `.claude/` real. Symlinks, tipos inválidos e migração automática para Codex com `.claude/` continuam bloqueados.
- Git e servidor mantêm prioridade da raiz e encontram código em `CODIGO/`, `CODIGO/*` e subpastas diretas. Servidor oferece escolha quando há vários pacotes, com confirmação antes de executar.
- Menu `6 → 9 → 4` oferece comandos Claude `/encerrar` e `/resumo` e skills equivalentes do Codex, sem sobrescrever arquivos. Publicação atômica, `noclobber` e validação de caminhos; criação normal de projetos inalterada.
- 32 regressões adicionadas, sem modificar testes antigos. Executados **327 testes Python (OK)** e **115 verificações shell (0 falhas)**, sintaxe dos 8 scripts e `--check` aprovados no Bash 3.2.57 real. Também aprovados validação dos manifests Codex e status Git real em subpasta e raiz.
- Logs atuais: `tests/resultado-core.txt`, `tests/resultado-rtk.txt`, `tests/resultado-verificacao.txt`. Escopo e limites em `AUDITORIA-2026-10-23.md`.

## Verificações da rodada anterior (22/10/2026)

Executadas nesta máquina (macOS, `/bin/bash` 3.2.57), com Codex, Claude e RTK **simulados**:

| Verificação | Resultado |
|---|---|
| `python3 -I -m unittest discover -s tests -p 'test_*.py'` | **295 casos, 0 falhas** |
| `/bin/bash tests/test_rtk.sh` | **115 verificações passaram, 0 falhas** |
| `/bin/bash ASSISTENTE-IA-MAC.command --check` | kit completo e sintaxe verificada |

Casos por arquivo: `test_assistente` 89 · `test_continuar` 11 · `test_controle` 9 · `test_dicas` 26 · `test_doctor` 16 · `test_eficiencia` 13 · `test_menu` 47 · `test_objetivo` 12 · `test_painel` 37 · `test_statusline` 35.

## Rodada final — atualização do RTK

- Instalador do RTK agora vem da **tag da última versão publicada**, não da branch `master`; `RTK_VERSION` vai fixado e o checksum continua obrigatório.
- **Verificação diária automática** (segundo plano, só consulta) com aviso no painel e no menu RTK; desligável em Preferências → `5` (a tela de transparência passou para `6`).
- Menu RTK **10 — Atualizar RTK** e `--rtk atualizar`: respeita o método de instalação (oficial ou Homebrew) e pede `ATUALIZAR`.
- Verificado: `unittest` **328 OK**, `tests/test_rtk.sh` **154 PASS, 0 FAIL**, `--check` OK; 39 verificações novas no shell e 1 em Python. Teste de mutação: voltar a URL para `master` faz os testes falharem. Consulta real ao GitHub com o RTK 1.0.1 instalado: identificou “em dia” sem instalar nada.

## Limites

- Os testes usam Codex, Claude e RTK simulados e diretórios temporários. Nenhum login real, conversa real, hook real nem instalação da barra no seu `~/.claude` foi exercitado.
- O formato dos arquivos de sessão do Claude é interno e pode mudar; por isso o painel mostra “(estimativa)” quando não há a barra instalada. Os números do Codex dependem do formato atual dos registros dele.
- Em “Encerrar com resumo” no Codex, não foi confirmado que o texto vira o pedido inicial ao retomar; o kit avisa o que digitar se isso acontecer.
- Medidas de tokens e de “mensagens” são aproximadas. Benchmarks de velocidade, memória e economia real de tokens **não** foram executados.
- As 4 verificações nativas de JavaScript for Automation (catálogo de modelos) devem ser repetidas por você no macOS real.

Arquivos de resultado: `tests/resultado-core.txt` e `tests/resultado-rtk.txt` (gerados na última rodada completa). Auditoria original: `AUDITORIA-2026-10-22.md`.
