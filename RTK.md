# RTK no Assistente IA Mac 1.0

> Onde fica no menu: **7 Ajuda e ajustes → 2 RTK**. Ao abrir uma conversa, o kit confere o RTK e só pergunta [S/n] se quer ativar (Enter = ativar; `n` desliga e não pergunta mais; desligue a conferência em 7 → 4).

O menu **RTK** permite instalar a edição OSS, consultar ganhos, ativar e desativar a integração do Codex ou do Claude. Instalar o programa e ativar sua integração são dois passos distintos.

## Acesso rápido

No Terminal, dentro da pasta do kit:

```sh
./ASSISTENTE-IA-MAC.command --rtk
./ASSISTENTE-IA-MAC.command --rtk status
./ASSISTENTE-IA-MAC.command --rtk ganhos
./ASSISTENTE-IA-MAC.command --rtk historico
./ASSISTENTE-IA-MAC.command --rtk verificar
./ASSISTENTE-IA-MAC.command --rtk monitor  # em outra janela do Terminal
./ASSISTENTE-IA-MAC.command --rtk desativar codex
./ASSISTENTE-IA-MAC.command --rtk ativar codex
```

Troque `codex` por `claude` para mudar a integração do outro agente. Ativar e desativar mostram uma prévia e pedem confirmação. No menu principal, escolha **7 Ajuda e ajustes → 2 RTK → Desativar integração em um agente** quando quiser parar a integração automática. O programa continua instalado e os ganhos anteriores permanecem disponíveis.

Com o RTK instalado, o comando mais curto para ver a economia é **`rtk gain`**, executado em qualquer Terminal. No menu RTK, a opção **Ver somente a economia** faz essa consulta. Para uso manual, `rtk git status` mostra um exemplo de saída compacta em um repositório Git. `rtk bypass git status` executa o comando sem o filtro. [Comandos oficiais](https://github.com/rtk-ai/rtk#measure-it)

Os números de tokens são estimativas das saídas processadas; não medem todo o consumo nem a conta do agente. A situação consulta **Codex e Claude separadamente**, com rótulos; a parte local corresponde ao projeto selecionado. Consultar integrações mostra a configuração; a atuação real do hook precisa ser observada durante comandos compatíveis no agente reiniciado. Se a versão do RTK não permitir consultar Codex, o menu informa que esse estado não foi consultado. Se o banco de ganhos estiver indisponível, a consulta das integrações continua e o comando retorna um aviso de resultado parcial.

## Como acompanhar ao vivo no macOS

- **Menu 7 → 2 → 7:** abre uma segunda janela de Terminal com `rtk gain --watch` (quando esta opção está disponível no RTK instalado). Mantenha a primeira janela com Codex ou Claude. Nenhum monitor ou serviço permanece instalado pelo kit; feche a janela do monitor ou pressione `Ctrl+C`.
- **Menu 7 → 2 → 8:** usa `rtk gain --history` para apresentar as operações recentes que passaram pelo RTK. Se o número mudar depois de comandos de shell da IA, é um indício forte de uso, mas comandos manuais ou de outros agentes compartilham o banco.
- **Menu 7 → 2 → 9:** executa `rtk rewrite 'git status'` para avaliar somente a transformação do comando (sem rodar Git). Não certifica que o hook do agente esteja acionado.
- **Menu 7 → 2 → 2:** mostra separadamente o estado da integração Codex e Claude, incluindo o contexto de projeto selecionado.

A atuação automática depende da versão instalada do RTK e da implementação dos hooks no CLI do agente. `rtk gain --watch` e o histórico monitoram estatísticas globais, **não** uso por processo, ferramenta ou projeto. Não faça um `rtk gain --reset` para verificar, pois apagaria estatísticas; o kit nunca faz isso.

## Primeira configuração

1. No menu RTK, escolha **Instalar RTK OSS**. Você pode usar o instalador oficial sem Homebrew ou um Homebrew já existente. A instalação pede `INSTALAR` antes de executar qualquer instalador.
2. Escolha **Ativar integração em um agente** e selecione Codex ou Claude.
3. Leia a prévia das alterações. Digite `ATIVAR` para aplicar.
4. Feche e abra novamente a conversa do agente. Se o Codex pedir confiança no hook, confira o que ele apresenta e decida no próprio Codex.
5. Depois de usar comandos, consulte **Situação dos hooks e ganhos de tokens**.

O instalador oficial usa `~/.local/bin/rtk`. O kit força a verificação SHA-256 do binário e não executa instalação com `sudo`. A edição OSS mantém filtros e reescrita de comandos sem o motor de compressão BUSL. As duas edições usam o mesmo nome de executável e não devem ser instaladas juntas. [Instalação oficial](https://www.rtk-ai.app/docs/getting-started/installation/)

## O que muda no agente

Um hook intercepta comandos de terminal compatíveis e os encaminha ao RTK. O agente recebe uma saída filtrada, com menos texto repetitivo. Isso pode reduzir os tokens usados para ler resultados de comandos. A economia varia; não é uma redução garantida do consumo total da conversa. A filtragem funciona sem proxy ou serviço do macOS. Se a edição do RTK já instalada oferecer recursos adicionais durante a ativação, leia cada pergunta antes de aceitar. [Guia oficial](https://www.rtk-ai.app/docs/getting-started/quick-start/)

As integrações oferecidas pelo menu são **globais**: também afetam conversas abertas fora deste kit. Cada ferramenta é configurada separadamente. O kit não usa `rtk init` local para anunciar um hook do Claude: atualmente esse comando local fornece instruções, enquanto a integração automática do Claude é instalada globalmente. [Agentes suportados](https://www.rtk-ai.app/docs/getting-started/supported-agents/)

| Ação | Codex | Claude |
| --- | --- | --- |
| Prévia para ativar | `rtk init --global --codex --dry-run` | `rtk init --global --dry-run` |
| Ativar | `rtk init --global --codex` | `rtk init --global` |
| Prévia para desativar | `rtk init --global --codex --uninstall --dry-run` | `rtk init --global --uninstall --dry-run` |
| Desativar | `rtk init --global --codex --uninstall` | `rtk init --global --uninstall` |
| Consultar integração | `rtk init --codex --show` | `rtk init --show` |
| Consultar ganhos | `rtk gain` | `rtk gain` |

A prévia é executada antes da confirmação. Se faltar uma opção no `rtk init --help`, o kit interrompe a ação e orienta atualizar. Desativar a integração mantém o executável disponível e não remove hooks locais independentes. Reinicie o agente depois de mudar a integração. [Comandos de integração](https://www.rtk-ai.app/docs/getting-started/supported-agents/)

## Quando algo não funcionar

- **RTK não encontrado:** instale pelo menu e reabra o Terminal se necessário.
- **`rtk gain` falhou:** confira se instalou Rust Token Killer (`rtk-ai/rtk`), pois existe outro projeto com o mesmo nome.
- **Hook não parece atuar:** confira `rtk init --codex --show` para Codex ou `rtk init --show` para Claude; reinicie o agente e observe se foram usados comandos compatíveis. A existência do executável não confirma que o hook está ativo. A consulta sem `--codex` não confirma o estado do Codex.
- **Saída com menos detalhes:** consulte a saída original ao investigar um erro que precise do contexto completo.
- **Desativação com aviso:** leia a saída e consulte os hooks. O kit não declara integração desativada apenas com base no código de saída do RTK.

## Verificações do kit original (v1.0)

A biblioteca passou na sintaxe do Bash 3.2 do macOS. Os 56 testes com comandos simulados cobriram argumentos de Codex/Claude, consulta individual de cada integração, prévia obrigatória, cancelamento, falhas e versões antigas, rejeição de opções com nomes parecidos, fim da entrada, comandos de acesso rápido e contexto do projeto selecionado. A instalação, o download e a existência de um executável no destino são simulados, permitindo testar também instalação cancelada, falha de download e proteção contra sobrescrita sem alterar a pasta pessoal. Não houve instalação real do RTK nem alteração de hooks ou credenciais durante a preparação. `rtk init --help` e `rtk init --codex --show` foram consultados na versão instalada; a atuação automática dentro dos agentes precisa ser confirmada no uso real. Resultado completo: `tests/resultado-rtk.txt`.

Fontes verificadas em 22/10/2026. O instalador remoto e os comandos podem evoluir após essa data.

## Auditoria das melhorias na versão 1.0 — 22/10/2026

Foram acrescentados monitor, histórico e teste somente-leitura do reescritor, com regressões simuladas. Consulte `AUDITORIA-2026-10-22.md` e `MUDANCAS-E-TESTES.md` para os resultados efetivamente repetidos neste ambiente Linux. O monitor AppleScript ainda exige verificação no macOS.
