#!/usr/bin/env python3
"""Continuar conversa com um toque, configurações salvas e RTK ao abrir."""
import unittest

import test_assistente as base


class ContinueTests(base.AssistantTests):
    def args(self, call):
        return call["args"]

    def test_c01_quick_resume_codex_uses_resume_last(self):
        project = self.managed_project("codex")
        result = self.project_shell(project, "quick_resume", "\n")
        self.assert_ok(result)
        calls = self.session_calls()
        self.assertEqual(len(calls), 1, self.calls())
        self.assertEqual(calls[0]["args"][:2], ["resume", "--last"])
        self.assertEqual(calls[0]["cwd"], str(project))
        self.assertNotIn("unbound variable", result.stderr)

    def test_c02_quick_resume_claude_uses_continue(self):
        project = self.managed_project("claude")
        result = self.project_shell(project, "quick_resume", "\n")
        self.assert_ok(result)
        calls = self.session_calls()
        self.assertEqual(len(calls), 1, self.calls())
        self.assertIn("--continue", calls[0]["args"])

    def test_c03_cancel_does_not_start_agent(self):
        project = self.managed_project("codex")
        result = self.project_shell(project, "quick_resume", "0\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.session_calls(), [])

    def test_c04_failed_resume_offers_new_conversation(self):
        project = self.managed_project("codex")
        self.env["TEST_RUN_STATUS"] = "1"
        result = self.project_shell(project, "quick_resume", "\ns\n")
        calls = self.session_calls()
        self.assertEqual(len(calls), 2, self.calls())
        self.assertEqual(calls[0]["args"][:2], ["resume", "--last"])
        self.assertNotIn("resume", calls[1]["args"])

    def test_c05_failed_resume_can_decline_new_conversation(self):
        project = self.managed_project("codex")
        self.env["TEST_RUN_STATUS"] = "1"
        result = self.project_shell(project, "quick_resume", "\nn\n")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(len(self.session_calls()), 1, self.calls())

    def test_c06_interrupt_does_not_offer_new_conversation(self):
        project = self.managed_project("codex")
        self.env["TEST_RUN_STATUS"] = "130"
        result = self.project_shell(project, "quick_resume", "\n")
        self.assertEqual(len(self.session_calls()), 1, self.calls())
        self.assertNotIn("conversa nova", result.stderr + result.stdout)

    def test_c07_saved_settings_skip_model_questions(self):
        project = self.managed_project("codex")
        first = self.project_shell(project, "launch_agent novo", "\n4\n\n")
        self.assert_ok(first)
        second = self.project_shell(project, "launch_agent novo", "\n4\n\n")
        self.assert_ok(second)
        self.assertIn("Usar essas configurações", second.stderr)
        self.assertNotIn("Escolher modelo", second.stdout)
        self.assertEqual(len(self.session_calls()), 2, self.calls())

    def test_c08_declining_saved_settings_asks_again(self):
        project = self.managed_project("codex")
        self.assert_ok(self.project_shell(project, "launch_agent novo", "\n4\n\n"))
        second = self.project_shell(project, "launch_agent novo", "n\n1\n1\n1\n4\n\n")
        self.assert_ok(second)
        self.assertIn("Escolher modelo", second.stdout)

    def test_c09_menu_c_without_project_explains(self):
        result = self.run_main(input_text="1\n0\n\n0\n")
        self.assertIn("Primeiro escolha ou crie um projeto", result.stdout + result.stderr)
        self.assertEqual(self.session_calls(), [])

    def test_c10_menu_enter_with_project_confirms_before_starting(self):
        project = self.managed_project("codex")
        self.assert_ok(self.project_shell(project, "true"))
        # Enter no menu leva a "continuar", mas ainda pede um segundo Enter.
        result = self.run_main(input_text="\n0\n\n0\n")
        self.assertEqual(self.session_calls(), [], self.calls())
        result = self.run_main(input_text="\n\n\n0\n")
        self.assertEqual(len(self.session_calls()), 1, self.calls())

    def test_c11_menu_offers_continue_only_with_project(self):
        project = self.managed_project("codex")
        self.assert_ok(self.project_shell(project, "true"))
        with_project = self.run_main(input_text="0\n")
        self.assertIn("Continuar de onde parei", with_project.stdout)


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(ContinueTests, _name, None)

if __name__ == "__main__":
    unittest.main()
