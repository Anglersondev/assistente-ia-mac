#!/usr/bin/env python3
"""Integration checks for Assistente IA Mac 1.0, using only isolated fake CLIs.

Run: python3 work/tests/test_assistente.py [--kit /absolute/path/to/kit]
No browser, network install, real login or real user state is used.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

SCRIPT_PATH = Path(__file__).resolve()
NEARBY_KIT = SCRIPT_PATH.parent.parent
DEFAULT_KIT = NEARBY_KIT if (NEARBY_KIT / "ASSISTENTE-IA-MAC.command").exists() else SCRIPT_PATH.parents[2] / "outputs" / "Assistente-IA-Mac-1.0"
parser = argparse.ArgumentParser(add_help=False)
parser.add_argument("--kit", type=Path, default=DEFAULT_KIT)
known, remaining = parser.parse_known_args()
KIT = known.kit.resolve()
MAIN = KIT / "ASSISTENTE-IA-MAC.command"


class AssistantTests(unittest.TestCase):
    maxDiff = None

    def setUp(self):
        if not MAIN.exists():
            self.skipTest(f"Main script not created yet: {MAIN}")
        self.tmp_obj = tempfile.TemporaryDirectory(prefix="assistente-test-")
        self.addCleanup(self.tmp_obj.cleanup)
        self.root = Path(self.tmp_obj.name).resolve()
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.state = self.root / "state"
        self.logs = self.root / "calls.jsonl"
        self.parent = self.root / "Projetos com espaços ação"
        for p in (self.home, self.bin, self.parent):
            p.mkdir()
        self.env = os.environ.copy()
        for key in list(self.env):
            if any(s in key for s in ("API_KEY", "AUTH_TOKEN", "ACCESS_TOKEN")):
                self.env.pop(key, None)
        self.env.update({
            "HOME": str(self.home),
            "CODEX_HOME": str(self.home / ".codex"),
            "CLAUDE_CONFIG_DIR": str(self.home / ".claude"),
            "ASSISTENTE_STATE_DIR": str(self.state),
            "ASSISTENTE_TEST_MODE": "1",
            "PATH": f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin",
            "TERM": "dumb",
            "NO_COLOR": "1",
            "TEST_CLI_LOG": str(self.logs),
            "TEST_AUTH_STATUS": "0",
        })
        self.create_cli("codex")
        self.create_cli("claude")
        for name in ("osascript", "open", "pbcopy", "screencapture"):
            (self.bin / name).write_text("#!/bin/bash\nexit 1\n")
            (self.bin / name).chmod(0o755)

    def create_cli(self, name):
        script = "#!" + sys.executable + "\n" + r'''
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_CLI_LOG"], "a") as log:
    log.write(json.dumps({"name": name, "args": args, "cwd": os.getcwd(),
                          "stdin_tty": os.isatty(0), "stdout_tty": os.isatty(1)}) + "\n")
if "--version" in args:
    print(name + " test-version")
    sys.exit(0)
if "--help" in args:
    print("Usage: " + name + " --model --effort --permission-mode --agent --resume --continue --sandbox --ask-for-approval --device-auth --no-alt-screen --no-daemon")
    sys.exit(0)
if args in (["login", "status"], ["auth", "status"], ["auth", "status", "--text"]):
    auth_file = os.environ.get("TEST_AUTH_FILE")
    rc = int(pathlib.Path(auth_file).read_text()) if auth_file and pathlib.Path(auth_file).exists() else int(os.environ.get("TEST_AUTH_STATUS", "0"))
    print("Logged in" if rc == 0 else "Not logged in")
    sys.exit(rc)
if args in (["login"], ["login", "--device-auth"], ["auth", "login"]):
    rc = int(os.environ.get("TEST_LOGIN_STATUS", "0"))
    if rc == 0 and os.environ.get("TEST_AUTH_FILE"):
        pathlib.Path(os.environ["TEST_AUTH_FILE"]).write_text("0")
    sys.exit(rc)
if args in (["logout"], ["auth", "logout"]):
    rc = int(os.environ.get("TEST_LOGOUT_STATUS", "0"))
    if rc == 0 and os.environ.get("TEST_AUTH_FILE"):
        pathlib.Path(os.environ["TEST_AUTH_FILE"]).write_text("1")
    sys.exit(rc)
sys.exit(int(os.environ.get("TEST_RUN_STATUS", "0")))
'''
        (self.bin / name).write_text(script)
        (self.bin / name).chmod(0o755)

    def run_main(self, *args, input_text="", timeout=5):
        return subprocess.run(["/bin/bash", str(MAIN), *args], input=input_text,
                              text=True, capture_output=True, env=self.env,
                              cwd=self.root, timeout=timeout)

    def run_shell(self, body, input_text="", timeout=5, initialize=True):
        preamble = f"source {shlex.quote(str(MAIN))}\n"
        if initialize:
            preamble += "init_state || exit 77\n"
        return subprocess.run(["/bin/bash", "-c", preamble + body], input=input_text,
                              text=True, capture_output=True, env=self.env,
                              cwd=self.root, timeout=timeout)

    def calls(self):
        return [json.loads(x) for x in self.logs.read_text().splitlines()] if self.logs.exists() else []

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + "\n" + result.stderr)

    def command(self, tool="codex", mode="novo", model="", effort="", workmode="trabalhar", prompt=""):
        body = "\n".join([
            "TOOL=" + shlex.quote(tool), "MODEL=" + shlex.quote(model),
            "EFFORT=" + shlex.quote(effort), "WORKMODE=" + shlex.quote(workmode),
            "INITIAL_PROMPT=" + shlex.quote(prompt),
            f"build_command {shlex.quote(tool)} {shlex.quote(mode)} || exit $?",
            "printf 'TESTARGV\\0'; printf '%s\\0' \"${COMMAND[@]}\"",
        ])
        result = self.run_shell(body)
        self.assert_ok(result)
        self.assertIn("TESTARGV\0", result.stdout)
        return result.stdout.split("TESTARGV\0", 1)[1].rstrip("\0").split("\0")

    def test_01_bash_32_syntax(self):
        result = subprocess.run(["/bin/bash", "-n", str(MAIN)], capture_output=True, text=True)
        self.assert_ok(result)

    def test_02_help_does_not_create_state(self):
        result = self.run_main("--help")
        self.assert_ok(result)
        self.assertFalse(self.state.exists())
        self.assertFalse(self.calls())

    def test_03_check_does_not_create_state(self):
        result = self.run_main("--check")
        self.assert_ok(result)
        self.assertFalse(self.state.exists())
        self.assertFalse(self.calls())

    def test_04_source_does_not_create_state_or_run_main(self):
        result = self.run_shell("printf 'SOURCED\\n'", initialize=False)
        self.assert_ok(result)
        self.assertEqual(result.stdout.strip(), "SOURCED")
        self.assertFalse(self.state.exists())
        self.assertFalse(self.calls())

    def test_05_eof_exits_main_without_loop(self):
        result = self.run_main(input_text="", timeout=3)
        self.assert_ok(result)
        self.assertLess(len(result.stdout), 18000)

    def test_06_exit_menu(self):
        result = self.run_main(input_text="0\n")
        self.assert_ok(result)
        self.assertFalse(self.calls())

    def test_07_create_minimal_project_where_user_chooses(self):
        name = "Minha aplicação legal"
        inputs = f"2\n{self.parent}\n{name}\n1\n1\n\n"
        result = self.run_shell("create_project", inputs)
        self.assert_ok(result)
        project = self.parent / "CODEX" / name
        self.assertTrue(project.is_dir(), result.stdout + result.stderr)
        self.assertFalse((self.parent / "Projetos-IA").exists())
        self.assertEqual([p.name for p in project.iterdir()], [".assistente-ia"])
        self.assertEqual((project / ".assistente-ia/tool").read_text().strip(), "codex")

    def test_08_create_organized_project(self):
        name = "Organizado"
        result = self.run_shell("create_project", f"2\n{self.parent}\n{name}\n1\n2\n\n")
        self.assert_ok(result)
        project = self.parent / "CODEX" / name
        for item in ("README.md", "AGENTS.md", "INSTRUCOES/PROJETO.md", "DOCS", "ANEXOS", "PROMPTS"):
            self.assertTrue((project / item).exists(), item + result.stdout + result.stderr)
        self.assertFalse((project / "CLAUDE.md").exists())
        self.assertIn("INSTRUCOES/PROJETO.md", (project / "AGENTS.md").read_text())

    def test_09_cancel_folder_does_not_create_project(self):
        result = self.run_shell("create_project", "0\n")
        self.assertFalse(list(self.parent.iterdir()))
        self.assertFalse(self.calls())

    def test_10_eof_does_not_create_project(self):
        result = self.run_shell("create_project", f"2\n{self.parent}\n")
        self.assertFalse(list(self.parent.iterdir()))
        self.assertFalse(self.calls())

    def test_11_existing_project_is_not_overwritten(self):
        project = self.parent / "CODEX" / "Existente"
        project.mkdir(parents=True)
        content = project / "README.md"
        content.write_text("PRESERVAR")
        result = self.run_shell("create_project", f"2\n{self.parent}\nExistente\n1\n2\n\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(content.read_text(), "PRESERVAR")
        self.assertEqual(set(p.name for p in project.iterdir()), {"README.md"})

    def test_12_cancel_confirmation_does_not_create(self):
        result = self.run_shell("create_project", f"2\n{self.parent}\nCancelar\n1\n1\nn\n")
        self.assertFalse(list(self.parent.iterdir()))

    def test_13_parent_does_not_exist_is_not_created(self):
        parent = self.parent / "não existe"
        result = self.run_shell("create_project", f"2\n{parent}\n0\n")
        self.assertFalse(parent.exists())

    def test_14_project_name_is_literal_no_shell_execution(self):
        name = "Teste $(touch INJETADO) `touch INJETADO2` & ação"
        result = self.run_shell("create_project", f"2\n{self.parent}\n{name}\n1\n1\n\n")
        self.assert_ok(result)
        self.assertTrue((self.parent / "CODEX" / name).is_dir(), result.stdout + result.stderr)
        self.assertFalse((self.root / "INJETADO").exists())
        self.assertFalse((self.root / "INJETADO2").exists())

    def test_15_invalid_traversal_name(self):
        result = self.run_shell("create_project", f"2\n{self.parent}\n../escapou\n1\n\n")
        self.assertFalse((self.root / "escapou").exists())
        self.assertFalse(list(self.parent.iterdir()))

    def test_16_select_existing_does_not_modify_contents(self):
        project = self.parent / "Projeto externo"
        project.mkdir()
        (project / "arquivo.txt").write_text("original")
        result = self.run_shell("select_project", f"2\n{project}\n")
        self.assert_ok(result)
        self.assertEqual([p.name for p in project.iterdir()], ["arquivo.txt"])
        self.assertEqual((project / "arquivo.txt").read_text(), "original")

    def test_17_set_project_literal_and_saved(self):
        project = self.parent / "$HOME ; ação 'aspas'"
        project.mkdir()
        body = f"set_project {shlex.quote(str(project))} || exit $?\nprintf 'PROJECT=%s\\n' \"$PROJECT\""
        result = self.run_shell(body)
        self.assert_ok(result)
        self.assertIn("PROJECT=" + str(project), result.stdout)
        self.assertTrue(any(str(project) in p.read_text() for p in self.state.rglob("*") if p.is_file()))

    def test_18_codex_default_command(self):
        args = self.command()
        self.assertEqual(args[0], "codex")
        self.assertNotIn("--model", args)
        self.assertNotIn("--dangerously-bypass-approvals-and-sandbox", args)

    def test_19_codex_explicit_model_effort(self):
        args = self.command(model="test-model", effort="high")
        self.assertEqual(args[args.index("--model") + 1], "test-model")
        self.assertTrue(any("model_reasoning_effort" in x and "high" in x for x in args))

    def test_20_codex_resume_last(self):
        args = self.command(mode="recente")
        self.assertIn("resume", args)
        self.assertIn("--last", args)

    def test_21_codex_resume_picker(self):
        args = self.command(mode="escolher")
        self.assertIn("resume", args)
        self.assertNotIn("--last", args)

    def test_22_claude_default_command(self):
        args = self.command(tool="claude")
        self.assertEqual(args[0], "claude")
        self.assertNotIn("--dangerously-skip-permissions", args)

    def test_23_claude_explicit_model_effort(self):
        args = self.command(tool="claude", model="sonnet", effort="high")
        self.assertEqual(args[args.index("--model") + 1], "sonnet")
        self.assertEqual(args[args.index("--effort") + 1], "high")

    def test_24_claude_continue(self):
        args = self.command(tool="claude", mode="recente")
        self.assertIn("--continue", args)

    def test_25_claude_resume_picker(self):
        args = self.command(tool="claude", mode="escolher")
        self.assertIn("--resume", args)

    def test_26_prompt_remains_one_literal_argument(self):
        prompt = "Corrija isto\n$(touch INJETADO) 'aspas' & comandos"
        args = self.command(prompt=prompt)
        self.assertIn(prompt, args)
        self.assertFalse((self.root / "INJETADO").exists())

    def test_27_prompt_beginning_with_dash_is_not_flag(self):
        prompt = "--model malicious"
        args = self.command(prompt=prompt)
        self.assertIn(prompt, args)
        self.assertIn("--", args)
        self.assertGreater(args.index(prompt), args.index("--"))

    def test_28_bounded_capture_timeout(self):
        result = self.run_shell("bounded_capture 1 /bin/sleep 20; rc=$?; [ $rc -ne 0 ]", timeout=4)
        self.assert_ok(result)

    def test_29_bounded_capture_preserves_exit_code(self):
        result = self.run_shell("bounded_capture 2 /bin/bash -c 'printf hello; exit 7'; rc=$?; printf 'RC=%s CAPTURE=%s\\n' \"$rc\" \"$CAPTURE\"; [ $rc -eq 7 ]")
        self.assert_ok(result)
        self.assertIn("RC=7 CAPTURE=hello", result.stdout)

    def test_30_switch_account_cancellation_never_logs_out(self):
        result = self.run_shell("TOOL=codex; switch_account", "n\n")
        self.assertFalse(any("logout" in c["args"] for c in self.calls()))

    def test_31_switch_account_eof_never_logs_out(self):
        result = self.run_shell("TOOL=claude; switch_account", "")
        self.assertFalse(any("logout" in c["args"] for c in self.calls()))

    def test_32_diagnostic_uses_only_read_only_cli_commands(self):
        result = self.run_main("--diagnostico", timeout=10)
        self.assert_ok(result)
        allowed = [["--version"], ["--help"], ["login", "status"], ["auth", "status"], ["auth", "status", "--text"]]
        self.assertTrue(all(c["args"] in allowed for c in self.calls()), self.calls())

    def test_33_existing_symlink_is_not_overwritten(self):
        target = self.parent / "Destino"
        target.mkdir()
        (target / "preservar").write_text("original")
        (self.parent / "CODEX").mkdir()
        (self.parent / "CODEX/Atalho").symlink_to(target, target_is_directory=True)
        result = self.run_shell("create_project", f"2\n{self.parent}\nAtalho\n1\n2\n\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.parent / "CODEX/Atalho").is_symlink())
        self.assertEqual([x.name for x in target.iterdir()], ["preservar"])

    def test_34_broken_symlink_is_not_replaced(self):
        (self.parent / "CODEX").mkdir()
        link = self.parent / "CODEX/Atalho quebrado"
        link.symlink_to(self.parent / "Ausente")
        result = self.run_shell("create_project", f"2\n{self.parent}\nAtalho quebrado\n1\n2\n\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(link.is_symlink())
        self.assertFalse(link.exists())

    def test_35_foreground_keeps_tty_and_project_directory(self):
        project = self.parent / "Projeto terminal"
        project.mkdir()
        master, slave = os.openpty()
        try:
            body = (f"source {shlex.quote(str(MAIN))}; init_state || exit 77; "
                    f"cd {shlex.quote(str(project))} || exit 78; run_foreground codex")
            process = subprocess.Popen(["/bin/bash", "-c", body], stdin=slave,
                                       stdout=slave, stderr=slave, env=self.env,
                                       cwd=self.root)
            try:
                self.assertEqual(process.wait(timeout=5), 0)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
        finally:
            os.close(slave)
            os.close(master)
        calls = self.calls()
        self.assertEqual(len(calls), 1, calls)
        self.assertEqual(calls[0]["cwd"], str(project))
        self.assertTrue(calls[0]["stdin_tty"], calls)
        self.assertTrue(calls[0]["stdout_tty"], calls)

    def test_36_foreground_preserves_failure(self):
        self.env["TEST_RUN_STATUS"] = "9"
        result = self.run_shell("run_foreground codex")
        self.assertEqual(result.returncode, 9, result.stdout + result.stderr)


    def launch(self, tool="codex", mode="novo", tail=None):
        project = self.parent / "Projeto da conversa"
        project.mkdir(exist_ok=True)
        if tail is None:
            tail = "\n4\n\n" if mode == "novo" else "\n\n"
        choice = "1" if tool == "codex" else "2"
        result = self.run_shell(
            f"set_project {shlex.quote(str(project))} || exit $?; launch_agent {shlex.quote(mode)}",
            choice + "\n" + tail, timeout=12)
        return result, project

    def session_calls(self):
        return [c for c in self.calls() if c["args"] and c["args"][0] not in ("login", "logout", "auth", "--help", "--version")]

    def test_37_complete_codex_launch_default_model(self):
        result, project = self.launch()
        self.assert_ok(result)
        calls = self.session_calls()
        self.assertEqual(len(calls), 1, self.calls())
        self.assertEqual(calls[0]["cwd"], str(project))
        self.assertIn("--cd", calls[0]["args"])
        self.assertNotIn("--model", calls[0]["args"])
        self.assertNotIn("unbound variable", result.stderr)

    def test_38_complete_claude_continue_in_project(self):
        result, project = self.launch(tool="claude", mode="recente")
        self.assert_ok(result)
        calls = self.session_calls()
        self.assertEqual(len(calls), 1, self.calls())
        self.assertEqual(calls[0]["cwd"], str(project))
        self.assertIn("--continue", calls[0]["args"])

    def test_39_complete_launch_reports_cli_failure(self):
        self.env["TEST_RUN_STATUS"] = "9"
        result, project = self.launch()
        self.assertEqual(result.returncode, 9, result.stdout + result.stderr)
        self.assertIn("9", result.stdout + result.stderr)

    def test_40_missing_cli_does_not_launch_or_install(self):
        (self.bin / "codex").unlink()
        result, project = self.launch(tail="n\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_41_cancel_final_launch_never_starts_chat(self):
        result, project = self.launch(tail="1\n1\n1\n2\n0\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.session_calls(), [])

    def test_42_logout_failure_does_not_attempt_new_login(self):
        self.env["TEST_LOGOUT_STATUS"] = "9"
        result = self.run_shell("TOOL=codex; switch_account", "TROCAR\n", timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(c["args"] == ["logout"] for c in self.calls()))
        self.assertFalse(any(c["args"] in (["login"], ["login", "--device-auth"]) for c in self.calls()))

    def test_43_login_failure_blocks_conversation(self):
        self.env["TEST_AUTH_STATUS"] = "1"
        self.env["TEST_LOGIN_STATUS"] = "7"
        result, project = self.launch(tail="1\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.session_calls(), [])
        self.assertTrue(any(c["args"] == ["login"] for c in self.calls()))

    def test_44_finder_cancel_can_fall_back_to_manual_path(self):
        result = self.run_shell("select_project", f"1\n2\n{self.parent}\n")
        self.assert_ok(result)
        self.assertTrue(any(str(self.parent) in p.read_text() for p in self.state.rglob("*") if p.is_file()))

    def test_45_preferences_are_data_not_executable_code(self):
        project = self.parent / "Preferências"
        project.mkdir()
        marker = self.root / "INJETADO"
        payload = "$(touch " + str(marker) + ")"
        body = (f"set_project {shlex.quote(str(project))} || exit $?; TOOL=codex; "
                f"put \"$PREF_DIR/codex.model\" {shlex.quote(payload)} || exit $?; "
                "load_preferences; [ -z \"$MODEL\" ]")
        result = self.run_shell(body)
        self.assert_ok(result)
        self.assertFalse(marker.exists())

    def test_46_changing_model_clears_previous_effort(self):
        result = self.run_shell("TOOL=claude; MODEL=opus; EFFORT=high; select_model || exit $?; [ \"$MODEL\" = sonnet ] && [ -z \"$EFFORT\" ]", "2\n")
        self.assert_ok(result)

    def test_47_default_model_clears_previous_effort(self):
        result = self.run_shell("TOOL=claude; MODEL=opus; EFFORT=high; select_model || exit $?; [ -z \"$MODEL\" ] && [ -z \"$EFFORT\" ]", "1\n")
        self.assert_ok(result)


    def test_48_successful_login_unlocks_model_and_chat(self):
        auth_file = self.root / "simulated-auth-status"
        auth_file.write_text("1")
        self.env["TEST_AUTH_FILE"] = str(auth_file)
        result, project = self.launch(tail="1\n\n4\n\n")
        self.assert_ok(result)
        self.assertEqual(auth_file.read_text(), "0")
        calls = self.calls()
        self.assertTrue(any(c["args"] == ["login"] for c in calls), calls)
        self.assertEqual(len(self.session_calls()), 1, calls)
        login_index = next(i for i, c in enumerate(calls) if c["args"] == ["login"])
        session_index = next(i for i, c in enumerate(calls) if c in self.session_calls())
        self.assertLess(login_index, session_index)

    def test_49_account_switch_logs_out_then_starts_fresh_login(self):
        auth_file = self.root / "simulated-auth-status"
        auth_file.write_text("0")
        self.env["TEST_AUTH_FILE"] = str(auth_file)
        result = self.run_shell("TOOL=codex; switch_account", "TROCAR\n1\n", timeout=10)
        self.assert_ok(result)
        calls = self.calls()
        logout_index = next(i for i, c in enumerate(calls) if c["args"] == ["logout"])
        login_index = next(i for i, c in enumerate(calls) if c["args"] == ["login"])
        self.assertLess(logout_index, login_index)
        self.assertEqual(auth_file.read_text(), "0")

    def test_50_malformed_effort_preference_is_ignored(self):
        project = self.parent / "Esforço"
        project.mkdir()
        body = (f"set_project {shlex.quote(str(project))} || exit $?; TOOL=codex; "
                "put \"$PREF_DIR/codex.effort\" 'high; touch INJETADO' || exit $?; "
                "load_preferences; [ -z \"$EFFORT\" ]")
        result = self.run_shell(body)
        self.assert_ok(result)
        self.assertFalse((self.root / "INJETADO").exists())

    def test_51_current_project_preference_is_data_not_code(self):
        self.state.mkdir()
        (self.state / "current").write_text("$(touch INJETADO)\n")
        result = self.run_shell("[ -z \"$PROJECT\" ]")
        self.assert_ok(result)
        self.assertFalse((self.root / "INJETADO").exists())

    def test_52_codex_planning_uses_read_only_sandbox(self):
        args = self.command(workmode="planejar")
        self.assertEqual(args[args.index("--sandbox") + 1], "read-only")

    def test_53_claude_planning_uses_plan_permission_mode(self):
        args = self.command(tool="claude", workmode="planejar")
        self.assertEqual(args[args.index("--permission-mode") + 1], "plan")


    def actual_catalog(self, data=None, raw=None):
        catalog_file = self.root / "models_cache.json"
        catalog_file.write_text(raw if raw is not None else json.dumps(data))
        return subprocess.run(["/usr/bin/osascript", "-l", "JavaScript", str(KIT / "lib" / "catalog.js"), str(catalog_file)], capture_output=True, text=True, timeout=5, env=self.env)

    @unittest.skipUnless(Path("/usr/bin/osascript").is_file(), "Exige JavaScript for Automation do macOS")
    def test_54_native_catalog_hides_hidden_models_and_limits_fields(self):
        result = self.actual_catalog({
            "identity": "NUNCA-MOSTRAR-ESTE-CAMPO",
            "models": [
                {"slug": "visible-model", "display_name": "Modelo visível", "visibility": "list", "supported_reasoning_levels": [{"effort": "low"}, {"effort": "high"}, {"effort": "unsupported"}]},
                {"slug": "hidden-model", "visibility": "hide"},
            ]
        })
        self.assert_ok(result)
        self.assertEqual(result.stdout.strip(), "visible-model\tModelo visível\tlow,high")
        self.assertNotIn("NUNCA-MOSTRAR", result.stdout)
        self.assertNotIn("hidden-model", result.stdout)

    @unittest.skipUnless(Path("/usr/bin/osascript").is_file(), "Exige JavaScript for Automation do macOS")
    def test_55_native_catalog_invalid_json_has_safe_fallback(self):
        result = self.actual_catalog(raw="{broken json")
        self.assert_ok(result)
        self.assertEqual(result.stdout.strip(), "")

    @unittest.skipUnless(Path("/usr/bin/osascript").is_file(), "Exige JavaScript for Automation do macOS")
    def test_56_native_catalog_sanitizes_label_controls(self):
        result = self.actual_catalog({"models": [{"slug": "visible", "display_name": "Teste\nlinha\ttab\u001b", "visibility": "list"}]})
        self.assert_ok(result)
        rows = result.stdout.strip().splitlines()
        self.assertEqual(len(rows), 1)
        self.assertEqual(len(rows[0].split("\t")), 3)
        self.assertNotIn("\u001b", result.stdout)

    def test_57_model_and_effort_menu_use_cached_capabilities(self):
        stub = "#!" + sys.executable + "\nimport os\nprint(os.environ['TEST_CATALOG_ROWS'])\n"
        (self.bin / "osascript").write_text(stub)
        self.env["TEST_CATALOG_ROWS"] = "model-alpha\tModelo de teste\tlow,high"
        result = self.run_shell("TOOL=codex; select_model || exit $?; select_effort || exit $?; [ \"$MODEL\" = model-alpha ] && [ \"$EFFORT\" = high ]", "2\n3\n")
        self.assert_ok(result)


    @unittest.skipUnless(Path("/usr/bin/osascript").is_file(), "Exige JavaScript for Automation do macOS")
    def test_58_native_catalog_missing_file_has_safe_fallback(self):
        result = subprocess.run(["/usr/bin/osascript", "-l", "JavaScript", str(KIT / "lib" / "catalog.js"), str(self.root / "missing.json")], capture_output=True, text=True, timeout=5, env=self.env)
        self.assert_ok(result)
        self.assertEqual(result.stdout.strip(), "")

    def test_59_normalize_folder_accepts_outer_quotes(self):
        for quoted in ('"' + str(self.parent) + '"', "'" + str(self.parent) + "'"):
            with self.subTest(quoted=quoted):
                result = self.run_shell("normalize_path " + shlex.quote(quoted))
                self.assert_ok(result)
                self.assertEqual(result.stdout.strip(), str(self.parent))

    def test_60_local_file_accepts_outer_quotes_and_literal_shell_chars(self):
        file = self.parent / "pedido $(touch INJETADO) ação.md"
        file.write_text("texto")
        for quoted in ('"' + str(file) + '"', "'" + str(file) + "'"):
            with self.subTest(quoted=quoted):
                result = self.run_shell("choose_local_file || exit $?; printf 'FILE=%s\\n' \"$CHOSEN_FILE\"", "2\n" + quoted + "\n")
                self.assert_ok(result)
                self.assertIn("FILE=" + str(file), result.stdout)
                self.assertFalse((self.root / "INJETADO").exists())

    def test_61_local_file_accepts_quoted_tilde_path(self):
        file = self.home / "pedido com espaço.md"
        file.write_text("texto")
        result = self.run_shell("choose_local_file || exit $?; printf 'FILE=%s\\n' \"$CHOSEN_FILE\"", '2\n"~/pedido com espaço.md"\n')
        self.assert_ok(result)
        self.assertIn("FILE=" + str(file), result.stdout)

    def test_62_expand_path_rejects_newline_without_execution(self):
        path = "nome\n$(touch INJETADO)"
        result = self.run_shell("expand_path " + shlex.quote(path))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "INJETADO").exists())

    def test_63_prompt_file_with_quoted_path_is_literal(self):
        file = self.parent / "pedido $(touch INJETADO).md"
        prompt = "--model malicious\nAção de teste $(touch INJETADO)"
        file.write_text(prompt)
        body = "TOOL=codex; choose_prompt || exit $?; build_command codex novo || exit $?; printf 'TESTARGV\\0'; printf '%s\\0' \"${COMMAND[@]}\""
        result = self.run_shell(body, '5\n2\n"' + str(file) + '"\n')
        self.assert_ok(result)
        args = result.stdout.split("TESTARGV\0", 1)[1].rstrip("\0").split("\0")
        self.assertIn(prompt, args)
        self.assertIn("--", args)
        self.assertFalse((self.root / "INJETADO").exists())

    def test_64_image_with_quoted_path_builds_explicit_attachment(self):
        file = self.parent / "imagem com espaço.png"
        file.write_bytes(b"fake image: CLI is stubbed")
        body = "TOOL=codex; choose_prompt || exit $?; build_command codex novo || exit $?; printf 'TESTARGV\\0'; printf '%s\\0' \"${COMMAND[@]}\""
        result = self.run_shell(body, '6\n2\n"' + str(file) + '"\nAnalise esta imagem\n')
        self.assert_ok(result)
        args = result.stdout.split("TESTARGV\0", 1)[1].rstrip("\0").split("\0")
        self.assertEqual(args[args.index("--image") + 1], str(file))
        self.assertIn("Analise esta imagem", args)

    def test_65_saved_prompt_is_selected_from_current_project_only(self):
        project = self.root / "Projeto da pasta atual"
        (project / "PROMPTS").mkdir(parents=True)
        (project / "PROMPTS" / "01-site.md").write_text("Construa o site desta pasta")
        (project / "PROMPTS" / "02-copia.txt").write_text("Use esta cópia")
        other = self.root / "PROMPTS de outro projeto"
        other.mkdir()
        (other / "nao-usar.md").write_text("Não pode aparecer")
        body = "PROJECT=" + shlex.quote(str(project)) + "; TOOL=codex; choose_prompt || exit $?; build_command codex novo || exit $?; printf 'TESTARGV\\0'; printf '%s\\0' \"${COMMAND[@]}\""
        result = self.run_shell(body, "3\n2\n")
        self.assert_ok(result)
        args = result.stdout.split("TESTARGV\0", 1)[1].rstrip("\0").split("\0")
        self.assertIn("Use esta cópia", args)
        self.assertNotIn("Não pode aparecer", args)

    def test_66_missing_saved_prompt_can_be_created_for_this_project(self):
        project = self.root / "Novo projeto com prompt"
        project.mkdir()
        body = "PROJECT=" + shlex.quote(str(project)) + "; TOOL=codex; choose_prompt || exit $?; build_command codex novo || exit $?; printf 'TESTARGV\\0'; printf '%s\\0' \"${COMMAND[@]}\""
        result = self.run_shell(body, "3\ns\nsite-novo\nFaça um site para esta loja\nFIM\n1\n")
        self.assert_ok(result)
        args = result.stdout.split("TESTARGV\0", 1)[1].rstrip("\0").split("\0")
        self.assertIn("Faça um site para esta loja", args)
        self.assertEqual((project / "PROMPTS" / "site-novo.md").read_text(), "Faça um site para esta loja\n")



    def managed_project(self, tool="codex"):
        project = self.parent / ("Gerenciado " + tool)
        project.mkdir(exist_ok=True)
        result = self.run_shell(
            f"PROJECT={shlex.quote(str(project))}; TOOL={tool}; prepare_project_files")
        self.assert_ok(result)
        return project

    def project_shell(self, project, body, inputs="", timeout=5):
        return self.run_shell(f"set_project {shlex.quote(str(project))} || exit $?; " + body, inputs, timeout=timeout)

    def test_67_claude_structure_has_native_import_and_no_codex_entry(self):
        result = self.run_shell("create_project", f"2\n{self.parent}\nClaude isolado\n2\n2\n\n")
        self.assert_ok(result)
        project = self.parent / "CLAUDE/Claude isolado"
        self.assertEqual((project / ".assistente-ia/tool").read_text().strip(), "claude")
        self.assertIn("@INSTRUCOES/PROJETO.md", (project / "CLAUDE.md").read_text())
        self.assertFalse((project / "AGENTS.md").exists())
        self.assertFalse((self.parent / "CODEX").exists())

    def test_68_selected_group_is_not_nested_again(self):
        for tool, choice in (("CODEX", "1"), ("CLAUDE", "2")):
            group = self.parent / tool
            group.mkdir()
            result = self.run_shell("create_project", f"2\n{group}\nMeu projeto\n{choice}\n1\n\n")
            self.assert_ok(result)
            self.assertTrue((group / "Meu projeto/.assistente-ia/tool").is_file())
            self.assertFalse((group / tool).exists())

    def test_69_saved_profile_is_reloaded_without_input(self):
        project = self.managed_project("claude")
        result = self.project_shell(project, "TOOL=codex; choose_project_tool || exit $?; [ \"$TOOL\" = claude ]")
        self.assert_ok(result)
        self.assertNotIn("Ferramenta:", result.stderr)

    def test_70_marked_project_launch_does_not_ask_for_tool(self):
        project = self.managed_project()
        result = self.project_shell(project, "launch_agent novo", "\n4\n\n")
        self.assert_ok(result)
        self.assertNotIn("Ferramenta:", result.stderr)
        calls = self.session_calls()
        self.assertEqual(len(calls), 1, self.calls())
        self.assertEqual(calls[0]["name"], "codex")
        self.assertEqual(calls[0]["cwd"], str(project))

    def test_71_legacy_migration_preserves_rules_and_prompts(self):
        project = self.parent / "Legado"
        (project / "PROMPTS").mkdir(parents=True)
        (project / "AGENTS.md").write_text("# Regra exclusiva Codex\nPreservar literalmente.\n")
        (project / "CLAUDE.md").write_text("# Regras Claude originais\n")
        (project / "PROMPTS/COMECE-AQUI.md").write_text("Pedido personalizado original\n")
        result = self.project_shell(project, "TOOL=codex; organize_project_files")
        self.assert_ok(result)
        self.assertIn("# Regra exclusiva Codex\nPreservar literalmente.\n", (project / "AGENTS.md").read_text())
        self.assertIn("INSTRUCOES/PROJETO.md", (project / "AGENTS.md").read_text())
        self.assertEqual((project / "PROMPTS/COMECE-AQUI.md").read_text(), "Pedido personalizado original\n")
        self.assertFalse((project / "CLAUDE.md").exists())
        archives = list((project / "DOCS/LEGADO").iterdir())
        self.assertEqual(len(archives), 1)
        self.assertEqual((archives[0] / "AGENTS.md.original").read_text(), "# Regra exclusiva Codex\nPreservar literalmente.\n")
        self.assertEqual((archives[0] / "CLAUDE.md.arquivado").read_text(), "# Regras Claude originais\n")
        self.assertEqual((project / ".assistente-ia/tool").read_text().strip(), "codex")
        result = self.project_shell(project, "TOOL=codex; organize_project_files")
        self.assert_ok(result)
        self.assertEqual((project / "AGENTS.md").read_text().count("<!-- assistente-ia: instrucoes-do-projeto -->"), 1)

    def test_72_cancel_migration_makes_no_project_changes(self):
        project = self.parent / "Cancelar organização"
        project.mkdir()
        (project / "AGENTS.md").write_text("original")
        result = self.project_shell(project, "organize_project", "2\n\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([p.name for p in project.iterdir()], ["AGENTS.md"])
        self.assertEqual((project / "AGENTS.md").read_text(), "original")

    def test_73_migration_refuses_symlinked_managed_paths(self):
        outside = self.parent / "Fora"
        outside.mkdir()
        (outside / "PROJETO.md").write_text("preservar")
        for relative in ("INSTRUCOES", "DOCS", "PROMPTS", ".assistente-ia"):
            with self.subTest(relative=relative):
                project = self.parent / ("Link " + relative)
                project.mkdir()
                (project / relative).symlink_to(outside, target_is_directory=True)
                result = self.project_shell(project, "TOOL=codex; organize_project_files")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(sorted(p.name for p in outside.iterdir()), ["PROJETO.md"])
                self.assertEqual((outside / "PROJETO.md").read_text(), "preservar")

    def test_74_migration_refuses_advanced_rules_without_partial_writes(self):
        for name in ("AGENTS.override.md", "CLAUDE.local.md", ".claude"):
            project = self.parent / ("Avançado " + name)
            project.mkdir()
            (project / name).write_text("customizado")
            result = self.project_shell(project, "TOOL=codex; organize_project_files")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual([p.name for p in project.iterdir()], [name])

    def test_75_instruction_edit_keeps_original_backup(self):
        project = self.managed_project()
        previous = (project / "INSTRUCOES/PROJETO.md").read_text()
        result = self.project_shell(project, "edit_instructions_terminal", "# Minhas regras\nUse português e acentuação.\nFIM\n")
        self.assert_ok(result)
        self.assertEqual((project / "INSTRUCOES/PROJETO.md").read_text().strip(), "# Minhas regras\nUse português e acentuação.")
        backups = list((project / "DOCS/BACKUPS-INSTRUCOES").glob("PROJETO.md.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), previous)

    def test_76_cancel_or_empty_instruction_edit_preserves_file(self):
        project = self.managed_project()
        previous = (project / "INSTRUCOES/PROJETO.md").read_bytes()
        for inputs in ("Rascunho\nCANCELAR\n", " \n\t\nFIM\n", "rascunho\n"):
            result = self.project_shell(project, "edit_instructions_terminal", inputs)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((project / "INSTRUCOES/PROJETO.md").read_bytes(), previous)
            self.assertFalse((project / "DOCS/BACKUPS-INSTRUCOES").exists())

    def test_77_empty_prompt_is_not_saved_or_loaded(self):
        project = self.parent / "Vazio"
        project.mkdir()
        result = self.project_shell(project, "save_prompt", "sem-conteudo\n \nFIM\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((project / "PROMPTS/sem-conteudo.md").exists())
        file = project / "vazio.md"
        file.write_text(" \n\t\n")
        result = self.project_shell(project, "load_prompt_file " + shlex.quote(str(file)))
        self.assertNotEqual(result.returncode, 0)

    def test_78_hundredth_prompt_can_be_selected(self):
        project = self.parent / "Muitos pedidos"
        (project / "PROMPTS").mkdir(parents=True)
        for i in range(1, 101):
            (project / "PROMPTS" / f"{i:03d}.md").write_text(f"Pedido {i}")
        result = self.project_shell(project, 'choose_saved_prompt || exit $?; [ "$INITIAL_PROMPT" = "Pedido 100" ]', "100\n")
        self.assert_ok(result)

    def test_79_utf8_prompt_size_uses_bytes(self):
        project = self.parent / "UTF8"
        project.mkdir()
        content = "é" * 30001
        result = self.project_shell(project, "save_prompt", "grande\n" + content + "\nFIM\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((project / "PROMPTS/grande.md").exists())
        file = project / "grande.md"
        file.write_text(content)
        result = self.project_shell(project, "load_prompt_file " + shlex.quote(str(file)))
        self.assertNotEqual(result.returncode, 0)

    def test_80_symlinked_prompt_folder_is_not_written(self):
        project = self.parent / "Prompt simbólico"
        project.mkdir()
        outside = self.parent / "Destino externo"
        outside.mkdir()
        (project / "PROMPTS").symlink_to(outside, target_is_directory=True)
        result = self.project_shell(project, "save_prompt", "novo\npedido\nFIM\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_81_group_symlink_does_not_create_project_outside_parent(self):
        outside = self.parent / "Externo"
        outside.mkdir()
        (self.parent / "CODEX").symlink_to(outside, target_is_directory=True)
        result = self.run_shell("create_project", f"2\n{self.parent}\nNovo\n1\n2\n\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_82_invalid_profile_does_not_launch(self):
        project = self.managed_project()
        (project / ".assistente-ia/tool").write_text("$(touch INJETADO)\n")
        result = self.project_shell(project, "launch_agent novo", "\n4\n\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.root / "INJETADO").exists())

    def test_83_rtk_help_is_documented(self):
        result = self.run_main("--help")
        self.assert_ok(result)
        self.assertIn("--rtk status", result.stdout)
        self.assertFalse(self.calls())

    def test_84_rtk_invalid_command_fails_without_running_tools(self):
        result = self.run_main("--rtk", "invalid-subcommand")
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.calls())

    def test_85_rtk_dispatch_routes_status_and_gains(self):
        for subcommand, handler in (("status", "rtk_status"), ("ganhos", "rtk_gains")):
            body = f"{handler}() {{ printf 'ROUTED-{subcommand}'; return 7; }}; rtk_command {subcommand}"
            result = self.run_shell(body)
            self.assertEqual(result.returncode, 7)
            self.assertEqual(result.stdout, "ROUTED-" + subcommand)
            self.assertFalse(self.calls())

    def test_86_migration_refuses_cross_tool_dependencies_without_mutation(self):
        cases = (("claude", "CLAUDE.md", "AGENTS.md"),
                 ("codex", "AGENTS.md", "CLAUDE.md"),
                 ("codex", "INSTRUCOES/PROJETO.md", "CLAUDE.md"))
        for i, (tool, referencing, opposite) in enumerate(cases):
            with self.subTest(referencing=referencing):
                project = self.parent / f"Dependência {i}"
                (project / referencing).parent.mkdir(parents=True)
                (project / referencing).write_text("@" + opposite + "\n")
                (project / opposite).write_text("Regras a preservar\n")
                before = {str(p.relative_to(project)): p.read_bytes() for p in project.rglob("*") if p.is_file()}
                result = self.project_shell(project, f"TOOL={tool}; organize_project_files")
                self.assertNotEqual(result.returncode, 0)
                after = {str(p.relative_to(project)): p.read_bytes() for p in project.rglob("*") if p.is_file()}
                self.assertEqual(after, before)
                self.assertFalse((project / "DOCS/LEGADO").exists())


    def test_87_rtk_new_readonly_commands_dispatch(self):
        for subcommand, handler in (("historico", "rtk_history"), ("verificar", "rtk_verify"), ("monitor", "rtk_monitor")):
            with self.subTest(command=subcommand):
                result = self.run_shell(f"{handler}() {{ printf 'ROUTED-{subcommand}'; return 7; }}; rtk_command {subcommand}")
                self.assertEqual(result.returncode, 7)
                self.assertEqual(result.stdout, "ROUTED-" + subcommand)
                self.assertFalse(self.calls())

    def test_88_monitor_opens_separate_terminal_with_quoted_absolute_executable(self):
        # Fake binaries: no actual Terminal window, activation or RTK process.
        rtk_file = self.bin / "rtk"
        rtk_file.write_text("#!/bin/sh\nexit 0\n")
        rtk_file.chmod(0o755)
        osa_file = self.bin / "osascript"
        osa_file.write_text("#!/bin/sh\nprintf '%s\n' \"$RTK_MONITOR_BIN\" > \"$TEST_MONITOR_LOG\"\nprintf '%s\n' \"$@\" >> \"$TEST_MONITOR_LOG\"\n")
        osa_file.chmod(0o755)
        self.env["TEST_MONITOR_LOG"] = str(self.root / "monitor.log")
        result = self.run_shell("rtk_identity() { return 0; }; bounded_capture() { CAPTURE='--watch'; return 0; }; rtk_open_monitor")
        self.assert_ok(result)
        content = (self.root / "monitor.log").read_text()
        self.assertTrue(content.startswith(str(rtk_file)))
        self.assertIn('quoted form of rtkExecutable', content)
        self.assertIn('gain --watch', content)
        self.assertFalse(self.calls())

    def test_89_monitor_does_not_open_terminal_for_unsupported_version(self):
        rtk_file = self.bin / "rtk"
        rtk_file.write_text("#!/bin/sh\nexit 0\n")
        rtk_file.chmod(0o755)
        result = self.run_shell("rtk_identity() { return 0; }; bounded_capture() { CAPTURE='--history'; return 0; }; rtk_open_monitor")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('não suporta', result.stderr)
        self.assertFalse(self.calls())


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], *remaining], verbosity=2)
