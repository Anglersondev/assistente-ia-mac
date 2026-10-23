#!/usr/bin/env python3
"""Controle total: chaves liga/desliga e tela de transparência."""
import unittest

import test_assistente as base


class ControlTests(base.AssistantTests):
    def flag(self, name):
        return self.state / f"opt-{name}-off"

    def test_k01_flip_creates_and_removes_flag(self):
        for name in ("rtk", "dicas", "peso", "atalho"):
            with self.subTest(name=name):
                self.assert_ok(self.run_shell(f"opt_flip {name}"))
                self.assertTrue(self.flag(name).exists())
                self.assert_ok(self.run_shell(f"opt_flip {name}"))
                self.assertFalse(self.flag(name).exists())

    def test_k02_control_menu_toggles_and_lists_state(self):
        result = self.run_shell("control_menu", "2\n0\n")
        self.assert_ok(result)
        self.assertTrue(self.flag("dicas").exists())
        self.assertIn("desligado", result.stdout)
        self.assertFalse(self.flag("rtk").exists())

    def test_k02b_update_check_toggle_and_transparency_moved(self):
        result = self.run_shell("control_menu", "5\n6\n\n0\n")
        self.assert_ok(result)
        self.assertTrue(self.flag("atualizacao").exists())
        self.assertIn("Verificar 1x por dia", result.stdout)
        self.assertIn("O que este assistente faz sozinho", result.stdout)
        result = self.run_shell("control_menu", "5\n0\n")
        self.assertFalse(self.flag("atualizacao").exists())

    def test_k03_transparency_states_limits(self):
        result = self.run_shell("transparency")
        self.assert_ok(result)
        flat = " ".join(result.stdout.split())
        for text in ("GRAVA, SÓ COM A SUA CONFIRMAÇÃO", "NÃO FAZ", "senhas, chaves", "Enter vale como sim", "1 a 5", "releases/latest", "nunca instala sozinho", "statusLine", "usage/claude"):
            self.assertIn(text, flat)

    def test_k04_enter_shortcut_can_be_disabled(self):
        project = self.managed_project("codex")
        self.assert_ok(self.project_shell(project, "true"))
        self.assert_ok(self.run_shell("opt_flip atalho"))
        result = self.run_main(input_text="\n0\n")
        self.assertEqual(self.session_calls(), [], self.calls())
        self.assertNotIn("Enter = continuar", result.stdout + result.stderr)

    def test_k05_rtk_autocheck_off_never_asks_or_changes(self):
        project = self.managed_project("codex")
        self.assert_ok(self.run_shell("opt_flip rtk"))
        result = self.project_shell(project, "TOOL=codex; rtk_preflight; echo FIM")
        self.assert_ok(result)
        self.assertIn("FIM", result.stdout)
        self.assertNotIn("Ativar agora", result.stderr + result.stdout)

    def test_k06_extras_respect_switches(self):
        body = ("tip_of_the_day() { echo DICA-X; }; session_weight_note() { echo PESO-X; }; "
                "launch_extras")
        both = self.run_shell(body)
        self.assertIn("DICA-X", both.stdout)
        self.assertIn("PESO-X", both.stdout)
        self.assert_ok(self.run_shell("opt_flip dicas; opt_flip peso"))
        none = self.run_shell(body)
        self.assertNotIn("DICA-X", none.stdout)
        self.assertNotIn("PESO-X", none.stdout)

    def test_k07_main_menu_lists_new_entries(self):
        result = self.run_main(input_text="0\n")
        for text in ("Encerrar com resumo", "Painel de uso", "Ajuda e ajustes"):
            self.assertIn(text, result.stdout)

    def fake_rtk(self):
        """RTK simulado: registra se alguém tentou alterar a configuração global."""
        rtk = self.bin / "rtk"
        rtk.write_text("#!/bin/bash\necho \"$@\" >> \"$TEST_CLI_LOG.rtk\"\n"
                       "case \"$1\" in --version) echo rtk-test;; init) echo 'init --global --codex --dry-run --show --uninstall';; esac\nexit 0\n")
        rtk.chmod(0o755)
        return self.logs.parent / (self.logs.name + ".rtk")

    def test_k08_unrecognised_answer_never_activates_rtk(self):
        log = self.fake_rtk()
        for answer in ("0", "x", "talvez"):
            with self.subTest(answer=answer):
                result = self.run_shell("TOOL=codex; rtk_autostart", answer + "\n")
                self.assert_ok(result)
                calls = log.read_text() if log.exists() else ""
                self.assertNotIn("init --global", calls.replace("init --global --codex --dry-run", ""))
                self.assertFalse((self.state / "rtk-off-codex").exists())

    def test_k09_no_marks_off_and_stops_asking(self):
        self.fake_rtk()
        self.assert_ok(self.run_shell("TOOL=codex; rtk_autostart", "n\n"))
        self.assertTrue((self.state / "rtk-off-codex").exists())
        again = self.run_shell("TOOL=codex; rtk_autostart", "")
        self.assertNotIn("Ativar agora", again.stdout + again.stderr)


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(ControlTests, _name, None)

if __name__ == "__main__":
    unittest.main()
