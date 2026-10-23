#!/usr/bin/env python3
"""Economia de tokens: seção Eficiência, prompts de encerramento, peso e ANDAMENTO."""
import unittest

import test_assistente as base

TOOLS = ("codex", "claude")


class EfficiencyTests(base.AssistantTests):
    def test_e01_template_has_efficiency_section_and_prompts(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                text = (project / "INSTRUCOES/PROJETO.md").read_text()
                self.assertIn("## Eficiência (economia de tokens)", text)
                self.assertIn("preencha o que deseja construir", text)
                self.assertLess(len(text.encode()), 2500)
                for name in ("ENCERRAR-SESSAO.md", "RESUMO-RAPIDO.md"):
                    self.assertTrue((project / "PROMPTS" / name).read_text().strip())
                self.assertIn("40 linhas", (project / "PROMPTS/ENCERRAR-SESSAO.md").read_text())
                self.assertIn("15 linhas", (project / "PROMPTS/RESUMO-RAPIDO.md").read_text())

    def test_e02_existing_prompts_are_not_overwritten(self):
        project = self.managed_project("codex")
        (project / "PROMPTS/ENCERRAR-SESSAO.md").write_text("meu texto\n")
        result = self.project_shell(project, "TOOL=codex; prepare_project_files")
        self.assert_ok(result)
        self.assertEqual((project / "PROMPTS/ENCERRAR-SESSAO.md").read_text(), "meu texto\n")

    def test_e03_legacy_migration_creates_new_prompts(self):
        for tool, native in (("codex", "AGENTS.md"), ("claude", "CLAUDE.md")):
            with self.subTest(tool=tool):
                project = self.parent / ("Antigo " + tool)
                (project / "PROMPTS").mkdir(parents=True)
                (project / native).write_text("# Regras\n")
                (project / "PROMPTS/Meu.md").write_text("pedido\n")
                result = self.project_shell(project, f"TOOL={tool}; organize_project_files")
                self.assert_ok(result)
                self.assertTrue((project / "PROMPTS/ENCERRAR-SESSAO.md").exists())
                self.assertTrue((project / "PROMPTS/RESUMO-RAPIDO.md").exists())
                self.assertEqual((project / "PROMPTS/Meu.md").read_text(), "pedido\n")

    def test_e04_doctor_shows_weight_estimate(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                result = self.project_shell(project, "project_doctor")
                self.assert_ok(result)
                self.assertIn("tokens por conversa", result.stdout)

    def test_e05_heavy_instructions_warn(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                (project / "INSTRUCOES/PROJETO.md").write_text("regra\n" * 3000)
                quick = self.project_shell(project, "project_quick_warnings")
                self.assertIn("instruções fixas pesadas", quick.stdout)
                doctor = self.project_shell(project, "project_doctor")
                self.assertIn("Instruções fixas pesadas", doctor.stdout)

    def test_e06_large_andamento_warns(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                (project / "DOCS/ANDAMENTO.md").write_text("x" * 9000)
                quick = self.project_shell(project, "project_quick_warnings")
                self.assertIn("ENCERRAR-SESSAO", quick.stdout)
                doctor = self.project_shell(project, "project_doctor")
                self.assertIn("está grande (mais de 8 KB)", doctor.stdout)

    def test_e07_quick_warnings_at_most_three_lines(self):
        project = self.managed_project("claude")
        (project / "INSTRUCOES/PROJETO.md").write_text("preencha\n" + "regra\n" * 3000)
        (project / "DOCS/ANDAMENTO.md").write_text("x" * 9000)
        (project / "PROMPTS/Doc.md").write_text("x" * 9000)
        (project / "CLAUDE.md").write_text("# sem referência\n")
        result = self.project_shell(project, "project_quick_warnings")
        self.assert_ok(result)
        self.assertLessEqual(len([l for l in result.stdout.splitlines() if l.startswith("Aviso")]), 3)

    def test_e08_append_section_with_backup(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                path = project / "INSTRUCOES/PROJETO.md"
                original = "# Instruções\nObjetivo: clínica.\n"
                path.write_text(original)
                result = self.project_shell(project, "project_doctor", "s\n\n")
                self.assert_ok(result)
                text = path.read_text()
                self.assertTrue(text.startswith(original))
                self.assertIn("## Eficiência (economia de tokens)", text)
                backups = list((project / "DOCS/BACKUPS-INSTRUCOES").iterdir())
                self.assertEqual(len(backups), 1)
                self.assertEqual(backups[0].read_text(), original)

    def test_e09_decline_keeps_file(self):
        project = self.managed_project("codex")
        path = project / "INSTRUCOES/PROJETO.md"
        path.write_text("# Instruções\nObjetivo: clínica.\n")
        result = self.project_shell(project, "project_doctor", "\n\n")
        self.assert_ok(result)
        self.assertEqual(path.read_text(), "# Instruções\nObjetivo: clínica.\n")

    def test_e10_create_missing_prompts_without_overwriting(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                (project / "PROMPTS/ENCERRAR-SESSAO.md").unlink()
                (project / "PROMPTS/RESUMO-RAPIDO.md").write_text("meu resumo\n")
                (project / "PROMPTS/RESUMO-RAPIDO.md").unlink()
                (project / "PROMPTS/RESUMO-RAPIDO.md").write_text("meu resumo\n")
                result = self.project_shell(project, "project_doctor", "s\n")
                self.assert_ok(result)
                self.assertTrue((project / "PROMPTS/ENCERRAR-SESSAO.md").read_text().strip())
                self.assertEqual((project / "PROMPTS/RESUMO-RAPIDO.md").read_text(), "meu resumo\n")

    def test_e11_eof_does_not_hang_or_change(self):
        project = self.managed_project("claude")
        path = project / "INSTRUCOES/PROJETO.md"
        path.write_text("# Instruções\nObjetivo: x.\n")
        (project / "PROMPTS/ENCERRAR-SESSAO.md").unlink()
        result = self.project_shell(project, "project_doctor", "")
        self.assert_ok(result)
        self.assertEqual(path.read_text(), "# Instruções\nObjetivo: x.\n")
        self.assertFalse((project / "PROMPTS/ENCERRAR-SESSAO.md").exists())

    def test_e12_symlinked_instructions_are_not_touched(self):
        project = self.managed_project("codex")
        real = self.root / "real.md"
        real.write_text("# externo\n")
        path = project / "INSTRUCOES/PROJETO.md"
        path.unlink()
        path.symlink_to(real)
        result = self.project_shell(project, "project_doctor", "s\ns\n")
        self.assertEqual(real.read_text(), "# externo\n")

    def test_e13_clean_new_project_has_no_efficiency_warnings(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                result = self.project_shell(project, "project_quick_warnings")
                self.assert_ok(result)
                self.assertNotIn("pesadas", result.stdout)
                self.assertNotIn("ANDAMENTO", result.stdout)


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(EfficiencyTests, _name, None)

if __name__ == "__main__":
    unittest.main()
