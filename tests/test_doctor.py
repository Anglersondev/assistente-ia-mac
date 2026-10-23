#!/usr/bin/env python3
"""Verificação de estrutura do projeto (project_quick_warnings e project_doctor)."""
import unittest

import test_assistente as base


class DoctorTests(base.AssistantTests):
    def filled(self, project):
        (project / "INSTRUCOES/PROJETO.md").write_text("# Instruções\nObjetivo: site da clínica.\n")

    def big(self, project, name="Documento.md"):
        path = project / "PROMPTS" / name
        path.write_text("x" * 9000)
        return path

    def warnings(self, project):
        result = self.project_shell(project, "project_quick_warnings")
        self.assert_ok(result)
        return result.stdout

    def test_d01_template_warns_unfilled(self):
        project = self.managed_project("claude")
        out = self.warnings(project)
        self.assertIn("ainda é o modelo", out)
        self.assertNotIn("PROMPTS/", out)

    def test_d02_clean_project_has_no_warnings(self):
        project = self.managed_project("codex")
        self.filled(project)
        self.assertEqual(self.warnings(project).strip(), "")

    def test_d03_large_prompt_warns(self):
        project = self.managed_project("codex")
        self.filled(project)
        self.big(project)
        out = self.warnings(project)
        self.assertIn("1 arquivo(s) grande(s) em PROMPTS/", out)
        self.assertIn("6 → 12", out)

    def test_d04_missing_entry_marker_warns(self):
        project = self.managed_project("claude")
        self.filled(project)
        (project / "CLAUDE.md").write_text("# sem referência\n")
        self.assertIn("não aponta para as instruções", self.warnings(project))
        (project / "CLAUDE.md").unlink()
        self.assertIn("não aponta para as instruções", self.warnings(project))

    def test_d05_warnings_never_prompt_and_always_succeed(self):
        project = self.parent / "Vazio"
        project.mkdir()
        result = self.project_shell(project, "project_quick_warnings; echo rc=$?")
        self.assert_ok(result)
        self.assertIn("rc=0", result.stdout)

    def test_d06_size_note(self):
        project = self.managed_project("codex")
        big = self.big(project)
        small = project / "PROMPTS/COMECE-AQUI.md"
        result = self.project_shell(project, f"prompt_size_note {base.shlex.quote(str(big))}; echo '|'; prompt_size_note {base.shlex.quote(str(small))}; echo '|'")
        self.assert_ok(result)
        first, second, _ = result.stdout.split("|")
        self.assertIn("melhor em DOCS/", first)
        self.assertEqual(second.strip(), "")

    def test_d07_doctor_healthy(self):
        project = self.managed_project("claude")
        self.filled(project)
        result = self.project_shell(project, "project_doctor")
        self.assert_ok(result)
        self.assertIn("Tudo certo com a estrutura.", result.stdout)
        self.assertIn("✓ CLAUDE.md aponta para INSTRUCOES/PROJETO.md", result.stdout)
        self.assertIn("INSTRUCOES/PROJETO.md.", result.stdout)

    def test_d08_doctor_move_with_s(self):
        project = self.managed_project("claude")
        self.filled(project)
        big = self.big(project)
        result = self.project_shell(project, "project_doctor", "s\n")
        self.assert_ok(result)
        self.assertFalse(big.exists())
        self.assertEqual((project / "DOCS/Documento.md").stat().st_size, 9000)

    def test_d09_doctor_enter_keeps_file(self):
        project = self.managed_project("claude")
        big = self.big(project)
        result = self.project_shell(project, "project_doctor", "\n")
        self.assert_ok(result)
        self.assertTrue(big.exists())
        self.assertFalse((project / "DOCS/Documento.md").exists())
        self.assertIn("ainda é o modelo", result.stdout)

    def test_d10_doctor_existing_destination_not_overwritten(self):
        project = self.managed_project("claude")
        big = self.big(project)
        (project / "DOCS/Documento.md").write_text("original")
        result = self.project_shell(project, "project_doctor", "s\n")
        self.assert_ok(result)
        self.assertTrue(big.exists())
        self.assertEqual((project / "DOCS/Documento.md").read_text(), "original")
        self.assertIn("Já existe DOCS/Documento.md", result.stderr)

    def test_d11_doctor_refuses_symlinked_docs(self):
        project = self.managed_project("claude")
        big = self.big(project)
        outside = self.root / "fora"
        outside.mkdir()
        (project / "DOCS").rename(self.root / "docs-real")
        (project / "DOCS").symlink_to(outside)
        result = self.project_shell(project, "project_doctor", "s\n")
        self.assert_ok(result)
        self.assertTrue(big.exists())
        self.assertEqual(list(outside.iterdir()), [])
        self.assertIn("link simbólico", result.stderr)

    def test_d12_doctor_ignores_symlinked_prompt_file(self):
        project = self.managed_project("claude")
        target = self.root / "grande.md"
        target.write_text("y" * 9000)
        (project / "PROMPTS/link.md").symlink_to(target)
        result = self.project_shell(project, "project_doctor")
        self.assert_ok(result)
        self.assertNotIn("link.md", result.stdout)
        self.assertTrue(target.exists())

    def test_d13_doctor_flags_both_entries(self):
        project = self.managed_project("codex")
        (project / "CLAUDE.md").write_text("x\n")
        result = self.project_shell(project, "project_doctor")
        self.assert_ok(result)
        self.assertIn("6 → 11", result.stdout)

    def test_d14_objective_written_details_pending_is_not_a_problem(self):
        for tool in ("codex", "claude"):
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                self.assert_ok(self.project_shell(project, "fill_project_objective 'Site do hotel fazenda'"))
                quick = self.project_shell(project, "project_quick_warnings")
                self.assertIn("Faltam detalhes".lower(), quick.stdout.lower())
                self.assertNotIn("ainda é o modelo", quick.stdout)
                doctor = self.project_shell(project, "project_doctor", "n\nn\n")
                self.assert_ok(doctor)
                self.assertIn("Faltam detalhes em INSTRUCOES/PROJETO.md", doctor.stdout)
                self.assertIn("Não é obrigatório para começar", doctor.stdout)
                self.assertNotIn("ainda é o modelo", doctor.stdout)
                self.assertNotIn("  ! INSTRUCOES/PROJETO.md", doctor.stdout)

    def test_d15_objective_still_template_is_a_problem(self):
        for tool in ("codex", "claude"):
            with self.subTest(tool=tool):
                project = self.managed_project(tool)
                doctor = self.project_shell(project, "project_doctor", "n\nn\n\n")
                self.assertIn("  ! INSTRUCOES/PROJETO.md ainda é o modelo", doctor.stdout)
                self.assertNotIn("Tudo certo", doctor.stdout)

    def test_d16_custom_file_without_template_lines_has_no_warning(self):
        project = self.managed_project("claude")
        self.filled(project)
        quick = self.project_shell(project, "project_quick_warnings")
        self.assertNotIn("Faltam detalhes", quick.stdout)
        self.assertNotIn("ainda é o modelo", quick.stdout)


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(DoctorTests, _name, None)

if __name__ == "__main__":
    unittest.main()
