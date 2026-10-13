#!/usr/bin/env python3
"""宣言設定をホーム側へ反映し、CLI が保存したローカル状態を保持する。"""

import argparse
from collections.abc import MutableMapping
import copy
import json
import os
from pathlib import Path
import shlex
import stat
import tempfile

import tomlkit


def merge(local, declared):
    for key, value in declared.items():
        if isinstance(value, MutableMapping) and isinstance(local.get(key), MutableMapping):
            merge(local[key], value)
        else:
            local[key] = copy.deepcopy(value)
    return local


def owned_hook(hook):
    if hook.get("type") != "command":
        return False
    try:
        words = shlex.split(hook.get("command", ""))
    except ValueError:
        return False
    return (len(words) == 2 and Path(words[0]).name == "bash"
            and any(words[1].endswith("/.codex/hooks/" + name)
                    for name in ("guard.sh", "harness.sh")))


def validate_hooks(config):
    if not isinstance(config.get("hooks", {}), dict):
        raise ValueError("hooks はオブジェクトである必要があります")
    for groups in config.get("hooks", {}).values():
        if not isinstance(groups, list):
            raise ValueError("イベントの hooks は配列である必要があります")
        for group in groups:
            if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
                raise ValueError("フックグループには hooks 配列が必要です")
            if any(not isinstance(hook, dict) for hook in group["hooks"]):
                raise ValueError("フックはオブジェクトである必要があります")


def merge_hooks(local, declared):
    validate_hooks(local)
    validate_hooks(declared)
    events = local.setdefault("hooks", {})
    # コマンドの所属で区別し、削除・matcher変更も反映する。外部ツールの登録は残す。
    for event, groups in list(events.items()):
        retained = []
        for group in groups:
            group = copy.deepcopy(group)
            group["hooks"] = [hook for hook in group["hooks"] if not owned_hook(hook)]
            if group["hooks"]:
                retained.append(group)
        events[event] = retained
    for event, groups in declared.get("hooks", {}).items():
        events[event] = copy.deepcopy(groups) + events.get(event, [])
    for key, value in declared.items():
        if key != "hooks":
            local[key] = copy.deepcopy(value)
    return local


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary = tempfile.mkstemp(prefix="." + path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            output.write(text)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, mode | stat.S_IWUSR)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def generate(repo, home, detach_only=False):
    files = [
        (repo / "codex/config.toml", home / ".codex/config.toml", "toml"),
        (repo / "codex/hooks.json", home / ".codex/hooks.json", "hooks"),
        (repo / "devin/config.json", home / ".config/devin/config.json", "json"),
    ]
    pending = []
    # 全ファイルを構文検査してから書く。不正な既存設定を空の設定に置き換えない。
    for source, destination, kind in files:
        parse = tomlkit.parse if kind == "toml" else json.loads
        original = destination.read_text() if destination.exists() else None
        if destination.is_symlink() and original is None:
            raise ValueError(f"設定のリンク先がありません: {destination}")
        local = parse(original) if original is not None else parse("" if kind == "toml" else "{}")
        declared = parse(source.read_text())
        if not isinstance(local, dict) or not isinstance(declared, dict):
            raise ValueError(f"設定はオブジェクトである必要があります: {destination}")
        if kind == "hooks":
            validate_hooks(local)
            validate_hooks(declared)
        if detach_only:
            if destination.is_symlink():
                pending.append((destination, original, original))
            continue
        if kind == "toml":
            # desktop のランタイムが未生成なら enabled だけの不完全な MCP を作らない。
            for name, server in list(declared.get("mcp_servers", {}).items()):
                if set(server) <= {"enabled"} and not any(
                    local.get("mcp_servers", {}).get(name, {}).get(key) for key in ("command", "url")
                ):
                    del declared["mcp_servers"][name]
            result = tomlkit.dumps(merge(local, declared))
        else:
            result = json.dumps(merge_hooks(local, declared) if kind == "hooks"
                                else merge(local, declared), ensure_ascii=False, indent=2) + "\n"
        if result != original or destination.is_symlink():
            pending.append((destination, original, result))
    for destination, original, result in pending:
        # 読み取り後に外部ツールが書き込んだ場合は、次の switch で再試行する。
        current = destination.read_text() if destination.exists() else None
        if current != original:
            raise ValueError(f"反映中に設定が変更されました: {destination}")
        atomic_write(destination, result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--detach-only", action="store_true")
    args = parser.parse_args()
    try:
        generate(args.repo, args.home, args.detach_only)
    except (ValueError, OSError, tomlkit.exceptions.TOMLKitError) as error:
        # パース例外には設定内容が含まれることがあるため出力しない。
        parser.exit(1, f"CLI 設定の反映に失敗しました（{type(error).__name__}）。元の設定を確認してください。\n")


if __name__ == "__main__":
    main()
