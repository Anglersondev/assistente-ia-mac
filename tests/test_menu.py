#!/usr/bin/env python3
"""Menu principal amigável: painel, itens 1–7, encerrar com resumo, projetos e ajustes."""
import unittest

import test_assistente as base


class MenuTests(base.AssistantTests):
    def with_project(self, tool="codex"):
        project = self.managed_project(tool)
        self.assert_ok(self.project_shell(project, "true"))
        return project

    def test_m01_panel_shows_project_tool_and_all_items(self):
        project = self.with_project("codex")
        out = self.run_main(input_text="0\n").stdout
        for text in ("Projeto:", project.name, "Pasta:", "Ferramenta:  Codex", "O QUE VOCÊ QUER FAZER?",
                     "1) Continuar de onde parei", "2) Começar uma conversa nova",
                     "3) Encerrar com resumo", "4) Painel de uso dos projetos",
                     "5) Projetos: trocar, abrir ou criar", "6) Cuidar do projeto",
                     "7) Ajuda e ajustes", "0) Sair"):
            self.assertIn(text, out)

    def test_m02_panel_without_project_invites_to_start(self):
        out = self.run_main(input_text="0\n").stdout
        self.assertIn("Vamos começar", out)
        self.assertNotIn("Pasta:", out)

    def test_m03_panel_shows_claude_name(self):
        self.with_project("claude")
        self.assertIn("Ferramenta:  Claude Code", self.run_main(input_text="0\n").stdout)

    def test_m04_new_conversation_from_menu(self):
        self.with_project("codex")
        result = self.run_main(input_text="2\n\n4\n\n\n0\n", timeout=12)
        self.assert_ok(result)
        self.assertEqual(len(self.session_calls()), 1, self.calls())

    def test_m05_close_with_summary_sends_prompt_codex(self):
        project = self.with_project("codex")
        result = self.run_main(input_text="3\n\n\n0\n", timeout=12)
        self.assert_ok(result)
        calls = self.session_calls()
        self.assertEqual(len(calls), 1, self.calls())
        self.assertEqual(calls[0]["args"][:2], ["resume", "--last"])
        text = (project / "PROMPTS/ENCERRAR-SESSAO.md").read_text().strip()
        self.assertIn(text, calls[0]["args"])
        self.assertEqual(calls[0]["args"][calls[0]["args"].index(text) - 1], "--")
        self.assertIn("digite: leia PROMPTS/ENCERRAR-SESSAO.md", result.stdout + result.stderr)

    def test_m06_close_with_summary_sends_prompt_claude(self):
        project = self.with_project("claude")
        result = self.run_main(input_text="3\n\n\n0\n", timeout=12)
        self.assert_ok(result)
        calls = self.session_calls()
        self.assertEqual(len(calls), 1, self.calls())
        self.assertIn("--continue", calls[0]["args"])
        self.assertIn((project / "PROMPTS/ENCERRAR-SESSAO.md").read_text().strip(), calls[0]["args"])

    def test_m07_close_offers_to_create_missing_prompt(self):
        project = self.with_project("codex")
        (project / "PROMPTS/ENCERRAR-SESSAO.md").unlink()
        result = self.run_main(input_text="3\n\n\n\n0\n", timeout=12)
        self.assert_ok(result)
        self.assertTrue((project / "PROMPTS/ENCERRAR-SESSAO.md").exists())
        self.assertEqual(len(self.session_calls()), 1, self.calls())

    def test_m08_close_cancel_never_starts_agent(self):
        self.with_project("codex")
        self.run_main(input_text="3\n0\n\n0\n", timeout=12)
        self.assertEqual(self.session_calls(), [])

    def test_m09_items_needing_project_open_project_chooser(self):
        for item in ("1", "2", "3", "4", "6"):
            with self.subTest(item=item):
                result = self.run_main(input_text=f"{item}\n0\n\n0\n")
                self.assertIn("Primeiro escolha ou crie um projeto", result.stdout + result.stderr)
                self.assertIn("Projetos: trocar, abrir ou criar", result.stdout)
        self.assertEqual(self.session_calls(), [])

    def test_m10_projects_menu_open_folder_without_starting(self):
        project = self.parent / "Pasta existente"
        project.mkdir()
        result = self.run_main(input_text=f"5\n2\n2\n{project}\nn\n\n0\n")
        self.assert_ok(result)
        self.assertEqual(self.session_calls(), [])
        self.assertIn(str(project), self.run_main(input_text="0\n").stdout)

    def test_m11_projects_menu_offers_conversation_after_picking(self):
        project = self.managed_project("codex")
        result = self.run_main(input_text=f"5\n2\n2\n{project}\n\n\n4\n\n\n0\n", timeout=12)
        self.assert_ok(result)
        self.assertIn("Começar uma conversa agora?", result.stdout + result.stderr)
        self.assertEqual(len(self.session_calls()), 1, self.calls())

    def test_m12_settings_menu_lists_everything(self):
        out = self.run_shell("settings_menu", "0\n").stdout
        for text in ("1) Contas e login", "2) RTK", "3) Dicas para economizar uso da conversa",
                     "4) Preferências", "5) Instalação e diagnóstico", "6) Como funciona em 4 passos",
                     "7) Aviso de uso dentro do chat do Claude", "0) Voltar ao menu"):
            self.assertIn(text, out)

    def test_m13_settings_preferences_reach_control_menu(self):
        result = self.run_shell("settings_menu", "4\n0\n0\n")
        self.assert_ok(result)
        self.assertIn("Preferências e controle", result.stdout)

    def test_m14_settings_statusline_missing_is_explained(self):
        result = self.run_shell("unset -f statusline_menu; settings_menu", "7\n\n0\n")
        self.assertIn("ainda não instalado", result.stdout + result.stderr)

    def test_m15_settings_statusline_calls_library_when_present(self):
        result = self.run_shell("statusline_menu() { echo STATUSLINE-OK; }; settings_menu", "7\n\n0\n")
        self.assertIn("STATUSLINE-OK", result.stdout)

    def test_m16_guide_has_four_steps(self):
        out = self.run_shell("show_guide", "\n").stdout
        for n in ("1.", "2.", "3.", "4."):
            self.assertIn(n, out)
        self.assertIn("Encerrar com resumo", out)

    def test_m17_usage_panel_item_calls_library(self):
        project = self.with_project("codex")
        result = self.project_shell(project, "usage_panel() { echo PAINEL-X; }; main", "4\n\n0\n")
        self.assertIn("PAINEL-X", result.stdout)

    def test_m18_panel_shows_conversation_line(self):
        project = self.with_project("codex")
        result = self.project_shell(
            project, "session_weight_line() { echo 'Conversa: leve (0,2 MB)'; }; unset -f project_usage_line; main", "0\n")
        self.assertIn("Conversa:    leve (0,2 MB)", result.stdout)

    def test_m19_enter_does_nothing_when_shortcut_is_off(self):
        self.with_project("codex")
        self.assert_ok(self.run_shell("opt_flip atalho"))
        result = self.run_main(input_text="\n0\n")
        self.assertEqual(self.session_calls(), [], self.calls())
        self.assertIn("Escolha uma opção de 0 a 8", result.stdout + result.stderr)

    def test_m20_new_conversation_default_continues_the_work(self):
        project = self.managed_project("codex")
        body = ("PROJECT=" + base.shlex.quote(str(project)) +
                "; TOOL=codex; choose_prompt || exit $?; build_command codex novo || exit $?; "
                "printf 'TESTARGV\\0'; printf '%s\\0' \"${COMMAND[@]}\"")
        (project / "DOCS/ANDAMENTO.md").write_text("# Andamento\n\n- Home publicada; falta revisar o SEO.\n")
        for answers in ("\n", "1\n"):
            result = self.run_shell(body, answers)
            self.assert_ok(result)
            args = result.stdout.split("TESTARGV\0", 1)[1].rstrip("\0").split("\0")
            self.assertIn((project / "PROMPTS/CONTINUAR.md").read_text().strip(), args)

    def test_m21_continue_option_without_file_is_refused(self):
        project = self.managed_project("codex")
        (project / "PROMPTS/CONTINUAR.md").unlink()
        result = self.project_shell(project, "TOOL=codex; choose_prompt", "1\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("indisponível", result.stdout)

    def test_m22_care_menu_is_grouped_and_keeps_numbers(self):
        project = self.with_project("codex")
        out = self.project_shell(project, "project_tools", "0\n").stdout
        for text in ("INSTRUÇÕES E PEDIDOS PRONTOS", "ARQUIVOS", "OUTROS", " 9) Editar as instruções permanentes",
                     "12) Verificar se a pasta está organizada", "11) Organizar um projeto antigo"):
            self.assertIn(text, out)

    def test_m23_menu_five_is_projects_and_six_is_care(self):
        project = self.with_project("codex")
        result = self.run_main(input_text="6\n0\n\n0\n")
        self.assertIn("Cuidar do projeto", result.stdout)
        self.assertIn("INSTRUÇÕES E PEDIDOS PRONTOS", result.stdout)


    # ---- Rodada de usabilidade ----
    def cmd_stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)
        return path

    def test_m24_rule_and_wrap_follow_terminal_width(self):
        for columns, expected in (("60", 58), ("200", 74), ("20", 54)):
            with self.subTest(columns=columns):
                self.env["COLUMNS"] = columns
                out = self.run_shell("rule; wrap 'palavra ' 'outra palavra comprida para quebrar a linha em varias partes de texto simples e claro'").stdout
                rule = [l for l in out.splitlines() if "─" in l][0]
                self.assertEqual(len(rule), expected)
                for line in out.splitlines():
                    self.assertLessEqual(len(line), int(columns) if int(columns) >= 56 else 56, line)

    def test_m25_first_conversation_offers_default_settings(self):
        project = self.managed_project("codex")
        result = self.project_shell(project, "launch_agent novo", "\n4\n\n")
        self.assert_ok(result)
        out = result.stdout + result.stderr
        for text in ("Passo 1 de 4", "Passo 2 de 4", "Passo 3 de 4", "Passo 4 de 4",
                     "Ajustar modelo e esforço? [s/N]", "Modelo = qual IA responde"):
            self.assertIn(text, out)
        self.assertNotIn("Escolher modelo", out)

    def test_m26_first_conversation_can_adjust_model_and_effort(self):
        project = self.managed_project("codex")
        result = self.project_shell(project, "launch_agent novo", "s\n\n\n1\n4\n\n")
        out = result.stdout + result.stderr
        self.assertIn("Passo 2 de 4 · Escolher modelo", out)
        self.assertIn("Passo 2 de 4 · Esforço de raciocínio", out)

    def test_m27_new_project_without_progress_defaults_to_written_request(self):
        project = self.managed_project("codex")
        body = ("PROJECT=" + base.shlex.quote(str(project)) +
                "; TOOL=codex; choose_prompt || exit $?; build_command codex novo || exit $?; "
                "printf 'TESTARGV\\0'; printf '%s\\0' \"${COMMAND[@]}\"")
        result = self.run_shell(body, "\nOlá mundo\nFIM\n")
        self.assert_ok(result)
        self.assertIn("Projeto novo: ainda não há andamento para continuar", result.stdout)
        args = result.stdout.split("TESTARGV\0", 1)[1].rstrip("\0").split("\0")
        self.assertIn("Olá mundo", "".join(args))

    def test_m28_header_hides_current_project_when_flagged(self):
        project = self.with_project("codex")
        shown = self.project_shell(project, "header 'X'").stdout
        hidden = self.project_shell(project, "HIDE_PROJECT_HEADER=1 header 'X'").stdout
        self.assertIn("Projeto atual", shown)
        self.assertNotIn("Projeto atual", hidden)

    def test_m29_creating_project_hides_previous_project_block(self):
        self.with_project("codex")
        frase = "Objetivo de teste."
        result = self.run_main(
            input_text=f"5\n1\n2\n{self.parent}\nProjeto Novo Z\n1\n2\n\n{frase}\nn\n0\n", timeout=12)
        self.assert_ok(result)
        after = result.stdout.split("Criar projeto · 1 de 4", 1)[1]
        self.assertNotIn("Projeto atual", after.split("Projeto pronto", 1)[0])

    def test_m30_accounts_menu_uses_project_tool_without_asking(self):
        project = self.with_project("claude")
        out = self.project_shell(project, "accounts_menu", "0\n").stdout
        self.assertIn("Ferramenta do projeto: claude", out)
        self.assertNotIn("1) Codex", out)

    def test_m31_login_message_inside_accounts_says_here(self):
        project = self.with_project("codex")
        result = self.project_shell(project, "accounts_menu", "2\n\n0\n")
        self.assertIn("escolha 3 (Trocar de conta) aqui mesmo", result.stdout)

    def test_m32_login_message_outside_accounts_gives_path(self):
        project = self.with_project("codex")
        result = self.project_shell(project, "TOOL=codex; login_tool")
        self.assertIn("Ajuda e ajustes (7) → 1 → Trocar de conta", result.stdout)

    def test_m33_recent_projects_show_name_tool_and_path(self):
        project = self.with_project("claude")
        out = self.run_shell("recent_projects", "0\n").stdout
        self.assertIn(f"{project.name} (Claude Code) — {project}", out)

    def test_m34_empty_recents_message(self):
        out = self.run_shell("recent_projects").stdout
        self.assertIn("Nenhum projeto recente ainda. Volte e escolha 1 (Criar) ou 2 (Abrir pasta).", out)

    def test_m35_care_menu_numbers_are_ascending_inside_groups(self):
        project = self.with_project("codex")
        out = self.project_shell(project, "project_tools", "0\n").stdout
        for group in (("3) Criar", "9) Editar", "10) Abrir", "11) Organizar", "12) Verificar"),
                      ("1) Abrir a pasta", "2) Copiar", "4) Capturar"),
                      ("5) Ver", "6) Criar uma cópia", "7) Abrir o site", "8) Iniciar")):
            positions = [out.index(item) for item in group]
            self.assertEqual(positions, sorted(positions), group)

    def test_m36_git_without_repository_is_explained(self):
        project = self.with_project("codex")
        self.cmd_stub("xcode-select", "exit 0\n")
        self.cmd_stub("git", 'echo "$@" >> "$TEST_CLI_LOG.git"\n[ "$3" = rev-parse ] && exit 128\nexit 0\n')
        out = self.project_shell(project, "git_changes").stdout
        self.assertIn("Esta pasta não usa Git; não há alterações para mostrar.", out)
        self.assertNotIn("fatal", out)

    def test_m37_git_checks_apple_tools_first(self):
        project = self.with_project("codex")
        self.cmd_stub("xcode-select", "exit 2\n")
        self.cmd_stub("git", 'echo chamou >> "$TEST_CLI_LOG.git"\nexit 0\n')
        out = self.project_shell(project, "git_changes").stdout
        if base.subprocess.run(["uname", "-s"], capture_output=True, text=True).stdout.strip() == "Darwin":
            self.assertIn("xcode-select --install", out)
            self.assertFalse((self.logs.parent / (self.logs.name + ".git")).exists())

    def test_m38_create_prompt_explains_and_warns(self):
        project = self.with_project("codex")
        bad = self.project_shell(project, "save_prompt", "nome/ruim\n")
        self.assertIn("Nome inválido", bad.stderr)
        eof = self.project_shell(project, "save_prompt", "bom\nlinha sem fim\n")
        self.assertIn("digite FIM numa linha sozinha", eof.stdout)
        self.assertIn("terminou antes do FIM; nada foi salvo", eof.stderr)
        self.assertFalse((project / "PROMPTS/bom.md").exists())
        empty = self.project_shell(project, "save_prompt", "\n")
        self.assertIn("Cancelado", empty.stdout)

    def test_m39_zip_dialog_has_its_own_sentence(self):
        project = self.with_project("codex")
        log = self.root / "osascript.log"
        self.cmd_stub("osascript", f'printf "%s\\n" "$*" >> "{log}"\nexit 1\n')
        self.project_shell(project, "backup_project", "1\n0\n")
        self.assertIn("Escolha a pasta onde salvar a cópia ZIP", log.read_text())

    def test_m40_no_pause_after_back_or_invalid_choices(self):
        self.with_project("codex")
        for text in ("6\n0\n0\n", "7\n0\n0\n", "5\n0\n0\n", "9\n0\n"):
            with self.subTest(entry=text):
                result = self.run_main(input_text=text)
                self.assertNotIn("Enter para voltar", result.stderr)

    def test_m41_care_menu_invalid_choice_does_not_pause(self):
        project = self.with_project("codex")
        result = self.project_shell(project, "project_tools", "77\n0\n")
        self.assertNotIn("Enter para voltar", result.stderr)
        self.assertIn("Opção inválida", result.stdout)

    def test_m42_empty_state_points_to_guide(self):
        out = self.run_main(input_text="0\n").stdout
        self.assertIn("Primeira vez? Veja o guia em Ajuda e ajustes (7) → 6.", out)

    def test_m43_very_long_conversation_offers_to_close_first(self):
        project = self.with_project("codex")
        setup = ("usage_measure() { USAGE_STATE=muito-longa; }; "
                 "quick_close() { echo FECHAR; }; quick_resume() { echo RETOMAR; }; main")
        yes = self.project_shell(project, setup, "1\n\n\n0\n")
        self.assertIn("Sua conversa está muito longa. Encerrar com resumo primeiro? [S/n]", yes.stderr)
        self.assertIn("FECHAR", yes.stdout)
        self.assertNotIn("RETOMAR", yes.stdout)
        no = self.project_shell(project, setup, "1\nn\n\n0\n")
        self.assertIn("RETOMAR", no.stdout)

    def test_m44_short_conversation_does_not_ask_to_close(self):
        project = self.with_project("codex")
        setup = ("usage_measure() { USAGE_STATE=leve; }; quick_resume() { echo RETOMAR; }; main")
        result = self.project_shell(project, setup, "1\n\n0\n")
        self.assertNotIn("muito longa", result.stderr)
        self.assertIn("RETOMAR", result.stdout)

    def test_m45_measurement_switch_off_stops_panel_and_gate(self):
        project = self.with_project("codex")
        self.assert_ok(self.run_shell("opt_flip peso"))
        setup = ("usage_measure() { echo MEDIU >&2; USAGE_STATE=muito-longa; }; "
                 "usage_panel() { echo PAINEL-X; }; quick_resume() { echo RETOMAR; }; main")
        result = self.project_shell(project, setup, "1\n\n4\n\n0\n")
        self.assertIn("medição desligada", result.stdout)
        self.assertNotIn("MEDIU", result.stderr)
        self.assertNotIn("PAINEL-X", result.stdout)
        self.assertIn("A medição do uso está desligada", result.stdout)
        self.assertIn("RETOMAR", result.stdout)

    def test_m46_preference_three_has_plain_wording(self):
        out = self.run_shell("control_menu", "0\n").stdout
        self.assertIn("Medir o uso da conversa e avisar quando estiver longa", out)

    def test_m47_menu_has_old_conversation_picker(self):
        out = self.run_main(input_text="0\n").stdout
        self.assertIn("8) Escolher uma conversa antiga", out)


for _name in dir(base.AssistantTests):
    if _name.startswith("test_"):
        setattr(MenuTests, _name, None)

if __name__ == "__main__":
    unittest.main()
