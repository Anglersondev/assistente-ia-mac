#!/usr/bin/env python3
"""Aviso dentro do chat: script da barra (statusline-claude.sh) e instalação segura (statusline.sh)."""
import json
import os
import stat
import subprocess
import unittest

import test_assistente as base

BAR = base.KIT / "lib" / "statusline-claude.sh"
LIB = base.KIT / "lib" / "statusline.sh"


def ctx(tokens, window=200000, pct=None, extra=""):
    pct_text = "null" if pct is None else str(pct)
    return ('{"workspace":{"project_dir":"/exemplo/Meu Projeto/"},"model":{"display_name":"Opus"},'
            f'"session_id":"abc-123","context_window":{{"total_input_tokens":{tokens},'
            f'"context_window_size":{window},"used_percentage":{pct_text}}}{extra}}}')


class StatuslineTests(base.AssistantTests):
    def bar(self, data, **env):
        e = dict(self.env)
        e["ASSISTENTE_STATE_DIR"] = str(self.state)
        e["NO_COLOR"] = "1"
        e.update(env)
        return subprocess.run(["/bin/bash", str(BAR)], input=data, text=True, capture_output=True,
                              env=e, cwd=self.root, timeout=10)

    def usage_file(self, project="/exemplo/Meu Projeto"):
        k = subprocess.run(["cksum"], input=project.encode(), capture_output=True).stdout.split()[0].decode()
        return self.state / "usage" / f"claude-{k}.txt"

    def settings(self):
        return self.home / ".claude" / "settings.json"

    def write_settings(self, text):
        self.settings().parent.mkdir(parents=True, exist_ok=True)
        self.settings().write_text(text)

    def lib(self, body, inputs=""):
        return self.run_shell(f"source {base.shlex.quote(str(LIB))}\n{body}", inputs)

    # ---- script da barra --------------------------------------------------
    def test_s01_light(self):
        r = self.bar(ctx(35000, pct=17.5))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "Meu Projeto · Opus · contexto 35 mil tokens (17%) · ✓ leve")

    def test_s02_getting_long(self):
        r = self.bar(ctx(120000, window=1000000, pct=12))
        self.assertIn("⚠ ficando longa", r.stdout)

    def test_s03_too_long_by_tokens(self):
        r = self.bar(ctx(250000, window=1000000, pct=25))
        self.assertIn("⛔ encerre: use Encerrar com resumo", r.stdout)

    def test_s04_percent_can_be_worse_than_tokens(self):
        r = self.bar(ctx(70000, window=80000, pct=90))
        self.assertIn("⛔", r.stdout)

    def test_s05_null_and_missing_context(self):
        for data in ('{"cwd":"/p/A","context_window":{"total_input_tokens":null,"current_usage":null}}',
                     '{"cwd":"/p/A"}', ""):
            with self.subTest(data=data):
                r = self.bar(data)
                self.assertEqual(r.returncode, 0)
                self.assertTrue(r.stdout.strip() == "" or "aguardando 1ª resposta" in r.stdout, r.stdout)

    def test_s06_rate_limits_percentage_is_not_used(self):
        data = ('{"cwd":"/p/A","context_window":{"total_input_tokens":null,"used_percentage":null},'
                '"rate_limits":{"five_hour":{"used_percentage":95}}}')
        self.assertNotIn("95%", self.bar(data).stdout)

    def test_s07_compact_and_multiline_json_match(self):
        compact = ctx(35000, pct=17.5)
        pretty = json.dumps(json.loads(compact), indent=2)
        self.assertEqual(self.bar(compact).stdout, self.bar(pretty).stdout)

    def test_s08_sums_current_usage_when_total_is_missing(self):
        data = ('{"cwd":"/p/A","context_window":{"total_input_tokens":null,"context_window_size":200000,'
                '"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":4000,"cache_read_input_tokens":45000,'
                '"output_tokens":9}}}')
        self.assertIn("contexto 50 mil tokens (25%)", self.bar(data).stdout)

    def test_s09_usage_file_has_only_numbers_and_ids(self):
        self.bar(ctx(35000, pct=17.5))
        text = self.usage_file().read_text()
        self.assertEqual(text.splitlines()[:3], ["tokens=35000", "window=200000", "percent=17"])
        self.assertRegex(text, r"when=\d+\n")
        self.assertIn("session=abc-123", text)
        self.assertNotIn("Opus", text)
        self.assertEqual(self.usage_file().stat().st_mode & 0o777, 0o600)

    def test_s10_symlinked_usage_dir_is_not_followed(self):
        target = self.root / "alvo"
        target.mkdir()
        self.state.mkdir(exist_ok=True)
        os.symlink(target, self.state / "usage")
        r = self.bar(ctx(35000, pct=17.5))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(list(target.iterdir()), [])

    def test_s11_symlinked_usage_file_is_not_followed(self):
        (self.state / "usage").mkdir(parents=True)
        victim = self.root / "vitima.txt"
        victim.write_text("intacto\n")
        os.symlink(victim, self.usage_file())
        self.assertEqual(self.bar(ctx(35000, pct=17.5)).returncode, 0)
        self.assertEqual(victim.read_text(), "intacto\n")

    def test_s12_empty_input_exits_zero(self):
        self.assertEqual(self.bar("").returncode, 0)

    # ---- estado e pré-visualização -----------------------------------------
    def test_s13_state_line_three_forms(self):
        out = self.lib("statusline_state_line").stdout
        self.assertIn("não instalada", out)
        self.write_settings('{"statusLine": {"type": "command", "command": "/outro/script.sh"}}')
        self.assertIn("outra barra", self.lib("statusline_state_line").stdout)
        self.write_settings(json.dumps({"statusLine": {"type": "command", "command": f"'{self.state}/statusline.sh'"}}))
        self.assertIn("instalada ✓", self.lib("statusline_state_line").stdout)

    def test_s14_preview_shows_three_levels_and_writes_nothing(self):
        r = self.lib("sl_preview")
        self.assert_ok(r)
        for text in ("✓ leve", "⚠ ficando longa", "⛔ encerre"):
            self.assertIn(text, r.stdout)
        self.assertFalse((self.state / "usage").exists())

    # ---- instalar ----------------------------------------------------------
    def test_s15_install_creates_settings_and_script(self):
        r = self.lib("sl_install", "INSTALAR\n")
        self.assert_ok(r)
        data = json.loads(self.settings().read_text())
        self.assertEqual(data["statusLine"]["type"], "command")
        self.assertEqual(data["statusLine"]["command"], f"'{self.state}/statusline.sh'")
        script = self.state / "statusline.sh"
        self.assertTrue(script.exists())
        self.assertEqual(stat.S_IMODE(script.stat().st_mode), 0o700)
        self.assertIn("ASSISTENTE_STATE_DIR", script.read_text().splitlines()[1])

    def test_s16_install_into_empty_object_and_installed_script_runs(self):
        self.write_settings("{}")
        self.assert_ok(self.lib("sl_install", "INSTALAR\n"))
        self.assertIn("statusLine", json.loads(self.settings().read_text()))
        r = subprocess.run([str(self.state / "statusline.sh")], input=ctx(35000, pct=17.5), text=True,
                           capture_output=True, env={"PATH": "/usr/bin:/bin", "HOME": str(self.home), "NO_COLOR": "1"})
        self.assertEqual(r.returncode, 0)
        self.assertIn("✓ leve", r.stdout)
        self.assertTrue(self.usage_file().exists())

    def test_s17_install_preserves_other_keys_and_makes_backup(self):
        original = {"model": "opus", "permissions": {"allow": ["Bash(ls:*)"]}, "env": {"X": "1"}}
        self.write_settings(json.dumps(original))
        self.assert_ok(self.lib("sl_install", "INSTALAR\n"))
        data = json.loads(self.settings().read_text())
        for key, value in original.items():
            self.assertEqual(data[key], value)
        backups = list((self.state / "backups").iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual(json.loads(backups[0].read_text()), original)

    def test_s18_existing_statusline_is_never_overwritten(self):
        text = '{"statusLine": {"type": "command", "command": "/outro/script.sh"}}'
        self.write_settings(text)
        r = self.lib("sl_install", "\n")
        self.assert_ok(r)
        self.assertEqual(self.settings().read_text(), text)
        self.assertIn("/statusline use o script", r.stdout)

    def test_s19_without_python_prints_manual_steps_and_leaves_settings(self):
        text = '{"model": "opus"}'
        self.write_settings(text)
        self.env["ASSISTENTE_PYTHON"] = ""
        r = self.lib("sl_install", "\n")
        self.assert_ok(r)
        self.assertEqual(self.settings().read_text(), text)
        self.assertIn("/statusline use o script", r.stdout)
        self.assertIn('"statusLine"', r.stdout)
        self.assertTrue((self.state / "statusline.sh").exists())

    def test_s20_wrong_confirmation_changes_nothing(self):
        text = '{"model": "opus"}'
        self.write_settings(text)
        for answer in ("", "instalar", "sim", "INSTALAR "):
            with self.subTest(answer=answer):
                r = self.lib("sl_install", answer + "\n")
                self.assert_ok(r)
                self.assertEqual(self.settings().read_text(), text)
                self.assertFalse((self.state / "statusline.sh").exists())
                self.assertFalse((self.state / "backups").exists())

    def test_s21_invalid_json_is_not_touched(self):
        text = '{ "model": "opus", // comentário\n}'
        self.write_settings(text)
        r = self.lib("sl_install", "INSTALAR\n")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(self.settings().read_text(), text)

    def test_s22_symlinked_settings_keeps_the_link(self):
        real = self.root / "dotfiles-settings.json"
        real.write_text('{"model": "opus"}')
        (self.home / ".claude").mkdir(parents=True)
        os.symlink(real, self.settings())
        self.assert_ok(self.lib("sl_install", "INSTALAR\n"))
        self.assertTrue(self.settings().is_symlink())
        self.assertIn("statusLine", json.loads(real.read_text()))
        self.assertEqual(json.loads(real.read_text())["model"], "opus")

    # ---- remover -----------------------------------------------------------
    def test_s23_remove_only_ours_and_keeps_other_keys(self):
        self.write_settings(json.dumps({"model": "opus", "env": {"A": "1"}}))
        self.assert_ok(self.lib("sl_install", "INSTALAR\n"))
        r = self.lib("sl_remove", "REMOVER\n")
        self.assert_ok(r)
        self.assertEqual(json.loads(self.settings().read_text()), {"model": "opus", "env": {"A": "1"}})
        self.assertEqual(len(list((self.state / "backups").iterdir())), 2)

    def test_s24_remove_does_not_touch_foreign_statusline(self):
        text = '{"statusLine": {"type": "command", "command": "/outro/script.sh"}}'
        self.write_settings(text)
        r = self.lib("sl_remove", "REMOVER\n")
        self.assert_ok(r)
        self.assertEqual(self.settings().read_text(), text)
        self.assertIn("/statusline delete", r.stdout)

    def test_s25_remove_wrong_confirmation_changes_nothing(self):
        self.assert_ok(self.lib("sl_install", "INSTALAR\n"))
        before = self.settings().read_text()
        for answer in ("", "remover", "sim"):
            with self.subTest(answer=answer):
                self.assert_ok(self.lib("sl_remove", answer + "\n"))
                self.assertEqual(self.settings().read_text(), before)

    # ---- menu --------------------------------------------------------------
    def test_s26_menu_lists_options_and_returns(self):
        r = self.lib("statusline_menu", "0\n")
        self.assert_ok(r)
        for text in ("Aviso dentro do chat", "1) Ver como ficará", "2) Instalar a barra",
                     "3) Remover a barra", "4) Como ver o uso sem instalar", "só funciona no Claude Code"):
            self.assertIn(text, r.stdout)

    def test_s27_menu_install_flow_and_without_install_text(self):
        r = self.lib("statusline_menu", "2\nINSTALAR\n\n4\n\n0\n")
        self.assert_ok(r)
        self.assertIn("statusLine", self.settings().read_text())
        self.assertIn("/context", r.stdout)
        self.assertIn("Codex", r.stdout)

    # ---- rodada de ajustes (auditoria) -------------------------------------
    def test_s28_leading_zero_and_huge_numbers(self):
        r = self.bar(ctx("0000000035", window="0200000", pct=17.5))
        self.assertEqual(r.stdout.strip(), "Meu Projeto · Opus · contexto 35 tokens (17%) · ✓ leve")
        r = self.bar(ctx("99999999999999999999"))
        self.assertIn("número inválido", r.stdout)
        self.assertNotIn("✓ leve", r.stdout)
        r = self.bar(ctx(250000, window="1000000000000"))
        self.assertEqual(r.returncode, 0)
        self.assertIn("⛔", r.stdout)
        self.assertNotIn("(", r.stdout)

    def test_s29_octal_looking_numbers_and_zero_window_print_one_clean_line(self):
        r = self.bar(ctx("08", window="0"))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stderr, "")
        self.assertEqual(len(r.stdout.strip().splitlines()), 1)
        self.assertIn("contexto 8 tokens", r.stdout)
        self.assertNotIn("%", r.stdout)
        extra = ',"x":1'
        r = self.bar('{"context_window":{"total_input_tokens":null,"current_usage":{"input_tokens":1000,'
                     '"cache_creation_input_tokens":09,"cache_read_input_tokens":5}}' + extra + '}')
        self.assertIn("contexto 1 mil tokens", r.stdout)

    def test_s30_is_ours_recognises_wrapped_commands(self):
        script = f"{self.state}/statusline.sh"
        forms = [f"'{script}'", f'"{script}"', f"bash '{script}'", f"sh -c '{script}'", f'/bin/bash -c "{script}"']
        for form in forms:
            with self.subTest(form=form):
                self.write_settings(json.dumps({"statusLine": {"type": "command", "command": form}}))
                r = self.lib("statusline_state_line")
                self.assert_ok(r)
                self.assertIn("instalada ✓", r.stdout)

    def test_s31_remove_works_with_wrapped_command_and_keeps_other_keys(self):
        script = f"{self.state}/statusline.sh"
        data = {"model": "opus", "statusLine": {"type": "command", "command": f"bash '{script}'", "padding": 2}}
        self.write_settings(json.dumps(data))
        r = self.lib("sl_remove", "REMOVER\n")
        self.assert_ok(r)
        self.assertEqual(json.loads(self.settings().read_text()), {"model": "opus"})

    def test_s32_foreign_statusline_remove_makes_no_backup(self):
        self.write_settings('{"statusLine": {"type": "command", "command": "/outro/script.sh"}}')
        r = self.lib("sl_remove", "REMOVER\n")
        self.assert_ok(r)
        self.assertIn("/statusline delete", r.stdout)
        self.assertFalse((self.state / "backups").exists())

    def test_s33_foreign_statusline_message_has_no_json_snippet(self):
        self.write_settings('{"statusLine": {"type": "command", "command": "/outro/script.sh"}}')
        r = self.lib("sl_install", "\n")
        self.assert_ok(r)
        self.assertIn("/statusline use o script", r.stdout)
        self.assertNotIn("Ou adicione", r.stdout)
        self.assertNotIn('"padding"', r.stdout)

    def test_s34_invalid_json_refused_before_any_file_is_created(self):
        self.write_settings('{ "model": "opus", }')
        r = self.lib("sl_install", "INSTALAR\n")
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse((self.state / "backups").exists())
        self.assertFalse((self.state / "statusline.sh").exists())
        self.assertNotIn("INSTALAR", r.stdout.split("Digite INSTALAR")[0] if "Digite INSTALAR" in r.stdout else "")

    def test_s35_without_python_other_bar_detected_by_command_line(self):
        self.env["ASSISTENTE_PYTHON"] = ""
        script = f"{self.state}/statusline.sh"
        self.write_settings('{"note": "' + script + '", "statusLine": {"type": "command", "command": "/outro.sh"}}')
        r = self.lib("statusline_state_line")
        self.assertIn("outra barra", r.stdout)
        self.write_settings('{"statusLine": {"type": "command", "command": "bash ' + script + '"}}')
        r = self.lib("statusline_state_line")
        self.assertIn("instalada ✓", r.stdout)


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(StatuslineTests, _name, None)

if __name__ == "__main__":
    unittest.main()
