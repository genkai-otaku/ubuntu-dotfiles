#!/bin/bash
# Codex / Devin の宣言設定マージを一時 HOME で検証する（実際のホームは触らない）。
# python3 に tomlkit が無ければ flake の共通 Python を取得する。CLI_CONFIG_PYTHON で指定もできる。
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
ROOT="$(cd "$TESTS_DIR/../.." && pwd)"

fail_python_setup() {
  report cli-config-python 0 1 "$1"
  # run.sh が表示する NG 行に取得失敗の詳細も残す。
  if [ -n "${2-}" ]; then printf '%s\n' "$2" | sed 's/^/  NG [cli-config-python] /'; fi
  summary cli-config-merge
  exit 1
}

python="${CLI_CONFIG_PYTHON-python3}"
if [ "${CLI_CONFIG_PYTHON+x}" != x ] && ! PYTHONDONTWRITEBYTECODE=1 python3 -c 'import tomlkit' >/dev/null 2>&1; then
  if ! command -v nix >/dev/null 2>&1; then
    fail_python_setup 'python3 に tomlkit が無く、共通 Python の取得に必要な nix が見つかりません'
  fi
  if python_store=$(nix build --no-link --print-out-paths --no-write-lock-file "$ROOT#cli-config-python" 2>"$T/cli-config-python.err"); then
    python="$python_store/bin/python3"
  else
    fail_python_setup 'flake の cli-config-python を取得できませんでした' "$(cat "$T/cli-config-python.err")"
  fi
fi

output=$(PYTHONDONTWRITEBYTECODE=1 CLI_CONFIG_REPO="$ROOT" "$python" - <<'PY' 2>&1
import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

import tomlkit

root = Path(os.environ["CLI_CONFIG_REPO"])
spec = importlib.util.spec_from_file_location("merge_cli_config", root / "nix/merge-cli-config.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MergeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cli-config-", dir=os.environ["TMPDIR"])
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name) / "repo"
        self.home = Path(self.temporary.name) / "home"
        for directory in [self.repo / "codex", self.repo / "devin", self.home / ".codex",
                          self.home / ".config/devin"]:
            directory.mkdir(parents=True)
        (self.repo / "codex/config.toml").write_text('model = "declared"\n[mcp_servers.node_repl]\nenabled = true\n')
        (self.repo / "codex/hooks.json").write_text((root / "codex/hooks.json").read_text())
        (self.repo / "devin/config.json").write_text('{"permissions":{"deny":["Exec(sudo)"]},"theme_mode":"dark"}')
        self.config = self.home / ".codex/config.toml"
        self.hooks = self.home / ".codex/hooks.json"
        self.devin = self.home / ".config/devin/config.json"

    def generate(self, detach_only=False):
        module.generate(self.repo, self.home, detach_only)

    def test_fresh_home_and_idempotence(self):
        self.generate()
        config = tomlkit.parse(self.config.read_text())
        self.assertEqual(config["model"], "declared")
        self.assertNotIn("node_repl", config.get("mcp_servers", {}))
        self.assertFalse(self.config.is_symlink())
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        times = [path.stat().st_mtime_ns for path in (self.config, self.hooks, self.devin)]
        self.generate()
        self.assertEqual(times, [path.stat().st_mtime_ns for path in (self.config, self.hooks, self.devin)])

    def test_local_state_and_runtime_survive(self):
        self.config.write_text('''# ユーザーのコメント
model = "local"
unknown_setting = "keep"
[projects."/fixture/work"]
trust_level = "trusted"
[hooks.state."fixture"]
trusted_hash = "do-not-change"
[marketplaces.fixture]
source = "/fixture/cache/version"
[mcp_servers.node_repl]
command = "/fixture/bin/node_repl"
enabled = false
[mcp_servers.node_repl.env]
CODEX_HOME = "/fixture/home/.codex"
''')
        self.devin.write_text('{"devin":{"org_id":"org-fixture"},"shell":{"setup_complete":true},"permissions":{"deny":["old"],"local_rule":true}}')
        self.generate()
        config = tomlkit.parse(self.config.read_text())
        self.assertEqual(config["model"], "declared")
        self.assertEqual(config["unknown_setting"], "keep")
        self.assertEqual(config["projects"]["/fixture/work"]["trust_level"], "trusted")
        self.assertEqual(config["hooks"]["state"]["fixture"]["trusted_hash"], "do-not-change")
        self.assertEqual(config["marketplaces"]["fixture"]["source"], "/fixture/cache/version")
        self.assertEqual(config["mcp_servers"]["node_repl"]["env"]["CODEX_HOME"], "/fixture/home/.codex")
        self.assertTrue(config["mcp_servers"]["node_repl"]["enabled"])
        self.assertIn("ユーザーのコメント", self.config.read_text())
        devin = json.loads(self.devin.read_text())
        self.assertEqual(devin["devin"]["org_id"], "org-fixture")
        self.assertTrue(devin["shell"]["setup_complete"])
        self.assertEqual(devin["permissions"]["deny"], ["Exec(sudo)"])
        self.assertTrue(devin["permissions"]["local_rule"])
        # 外部ツールが switch 間に追加した値も次回そのまま引き継ぐ。
        config["hooks"]["state"]["second"] = {"trusted_hash": "new-local-hash"}
        self.config.write_text(tomlkit.dumps(config))
        self.generate()
        self.assertEqual(tomlkit.parse(self.config.read_text())["hooks"]["state"]["second"]["trusted_hash"], "new-local-hash")

    def test_legacy_symlink_migration_never_writes_repo(self):
        old = Path(self.temporary.name) / "old"
        old.mkdir()
        originals = ["model = 'old'\n[projects.fixture]\ntrust_level = 'trusted'\n", '{"hooks":{}}', '{"devin":{"org_id":"org-old"}}']
        for destination, text in zip((self.config, self.hooks, self.devin), originals):
            source = old / destination.name
            source.write_text(text)
            destination.symlink_to(source)
        self.generate(detach_only=True)
        for destination, text in zip((self.config, self.hooks, self.devin), originals):
            self.assertFalse(destination.is_symlink())
            self.assertEqual(destination.read_text(), text)
        # home-manager の旧リンク削除は実ファイルになった対象を削除しない。
        self.generate()
        self.assertEqual(tomlkit.parse(self.config.read_text())["projects"]["fixture"]["trust_level"], "trusted")
        self.assertEqual(json.loads(self.devin.read_text())["devin"]["org_id"], "org-old")
        for source, text in zip((old / "config.toml", old / "hooks.json", old / "config.json"), originals):
            self.assertEqual(source.read_text(), text)

    def test_direct_merge_detaches_symlink(self):
        original = Path(self.temporary.name) / "linked.toml"
        original.write_text("model = 'old'\n")
        self.config.symlink_to(original)
        self.generate()
        self.assertEqual(original.read_text(), "model = 'old'\n")
        self.assertFalse(self.config.is_symlink())

    def test_external_hooks_and_metadata_preserved_managed_hooks_updated(self):
        external = {"type": "command", "command": "/fixture/.orca/agent-hooks/codex-hook", "timeout": 77}
        old_owned = {"type": "command", "command": 'bash "/fixture/.codex/hooks/guard.sh"', "timeout": 1}
        self.hooks.write_text(json.dumps({"local_metadata": True, "hooks": {
            "PreToolUse": [{"matcher": "old", "custom": "keep", "hooks": [old_owned, external]}],
            "UnknownEvent": [{"hooks": [external]}]}}))
        self.generate()
        hooks = json.loads(self.hooks.read_text())
        self.assertTrue(hooks["local_metadata"])
        self.assertEqual(hooks["hooks"]["PreToolUse"][-1], {"matcher": "old", "custom": "keep", "hooks": [external]})
        self.assertEqual(hooks["hooks"]["UnknownEvent"][0]["hooks"], [external])
        self.assertEqual(hooks["hooks"]["PreToolUse"][0]["matcher"], "Bash")
        # 宣言から登録を消すと管理フックだけ消える。外部登録は残る。
        (self.repo / "codex/hooks.json").write_text('{"hooks":{}}')
        self.generate()
        remaining = json.loads(self.hooks.read_text())["hooks"]
        self.assertEqual(remaining["PreToolUse"], [{"matcher": "old", "custom": "keep", "hooks": [external]}])

    def test_invalid_local_toml_fails_before_any_write(self):
        self.config.write_text("invalid = [\n")
        with self.assertRaises(tomlkit.exceptions.TOMLKitError):
            self.generate()
        self.assertEqual(self.config.read_text(), "invalid = [\n")
        self.assertFalse(self.hooks.exists())

    def test_invalid_last_config_fails_before_any_write(self):
        self.devin.write_text("{")
        with self.assertRaises(ValueError):
            self.generate()
        self.assertFalse(self.config.exists())
        self.assertFalse(self.hooks.exists())
        self.assertEqual(self.devin.read_text(), "{")

    def test_invalid_hooks_structure_fails_before_any_write(self):
        self.hooks.write_text('{"hooks":{"PreToolUse":false}}')
        with self.assertRaises(ValueError):
            self.generate()
        self.assertFalse(self.config.exists())

    def test_removed_declaration_preserves_unknown_local_value(self):
        self.config.write_text("model = 'local'\nunknown = 'keep'\n")
        self.generate()
        (self.repo / "codex/config.toml").write_text("model = 'updated'\n")
        self.generate()
        self.assertEqual(tomlkit.parse(self.config.read_text())["unknown"], "keep")


unittest.main()
PY
)
rc=$?
report cli-config-merge-python 0 "$rc" "$output"
if [ "$rc" -ne 0 ]; then printf '%s\n' "$output"; fi
summary cli-config-merge
