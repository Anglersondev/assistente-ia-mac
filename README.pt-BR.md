<div align="center">
  <img src="assets/assistente-ia-mac-banner.svg" alt="Assistente IA Mac — ambiente de projetos para Codex CLI e Claude Code" width="100%">
  <br><br>
  <strong>Um ambiente organizado no macOS para desenvolver com ajuda de IA.</strong>
  <br>
  Organize projetos, mantenha o contexto junto do código e use Codex CLI ou Claude Code em um único menu.
</div>

---

**Idiomas:** [English](README.md) · Português (Brasil)

Projeto mantido por [Anglersondev](https://github.com/Anglersondev). Se ele ajudar você, [apoie o mantenedor](https://pixgg.com/Anglerson).

## O que ele faz

O **Assistente IA Mac** é um conjunto de ferramentas em menu para quem desenvolve com **Codex CLI** e **Claude Code**. Cada projeto ganha um lugar para instruções permanentes, pedidos reutilizáveis, notas e anexos. As conversas continuam nas ferramentas oficiais.

Você pode escolher uma pasta pelo Finder ou digitar o caminho, criar um projeto, retomar uma conversa, consultar alterações Git ou iniciar um servidor local. O código pode ficar na raiz, em `CODIGO/` ou em uma subpasta de primeiro nível.

## Recursos

- Um menu para projetos Codex CLI e Claude Code, com a ferramenta escolhida registrada por projeto.
- Projetos em qualquer pasta escolhida por você, inclusive pastas já existentes.
- Instruções duradouras em `INSTRUCOES/PROJETO.md`, ligadas ao `AGENTS.md` ou `CLAUDE.md` do projeto.
- Pedidos reutilizáveis em `PROMPTS/`, enviados apenas quando você os escolhe.
- Continuação de conversas, resumo de encerramento e atalhos opcionais `encerrar` e `resumo`.
- Visualização do estado Git e descoberta de projetos de código em subpastas.
- Servidor local para pacotes Node.js encontrados no projeto.
- Verificação da organização do projeto e integração opcional com RTK.
- Compatibilidade com o Bash 3.2 incluído no macOS.
- Menu em português do Brasil ou inglês: detecta o idioma do macOS na primeira abertura e salva qualquer escolha manual.

## Comece em quatro passos

1. Baixe e descompacte o arquivo da versão publicada.
2. Mantenha a pasta `Assistente-IA-Mac-1.0` inteira, inclusive `lib/`.
3. Abra `ASSISTENTE-IA-MAC.command` no Terminal.
4. No menu **5**, crie um projeto ou abra uma pasta existente; escolha Codex CLI ou Claude Code.

Na primeira abertura, o programa usa inglês ou português do Brasil conforme o idioma do macOS. Para outros idiomas do sistema, usa português do Brasil. Você pode mudar em **Ajuda e ajustes (7) → Idioma / Language (8)**; a escolha fica salva e tem prioridade sobre o idioma do sistema. Projetos novos organizados recebem modelos de arquivos no idioma selecionado; os arquivos de projetos existentes são preservados.

Se o macOS não abrir o arquivo com dois cliques, use:

```bash
cd /caminho/para/Assistente-IA-Mac-1.0
/bin/bash ASSISTENTE-IA-MAC.command
```

Para verificar o kit sem abrir o menu:

```bash
/bin/bash ASSISTENTE-IA-MAC.command --check
```

Instale e autentique a CLI de Codex ou Claude Code separadamente. O kit não fornece um modelo de IA próprio.

## Organização de um projeto

```text
meu-projeto/
├── AGENTS.md                    # Entrada dos projetos Codex
├── CLAUDE.md                    # Entrada dos projetos Claude Code
├── INSTRUCOES/PROJETO.md       # Instruções permanentes
├── PROMPTS/                     # Pedidos prontos
├── DOCS/                        # Notas e andamento
├── ANEXOS/                      # Material de apoio
├── CODIGO/                      # Código opcional em subpastas
├── .agents/skills/              # Skills opcionais do Codex
├── .claude/commands/            # Comandos opcionais do Claude Code
└── .assistente-ia/tool          # Ferramenta escolhida
```

Não é preciso mover um repositório existente para essa estrutura. Ao organizar um projeto, o kit preserva os arquivos existentes. Leia o [guia completo](GUIA-DE-USO.md) para ver os menus e os fluxos de trabalho.

## Segurança e privacidade

O kit organiza o trabalho, mas não é uma sandbox. Ele evita substituir arquivos gerenciados e pede confirmação para ações que instalam ou atualizam integrações. Não pede nem guarda senhas dos agentes. Comandos Git e npm são executados no projeto ou pacote selecionado; confira os scripts do projeto antes de usá-los. Leia as [notas de auditoria](AUDITORIA-2026-10-23.md) para conhecer os limites.

## Verificação

A versão 1.0 foi verificada no macOS com Bash 3.2.57: 332 testes Python, 154 verificações RTK, análise de sintaxe dos scripts e `--check`. Os testes de integração usam ferramentas simuladas e diretórios isolados; não substituem um teste com suas contas reais.

## Idioma

O programa detecta o idioma do macOS na primeira abertura (inglês ou português do Brasil; outros idiomas usam português do Brasil). A escolha salva em **Ajuda e ajustes → Idioma / Language** tem prioridade. Este README também está disponível em [inglês](README.md).

## Contribuir

Contribuições em português ou inglês são bem-vindas. Abra um pull request para revisão do mantenedor e consulte [CONTRIBUTING.md](CONTRIBUTING.md).

## Apoiar

Você pode doar diretamente ao mantenedor em [PixGG / Anglerson](https://pixgg.com/Anglerson). A doação é opcional e não altera os recursos disponíveis.

## Licença

Distribuído sob a [licença MIT](LICENSE).
