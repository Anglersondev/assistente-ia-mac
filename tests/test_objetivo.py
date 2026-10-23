#!/usr/bin/env python3
"""Objetivo em uma frase: criação e verificador, para Codex e Claude."""
import unittest

import test_assistente as base

FRASE = "Site de reservas do hotel fazenda, com foco em atrair famílias."


class ObjectiveTests(base.AssistantTests):
    def test_o01_doctor_fills_objective_codex_and_claude(self):
        for tool in ("codex", "claude"):
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                (project / "README.md").write_text("# X\n\n## Objetivo\n\nDescreva a finalidade do projeto.\n")
                result = self.project_shell(project, "project_doctor", FRASE + "\n")
                self.assert_ok(result)
                instrucoes = (project / "INSTRUCOES/PROJETO.md").read_text()
                self.assertIn("- Objetivo: " + FRASE, instrucoes)
                self.assertNotIn("preencha o que deseja construir", instrucoes)
                self.assertIn(FRASE, (project / "README.md").read_text())
                # Arquivo ainda igual ao modelo: nada do usuário a proteger, sem backup.
                self.assertFalse((project / "DOCS/BACKUPS-INSTRUCOES").exists())
                self.assertNotIn("Backup do PROJETO.md", result.stdout)

    def test_o02_enter_skips_without_changes(self):
        project = self.managed_project("codex")
        before = (project / "INSTRUCOES/PROJETO.md").read_text()
        result = self.project_shell(project, "project_doctor", "\n")
        self.assert_ok(result)
        self.assertEqual((project / "INSTRUCOES/PROJETO.md").read_text(), before)

    def test_o03_never_overwrites_written_objective(self):
        project = self.managed_project("claude")
        path = project / "INSTRUCOES/PROJETO.md"
        path.write_text(path.read_text().replace(
            "- Objetivo: preencha o que deseja construir e para quem.", "- Objetivo: meu texto."))
        result = self.project_shell(project, "fill_project_objective 'outro texto'")
        self.assert_ok(result)
        self.assertIn("- Objetivo: meu texto.", path.read_text())
        self.assertNotIn("outro texto", path.read_text())

    def test_o04_create_project_asks_objective(self):
        for tool, choice, group in (("codex", "1", "CODEX"), ("claude", "2", "CLAUDE")):
            with self.subTest(tool=tool):
                result = self.run_shell("create_project", f"2\n{self.parent}\nProj {tool}\n{choice}\n2\n\n{FRASE}\n")
                self.assert_ok(result)
                project = self.parent / group / f"Proj {tool}"
                self.assertIn("- Objetivo: " + FRASE, (project / "INSTRUCOES/PROJETO.md").read_text())
                self.assertIn(FRASE, (project / "README.md").read_text())

    def test_o05_create_project_without_answer_still_works(self):
        result = self.run_shell("create_project", f"2\n{self.parent}\nSem objetivo\n1\n2\n\n\n")
        self.assert_ok(result)
        self.assertTrue((self.parent / "CODEX/Sem objetivo/INSTRUCOES/PROJETO.md").exists())

    def test_o06_rejects_multiline_and_long(self):
        project = self.managed_project("codex")
        result = self.project_shell(project, "ask_project_objective", "x" * 301 + "\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("preencha o que deseja construir", (project / "INSTRUCOES/PROJETO.md").read_text())

    def test_o07_blank_objective_is_ignored(self):
        project = self.managed_project("claude")
        result = self.project_shell(project, "ask_project_objective", "     \n")
        self.assert_ok(result)
        self.assertIn("preencha o que deseja construir", (project / "INSTRUCOES/PROJETO.md").read_text())

    def test_o08_message_names_only_changed_file(self):
        project = self.managed_project("codex")
        result = self.project_shell(project, "fill_project_objective 'Meu hotel'")
        self.assert_ok(result)
        self.assertIn("Objetivo registrado em INSTRUCOES/PROJETO.md.", result.stdout)
        self.assertNotIn("README.md", result.stdout)

    def test_o09_special_characters_are_literal_and_mode_is_kept(self):
        project = self.managed_project("claude")
        path = project / "INSTRUCOES/PROJETO.md"
        path.chmod(0o644)
        texto = "A & B \\1 $HOME `id` \"q\" #h %s"
        result = self.project_shell(project, f"fill_project_objective {base.shlex.quote(texto)}")
        self.assert_ok(result)
        self.assertIn("- Objetivo: " + texto, path.read_text())
        self.assertEqual(path.stat().st_mode & 0o777, 0o644)

    def test_o10_edited_file_gets_backup_and_message(self):
        for tool in ("codex", "claude"):
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                path = project / "INSTRUCOES/PROJETO.md"
                path.write_text(path.read_text() + "\n- Regra minha: sempre responder curto.\n")
                result = self.project_shell(project, "fill_project_objective 'Meu hotel'")
                self.assert_ok(result)
                self.assertIn("Backup do PROJETO.md", result.stdout)
                self.assertEqual(len(list((project / "DOCS/BACKUPS-INSTRUCOES").iterdir())), 1)
                self.assertIn("- Regra minha: sempre responder curto.", path.read_text())

    def test_o11_new_wording_after_filling(self):
        project = self.managed_project("claude")
        result = self.project_shell(project, "fill_project_objective 'Meu hotel'")
        self.assert_ok(result)
        self.assertIn("Cuidar do projeto → 9", result.stdout)
        self.assertIn("comece uma conversa nova", result.stdout)
        self.assertNotIn("para valer", result.stdout)

    def test_o12_question_points_to_real_places(self):
        project = self.managed_project("codex")
        result = self.project_shell(project, "ask_project_objective", "\n")
        self.assert_ok(result)
        self.assertIn("Cuidar do projeto → 9", result.stdout)
        self.assertNotIn("→ 12", result.stdout)


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(ObjectiveTests, _name, None)

if __name__ == "__main__":
    unittest.main()
