#!/usr/bin/env python3
"""Regressões 1.0: Claude real, atalhos opcionais e código em subpastas.

Somente pastas temporárias e CLIs simulados; não executa npm nem altera Git real.
"""
import json
import sys
import unittest

import test_assistente as base


class ImprovementsTests(base.AssistantTests):
    def fresh_project(self, name="Projeto com espaços ação"):
        project = self.parent / name
        project.mkdir()
        return project

    def snapshot(self, project):
        return {str(p.relative_to(project)): ("link", str(p.readlink())) if p.is_symlink()
                else ("dir",) if p.is_dir() else ("file", p.read_bytes())
                for p in project.rglob("*")}

    def fake_code_tools(self):
        script = "#!" + sys.executable + "\n" + r'''
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
cwd = pathlib.Path(os.getcwd())
if name == "git" and args[:1] == ["-C"]:
    cwd = pathlib.Path(args[1])
    args = args[2:]
with open(os.environ["TEST_CLI_LOG"], "a") as log:
    log.write(json.dumps({"name": name, "args": args, "cwd": str(cwd)}) + "\n")
if name == "git" and args[:1] == ["rev-parse"]:
    sys.exit(0 if (cwd / ".git").exists() else 1)
if name == "git":
    print("## main")
    print(" M arquivo com espaços.txt")
sys.exit(int(os.environ.get("TEST_CODE_STATUS", "0")))
'''
        for name in ("git", "npm"):
            path = self.bin / name
            path.write_text(script)
            path.chmod(0o755)
        # O teste deve ser independente de Xcode instalado na máquina hospedeira.
        path = self.bin / "xcode-select"
        path.write_text("#!/bin/sh\nexit 0\n")
        path.chmod(0o755)

    def repo(self, project, relative):
        path = project / relative
        path.mkdir(parents=True, exist_ok=True)
        (path / ".git").mkdir()
        return path

    def package(self, project, relative):
        path = project / relative
        path.mkdir(parents=True, exist_ok=True)
        (path / "package.json").write_text(json.dumps({"scripts": {"dev": "fake"}}))
        return path

    def status_calls(self):
        return [call for call in self.calls() if call["name"] == "git"
                and call["args"] == ["status", "--short", "--branch"]]

    def npm_calls(self):
        return [call for call in self.calls() if call["name"] == "npm"]

    def test_m01_claude_real_directory_is_preserved_while_organizing(self):
        project = self.fresh_project()
        (project / "CLAUDE.md").write_text("# Regras minhas\n")
        (project / ".claude/skills/minha-skill").mkdir(parents=True)
        (project / ".claude/settings.local.json").write_text('{"custom": true}\n')
        (project / ".claude/skills/minha-skill/SKILL.md").write_text("# Minha skill\n")
        before = self.snapshot(project / ".claude")
        result = self.project_shell(project, "TOOL=claude; organize_project_files")
        self.assert_ok(result)
        self.assertEqual(self.snapshot(project / ".claude"), before)
        self.assertEqual((project / ".assistente-ia/tool").read_text().strip(), "claude")
        self.assertIn("# Regras minhas", (project / "CLAUDE.md").read_text())

    def test_m02_profile_recognizes_claude_with_real_config_directory(self):
        project = self.fresh_project()
        (project / "CLAUDE.md").write_text("# Claude\n")
        (project / ".claude").mkdir()
        result = self.project_shell(project, "project_profile")
        self.assert_ok(result)
        self.assertEqual(result.stdout.strip(), "claude")

    def test_m03_codex_still_blocks_real_claude_directory_without_writes(self):
        project = self.fresh_project()
        (project / ".claude").mkdir()
        before = self.snapshot(project)
        result = self.project_shell(project, "TOOL=codex; organize_project_files")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Projeto tem .claude", result.stderr)
        self.assertEqual(self.snapshot(project), before)

    def test_m04_both_tools_block_invalid_claude_paths_without_writes(self):
        outside = self.parent / "Fora"
        outside.mkdir()
        for tool in ("claude", "codex"):
            for kind in ("file", "symlink", "broken"):
                with self.subTest(tool=tool, kind=kind):
                    project = self.fresh_project(tool + kind)
                    target = project / ".claude"
                    if kind == "file":
                        target.write_text("preservar")
                    else:
                        target.symlink_to(outside if kind == "symlink" else outside / "ausente")
                    before = self.snapshot(project)
                    result = self.project_shell(project, f"TOOL={tool}; organize_project_files")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(self.snapshot(project), before)
        self.assertEqual(list(outside.iterdir()), [])

    def test_m05_clean_preparation_does_not_create_optional_commands(self):
        for tool in ("claude", "codex"):
            project = self.managed_project(tool)
            self.assertFalse((project / ".claude").exists())
            self.assertFalse((project / ".agents").exists())

    def test_m06_claude_commands_reference_prompts_and_preserve_existing(self):
        project = self.managed_project("claude")
        commands = project / ".claude/commands"
        commands.mkdir(parents=True)
        (commands / "encerrar.md").write_text("meu comando\n")
        result = self.project_shell(project, "TOOL=claude; create_claude_commands")
        self.assert_ok(result)
        self.assertEqual((commands / "encerrar.md").read_text(), "meu comando\n")
        self.assertIn("@PROMPTS/RESUMO-RAPIDO.md", (commands / "resumo.md").read_text())
        before = self.snapshot(project)
        self.assert_ok(self.project_shell(project, "TOOL=claude; create_claude_commands"))
        self.assertEqual(self.snapshot(project), before)

    def test_m07_claude_commands_create_both_imports(self):
        project = self.managed_project("claude")
        self.assert_ok(self.project_shell(project, "TOOL=claude; create_claude_commands"))
        for name, prompt in (("encerrar", "ENCERRAR-SESSAO"), ("resumo", "RESUMO-RAPIDO")):
            self.assertIn(f"@PROMPTS/{prompt}.md", (project / f".claude/commands/{name}.md").read_text())

    def test_english_shortcuts_use_english_names_and_instructions(self):
        self.env["ASSISTENTE_LANG"] = "en"
        for tool in ("claude", "codex"):
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                self.assert_ok(self.project_shell(project, f"TOOL={tool}; create_project_shortcuts"))
                if tool == "claude":
                    self.assertIn("@PROMPTS/ENCERRAR-SESSAO.md", (project / ".claude/commands/wrap-up.md").read_text())
                    self.assertTrue((project / ".claude/commands/summary.md").exists())
                else:
                    skill = (project / ".agents/skills/wrap-up/SKILL.md").read_text()
                    self.assertIn("name: wrap-up", skill)
                    self.assertIn("Use this skill only", skill)
                    self.assertTrue((project / ".agents/skills/summary/SKILL.md").exists())

    def test_m08_claude_commands_reject_symlinks_and_directories_before_any_write(self):
        outside = self.parent / "Comandos externos"
        outside.mkdir()
        (outside / "resumo.md").write_text("preservar")
        for i, relative in enumerate((".claude", ".claude/commands", ".claude/commands/resumo.md")):
            with self.subTest(relative=relative):
                project = self.fresh_project("Symlink comandos " + str(i))
                self.assert_ok(self.project_shell(project, "TOOL=claude; prepare_project_files"))
                path = project / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.symlink_to(outside if relative != ".claude/commands/resumo.md" else outside / "resumo.md")
                before = self.snapshot(project)
                result = self.project_shell(project, "TOOL=claude; create_claude_commands")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.snapshot(project), before)
        self.assertEqual((outside / "resumo.md").read_text(), "preservar")
        project = self.managed_project("claude")
        (project / ".claude/commands/resumo.md").mkdir(parents=True)
        before = self.snapshot(project)
        result = self.project_shell(project, "TOOL=claude; create_claude_commands")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot(project), before)

    def test_m09_claude_commands_reject_codex_profile_and_wrong_tool(self):
        for tool, profile in (("claude", "codex"), ("codex", "claude")):
            project = self.managed_project(profile)
            before = self.snapshot(project)
            result = self.project_shell(project, f"TOOL={tool}; create_claude_commands")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.snapshot(project), before)

    def test_m10_git_root_takes_precedence(self):
        self.fake_code_tools()
        project = self.fresh_project()
        self.repo(project, ".")
        self.repo(project, "CODIGO/segundo")
        result = self.project_shell(project, "git_changes")
        self.assert_ok(result)
        self.assertEqual([c["cwd"] for c in self.status_calls()], [str(project)])
        self.assertIn("## main", result.stdout)

    def test_m11_git_finds_codigo_and_direct_sibling_repos_with_spaces(self):
        self.fake_code_tools()
        project = self.fresh_project()
        repos = [self.repo(project, "CODIGO/Meu app ação"), self.repo(project, "Site direto")]
        result = self.project_shell(project, "git_changes")
        self.assert_ok(result)
        self.assertEqual(set(c["cwd"] for c in self.status_calls()), set(map(str, repos)))
        for repo in repos:
            self.assertIn(str(repo.relative_to(project)), result.stdout)

    def test_m12_git_ignores_hidden_symlinked_and_deep_repositories(self):
        self.fake_code_tools()
        project = self.fresh_project()
        self.repo(project, ".oculto")
        self.repo(project, "CODIGO/.oculto")
        self.repo(project, "direto/fundo")
        outside = self.repo(self.parent, "repo externo")
        (project / "atalho").symlink_to(outside)
        (project / "CODIGO/atalho").symlink_to(outside)
        directory = project / "git-link"
        directory.mkdir()
        (directory / ".git").symlink_to(outside / ".git")
        result = self.project_shell(project, "git_changes")
        self.assert_ok(result)
        self.assertEqual(self.status_calls(), [])
        self.assertIn("Esta pasta não usa Git", result.stdout)

    def test_m13_git_ignores_symlinked_codigo_container(self):
        self.fake_code_tools()
        project = self.fresh_project()
        outside = self.parent / "externo"
        self.repo(outside, "app")
        (project / "CODIGO").symlink_to(outside)
        self.assert_ok(self.project_shell(project, "git_changes"))
        self.assertEqual(self.status_calls(), [])

    def test_m14_server_root_takes_precedence(self):
        self.fake_code_tools()
        project = self.fresh_project()
        self.package(project, ".")
        self.package(project, "CODIGO/segundo")
        result = self.project_shell(project, "start_dev_server", "\n")
        self.assert_ok(result)
        self.assertEqual(self.npm_calls(), [{"name": "npm", "args": ["run", "dev"], "cwd": str(project)}])

    def test_m15_server_finds_single_codigo_package_and_confirms(self):
        self.fake_code_tools()
        project = self.fresh_project()
        app = self.package(project, "CODIGO/Meu app ação")
        result = self.project_shell(project, "start_dev_server", "\n")
        self.assert_ok(result)
        self.assertEqual([c["cwd"] for c in self.npm_calls()], [str(app)])
        self.assertIn("CODIGO/Meu app ação", result.stdout)
        self.assertIn("Enter para executar; 0 para cancelar", result.stderr)

    def test_m16_server_finds_single_direct_package(self):
        self.fake_code_tools()
        project = self.fresh_project()
        app = self.package(project, "Meu app direto")
        self.assert_ok(self.project_shell(project, "start_dev_server", "\n"))
        self.assertEqual([c["cwd"] for c in self.npm_calls()], [str(app)])

    def test_m17_server_multiple_packages_selects_displayed_option(self):
        self.fake_code_tools()
        project = self.fresh_project()
        self.package(project, "CODIGO/App um")
        self.package(project, "App dois")
        result = self.project_shell(project, "start_dev_server", "2\n\n")
        self.assert_ok(result)
        option = next(line.strip()[3:] for line in result.stdout.splitlines() if line.strip().startswith("2) "))
        self.assertEqual([c["cwd"] for c in self.npm_calls()], [str(project / option)])
        self.assertIn("1) ", result.stdout)

    def test_m18_server_cancel_and_eof_never_execute(self):
        self.fake_code_tools()
        for i, (multiple, inputs) in enumerate(((False, "0\n"), (False, ""),
                                               (True, "0\n"), (True, ""), (True, "1\n0\n"))):
            with self.subTest(multiple=multiple, inputs=inputs):
                project = self.fresh_project("Cancelar " + str(i))
                self.package(project, "CODIGO/app")
                if multiple:
                    self.package(project, "outro")
                result = self.project_shell(project, "start_dev_server", inputs)
                self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.npm_calls(), [])

    def test_m19_server_rejects_invalid_selection_without_execution(self):
        self.fake_code_tools()
        project = self.fresh_project()
        self.package(project, "CODIGO/app")
        self.package(project, "outro")
        result = self.project_shell(project, "start_dev_server", "99\n$(touch INJETADO)\n0\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.npm_calls(), [])
        self.assertFalse((self.root / "INJETADO").exists())

    def test_m20_server_ignores_hidden_node_modules_symlinks_and_deep_packages(self):
        self.fake_code_tools()
        project = self.fresh_project()
        for relative in (".oculto", "CODIGO/.oculto", "node_modules", "CODIGO/node_modules", "outro/fundo"):
            self.package(project, relative)
        outside = self.package(self.parent, "pacote externo")
        (project / "atalho").symlink_to(outside)
        (project / "CODIGO/atalho").symlink_to(outside)
        linked = project / "package-link"
        linked.mkdir()
        (linked / "package.json").symlink_to(outside / "package.json")
        result = self.project_shell(project, "start_dev_server", "\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.npm_calls(), [])
        self.assertIn("Não existe package.json", result.stderr)

    def test_m21_server_propagates_npm_failure(self):
        self.fake_code_tools()
        project = self.fresh_project()
        self.package(project, "CODIGO/app")
        self.env["TEST_CODE_STATUS"] = "7"
        result = self.project_shell(project, "start_dev_server", "\n")
        self.assertEqual(result.returncode, 7)

    def test_m22_codex_shortcuts_have_skill_metadata_and_preserve_custom_skill(self):
        project = self.managed_project("codex")
        custom = project / ".agents/skills/encerrar/SKILL.md"
        custom.parent.mkdir(parents=True)
        custom.write_text("---\nname: encerrar\ndescription: Meu encerramento\n---\nOriginal\n")
        before = custom.read_bytes()
        self.assert_ok(self.project_shell(project, "TOOL=codex; create_project_shortcuts"))
        self.assertEqual(custom.read_bytes(), before)
        summary = (project / ".agents/skills/resumo/SKILL.md").read_text()
        self.assertTrue(summary.startswith("---\nname: resumo\n"))
        self.assertIn("description:", summary)
        self.assertIn("PROMPTS/RESUMO-RAPIDO.md", summary)
        snapshot = self.snapshot(project)
        self.assert_ok(self.project_shell(project, "TOOL=codex; create_project_shortcuts"))
        self.assertEqual(self.snapshot(project), snapshot)

    def test_m23_codex_shortcuts_reject_symlinked_components_without_mutation(self):
        outside = self.parent / "Skills externas"
        outside.mkdir()
        for i, relative in enumerate((".agents", ".agents/skills", ".agents/skills/resumo", ".agents/skills/resumo/SKILL.md")):
            with self.subTest(relative=relative):
                project = self.fresh_project("Codex link " + str(i))
                self.assert_ok(self.project_shell(project, "TOOL=codex; prepare_project_files"))
                path = project / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.symlink_to(outside)
                before = self.snapshot(project)
                result = self.project_shell(project, "TOOL=codex; create_project_shortcuts")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.snapshot(project), before)
        self.assertEqual(list(outside.iterdir()), [])

    def test_m24_shortcuts_work_with_noclobber_and_leave_no_temporary_files(self):
        for tool in ("claude", "codex"):
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                result = self.project_shell(project, f"TOOL={tool}; set -o noclobber; create_project_shortcuts")
                self.assert_ok(result)
                self.assertFalse(any(p.name.startswith(".assistente-comando.") for p in project.rglob("*")))
                before = self.snapshot(project)
                self.assert_ok(self.project_shell(project, f"TOOL={tool}; set -o noclobber; create_project_shortcuts"))
                self.assertEqual(self.snapshot(project), before)

    def test_m25_atomic_writer_does_not_publish_incomplete_content(self):
        project = self.managed_project("claude")
        (project / ".claude/commands").mkdir(parents=True)
        # Simula erro de leitura/gravação durante a cópia do conteúdo temporário.
        result = self.project_shell(project, "cat() { printf 'parcial'; return 9; }; printf 'completo' | write_new_file_atomic .claude/commands/encerrar.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((project / ".claude/commands/encerrar.md").exists())
        self.assertEqual(list((project / ".claude/commands").iterdir()), [])

    def test_m26_atomic_writer_preserves_destination_created_during_publication(self):
        project = self.managed_project("claude")
        (project / ".claude/commands").mkdir(parents=True)
        # Simula outro processo que publica seu arquivo antes do hard link final.
        result = self.project_shell(project, r'''ln() { printf 'concorrente\n' > "${!#}"; command ln "$@"; }; printf 'nosso\n' | write_new_file_atomic .claude/commands/encerrar.md''')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((project / ".claude/commands/encerrar.md").read_text(), "concorrente\n")
        self.assertEqual([p.name for p in (project / ".claude/commands").iterdir()], ["encerrar.md"])

    def test_m27_shortcuts_reject_missing_or_symlinked_prompt_before_mutation(self):
        for tool in ("claude", "codex"):
            project = self.managed_project(tool)
            path = project / "PROMPTS/RESUMO-RAPIDO.md"
            path.unlink()
            before = self.snapshot(project)
            result = self.project_shell(project, f"TOOL={tool}; create_project_shortcuts")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.snapshot(project), before)
            path.symlink_to(project / "PROMPTS/ENCERRAR-SESSAO.md")
            before = self.snapshot(project)
            result = self.project_shell(project, f"TOOL={tool}; create_project_shortcuts")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.snapshot(project), before)

    def test_m28_existing_claude_skill_name_is_preserved_without_command_collision(self):
        project = self.managed_project("claude")
        skill = project / ".claude/skills/encerrar/SKILL.md"
        skill.parent.mkdir(parents=True)
        skill.write_text("Minha skill\n")
        self.assert_ok(self.project_shell(project, "TOOL=claude; create_project_shortcuts"))
        self.assertEqual(skill.read_text(), "Minha skill\n")
        self.assertFalse((project / ".claude/commands/encerrar.md").exists())
        self.assertTrue((project / ".claude/commands/resumo.md").is_file())

    def test_m29_git_supports_worktree_marker_file(self):
        self.fake_code_tools()
        project = self.fresh_project()
        worktree = project / "CODIGO/worktree"
        worktree.mkdir(parents=True)
        (worktree / ".git").write_text("gitdir: /caminho/simulado\n")
        self.assert_ok(self.project_shell(project, "git_changes"))
        self.assertEqual([c["cwd"] for c in self.status_calls()], [str(worktree)])

    def test_m30_server_ignores_symlinked_codigo_container(self):
        self.fake_code_tools()
        project = self.fresh_project()
        outside = self.parent / "codigo externo"
        self.package(outside, "app")
        (project / "CODIGO").symlink_to(outside)
        result = self.project_shell(project, "start_dev_server", "\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.npm_calls(), [])

    def test_m31_server_rejects_root_package_symlink(self):
        self.fake_code_tools()
        project = self.fresh_project()
        outside = self.package(self.parent, "externo package")
        (project / "package.json").symlink_to(outside / "package.json")
        result = self.project_shell(project, "start_dev_server", "\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.npm_calls(), [])

    def test_m32_atomic_writer_rejects_concurrent_directory_symlink(self):
        project = self.managed_project("claude")
        (project / ".claude/commands").mkdir(parents=True)
        outside = self.parent / "alvo externo"
        outside.mkdir()
        self.env["TEST_OUTSIDE"] = str(outside)
        result = self.project_shell(project, r'''ln() { command ln -s "$TEST_OUTSIDE" "${!#}"; command ln "$@"; }; printf 'nosso\n' | write_new_file_atomic .claude/commands/encerrar.md''')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertTrue((project / ".claude/commands/encerrar.md").is_symlink())
        self.assertEqual([p.name for p in (project / ".claude/commands").iterdir()], ["encerrar.md"])


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(ImprovementsTests, _name, None)

if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], *base.remaining], verbosity=2)
