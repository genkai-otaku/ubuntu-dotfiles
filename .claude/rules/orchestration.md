# モデル運用（Claude Code 専用）

Grok はこのファイルを読まない（`compat.claude.rules = false`）。Grok は `~/.grok/AGENTS.md`。

メイン（Fable 5.1）は要件整理・設計・分解・指示・監査・最終判断に専念し、実装はサブエージェントへ。

- 通常の実装: Agent ツールで `model: "sonnet"`
- 中〜高難度: `model: "opus"`
- 調査: Explore 等へ委譲。`model: "sonnet"`（軽ければ `"haiku"`）。省略すると親の Fable 5.1 を継承する
