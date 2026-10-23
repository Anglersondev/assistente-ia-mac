#!/usr/bin/env python3
"""Painel de uso por projeto (usage_measure, project_usage_line, usage_panel)."""
import json
import os
import re
import shlex
import subprocess
import time
import unittest

import test_assistente as base

PAINEL = base.KIT / "lib" / "painel.sh"


def dumps(obj):
    """Compacto e em UTF-8, como nos arquivos reais das ferramentas."""
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


def collapse(path):
    return re.sub(r"-+", "-", re.sub(r"[^A-Za-z0-9]", "-", str(path)))


class PainelTests(base.AssistantTests):
    # ---------- sessões falsas ----------
    def claude_dir(self, project):
        d = self.home / ".claude" / "projects" / collapse(project)
        d.mkdir(parents=True, exist_ok=True)
        return d

    def claude_session(self, project, tokens, users=3, name="s1.jsonl", extra=""):
        lines = [dumps({"type": "summary"})]
        for i in range(users):
            lines.append(dumps({"type": "user", "message": {"role": "user", "content": f"pedido {i} {extra}"}}))
            lines.append(dumps({"type": "user", "message": {"role": "user", "content": [{"type": "tool_result", "content": "ok"}]}}))
            lines.append(dumps({"type": "assistant", "isSidechain": False, "message": {"role": "assistant", "usage": {
                "input_tokens": 2, "cache_creation_input_tokens": 100, "cache_read_input_tokens": 1000 * (i + 1),
                "output_tokens": 30, "output_tokens_details": {"thinking_tokens": 0}}}}))
        rest = tokens - 2 - 100
        lines.append(dumps({"type": "assistant", "isSidechain": False, "message": {"role": "assistant", "usage": {
            "input_tokens": 2, "cache_creation_input_tokens": 100, "cache_read_input_tokens": rest,
            "output_tokens": 30, "output_tokens_details": {"thinking_tokens": 0}}}}))
        path = self.claude_dir(project) / name
        path.write_text("\n".join(lines) + "\n")
        return path

    def codex_session(self, project, tokens, turns=2, window=258400, name="rollout-a.jsonl", day="22"):
        d = self.home / ".codex" / "sessions" / "2026" / "10" / day
        d.mkdir(parents=True, exist_ok=True)
        lines = [dumps({"type": "session_meta", "payload": {"cwd": str(project)}})]
        for _ in range(turns):
            lines.append(dumps({"type": "event_msg", "payload": {"type": "task_started"}}))
        lines.append(dumps({"type": "event_msg", "payload": {"type": "token_count", "info": {
            "total_token_usage": {"input_tokens": tokens * 5},
            "last_token_usage": {"input_tokens": tokens, "output_tokens": 3},
            "model_context_window": window}}}))
        path = d / name
        path.write_text("\n".join(lines) + "\n")
        return path

    def make_project(self, name, tool):
        project = self.parent / name
        project.mkdir(exist_ok=True)
        (project / ".assistente-ia").mkdir(exist_ok=True)
        (project / ".assistente-ia" / "tool").write_text(tool + "\n")
        return project

    def shell(self, body, project=None, tool="claude", inputs=""):
        pre = f"source {shlex.quote(str(PAINEL))}; "
        if project is not None:
            pre += f"PROJECT={shlex.quote(str(project))}; TOOL={tool}; "
        return self.run_shell(pre + body, inputs)

    def line(self, project, tool):
        result = self.shell("project_usage_line", project, tool)
        self.assert_ok(result)
        return result.stdout

    def recents(self, *projects):
        self.state.mkdir(parents=True, exist_ok=True)
        (self.state / "recents").write_text("".join(f"{p}\n" for p in projects))

    # ---------- testes ----------
    def test_p01_claude_light(self):
        project = self.make_project("Projeto Ação é", "claude")
        self.claude_session(project, 35000, users=3)
        out = self.line(project, "claude")
        self.assertIn("Conversa: ✓ leve", out)
        self.assertIn("~35 mil tokens", out)
        self.assertIn("3 mensagens", out)
        self.assertIn("hoje", out)
        self.assertNotIn("estimativa", out)

    def test_p02_claude_getting_long(self):
        project = self.make_project("Longa", "claude")
        self.claude_session(project, 120000)
        out = self.line(project, "claude")
        self.assertIn("ficando longa", out)
        self.assertIn("~120 mil tokens", out)

    def test_p03_claude_very_long(self):
        project = self.make_project("Muito longa", "claude")
        self.claude_session(project, 259000)
        out = self.line(project, "claude")
        self.assertIn("Conversa: ⛔ muito longa", out)
        self.assertIn("Encerrar com resumo", out)

    def test_p04_codex_shows_window_percent_and_turns(self):
        project = self.make_project("Codex proj", "codex")
        self.codex_session(project, 25840, turns=4)
        out = self.line(project, "codex")
        self.assertIn("10% da janela", out)
        self.assertIn("4 mensagens", out)
        self.assertIn("Conversa: ✓ leve", out)

    def test_p05_no_session(self):
        project = self.make_project("Sem conversa", "claude")
        self.assertIn("nenhuma ainda", self.line(project, "claude"))
        self.assertIn("nenhuma ainda", self.line(project, "codex"))

    def test_p06_symlinked_session_file_is_refused(self):
        project = self.make_project("Com link", "claude")
        real = self.root / "real.jsonl"
        real.write_text(dumps({"type": "assistant", "message": {"usage": {
            "input_tokens": 1, "cache_creation_input_tokens": 1, "cache_read_input_tokens": 250000}}}) + "\n")
        os.symlink(real, self.claude_dir(project) / "link.jsonl")
        self.assertIn("nenhuma ainda", self.line(project, "claude"))

    def test_p07_symlinked_projects_root_is_refused(self):
        project = self.make_project("Raiz link", "claude")
        self.claude_session(project, 50000)
        real = self.home / ".claude" / "projects"
        moved = self.home / ".claude" / "projects-real"
        real.rename(moved)
        os.symlink(moved, real)
        self.assertIn("nenhuma ainda", self.line(project, "claude"))

    def test_p08_estimate_when_no_usage_record(self):
        project = self.make_project("Sem usage", "claude")
        (self.claude_dir(project) / "s.jsonl").write_text(
            (dumps({"type": "user", "message": {"role": "user", "content": "x" * 100}}) + "\n") * 5000)
        out = self.line(project, "claude")
        self.assertIn("(estimativa)", out)
        self.assertIn("mensagens", out)

    def test_p09_message_count_ignores_tool_results(self):
        project = self.make_project("Contagem", "claude")
        self.claude_session(project, 20000, users=7)
        self.assertIn("7 mensagens", self.line(project, "claude"))

    def test_p10_never_prints_conversation_content(self):
        project = self.make_project("Sigilo", "claude")
        self.claude_session(project, 20000, extra="SEGREDO-DA-CONVERSA-123")
        out = self.line(project, "claude") + self.shell("usage_panel", project, "claude").stdout
        self.assertNotIn("SEGREDO", out)

    def test_p11_panel_orders_heaviest_first_and_skips_missing(self):
        leve = self.make_project("Projeto leve", "claude")
        pesado = self.make_project("Projeto pesado", "codex")
        medio = self.make_project("Projeto médio", "claude")
        vazio = self.make_project("Projeto vazio", "claude")
        self.claude_session(leve, 30000)
        self.codex_session(pesado, 230000)
        self.claude_session(medio, 120000)
        self.recents(leve, pesado, self.parent / "apagado", medio, vazio)
        result = self.shell("usage_panel")
        self.assert_ok(result)
        out = result.stdout
        order = [out.index(n) for n in ("Projeto pesado", "Projeto médio", "Projeto leve", "Projeto vazio")]
        self.assertEqual(order, sorted(order), out)
        self.assertNotIn("apagado", out)
        self.assertIn("⛔ Projeto pesado", out)
        self.assertIn("⚠ Projeto médio", out)
        self.assertIn("✓ Projeto leve", out)
        self.assertIn("nenhuma conversa ainda", out)
        self.assertIn("Legenda", out)
        self.assertIn("Continuar o trabalho", out)

    def test_p12_panel_without_recents_is_friendly(self):
        out = self.shell("usage_panel").stdout
        self.assertIn("Painel de uso dos projetos", out)
        self.assertIn("Ainda não há projetos recentes", out)

    def test_p13_project_without_tool_is_flagged(self):
        project = self.parent / "Sem ferramenta"
        project.mkdir()
        self.recents(project)
        out = self.shell("usage_panel").stdout
        self.assertIn("sem ferramenta definida", out)

    def test_p14_no_project_prints_nothing_and_returns_zero(self):
        result = self.shell("PROJECT=''; project_usage_line; usage_measure claude ''; echo rc=$?")
        self.assert_ok(result)
        self.assertEqual(result.stdout.strip(), "rc=0")

    def test_p15_measure_sets_variables(self):
        project = self.make_project("Variaveis", "codex")
        self.codex_session(project, 90000, turns=3)
        result = self.shell(
            f"usage_measure codex {shlex.quote(str(project))}; "
            "echo \"$USAGE_STATE|$USAGE_TOKENS|$USAGE_WINDOW|$USAGE_MSGS\"")
        self.assert_ok(result)
        self.assertIn("longa|90000|258400|3", result.stdout)

    def test_p16_most_recent_session_wins(self):
        project = self.make_project("Duas sessoes", "claude")
        old = self.claude_session(project, 150000, name="velha.jsonl")
        past = time.time() - 3600
        os.utime(old, (past, past))
        self.claude_session(project, 10000, name="nova.jsonl")
        self.assertIn("Conversa: ✓ leve", self.line(project, "claude"))

    # ---------- arquivo da barra de status (fonte principal do Claude) ----------
    def status_file(self, project, tokens=None, window=None, percent=None, when=None, extra=""):
        key = subprocess.run(f"printf '%s' {shlex.quote(str(project).rstrip('/'))} | cksum | cut -d' ' -f1",
                             shell=True, capture_output=True, text=True).stdout.strip()
        d = self.state / "usage"
        d.mkdir(parents=True, exist_ok=True)
        lines = []
        if tokens is not None:
            lines.append(f"tokens={tokens}")
        if window is not None:
            lines.append(f"window={window}")
        if percent is not None:
            lines.append(f"percent={percent}")
        lines.append(f"when={int(time.time()) if when is None else when}")
        lines.append("session=abc")
        path = d / f"claude-{key}.txt"
        path.write_text("\n".join(lines) + "\n" + extra)
        return path

    def test_s01_statusline_is_exact_and_needs_no_transcript(self):
        project = self.make_project("Barra exata", "claude")
        self.status_file(project, tokens=150000, window=1000000, percent=15)
        out = self.line(project, "claude")
        self.assertIn("ficando longa", out)
        self.assertIn("~150 mil tokens", out)
        self.assertIn("15% da janela", out)
        self.assertNotIn("estimativa", out)

    def test_s02_statusline_wins_over_transcript(self):
        project = self.make_project("Barra vence", "claude")
        self.claude_session(project, 10000, users=4)
        self.status_file(project, tokens=230000, window=1000000)
        out = self.line(project, "claude")
        self.assertIn("muito longa", out)
        self.assertIn("~230 mil tokens", out)
        self.assertIn("4 mensagens", out)

    def test_s03_stale_statusline_falls_back_to_transcript(self):
        project = self.make_project("Barra velha", "claude")
        self.claude_session(project, 40000)
        self.status_file(project, tokens=230000, when=int(time.time()) - 31 * 86400)
        out = self.line(project, "claude")
        self.assertIn("Conversa: ✓ leve", out)
        self.assertIn("~40 mil tokens", out)

    def test_s04_status_file_is_data_never_code(self):
        project = self.make_project("Barra maliciosa", "claude")
        marker = self.root / "executou"
        self.claude_session(project, 40000)
        self.status_file(project, tokens="$(touch %s)" % marker, extra="`touch %s`\n" % marker)
        out = self.line(project, "claude")
        self.assertFalse(marker.exists())
        self.assertIn("~40 mil tokens", out)

    def test_s05_symlinked_status_file_and_dir_are_refused(self):
        project = self.make_project("Barra link", "claude")
        self.claude_session(project, 40000)
        real = self.status_file(project, tokens=230000)
        keep = self.root / "real-status.txt"
        real.rename(keep)
        os.symlink(keep, real)
        self.assertIn("~40 mil tokens", self.line(project, "claude"))
        real.unlink()
        keep.rename(real)
        moved = self.state / "usage-real"
        (self.state / "usage").rename(moved)
        os.symlink(moved, self.state / "usage")
        self.assertIn("~40 mil tokens", self.line(project, "claude"))

    def test_s06_percent_without_window_is_shown(self):
        project = self.make_project("Barra percent", "claude")
        self.status_file(project, tokens=60000, percent="31.7")
        out = self.line(project, "claude")
        self.assertIn("31% da janela", out)
        self.assertIn("Conversa: ✓ leve", out)

    def test_s07_transcript_without_usage_is_estimate(self):
        project = self.make_project("Formato mudou", "claude")
        (self.claude_dir(project) / "s.jsonl").write_text(
            (dumps({"type": "assistant", "message": {"novo_campo": {"tokens": 5}}}) + "\n") * 4000)
        out = self.line(project, "claude")
        self.assertIn("(estimativa)", out)

    def test_s08_trailing_slash_uses_same_key(self):
        project = self.make_project("Barra barra", "claude")
        self.status_file(project, tokens=99000)
        result = self.shell(f"PROJECT={shlex.quote(str(project) + '/')}; TOOL=claude; usage_measure claude {shlex.quote(str(project))}; echo \"$USAGE_TOKENS|$USAGE_SOURCE\"")
        self.assert_ok(result)
        self.assertIn("99000|statusline", result.stdout)

    def test_s09_codex_ignores_claude_status_file(self):
        project = self.make_project("Codex sem barra", "codex")
        self.status_file(project, tokens=230000)
        self.codex_session(project, 20000)
        out = self.line(project, "codex")
        self.assertIn("Conversa: ✓ leve", out)
        self.assertIn("~20 mil tokens", out)

    def test_s10_panel_uses_statusline_numbers(self):
        project = self.make_project("Painel barra", "claude")
        self.status_file(project, tokens=210000, window=1000000)
        self.recents(project)
        out = self.shell("usage_panel").stdout
        self.assertIn("⛔ Painel barra", out)
        self.assertIn("~210 mil tokens", out)

    def test_s11_invalid_numbers_are_rejected(self):
        project = self.make_project("Barra invalida", "claude")
        self.claude_session(project, 40000)
        self.status_file(project, tokens="abc", window="x", percent="y")
        self.assertIn("~40 mil tokens", self.line(project, "claude"))

    # ---------- rodada de ajustes (auditoria e usabilidade) ----------
    def test_s12_measurement_off_reads_nothing(self):
        project = self.make_project("Sem medir", "claude")
        self.claude_session(project, 230000)
        self.status_file(project, tokens=230000)
        self.recents(project)
        self.assert_ok(self.run_shell("opt_flip peso"))
        pre = "source %s; opt_enabled() { [ ! -e \"$STATE_DIR/opt-$1-off\" ]; }; " % shlex.quote(str(PAINEL))
        line = self.run_shell(pre + f"PROJECT={shlex.quote(str(project))}; TOOL=claude; project_usage_line")
        self.assert_ok(line)
        self.assertEqual(line.stdout.strip(), "Medição de uso desligada (Ajuda e ajustes → 4)")
        panel = self.run_shell(pre + "usage_panel")
        self.assert_ok(panel)
        self.assertIn("Medição de uso desligada (Ajuda e ajustes → 4)", panel.stdout)
        self.assertNotIn("⛔", panel.stdout)

    def test_s13_statusline_older_than_transcript_is_ignored(self):
        project = self.make_project("Barra atrasada", "claude")
        session = self.claude_session(project, 40000)
        self.status_file(project, tokens=230000, when=int(time.time()) - 3600)
        os.utime(session, (time.time(), time.time()))
        out = self.line(project, "claude")
        self.assertIn("~40 mil tokens", out)
        self.assertNotIn("230", out)

    def test_s14_statusline_within_tolerance_is_used(self):
        project = self.make_project("Barra quase", "claude")
        session = self.claude_session(project, 40000)
        self.status_file(project, tokens=230000, when=int(time.time()) - 120)
        os.utime(session, (time.time(), time.time()))
        self.assertIn("~230 mil tokens", self.line(project, "claude"))

    def test_s15_zero_tokens_means_new_conversation(self):
        project = self.make_project("Conversa limpa", "claude")
        self.status_file(project, tokens=0, window=1000000)
        out = self.line(project, "claude")
        self.assertIn("conversa nova", out)
        self.assertNotIn("0 tokens", out)
        self.assertIn("✓ leve", out)

    def test_s16_huge_and_padded_numbers_never_break_or_look_light(self):
        project = self.make_project("Numeros ruins", "claude")
        self.status_file(project, tokens="99999999999999999999", window="000000000000000000200000")
        result = self.shell("project_usage_line", project, "claude")
        self.assert_ok(result)
        self.assertNotIn("✓ leve", result.stdout)
        self.assertNotIn("value too great", result.stderr + result.stdout)
        self.assertIn("não consegui medir", result.stdout)
        self.status_file(project, tokens="0000000035", window="0200000")
        out = self.line(project, "claude")
        self.assertIn("~35 tokens", out)
        self.assertIn("0% da janela", out)

    def test_s17_octal_looking_numbers_do_not_error(self):
        project = self.make_project("Octal", "claude")
        self.status_file(project, tokens="08", window="09", percent="010", when=None)
        result = self.shell("project_usage_line", project, "claude")
        self.assert_ok(result)
        self.assertEqual(result.stderr.strip(), "", result.stderr)
        self.assertIn("Conversa:", result.stdout)

    def test_s18_window_zero_is_ignored_and_percent_used(self):
        project = self.make_project("Janela zero", "claude")
        self.status_file(project, tokens=60000, window=0, percent="31")
        out = self.line(project, "claude")
        self.assertIn("31% da janela", out)

    def test_s19_all_trailing_slashes_are_removed(self):
        project = self.make_project("Barras", "claude")
        self.status_file(project, tokens=99000)
        result = self.shell(f"usage_measure claude {shlex.quote(str(project) + '///')}; echo \"$USAGE_TOKENS|$USAGE_SOURCE\"")
        self.assert_ok(result)
        self.assertIn("99000|statusline", result.stdout)

    def test_s20_corrupt_transcript_numbers_do_not_print_arithmetic_errors(self):
        project = self.make_project("Transcript ruim", "claude")
        line = dumps({"type": "assistant", "message": {"usage": {
            "input_tokens": 99999999999999999999, "cache_creation_input_tokens": 1, "cache_read_input_tokens": 2}}})
        (self.claude_dir(project) / "s.jsonl").write_text(line + "\n")
        result = self.shell("project_usage_line", project, "claude")
        self.assert_ok(result)
        self.assertNotIn("value too great", result.stderr + result.stdout)
        self.assertNotIn("✓ leve — ~0", result.stdout)

    def test_s21_legend_and_icons_are_friendly(self):
        project = self.make_project("Legenda", "claude")
        self.claude_session(project, 230000)
        self.recents(project)
        out = self.shell("usage_panel").stdout
        self.assertIn("Continuar o trabalho", out)
        self.assertNotIn("prompt CONTINUAR", out)
        self.assertNotIn("Conversa: Conversa", self.line(project, "claude"))
        self.assertTrue(self.line(project, "claude").startswith("Conversa: ⛔ muito longa"))


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(PainelTests, _name, None)

if __name__ == "__main__":
    unittest.main()
