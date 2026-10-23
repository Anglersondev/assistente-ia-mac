#!/usr/bin/env python3
"""Dicas de economia e aviso de conversa longa (lib/dicas.sh), Codex e Claude."""
import json
import os
import re
import shlex
import unittest

import test_assistente as base

KIT_LIB = base.KIT / "lib" / "dicas.sh"


class TipsTests(base.AssistantTests):
    def shell(self, body, inputs="", env=None):
        if env:
            self.env.update(env)
        return self.run_shell(f"source {shlex.quote(str(KIT_LIB))}\n{body}", inputs)

    def project(self, name="Projeto longo"):
        project = self.parent / name
        project.mkdir(exist_ok=True)
        return project

    def claude_session(self, project, size, name="s1.jsonl"):
        folder = self.home / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(project))
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / name
        path.write_text("x" * size)
        return path

    def codex_session(self, project, size, name="rollout-2026-10-22T10-00-00-abc.jsonl", cwd=None):
        folder = self.home / ".codex" / "sessions" / "2026" / "10" / "22"
        folder.mkdir(parents=True, exist_ok=True)
        head = json.dumps({"type": "session_meta", "payload": {"cwd": cwd or str(project)}}, ensure_ascii=False, separators=(",", ":"))
        path = folder / name
        path.write_text(head + "\n" + "y" * size)
        return path

    def note(self, project, tool):
        result = self.shell(f"PROJECT={shlex.quote(str(project))}; TOOL={tool}; session_weight_note; echo rc=$?")
        self.assert_ok(result)
        self.assertIn("rc=0", result.stdout)
        return result.stdout

    def test_t01_tip_has_prefix_and_is_deterministic_per_day(self):
        first = self.shell("tip_of_the_day", env={"TIP_DAY": "100"})
        again = self.shell("tip_of_the_day", env={"TIP_DAY": "100"})
        self.assert_ok(first)
        self.assertTrue(first.stdout.startswith("Dica: "), first.stdout)
        self.assertEqual(first.stdout, again.stdout)
        self.assertEqual(len(first.stdout.strip().splitlines()), 1)

    def test_t02_tips_rotate_through_all_days(self):
        seen = set()
        for day in range(1, 40):
            out = self.shell("tip_of_the_day", env={"TIP_DAY": str(day)}).stdout
            self.assertTrue(out.startswith("Dica: "))
            seen.add(out)
        self.assertGreaterEqual(len(seen), 16)

    def test_t03_tip_with_invalid_day_still_prints(self):
        out = self.shell("tip_of_the_day", env={"TIP_DAY": "abc"}).stdout
        self.assertTrue(out.startswith("Dica: "), out)

    def test_t04_tips_menu_shows_four_groups_and_session_flow(self):
        result = self.shell("tips_menu")
        self.assert_ok(result)
        for group in ("ECONOMIA", "QUALIDADE", "CONVERSAS LONGAS", "PROJETO"):
            self.assertIn(group, result.stdout)
        self.assertIn("Encerrar com resumo", result.stdout)
        self.assertIn("Continuar o trabalho", result.stdout)

    def test_t05_claude_small_session_is_silent(self):
        project = self.project()
        self.claude_session(project, 1000)
        self.assertEqual(self.note(project, "claude").replace("rc=0", "").strip(), "")

    def test_t06_claude_medium_session_light_warning(self):
        project = self.project()
        self.claude_session(project, 700000)
        out = self.note(project, "claude")
        self.assertIn("ficando grande", out)
        self.assertIn("estimativa", out)
        self.assertNotIn("xxxx", out)

    def test_t07_claude_large_session_strong_warning(self):
        project = self.project()
        self.claude_session(project, 2000000)
        out = self.note(project, "claude")
        self.assertIn("conversa muito longa", out)
        self.assertIn("Encerrar com resumo", out)
        self.assertIn("/compact", out)
        self.assertIn("MB", out)

    def test_t08_claude_uses_most_recent_session(self):
        project = self.project()
        old = self.claude_session(project, 2000000, "velha.jsonl")
        new = self.claude_session(project, 1000, "nova.jsonl")
        os.utime(old, (1000, 1000))
        os.utime(new, (2000, 2000))
        self.assertNotIn("longa", self.note(project, "claude"))

    def test_t09_codex_matches_project_by_cwd(self):
        project = self.project()
        self.codex_session(project, 2000000)
        out = self.note(project, "codex")
        self.assertIn("conversa muito longa", out)

    def test_t10_codex_ignores_other_projects(self):
        project = self.project()
        self.codex_session(project, 2000000, cwd=str(self.parent / "Outro projeto"))
        self.assertEqual(self.note(project, "codex").replace("rc=0", "").strip(), "")

    def test_t11_no_session_is_silent_and_ok(self):
        project = self.project()
        for tool in ("claude", "codex"):
            self.assertEqual(self.note(project, tool).replace("rc=0", "").strip(), "")

    def test_t12_symlinked_session_file_is_refused(self):
        project = self.project()
        real = self.root / "real.jsonl"
        real.write_text("x" * 2000000)
        folder = self.home / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(project))
        folder.mkdir(parents=True)
        (folder / "link.jsonl").symlink_to(real)
        self.assertNotIn("longa", self.note(project, "claude"))

    def test_t13_symlinked_codex_session_is_refused(self):
        project = self.project()
        real = self.root / "rollout-real.jsonl"
        real.write_text(json.dumps({"payload": {"cwd": str(project)}}, ensure_ascii=False, separators=(",", ":")) + "y" * 2000000)
        folder = self.home / ".codex" / "sessions" / "2026" / "10" / "22"
        folder.mkdir(parents=True)
        (folder / "rollout-link.jsonl").symlink_to(real)
        self.assertNotIn("longa", self.note(project, "codex"))

    def test_t14_symlinked_projects_root_is_refused(self):
        project = self.project()
        real = self.root / "realprojects"
        folder = real / re.sub(r"[^A-Za-z0-9]", "-", str(project))
        folder.mkdir(parents=True)
        (folder / "s.jsonl").write_text("x" * 2000000)
        (self.home / ".claude").mkdir()
        (self.home / ".claude" / "projects").symlink_to(real)
        self.assertNotIn("longa", self.note(project, "claude"))

    def test_t15_never_prints_session_content(self):
        project = self.project()
        path = self.claude_session(project, 10)
        path.write_text("SEGREDO-NAO-IMPRIMIR " * 100000)
        out = self.note(project, "claude")
        self.assertNotIn("SEGREDO", out)

    def test_t16_unknown_tool_or_missing_project_is_ok(self):
        result = self.shell("PROJECT=''; TOOL=''; session_weight_note; echo rc=$?")
        self.assert_ok(result)
        self.assertIn("rc=0", result.stdout)


    def line(self, project, tool):
        result = self.shell(f"PROJECT={shlex.quote(str(project))}; TOOL={tool}; session_weight_line; echo rc=$?")
        self.assert_ok(result)
        self.assertIn("rc=0", result.stdout)
        return result.stdout.replace("rc=0", "").strip()

    def test_t17_line_light_both_tools(self):
        project = self.project()
        self.claude_session(project, 200000)
        self.codex_session(project, 200000)
        for tool in ("claude", "codex"):
            self.assertEqual(self.line(project, tool), "Conversa: ✓ leve (0,1 MB)")

    def test_t18_line_getting_long(self):
        project = self.project()
        self.claude_session(project, 800000)
        self.codex_session(project, 800000)
        for tool in ("claude", "codex"):
            out = self.line(project, tool)
            self.assertTrue(out.startswith("Conversa: ⚠ ficando longa ("), out)
            self.assertTrue(out.endswith("MB) — considere encerrar"), out)
            self.assertEqual(len(out.splitlines()), 1)

    def test_t19_line_very_long(self):
        project = self.project()
        self.claude_session(project, 1800000)
        self.codex_session(project, 1800000)
        for tool in ("claude", "codex"):
            out = self.line(project, tool)
            self.assertEqual(out, "Conversa: ⛔ muito longa (1,7 MB) — use Encerrar com resumo")

    def test_t20_line_without_session(self):
        project = self.project()
        for tool in ("claude", "codex"):
            self.assertEqual(self.line(project, tool), "Conversa: nenhuma ainda neste projeto")

    def test_t21_line_cannot_measure_for_unknown_tool(self):
        project = self.project()
        self.assertEqual(self.line(project, "outra"), "Conversa: não consegui medir")

    def test_t22_line_without_project_prints_nothing(self):
        result = self.shell("PROJECT=''; TOOL=claude; session_weight_line; echo rc=$?")
        self.assert_ok(result)
        self.assertEqual(result.stdout.strip(), "rc=0")

    def test_t23_line_refuses_symlinks_and_never_prints_content(self):
        project = self.project()
        real = self.root / "real.jsonl"
        real.write_text("SEGREDO-NAO-IMPRIMIR " * 100000)
        folder = self.home / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(project))
        folder.mkdir(parents=True)
        (folder / "link.jsonl").symlink_to(real)
        self.assertEqual(self.line(project, "claude"), "Conversa: nenhuma ainda neste projeto")
        path = self.claude_session(project, 10)
        path.write_text("SEGREDO-NAO-IMPRIMIR " * 100000)
        out = self.line(project, "claude")
        self.assertNotIn("SEGREDO", out)
        self.assertTrue(out.startswith("Conversa: ⛔ muito longa"), out)

    def test_t24_codex_line_ignores_other_projects(self):
        project = self.project()
        self.codex_session(project, 2000000, cwd=str(self.parent / "Outro projeto"))
        self.assertEqual(self.line(project, "codex"), "Conversa: nenhuma ainda neste projeto")

    def test_t25_context_tips_are_cautious_and_claude_only(self):
        menu = self.shell("tips_menu").stdout
        self.assertIn("/context mostra quanto da conversa já foi usado", menu)
        self.assertIn("/statusline", menu)
        self.assertIn("No Codex não há comando para isso", menu)
        tips = "".join(self.shell("tip_of_the_day", env={"TIP_DAY": str(d)}).stdout for d in range(1, 40))
        self.assertIn("/context", tips)
        self.assertIn("No Claude Code, /context", tips)

    def test_t26_note_behaviour_unchanged_with_shared_measure(self):
        project = self.project()
        self.claude_session(project, 700000)
        self.assertIn("ficando grande", self.note(project, "claude"))
        self.claude_session(project, 2000000, "grande.jsonl")
        self.assertIn("conversa muito longa", self.note(project, "claude"))


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(TipsTests, _name, None)

if __name__ == "__main__":
    unittest.main()
