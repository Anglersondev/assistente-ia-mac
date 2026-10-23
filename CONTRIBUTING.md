# Contributing

Thanks for helping improve **Assistente IA Mac**. Issues and pull requests can be written in Portuguese or English.

## How contributions work

1. Fork the repository and create a branch from `main`.
2. Make a focused change. Keep the launcher compatible with the macOS system Bash **3.2**.
3. Run the checks below and paste the summary in the pull request.
4. Open a pull request. The maintainer reviews every pull request; only approved changes are merged into `main`.

## Checks before submitting

```bash
/bin/bash ASSISTENTE-IA-MAC.command --check
python3 -I -m unittest discover -s tests -p 'test_*.py'
/bin/bash tests/test_rtk.sh
```

All three must pass. Add or update tests for any behavior you change.

## Ground rules

- No `eval`, and never `source` user data or preferences.
- Never read, print, or store credentials, tokens, or `.env` files.
- Changes to the user's files must ask first and must not overwrite existing content.
- Anything that uses the network or changes global agent settings must be explicit and documented in the transparency screen (`menu 7 → 4 → 6`).

## Reporting security issues

Please do not open a public issue for security problems. Use GitHub's **Report a vulnerability** button on the repository's Security tab.
