<div align="center">
  <img src="assets/assistente-ia-mac-banner.svg" alt="Assistente IA Mac — a project workspace for Codex CLI and Claude Code" width="100%">
  <br><br>
  <img src="https://img.shields.io/badge/macOS-supported-111827?style=flat-square&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Bash-3.2%2B-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash 3.2 or later">
  <img src="https://img.shields.io/badge/Codex%20CLI-supported-111827?style=flat-square" alt="Codex CLI supported">
  <img src="https://img.shields.io/badge/Claude%20Code-supported-D97757?style=flat-square" alt="Claude Code supported">
  <br><br>
  <strong>A focused macOS workspace for AI-assisted software development.</strong>
  <br>
  Organize projects, keep context close to the code, and move between Codex CLI and Claude Code from one menu.
  <br><br>
  <a href="#features">Features</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#project-layout">Project layout</a> ·
  <a href="#security-and-privacy">Security & privacy</a> ·
  <a href="#verification">Verification</a> ·
  <a href="https://pixgg.com/Anglerson">Support the maintainer</a>
</div>

---

**Languages:** English · [Português (Brasil)](README.pt-BR.md)

Maintained by [Anglersondev](https://github.com/Anglersondev). If this project helps you, you can [support its maintainer](https://pixgg.com/Anglerson).

## What it does

**Assistente IA Mac** is a menu-driven toolkit for people who build software with **Codex CLI** and **Claude Code**. It gives each project a clear home for its instructions, reusable prompts, notes, and attachments, while keeping the actual coding workflow in the official agent CLIs.

Choose a project in Finder or enter its path. Start a new conversation, resume an existing one, inspect Git changes, or launch a local development server. The project can live anywhere you choose, and its code can be at the project root or inside `CODIGO/` and a first-level subfolder.

The terminal interface supports Brazilian Portuguese and English. The repository documentation is available in both languages.

## At a glance

```text
Choose a project
      │
      ├── Codex CLI ─────── AGENTS.md ─────── .agents/skills/
      │
      └── Claude Code ───── CLAUDE.md ─────── .claude/commands/
                              │
                    INSTRUCOES/PROJETO.md
                    PROMPTS/ · DOCS/ · ANEXOS/
```

The toolkit organizes the workflow around each agent's native project entry file. Optional shortcuts reuse the prompts already stored in the project.

## Features

- **One menu for two coding agents.** Keep Codex CLI and Claude Code projects in a consistent workflow, with a tool profile stored per project.
- **Choose your own project location.** Open an existing directory or create a new project under a location you select in Finder or by path.
- **Project-specific context.** Keep durable instructions in `INSTRUCOES/PROJETO.md`; the project’s `AGENTS.md` or `CLAUDE.md` points the agent to them.
- **Reusable task prompts.** Save prompts in `PROMPTS/` and choose which one to send when a conversation starts.
- **Session continuity.** Continue a conversation, start a clean one, or use optional `wrap-up` and `summary` shortcuts to record progress and prepare a concise handoff.
- **Native agent skills and commands.** Generate optional Codex skills under `.agents/skills/` or Claude Code commands under `.claude/commands/` without replacing existing files.
- **Git visibility across nested code.** Review status at the project root or in repositories found in `CODIGO/`, its immediate subfolders, and direct project subfolders.
- **Local development server.** Find `package.json` at the root or in supported code subfolders. When several packages are available, select which one to run.
- **Project health checks.** Identify missing structure, unfinished instructions, oversized prompts, and other organization issues.
- **Optional RTK integration.** Manage the RTK command-line integration and view recorded savings. An optional daily release check only reports a newer version; installation always requires an explicit confirmation.
- **macOS-native compatibility.** The launcher is written for the Bash 3.2 included with macOS.

## Quick start

1. Download and unzip the release archive.
2. Keep the complete `Assistente-IA-Mac-1.0` folder together; the launcher needs the `lib/` directory beside it.
3. Open `ASSISTENTE-IA-MAC.command` in Terminal.
4. Choose **Projects** to create a project or open an existing folder, then select Codex CLI or Claude Code.

If macOS does not open the command file with a double-click, run it from Terminal:

```bash
cd /path/to/Assistente-IA-Mac-1.0
/bin/bash ASSISTENTE-IA-MAC.command
```

To check the extracted kit without opening the interactive menu:

```bash
/bin/bash ASSISTENTE-IA-MAC.command --check
```

The appropriate agent CLI must be installed and authenticated separately. The toolkit does not replace either CLI or provide an AI model of its own.

## A typical workflow

1. **Select a project.** Open an existing project folder or create one in a location you choose.
2. **Choose the agent.** The project profile determines whether Codex CLI or Claude Code is used.
3. **Add project context.** Write durable project rules in `INSTRUCOES/PROJETO.md`; keep task-specific requests in `PROMPTS/`.
4. **Work from the menu.** Start or resume a conversation, review Git status, or start a development server.
5. **Carry context forward.** Optionally create the session shortcuts from **Project Care → Instructions → 4**. In a new agent session, use `/encerrar` or `/resumo` in Claude Code, or invoke the corresponding Codex skill.

On first launch, the menu follows the macOS system language when it is English or Brazilian Portuguese; other system languages use Brazilian Portuguese. To change it, open **Help and settings (7) → Language (8)**. The choice is saved for future launches and takes priority over the system language. The complete Portuguese user guide is [GUIA-DE-USO.md](GUIA-DE-USO.md) in the release package.

## Project layout

An organized project follows this structure. The code can stay in the root or live under `CODIGO/`.

```text
my-project/
├── AGENTS.md                    # Codex project entry (Codex projects)
├── CLAUDE.md                    # Claude Code project entry (Claude projects)
├── INSTRUCOES/
│   └── PROJETO.md               # Durable project instructions
├── PROMPTS/                     # Reusable, user-selected task prompts
├── DOCS/
│   └── ANDAMENTO.md             # Optional progress notes
├── ANEXOS/                      # Reference material
├── CODIGO/                      # Optional code and package repositories
│   └── my-app/
│       └── package.json
├── .agents/skills/              # Optional Codex skills
├── .claude/commands/            # Optional Claude Code commands
└── .assistente-ia/tool          # Project's selected agent
```

The toolkit never needs you to move an existing repository into this layout. When organizing an existing project, it preserves project files and stores the selected tool profile. A real `.claude/` directory is supported for Claude projects and is preserved during organization.

## Optional session shortcuts

The shortcuts reuse the default prompts in `PROMPTS/`:

| Agent | Shortcut | What it does |
|---|---|---|
| Claude Code | `/wrap-up` | Summarizes completed work and updates `DOCS/ANDAMENTO.md` |
| Claude Code | `/summary` | Produces a short context handoff for a new conversation |
| Codex | `$wrap-up` | Uses the same session wrap-up prompt |
| Codex | `$summary` | Uses the same quick-summary prompt |

These names are created when English is selected. In Portuguese, the names are `/encerrar`, `/resumo`, `$encerrar`, and `$resumo`. They are opt-in and project-local. Existing command or skill files are preserved.

Terminal options also have English names: `--diagnostics`, `--rtk gain`, `--rtk history`, `--rtk verify`, `--rtk update`, and `--rtk enable|disable codex|claude`. Existing Portuguese options remain available.

## Security and privacy

Assistente IA Mac is a project workflow tool, not a filesystem sandbox. Its safeguards are designed to reduce accidental changes:

- Managed project paths reject symbolic links, and generated shortcut files are published without overwriting an existing file.
- Project selection and actions that install or update integrations are explicit. RTK updates require typing `ATUALIZAR`.
- The optional RTK release check requests the public latest-release endpoint at most once per day when RTK is installed and the preference is enabled. It checks version metadata and does not install anything automatically.
- The toolkit does not ask for or store agent passwords. Authentication is handled by the official Codex CLI and Claude Code.
- Git and npm commands run against the selected project or selected package. Review a project's scripts before running them, as you would with any `npm run` command.

Your agents' own permissions, sandbox settings, and access controls continue to apply. Read the full [privacy and behavior notes](AUDITORIA-2026-10-23.md) before relying on the toolkit in a sensitive environment.

## Verification

The 1.0 release was verified on macOS with the system Bash **3.2.57**:

- **334 Python tests passed.**
- **156 RTK shell checks passed; 0 failed.**
- All 8 `.sh` and `.command` scripts passed `/bin/bash -n`.
- `ASSISTENTE-IA-MAC.command --check` passed.
- Codex skill manifests were validated; Git discovery was also checked against a real temporary repository.

Most integration tests use isolated directories and simulated Codex, Claude, Git, npm, and RTK commands. They do not constitute an authenticated end-to-end test of every external CLI or a real project server.

## Requirements

- macOS
- The system `/bin/bash` (Bash 3.2 compatible)
- Codex CLI and/or Claude Code, installed separately
- Optional: Git, Node.js/npm, Homebrew, and RTK, depending on the features you use

## Release contents

```text
Assistente-IA-Mac-1.0/
├── ASSISTENTE-IA-MAC.command
├── lib/
├── GUIA-DE-USO.md
├── LEIA-PRIMEIRO.txt
├── RTK.md
├── MUDANCAS-E-TESTES.md
└── tests/
```

Keep the launcher and `lib/` together when extracting or copying the toolkit.

## Language

The application detects the macOS language on first launch (English or Brazilian Portuguese; otherwise Brazilian Portuguese). A saved choice in **Help and settings → Language** takes priority. New organized projects use the selected language for their built-in templates; existing project files are preserved. Read this README in [Brazilian Portuguese](README.pt-BR.md); the full Portuguese guide is [GUIA-DE-USO.md](GUIA-DE-USO.md).

## Support

Donations go to the project maintainer through [PixGG / Anglerson](https://pixgg.com/Anglerson). They are optional; all features remain available without a donation.

## Contributing

Contributions are welcome. Fork the repository, create a branch, and open a pull request. Every change is reviewed and merged by the maintainer; nothing reaches `main` without approval. See [CONTRIBUTING.md](CONTRIBUTING.md) for the checks to run before submitting.

## License

Released under the [MIT License](LICENSE).
