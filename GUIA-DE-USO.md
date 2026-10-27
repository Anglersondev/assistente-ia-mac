# Assistente IA Mac 1.0

Um menu em português do Brasil ou inglês para criar ou abrir projetos no lugar que você escolher e trabalhar com **Codex CLI** ou **Claude Code**. Um painel no topo mostra o projeto, a ferramenta, o RTK e o tamanho da conversa. O **RTK** fica em Ajuda e ajustes, com instalação e integração opcionais.

Na primeira abertura, o programa segue o idioma do macOS quando é inglês ou português do Brasil. Outros idiomas usam português do Brasil. Para mudar, escolha **Ajuda e ajustes (7) → Idioma / Language (8)**. A preferência fica salva e tem prioridade sobre o idioma do sistema. Projetos novos organizados recebem modelos no idioma escolhido; arquivos existentes são preservados.

Cada projeto pode ter **instruções permanentes próprias** e **prompts salvos para tarefas específicas**. Na criação, você escolhe Codex ou Claude; o kit separa os projetos por ferramenta e gera apenas a entrada de instruções correspondente.

A sequência é: **destino → nome → ferramenta → estrutura → confirmação → login → modelo → modo de trabalho → conversa**. Ao reabrir um projeto, o menu reutiliza a ferramenta registrada nele.

## Abrir o kit no Mac

1. Descompacte o ZIP em uma pasta local de sua preferência.
2. Mantenha a pasta completa do kit junta, incluindo `lib/`. A pasta do kit e a pasta dos seus projetos podem ficar em lugares diferentes.
3. Dê dois cliques em `ASSISTENTE-IA-MAC.command`. Ele deve abrir no Terminal.
4. Crie um projeto ou abra uma pasta existente pelo menu.

Se os dois cliques não funcionarem, abra o Terminal, digite `/bin/bash` seguido de um espaço, arraste o arquivo `.command` do Finder para o Terminal e pressione Enter. Isso executa o arquivo sem exigir a permissão de execução.

Para habilitar os dois cliques, digite `chmod u+x` seguido de um espaço, arraste o arquivo `.command` para o Terminal e pressione Enter. O caminho será preenchido pelo Finder. Não é necessário usar `sudo`.

Se o arquivo abrir no TextEdit, use **Abrir com → Terminal** no Finder. Se houver bloqueio de segurança, confira a origem do kit e a mensagem em **Ajustes do Sistema → Privacidade e Segurança**. Se o Terminal pedir acesso a Documentos, Downloads ou outra pasta selecionada, permita o acesso necessário para trabalhar ali.

## Onde encontrar cada função

O menu principal tem um **painel** no topo (projeto, pasta, ferramenta, RTK, aviso no chat e a linha **Conversa**) e oito opções:

| Menu principal | Para que serve |
|---|---|
| `1` Continuar de onde parei | Retoma a última conversa do projeto com a ferramenta e as preferências já salvas. **Enter** faz o mesmo quando há projeto aberto. |
| `2` Começar uma conversa nova | Pede login, modelo e modo (ou reaproveita as configurações salvas) e abre uma conversa limpa. |
| `3` Encerrar com resumo | Abre a última conversa e envia o prompt `ENCERRAR-SESSAO`, que atualiza `DOCS/ANDAMENTO.md`. |
| `4` Painel de uso dos projetos | Lista seus projetos recentes com o tamanho de cada conversa e diz quando vale encerrar. |
| `5` Projetos: trocar, abrir ou criar | `1` Criar projeto novo · `2` Abrir a pasta de um projeto existente · `3` Projetos recentes. |
| `6` Cuidar do projeto | Instruções, prompts, anexos, Git, cópia ZIP e o verificador da pasta (veja a tabela mais abaixo). |
| `7` Ajuda e ajustes | `1` Contas e login · `2` RTK · `3` Dicas para economizar tokens · `4` Preferências · `5` Instalação e diagnóstico · `6` Guia de 4 passos · `7` Aviso dentro do chat do Claude. |
| `8` Escolher uma conversa antiga | Mostra a lista oficial de conversas da ferramenta (`codex resume` ou `claude --resume`) para você escolher uma. |
| `0` Sair | Encerra o menu. |

Sem projeto aberto, as opções `1`, `2`, `3`, `4`, `6` e `8` dizem "Primeiro escolha ou crie um projeto" e abrem o menu de projetos. Os submenus usam `0` para voltar. Nas etapas de confirmação, leia o texto ao lado do campo: Enter pode manter uma escolha ou confirmar a ação apresentada.

## Criar um projeto onde você quiser

Escolha **`5` → `1`** (Criar um projeto novo). Selecione a **pasta que vai receber seus projetos**, informe o nome, escolha **Codex ou Claude** e a estrutura. Confira o caminho completo antes de confirmar.

O kit organiza os projetos em uma pasta da ferramenta:

```text
Pasta escolhida: /Users/seu-usuario/Documents/Projetos-IA
Nome informado: Loja da Ana
Ferramenta:      Codex
Resultado:       /Users/seu-usuario/Documents/Projetos-IA/CODEX/Loja da Ana
```

Para Claude, o resultado fica em `Projetos-IA/CLAUDE/Loja da Ana`. Se você selecionar diretamente a pasta `CODEX` para criar um projeto Codex, ou `CLAUDE` para um projeto Claude, o nome da ferramenta não será duplicado.

Você pode selecionar o destino pelo Finder ou informar o caminho manualmente. A pasta pode estar em Documentos, em um disco externo ou em um local sincronizado disponível no Mac. Se o Finder for cancelado, siga a orientação do menu para voltar ou usar o caminho manual. A criação exige um nome novo; se o projeto já existe, abra-o por **`5` → `2`**.

### Estrutura mínima ou organizada

- **Mínima:** prepara a pasta e registra a ferramenta escolhida. Você cria os documentos e o código conforme precisar.
- **Organizada:** prepara as pastas e os modelos abaixo, para começar com instruções e contexto próprios. Ao terminar, o kit pergunta em **uma frase** para que o projeto serve (Enter pula; depois dá para responder em **Cuidar do projeto → 12**, ou escrever em **→ 9**) e grava a frase em `INSTRUCOES/PROJETO.md` e `README.md`. Depois pergunta se você quer começar uma conversa agora.

```text
Projetos-IA/
  CODEX/
    Loja da Ana/
      AGENTS.md
      README.md
      INSTRUCOES/
        PROJETO.md
      PROMPTS/
        COMECE-AQUI.md  PLANEJAR.md  CONTINUAR.md
        ENCERRAR-SESSAO.md  RESUMO-RAPIDO.md
      DOCS/
        ANDAMENTO.md
      ANEXOS/
      .assistente-ia/
        tool
  CLAUDE/
    Outro projeto/
      CLAUDE.md
      README.md
      INSTRUCOES/
        PROJETO.md
      PROMPTS/
      DOCS/
        ANDAMENTO.md
      ANEXOS/
      .assistente-ia/
        tool
```

Na estrutura organizada, um projeto Codex novo recebe `AGENTS.md`; um projeto Claude novo recebe `CLAUDE.md`. O arquivo da outra ferramenta não é criado. A pasta `.assistente-ia` é oculta no Finder e contém o perfil portátil da ferramenta, inclusive na estrutura mínima. Ela não guarda sua senha nem transfere o login para outro Mac.

### Onde escrever as instruções de cada projeto

Edite **`INSTRUCOES/PROJETO.md`**. Esse é o lugar para registrar o que deve valer em todas as tarefas daquele projeto: objetivo, público, idioma, estilo, limites, prioridades, convenções e critérios de conclusão. O arquivo de entrada (`AGENTS.md` ou `CLAUDE.md`) orienta o agente a ler essas instruções.

Exemplo para uma loja:

```markdown
# Instruções deste projeto

## Objetivo
Criar e manter o site da minha loja de cosméticos.

## Público e linguagem
Consumidores brasileiros. Use português simples e valores em reais.

## Preferências
Explique decisões importantes antes de mudanças extensas.
Preserve produtos, imagens e dados existentes.

## Conclusão
Informe os arquivos alterados, verificações realizadas e pendências.
```

No menu, use **`6 → 9`** para criar ou editar as instruções. Você pode escrever pelo Terminal, abrir no TextEdit ou abrir a pasta. Ao substituir o texto pelo editor do Terminal, o menu preserva uma cópia do arquivo anterior em `DOCS/BACKUPS-INSTRUCOES/`. No TextEdit, mantenha o documento como texto simples com extensão `.md`.

### Atalhos opcionais no Claude e no Codex

Use **`6 → 9 → 4`** para conferir e ativar os atalhos do projeto. A criação normal de projetos continua sem esses arquivos; você decide quando adicioná-los.

- **Claude Code:** cria `.claude/commands/encerrar.md` e `resumo.md`, referenciando `@PROMPTS/ENCERRAR-SESSAO.md` e `@PROMPTS/RESUMO-RAPIDO.md`. No chat, use `/encerrar` ou `/resumo`.
- **Codex:** cria `.agents/skills/encerrar/SKILL.md` e `.agents/skills/resumo/SKILL.md`. No chat, selecione a skill ou peça `$encerrar` ou `$resumo`. Cada skill orienta a leitura do prompt correspondente na raiz do projeto.

Os prompts continuam em `PROMPTS/`, como fonte única do conteúdo. `encerrar` atualiza `DOCS/ANDAMENTO.md`; `resumo` prepara contexto curto para outra conversa. Arquivos existentes são preservados e caminhos gerenciados com links simbólicos são recusados. Confira as mensagens de criação e preservação; um arquivo seu que já exista não é substituído pelo modelo do kit. Abra uma nova sessão no projeto para conferir os atalhos.

A documentação oficial confirma o suporte aos [comandos e skills do Claude Code](https://code.claude.com/docs/en/skills) e às [skills locais do Codex](https://learn.chatgpt.com/docs/build-skills). Esses arquivos são instruções para o agente: o kit testa sua geração e preservação, mas a execução dentro do chat depende da CLI instalada e da sessão.

Se tiver mais contexto, organize outros `.md` em `INSTRUCOES/` ou `DOCS/` e cite os arquivos relevantes no seu pedido ou em `PROJETO.md`. Colocar arquivos nessas pastas não significa que todos serão lidos automaticamente. Mantenha as regras permanentes curtas e evite orientações contraditórias.

### Instruções permanentes, prompts e anexos

| Lugar | O que colocar | Como usar |
|---|---|---|
| `INSTRUCOES/PROJETO.md` | Regras e contexto que valem em todas as tarefas do projeto | O agente lê esse arquivo em **toda** conversa (a entrada `AGENTS.md`/`CLAUDE.md` manda ler). Por isso, mantenha-o curto. |
| `PROMPTS/` | Pedidos reutilizáveis, como revisar uma página ou planejar uma campanha | Escolha um arquivo ao começar a conversa (menu `2` → "Escolher um prompt salvo"). Só o pedido selecionado é enviado; fora da lista, o agente não lê a pasta sozinho. |
| `DOCS/` | Requisitos, decisões, referências e andamento | Lidos **só quando você pedir** (ex.: “leia `DOCS/briefing.md`”). `ANDAMENTO.md` é lido pelo prompt Continuar. |
| `ANEXOS/` | Imagens, planilhas, PDFs e outros materiais | Cite o arquivo na conversa para o agente utilizá-lo. |
| `README.md` | Visão geral e orientações para abrir o projeto | Atualize quando a forma de usar o projeto mudar. |

Para criar um prompt, use **`6 → 3`**. Para abrir a pasta e organizar seus `.md`, use **`6 → 10`**. Os modelos são pontos de partida: adapte o objetivo, os materiais e o resultado desejado ao seu projeto. Não existe um prompt único que garanta o resultado de qualquer tarefa.

### O que essa separação faz

As pastas `CODEX` e `CLAUDE` facilitam encontrar o projeto certo e evitam gerar instruções das duas ferramentas no mesmo projeto. Elas **não são uma barreira de segurança**. O acesso aos arquivos depende das permissões e da sandbox da ferramenta.

Instruções globais ou existentes em pastas acima do projeto também podem ser carregadas. Evite colocar `AGENTS.md` ou `CLAUDE.md` com regras de um projeto específico na pasta agrupadora. Versões recentes do Claude Code também podem ler `AGENTS.md` em determinadas configurações; não use apenas o nome do arquivo como garantia de isolamento. No Claude, `/context` ajuda a conferir os arquivos de instruções carregados. Consulte as [regras de projeto do Codex](https://learn.chatgpt.com/docs/agent-configuration/agents-md) e a [memória do Claude Code](https://code.claude.com/docs/en/memory).

### Pasta local, disco externo ou Google Drive

A escolha é sua. Se usar um disco externo, ele precisa estar conectado quando você abrir ou retomar o projeto. Se usar uma pasta sincronizada, confira se os arquivos estão disponíveis localmente antes de trabalhar.

Para projetos com muitos arquivos e dependências, desenvolver no SSD local costuma evitar esperas e conflitos de sincronização. Google Drive não substitui Git ou um backup revisado; `.gitignore` não impede a sincronização do Drive.

## Abrir um projeto existente ou recente

**Abrir a pasta de um projeto existente** (`5` → `2`) usa a própria pasta escolhida como diretório de trabalho. Não cria uma nova pasta dentro dela e não substitui arquivos do projeto.

**Projetos recentes** (`5` → `3`) é um atalho para pastas usadas pelo menu. Escolher uma entrada reabre o caminho salvo e pergunta se você quer começar uma conversa. Para continuar uma conversa já salva, use o menu `1`. Se você moveu, renomeou ou desconectou a pasta, selecione o novo local pelo Finder. O registro recente não é uma cópia do projeto.

O perfil em `.assistente-ia/tool` acompanha a pasta. Quando ele existe, o menu reutiliza a ferramenta registrada. Projetos antigos podem ainda não ter esse perfil; siga a escolha apresentada pelo menu. Abrir uma pasta antiga não reorganiza nem arquiva seus arquivos automaticamente.

Confira sempre o **projeto atual** antes de iniciar o agente. A pasta selecionada define onde a conversa começa e onde o agente trabalha por padrão; as permissões efetivas também dependem da CLI e de suas configurações.

## Escolher Codex ou Claude

Cada projeto usa a ferramenta escolhida na criação ou organização. Você pode ter projetos de Codex e projetos de Claude no mesmo Mac, sem precisar entrar nas duas contas para começar. Para projetos existentes, confira o perfil antes de abrir uma sessão.

| Escolha | Conta utilizada | Ferramenta que precisa existir no Terminal |
|---|---|---|
| Codex | Conta ChatGPT ou outra autenticação aceita pelo Codex | `codex` |
| Claude | Conta Claude/Anthropic ou provedor configurado no Claude Code | `claude` |

O aplicativo gráfico e a ferramenta do Terminal são instalações diferentes. Ter Codex ou Claude na pasta Aplicativos não garante que `codex` ou `claude` esteja disponível no Terminal.

Quando o menu avisar que falta uma CLI, use a instalação oficial oferecida pelo kit. Escolha um método e conclua a instalação. Depois, o diagnóstico deve conseguir mostrar a versão. Se ainda não encontrar o comando, feche e reabra o Terminal para atualizar o ambiente.

O menu não precisa de Node.js ou Python para funcionar. Alguns métodos opcionais de instalação, como npm, exigem seus próprios pré-requisitos.

## Login e conta conectada

O assistente verifica o status e chama os comandos oficiais de login quando necessário. A senha e a autorização são tratadas pelo serviço; o kit não deve receber nem armazenar sua senha ou copiar arquivos de credenciais.

### Codex

O login normal abre o navegador. Conclua a autorização com a conta que quer usar e volte ao Terminal. Se o retorno pelo navegador ou `localhost` falhar, tente a opção de **código de dispositivo**, quando disponível na sua CLI e habilitada na conta.

Comandos oficiais de referência:

```bash
codex --version
codex login status
codex login
codex login --device-auth
```

O status pode mostrar apenas o método de autenticação. Para confirmar a conta, use também as informações exibidas pelo próprio Codex, por exemplo `/status` dentro da sessão.

### Claude

O login abre o fluxo oficial do Claude Code. Escolha a conta e conclua a autorização no navegador; depois volte ao Terminal.

```bash
claude --version
claude auth status
claude auth login
```

Assinatura do Claude e autenticação pela Console/API são modalidades distintas. Se você usa assinatura, confira que está entrando pela modalidade correspondente. API e provedores externos seguem suas próprias condições de cobrança.

### Trocar de conta

Abra **Contas e login** (`7` → `1`), escolha Codex ou Claude e use **Trocar de conta**. Confira a ferramenta e confirme a saída da conta atual. O kit executa logout e abre um novo login.

Se o navegador entrar automaticamente na conta anterior, escolha outra conta na página de autorização ou ajuste a sessão do serviço no navegador. Não apague as pastas de configuração como tentativa de trocar de conta.

Se o diagnóstico indicar variáveis de API ou provedor configuradas, elas podem prevalecer sobre o login do navegador; confira a configuração do seu Terminal sem divulgar os valores.

A troca pode afetar outras interfaces que compartilhem as mesmas credenciais. As pastas de código continuam no lugar, mas o acesso ao histórico e aos modelos depende da nova conta. Este kit usa a configuração ativa das CLIs; não mantém um cofre de contas ou vários perfis de credenciais.

Você não precisa fazer logout ao terminar o trabalho. Fechar uma ferramenta e desconectar a conta são ações diferentes.

## Escolher modelo e raciocínio

Escolha o modelo depois de confirmar o login. O assistente apresenta essa escolha ao abrir uma conversa e lembra as preferências por projeto. Enter mantém a preferência mostrada; `1` volta ao padrão da CLI. Assim, você pode usar escolhas diferentes em pastas diferentes.

### Codex

Quando existir um catálogo local compatível, o menu pode apresentar os modelos visíveis registrados pela própria CLI. Esse catálogo pode estar antigo ou corresponder a uma conta anterior; ele não confirma sozinho que um modelo está liberado para você.

Você também pode usar o padrão da CLI ou informar um identificador exato. Para conferir as opções da sessão atual, entre no Codex e use:

```text
/model
/status
```

O seletor `/model` é a melhor referência para a conta e o ambiente atuais. Se um modelo for recusado, volte à escolha de modelo, use o padrão ou selecione uma opção disponível na própria ferramenta. Não é necessário recriar o projeto.

### Claude

Os atalhos **Sonnet**, **Opus** e **Haiku** usam aliases do Claude Code. Os aliases acompanham a configuração do provedor, sem exigir que você memorize uma versão específica. A opção padrão deixa a decisão com a configuração ativa da ferramenta.

Use `/model` dentro do Claude para conferir e trocar o modelo da sessão. Modelos permitidos podem depender da conta, do provedor e das regras da organização.

### Nível de raciocínio

Um nível mais alto pode levar mais tempo e consumir mais recursos. Nem todo modelo aceita os mesmos níveis. No Codex, o menu só apresenta níveis encontrados no catálogo compatível do modelo escolhido. No Claude, mantenha o padrão no menu e ajuste dentro da própria ferramenta com `/model`. Se estiver em dúvida, mantenha **Automático / padrão**.

As preferências do menu são aplicadas quando ele abre a sessão. Uma mudança feita com `/model` dentro da ferramenta pode não atualizar a preferência salva pelo menu. Ao retomar uma conversa, confira o modelo que a CLI exibe.

## Começar a conversa

Ao abrir uma conversa nova (menu `2`), as telas são numeradas: **Passo 1 de 4** (ferramenta e login), **Passo 2 de 4** (modelo e modo), **Passo 3 de 4** (seu pedido) e **Passo 4 de 4** (conferir e começar). Na **primeira conversa de um projeto**, o kit usa modelo e esforço padrão e só pergunta **“Ajustar modelo e esforço? [s/N]”**; nas seguintes, pergunta “Usar essas configurações? [S/n]”. Escolha o modo de trabalho oferecido pelo menu. Confira no resumo o modo escolhido: **Trabalhar** permite implementar na pasta do projeto; **Planejar** começa com as restrições de planejamento da ferramenta. No Codex, o kit usa sandbox de leitura nesse modo; no Claude, usa o modo Plan.

Com configurações salvas, Enter em “Usar essas configurações?” pula modelo, esforço e modo.

Na etapa **Como você quer começar?**, o nome e o caminho completo do projeto aparecem na tela. As opções são:

1. **Continuar o trabalho:** envia o prompt `CONTINUAR`, que lê o andamento do projeto. É a opção padrão quando o projeto já tem andamento registrado; em projeto novo, sem andamento, o padrão é a opção 2 (“Escrever um pedido novo”).
2. **Escrever um pedido novo:** aceita várias linhas; `FIM` sozinho conclui e `CANCELAR` sozinho volta.
3. **Escolher um prompt salvo:** lista os arquivos em `PROMPTS/` deste projeto. O conteúdo selecionado vira o pedido inicial da sessão.
4. **Começar sem pedido e escrever dentro do agente:** abre o Codex ou Claude para você digitar lá.
5. **Usar um arquivo `.md` ou `.txt` de outra pasta:** pelo Finder ou pelo caminho; limite de 60 KB.
6. **Começar com uma imagem (Codex):** PNG, JPG ou WEBP. No Claude, use os anexos do projeto e peça para ler o arquivo.

Escreva o que pretende construir ou corrigir. Um pedido útil contém o objetivo e um resultado observável:

> Quero criar um site para minha loja. Primeiro examine esta pasta e me explique o que já existe. Depois crie uma página inicial, catálogo e contato em português. Antes de finalizar, execute os testes disponíveis e me diga como abrir o site no Mac.

Durante a conversa, você está na interface oficial do Codex ou do Claude. As perguntas de confiança na pasta, permissões e conta pertencem à própria ferramenta. Leia o que ela pede antes de confirmar.

Para sair da conversa, use `/exit` quando disponível ou `Ctrl+C`, conforme a orientação da CLI. Algumas versões exigem mais de um `Ctrl+C` para encerrar. Aguarde o retorno ao menu; depois escolha `0` para sair do kit. Terminou uma tarefa? Use o menu `3` antes de fechar.

## Continuar de onde parei

Escolha **`1`** no menu principal ou apenas aperte **Enter** (com projeto aberto). O kit usa a ferramenta, o modelo e o modo já salvos do projeto e continua a **última conversa**, sem repetir as etapas. Se ainda não existir conversa anterior, ele pergunta se você quer abrir uma nova com as mesmas configurações. Se a conversa estiver **muito longa**, o kit pergunta antes **“Encerrar com resumo primeiro? [S/n]”** (S abre o Encerrar com resumo; n continua mesmo assim). Se você preferir que o Enter não faça isso, desligue-o em `7` → `4`.

| Ação | Codex | Claude |
|---|---|---|
| Continuar a sessão mais recente da pasta (menu `1`) | `codex resume --last` | `claude --continue` |
| Escolher uma sessão antiga (menu `8`) | `codex resume` | `claude --resume` |

O menu **`8` — Escolher uma conversa antiga** abre a lista oficial da ferramenta do projeto. Selecione o projeto correto antes de continuar. A identificação por pasta pode mudar quando você renomeia ou move um projeto.

**Cuidado:** o menu `1` retoma a conversa antiga inteira, inclusive se ela estiver grande. Depois de **Encerrar com resumo**, prefira o menu `2` → **Continuar o trabalho**: a conversa nova começa leve e só lê o andamento.

Codex e Claude não compartilham automaticamente o mesmo histórico. O arquivo `DOCS/ANDAMENTO.md` (atualizado pelo prompt `ENCERRAR-SESSAO`) registra o que foi concluído, decisões, comandos e a próxima tarefa, e serve também para migrar o projeto para outra ferramenta.

## Painel de uso e quando encerrar

Cada mensagem reenvia a conversa inteira; conversas grandes custam mais e rendem menos. O kit mostra isso de três formas:

- **Linha “Conversa” no painel do menu principal:** leve, ficando longa ou muito longa, com tokens e mensagens aproximadas (só aparece com a medição ligada).
- **Menu `4` — Painel de uso dos projetos:** lista até 12 projetos recentes, do mais pesado ao mais leve, com ✓ (leve), ⚠ (ficando longa) ou ⛔ (muito longa). Os limites usados são: até cerca de 80 mil tokens é leve; de 80 a 200 mil, ficando longa; acima de 200 mil, muito longa.
- **Aviso ao abrir a conversa:** quando a conversa mais recente está pesada, o resumo antes do Enter avisa.

O que fazer: ✓ continue; ⚠ termine a tarefa e use o menu `3` (Encerrar com resumo); ⛔ encerre agora e abra uma conversa nova com **Continuar o trabalho**.

De onde vêm os números: no **Codex**, do registro de uso da própria sessão (inclui a janela de contexto, então aparece a porcentagem). No **Claude**, o número é exato se você instalou a barra do chat (próxima seção) **e** o registro dela for tão recente quanto a conversa; senão, o kit estima pelos arquivos de sessão e marca “(estimativa)”. O kit só conta mensagens e soma números nos arquivos de sessão; nada do conteúdo das conversas é exibido ou enviado.

Para desligar tudo isso, use `7` → `4` → item `3` (**“Medir o uso da conversa e avisar quando estiver longa”**): desligado, o kit deixa de medir no painel da tela inicial, no menu `4`, no aviso ao abrir a conversa e na pergunta do menu `1`. O menu `4` passa a dizer como religar.

### Encerrar com resumo (menu `3`)

O kit abre a última conversa do projeto e envia o prompt `PROMPTS/ENCERRAR-SESSAO.md`: o agente resume o que foi feito e **atualiza `DOCS/ANDAMENTO.md`**, condensado e com só fatos confirmados. Depois feche com `/exit`. Na próxima vez, use o menu `2` → **Continuar o trabalho**. Se o projeto não tiver o prompt, o kit oferece criá-lo, sem sobrescrever nada. No Codex, se a conversa abrir sem o pedido, digite: `leia PROMPTS/ENCERRAR-SESSAO.md e siga`. O prompt `RESUMO-RAPIDO` gera um resumo curto para colar numa conversa nova.

## Aviso dentro do chat (Claude Code)

É uma barra no rodapé do Claude Code, **opcional**, que mostra o uso do contexto: verde enquanto está leve, amarela quando está ficando longa, vermelha quando é hora de encerrar. Depois de instalada, ela grava sozinha, a cada atualização, só números de uso (que o painel `4` usa para o Claude), mesmo fora do assistente; isso para quando você remove a barra. **Não existe barra equivalente conhecida no Codex**; lá, use o menu `4` e `/status`.

Para instalar, abra **`7` → `7`**:

1. **Ver como ficará** mostra a barra com um exemplo, sem alterar nada.
2. **Instalar a barra:** o kit mostra o que será adicionado ao `~/.claude/settings.json`, **valida o JSON antes** de criar o backup, copia o script para a pasta de preferências do kit e só grava depois que você digitar **`INSTALAR`**. Ele só altera a chave `statusLine`; o resto do arquivo fica como está. O kit reconhece a barra dele em qualquer formato de comando no `settings.json`. Se você já tem outra barra, o kit **não sobrescreve** e mostra como usar o script pelo comando `/statusline` do Claude, que pede a sua aprovação. Sem o Python, mostra o trecho exato para colar.
3. Abra uma **conversa nova** no Claude Code para ver a barra.

Para **remover**: `7` → `7` → **Remover a barra**, digite **`REMOVER`**. O kit só remove a barra que ele mesmo instalou (com backup); para outra barra, use `/statusline delete` no Claude. Sem instalar nada, `/context` mostra o uso e `/compact` resume a conversa sem sair dela.

## Arquivos e ferramentas do projeto

Abra **`6` Cuidar do projeto** no menu principal. A tela é dividida em *Instruções e prompts*, *Arquivos* e *Outros*; os números abaixo são os da tela. Confira o caminho do projeto no cabeçalho antes de escolher:

| Opção do submenu | Como usar |
|---|---|
| `1` Abrir pasta no Finder | Mostra a pasta atual para você inspecionar ou organizar os arquivos. |
| `2` Copiar anexo | Escolha o arquivo pelo Finder ou caminho manual. Confirme a cópia para `ANEXOS/`; o original continua onde estava e um nome já existente é recusado. |
| `3` Criar prompt personalizado para este projeto | Dê um nome e escreva o texto. `FIM` salva em `PROMPTS/`; `CANCELAR` volta. Na próxima conversa, escolha “Escolher um prompt salvo” para usar esse prompt. |
| `4` Capturar parte da tela | Selecione uma região; a imagem fica em `ANEXOS/`. Esc cancela a captura. |
| `5` Ver alterações do Git | Mostra o status do repositório, sem criar commits. A pasta precisa ser um repositório Git para isso funcionar. |
| `6` Criar cópia ZIP | Escolha um destino fora do projeto e confirme. A cópia inclui o projeto inteiro, inclusive arquivos ocultos como `.env`, se existirem. |
| `7` Abrir site no Safari | Informe o caminho completo de um HTML existente ou a URL local que seu servidor exibiu, por exemplo `http://localhost:3000`. |
| `8` Executar npm run dev | Usa o pacote na raiz; se ausente, procura em `CODIGO/`, `CODIGO/*` e nas subpastas diretas. Mostra o caminho e, se houver vários, pede a escolha. Exige Node.js/npm e dependências já preparadas. Ctrl+C encerra o servidor. |
| `9` Instruções permanentes | Edita `INSTRUCOES/PROJETO.md` e oferece atalhos opcionais de Claude/Codex na opção `4`. |
| `10` Abrir pasta de prompts | Abre `PROMPTS/` no Finder para organizar os pedidos salvos. |
| `11` Organizar projeto antigo | Escolhe o perfil e mostra a prévia da organização. Só aplica depois da confirmação `ORGANIZAR`. |
| `12` Verificar se a pasta está organizada | Confere pastas, perfil, entrada do agente, `PROJETO.md`, peso das instruções e `ANDAMENTO.md`; avisa de documentos grandes em `PROMPTS/`, oferece mover para `DOCS/`, anexar a seção Eficiência e criar prompts ausentes, e pergunta o objetivo. Distingue **objetivo em modelo** (aviso forte) de **faltam detalhes de contexto e requisitos** (aviso leve, não obrigatório). Tudo com confirmação e backup. |

Copiar um documento para `ANEXOS/` não o envia automaticamente ao agente. Na conversa, peça por exemplo: “Leia `ANEXOS/requisitos.md` e implemente as alterações”. A leitura de PDF, DOCX ou outros formatos depende dos recursos disponíveis na ferramenta.

Uma cópia ZIP não é validada apenas por ter sido criada. Abra-a e confira os arquivos antes de depender dela como backup ou compartilhá-la. Se o projeto contém credenciais, elas também podem entrar na cópia completa.

O servidor de desenvolvimento usa a janela enquanto estiver rodando. Para abrir o site pelo menu em paralelo, abra outra janela do Terminal e execute o kit nela. O menu não instala automaticamente dependências nem escolhe como executar todos os tipos de projeto; `npm run dev` atende aos projetos que definem esse script.

**Git (`6 → 5`):** o repositório da raiz mantém a prioridade. Sem ele, o kit mostra o status separado de cada repositório em `CODIGO/`, `CODIGO/*` e nas subpastas diretas, identificado pelo caminho relativo. As buscas de Git e servidor ignoram pastas ocultas, `node_modules` e links simbólicos; não varrem recursivamente o projeto inteiro.

## Onde ficam instruções, prompts e documentos

| Pasta ou arquivo | Para quê |
|---|---|
| `INSTRUCOES/PROJETO.md` | Regras permanentes: objetivo, público, estilo, limites. Vale para toda tarefa. |
| `PROMPTS/` | Pedidos curtos e reutilizáveis (ex.: Continuar, Planejar). Você escolhe um por conversa. |
| `DOCS/` | Briefings, requisitos longos, referências e `ANDAMENTO.md`. |
| `ANEXOS/` | Imagens, PDFs e outros materiais. |

Instruções permanentes **não** ficam em `PROMPTS/`. Um documento grande em `PROMPTS/` seria enviado inteiro como pedido. Use **`6` → `12`** para o kit conferir a pasta: ele avisa sobre instruções ainda em branco, documentos grandes fora do lugar e a referência da ferramenta, e move para `DOCS/` só se você confirmar. Os mesmos avisos aparecem ao abrir uma conversa.

## Economia de tokens e conversas longas

Cada conversa carrega as instruções fixas do projeto (`CLAUDE.md`/`AGENTS.md` e `INSTRUCOES/PROJETO.md`) e cresce a cada mensagem. Para render mais com menos tokens:

- Mantenha `INSTRUCOES/PROJETO.md` curto e `DOCS/ANDAMENTO.md` com poucas linhas; o menu `6` → `12` mostra uma estimativa do peso (bytes ÷ 4 ≈ tokens) e avisa quando passa do razoável.
- Uma conversa por tarefa. Quando ela ficar grande, use o prompt **ENCERRAR-SESSAO** (resume e atualiza o andamento), abra uma conversa nova e use **CONTINUAR**. **RESUMO-RAPIDO** gera um resumo curto para colar numa conversa nova.
- Cite o caminho exato dos arquivos, peça trechos ou diffs, use o modo **Planejar** antes de mudanças grandes e esforço menor em tarefas simples.
- No Claude Code, `/compact` e `/clear` ajudam; o menu `7` → `3` do kit traz as dicas completas, e uma dica aparece ao abrir cada conversa.
- O aviso de conversa longa e o painel `4` usam tamanho, data e registros de uso dos arquivos de sessão (no Codex, o kit também confere o início do arquivo para achar o projeto). Sem a barra do Claude instalada, são estimativas. Nada do conteúdo é exibido ou enviado.

## Controle total (menu `7` → `4`)

Em **Preferências**, você liga ou desliga cada recurso automático:

| Item | O que faz quando ligado |
|---|---|
| `1` RTK | Ao abrir uma conversa, confere o RTK e **pergunta** [S/n] (Enter = ativar; `n` desliga e não pergunta mais). |
| `2` Dicas | Mostra uma dica de economia ao abrir a conversa. |
| `3` Medir o uso da conversa e avisar quando estiver longa | Liga a medição no painel inicial, no menu `4`, no aviso ao abrir e na pergunta “Encerrar com resumo primeiro?”. Desligado, nada disso é medido. |
| `4` Enter = continuar | Enter no menu principal equivale à opção `1`. |
| `5` Verificar RTK novo | Uma vez por dia, em segundo plano, consulta `github.com/rtk-ai/rtk/releases/latest` para saber o número da versão mais nova. Só consulta: instalar exige o menu `7` → `2` → `10` e a palavra `ATUALIZAR`. |
| `6` | Mostra a tela **“O que este assistente faz sozinho”**: o que o kit grava, lê e não faz. |

Resumo honesto dessa tela:

- **Grava só com sua confirmação:** projetos, pedidos prontos, anexos e instruções (com cópia de segurança quando altera texto seu); a barra do chat (edita **só a chave `statusLine`** do `~/.claude/settings.json`, com backup e depois de você digitar `INSTALAR`); o RTK global (só se você responder sim).
- **Grava sem perguntar:** as preferências do próprio kit (projeto atual, recentes, modelo, modo, as chaves acima e o número da última versão do RTK consultada) e, **depois de instalada, a barra do chat**, que grava números de uso a cada atualização até você removê-la.
- **Lê, sem mostrar nem enviar:** nas sessões do agente, tamanho, data, **contagem aproximada de mensagens e números de uso** (e, no Codex, o início do arquivo para achar o projeto); o estado do login e os *nomes* das variáveis de API; se o hook do RTK existe; `PROJETO.md`, `README.md` e a pasta de pedidos prontos do projeto atual.
- **Não faz:** mostrar ou enviar senhas, tokens ou `.env`; apagar arquivos seus; usar a internet por conta própria (exceção desligável: a consulta diária da versão do RTK, que não envia dados seus). O modo **Trabalhar** pede aprovação sob demanda e **Planejar** só lê.

## Organizar um projeto da versão anterior

Se sua pasta antiga tem `AGENTS.md` e `CLAUDE.md` juntos, abra essa pasta por **Projetos (`5`) → `2`**. Depois use **`6 → 11`**, escolha a ferramenta que vai usar e leia a prévia.

Digite **`ORGANIZAR`** apenas quando o caminho e a ferramenta estiverem corretos. A organização registra o perfil, prepara as pastas e preserva o conteúdo das instruções da ferramenta escolhida. O arquivo de entrada da ferramenta oposta é arquivado em **`DOCS/LEGADO/`**, preservando seu conteúdo para consulta. Confira o resumo final para localizar os arquivos e eventuais cópias preservadas.

Esse procedimento é uma ação explícita do menu. Ele não acontece quando você apenas abre, retoma ou consulta o projeto. Não é necessário recriar seus arquivos de trabalho. Depois, revise `INSTRUCOES/PROJETO.md` para manter somente as orientações que você quer usar nas próximas tarefas.

Ao organizar para **Claude**, uma pasta `.claude/` real é permitida e preservada, incluindo configurações, skills e comandos existentes. Se `.claude` for link simbólico ou não for diretório, a organização é bloqueada. Ao organizar para **Codex**, a presença de `.claude/` continua bloqueando a migração automática para evitar uma conversão parcial das regras do Claude. `AGENTS.override.md` e `CLAUDE.local.md` continuam exigindo revisão manual.

## RTK: instalar e usar

**RTK abre ligado.** Ao iniciar uma conversa, o kit confere o RTK do agente escolhido. Se estiver instalado e desligado, pergunta uma vez (Enter = ativar). Se você desligar de propósito (menu `7` → `2` → `4`, ou respondendo `n`), o kit respeita e não pergunta mais; `7` → `2` → `3` religa. O estado aparece no menu principal e no resumo da conversa.

RTK compacta a saída de comandos compatíveis para reduzir o volume de texto entregue ao agente. Ele não é um modelo, não troca sua conta e não substitui a autenticação do Codex ou do Claude.

A instalação e a ativação são etapas separadas:

1. Abra **Ajuda e ajustes → RTK** (`7` → `2`) e confira se a ferramenta já está instalada.
2. Se necessário, escolha um método de instalação e confirme o comando apresentado.
3. Escolha Codex ou Claude para ativar a integração.
4. Leia a prévia mostrada pelo RTK e confirme a alteração.
5. Feche a sessão do agente e abra outra para carregar a integração.
6. Depois de usar comandos compatíveis, consulte os ganhos e o status no submenu RTK.

### Como enxergar o RTK funcionando enquanto usa Claude ou Codex

No menu **RTK** (`7` → `2`), escolha **7 — Abrir monitor RTK ao vivo em outra janela**. O kit solicita ao Terminal do macOS uma janela separada com `rtk gain --watch`; assim o Codex/Claude permanece utilizável no Terminal original. Para encerrar o monitor, pressione `Ctrl+C` na segunda janela. Se o macOS negar a abertura, confira a permissão de Automação e use `rtk gain --watch` em outro Terminal aberto manualmente.

A opção **8 — Últimos comandos RTK** (`rtk gain --history`) mostra até dez operações recentes registradas. Abra uma conversa nova, peça uma operação de terminal compatível (por exemplo, examinar `git status` em um projeto Git) e depois confira o histórico. Para confirmar a ligação ao agente, consulte o hook da ferramenta pelo menu `7` → `2` → `2` e compare a atividade durante a conversa. O uso direto de `rtk` no Terminal também gera registros, portanto histórico novo não prova sozinho que o agente usou um hook.

A opção **9 — Verificar reescrita** consulta `rtk rewrite 'git status'`, sem executar `git status`, sem instalar e sem mexer nas configurações. Ela testa o reescritor do RTK, **não** se o Claude ou Codex acionou o hook. Os comandos internos do agente, como Read/Grep/Glob, podem não passar por esse hook. Os ganhos e o histórico são **globais**: não permitem atribuir cada economia com certeza a um projeto ou agente.

A integração global pode afetar sessões abertas fora deste menu. Integrar o Codex e integrar o Claude são escolhas separadas. Desativar a integração gerenciada não equivale a desinstalar o binário do RTK; integrações locais existentes em projetos podem ter configuração própria.

As medidas de `rtk gain` são estimativas do RTK para as saídas observadas. Elas não equivalem a uma redução garantida na cobrança total, no contexto completo ou na memória RAM do agente. Ao investigar um erro, confira a saída completa do comando quando a compactação esconder detalhes úteis.

### Atualizar o RTK

O kit confere **uma vez por dia**, em segundo plano e sem atrasar o menu, qual é a última versão publicada do RTK. Quando há versão nova, o painel mostra `Atualização: RTK vX.Y.Z disponível (você tem vA.B.C)`. A opção **10 — Atualizar RTK** (`7` → `2` → `10`) consulta de novo, mostra as duas versões e pede `ATUALIZAR`:

- instalado pelo **instalador oficial** (`~/.local/bin/rtk`): baixa o `install.sh` **da tag da versão publicada** (nunca da branch `master`), com `RTK_VERSION` fixado e conferência de SHA-256 obrigatória;
- instalado pelo **Homebrew**: usa `brew upgrade rtk-ai/tap/rtk-oss`;
- instalado de outro jeito: não mexe e pede que você atualize pelo mesmo método.

A primeira instalação (opção 1) também usa a tag da última versão publicada. Para desligar a consulta diária: Preferências (`7` → `4`) → item `5`.

Você também pode abrir as funções RTK pelo Terminal, a partir da pasta do kit:

```bash
/bin/bash ASSISTENTE-IA-MAC.command --rtk menu
/bin/bash ASSISTENTE-IA-MAC.command --rtk status
/bin/bash ASSISTENTE-IA-MAC.command --rtk ganhos
/bin/bash ASSISTENTE-IA-MAC.command --rtk historico
/bin/bash ASSISTENTE-IA-MAC.command --rtk verificar
/bin/bash ASSISTENTE-IA-MAC.command --rtk monitor # execute em outra janela de Terminal
/bin/bash ASSISTENTE-IA-MAC.command --rtk atualizar
/bin/bash ASSISTENTE-IA-MAC.command --rtk ativar codex
/bin/bash ASSISTENTE-IA-MAC.command --rtk desativar codex
```

Troque `codex` por `claude` nas ações de ativar/desativar para gerenciar essa ferramenta. A ativação mantém a prévia e a confirmação. No Codex, a reescrita automática de comandos depende do suporte a hooks na versão instalada; sem esse suporte, não presuma que a presença do RTK ou de instruções globais torne todo uso automático.

Consulte também [RTK.md](RTK.md), com os comandos e as fontes utilizados na integração. As ações globais usadas são `rtk init --global --codex` para Codex e `rtk init --global` para Claude; o menu mostra `--dry-run` antes de aplicar. A desativação usa `--uninstall`. O status é consultado com `rtk init --show` e as estimativas com `rtk gain`.

## Problemas comuns

| O que acontece | Como seguir |
|---|---|
| Não consigo criar o projeto | Escolha uma pasta existente e gravável como destino; informe um nome novo e confira o caminho antes de confirmar. |
| A pasta já existe | Use **Abrir projeto existente**. Não é preciso criar ou sobrescrever a pasta. |
| O Finder foi cancelado ou não abriu | Refaça a escolha usando o caminho manual. |
| A pasta recente desapareceu | Conecte o disco, disponibilize os arquivos localmente ou selecione o novo caminho. |
| `command not found: codex` ou `claude` | Use instalação/diagnóstico da CLI. Ter o aplicativo gráfico não basta. |
| O navegador autorizou, mas o menu não confirmou | Volte ao diagnóstico. Para Codex, experimente código de dispositivo se o fluxo do navegador falhou. |
| O modelo ou esforço foi recusado | Use o padrão ou `/model` dentro da CLI e selecione uma opção disponível para a conta. |
| A conversa anterior não aparece | Confira ferramenta, conta e pasta; abra o seletor de sessões. |
| Troquei Codex por Claude e o contexto sumiu | Cada ferramenta tem seu histórico. Use os arquivos do projeto e um registro de andamento para transmitir contexto. |
| RTK foi instalado, mas não aparece ativo | Confira o status, ative a integração do agente escolhido e reinicie a sessão. |
| O monitor RTK abre, mas nada muda | Confirme que o agente usou comandos de Terminal compatíveis, compare `rtk gain --history` e verifique o hook da ferramenta; operações internas Read/Grep/Glob não acionam o hook do shell. |
| Ainda aparece o menu antigo com opções 11–43 ou o erro `flags[@]: unbound variable` | Digite `0` para sair, feche a janela antiga do Terminal e abra novamente o arquivo `.command` desta versão. Um menu que já estava aberto continua executando o script antigo até ser reiniciado. |
| A barra do chat não aparece | Instale em `7` → `7`, confirme com `INSTALAR` e abra uma conversa **nova** no Claude Code. Ela só existe no Claude Code. Se você já tinha outra barra, o kit não sobrescreve: use `/statusline` como o menu orienta. |
| O painel `4` mostra “não consegui medir” ou “estimativa” | Sem a barra do Claude, o número vem dos arquivos de sessão e pode faltar ou ser aproximado. Instale a barra para números exatos; no Codex, confirme que existe uma conversa nesse projeto. |
| Encerrar com resumo abriu sem o pedido (Codex) | Digite na conversa: `leia PROMPTS/ENCERRAR-SESSAO.md e siga`. |
| Não vejo a linha “Conversa” nem o aviso de conversa longa | Eles só existem com a medição ligada: confira em `7` → `4` se o item `3` (“Medir o uso da conversa…”) está ligado. O aviso só aparece quando a conversa passa dos limites. |
| O menu voltou após um erro | Leia a mensagem exibida. Os arquivos do projeto permanecem na pasta; corrija a causa e tente a ação novamente. |

O diagnóstico é um primeiro passo para conferir executáveis, versões e autenticação. Não envie tokens, arquivos `auth.json`, cookies ou conteúdo de `.env` ao pedir ajuda. Uma captura da mensagem de erro, sem dados privados, costuma ser suficiente.

## Preferências e verificação

As preferências locais do menu ficam em `~/Library/Application Support/Assistente IA Mac/` e registram caminhos e escolhas de uso (projeto atual, recentes, modelo, modo, as chaves de `7` → `4`, os números de uso gravados pela barra do chat e, se você instalar a barra, o script dela e os backups do `settings.json`). O perfil da ferramenta fica também em `.assistente-ia/tool` dentro do projeto, para acompanhar a pasta. As credenciais continuam sob responsabilidade das CLIs. O kit original em Downloads não precisa ser removido para usar a versão nova.

Consulte `MUDANCAS-E-TESTES.md` para saber quais verificações foram realmente executadas nesta versão. Testes com ferramentas simuladas não substituem uma conversa autenticada com os serviços. Login no navegador, acesso aos modelos e uso da sua conta precisam ser confirmados na sua sessão. Não há garantia de que serviços externos ou versões futuras das CLIs mantenham o mesmo comportamento.

## Referências oficiais

- [Instruções de projeto do Codex — AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)
- [Autenticação do Codex](https://developers.openai.com/codex/auth/)
- [Comandos do Codex e seletor de modelos](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
- [Instruções e memória do Claude Code — CLAUDE.md](https://code.claude.com/docs/en/memory)
- [Instalação do Claude Code](https://code.claude.com/docs/en/setup)
- [Comandos do Claude Code](https://code.claude.com/docs/en/cli-reference)
- [Modelos do Claude Code](https://code.claude.com/docs/en/model-config)
- [RTK](https://github.com/rtk-ai/rtk)
