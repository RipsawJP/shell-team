# Retro `<YYYY-MM-DD>`

> Template for `tasks/retros/<YYYY-MM-DD>.md`. The scrum-master agent reads
> this file as the structural source of truth and fills it in with values
> derived from the recent merged PRs, review artifacts, and the lessons log.
>
> **Required structure** (the linter equivalent — anything that breaks these
> rules should be treated as a bug in the agent prompt):
>
> 1. A `## Retro inputs` ledger appears first (T-1001), declaring the material
>    the rest of the retro rests on. Produced by `bin/retro-inputs.sh` and
>    pasted verbatim — do not hand-write it. Its canonical ids and statuses
>    (single source: `templates/prompt-blocks/retro-inputs.md`):
>    - input: cycle-window
>    - input: review-artifacts
>    - input: provenance
>    - input: specs
>    - input: run-telemetry
>    - input: previous-retro
>    - input: lessons
>    - input: pr-metadata
>    - status: read
>    - status: empty
>    - status: unavailable
>    empty means the input was consulted and held nothing; unavailable means it could not be consulted at all. Never report one as the other.
>    `check-retro.sh` validates this section against a closed enum and fails
>    closed — see "What this mechanism does not deliver" in
>    `docs/specs/T-1001-retro-input-acquisition.md`: it confirms the ledger is
>    well-formed, never that a `read` status is true.
> 2. Top-level heading is exactly `# Retro <YYYY-MM-DD>`.
> 3. The five H2 sections appear in that order, verbatim:
>    `## Keep（続けたい良い動き）` / `## Problem（直面した課題 / 痛み）` /
>    `## Try（次サイクルで試すこと）` /
>    `## 罠の点検（Comprehension Debt / Cognitive Surrender）` /
>    `## Lesson 候補（ユーザー判断で `tasks/lessons.md` にマージ）`.
>    If a section has no real content, keep the heading and write
>    `- (該当なし)` as a single bullet — never delete the heading.
>    The `罠の点検` section is **mandatory and not skippable** — it is the
>    AI-attest reflection on the Comprehension Debt / Cognitive Surrender
>    traps (see `docs/loop-engineering/loop-traps.md`). `check-retro.sh`
>    enforces it precisely because it is the reflection most tempting to skip.
> 4. Every bullet under `## Lesson 候補` starts with `[common]` or
>    `[target-specific]`. No bare bullets allowed.
> 5. Every bullet under Keep / Problem / Try cites a source (PR number,
>    `tasks/reviews/T-XXX.md`, `tasks/lessons.md` line range, etc.) so the
>    observation can be traced.
> 6. The agent never edits `tasks/lessons.md`. Lesson candidates are
>    proposed here for the human to merge.
>
> Delete this blockquote when the file is filled in.

---

# Retro `<YYYY-MM-DD>`

**対象サイクル**: 直近 `<N>` 個のマージ済み PR
**対象 PR**: `#<a>`, `#<b>`, `#<c>`, ...
**生成元**: scrum-master agent v0 (manual trigger)

`bin/retro-inputs.sh` prints the `## Retro inputs` heading below and its
ledger lines together — paste its output here verbatim, unedited, right after
that heading. Example shape shown below (a well-formed ledger: all eight
canonical ids, exactly once, each one of `read` / `empty` / `unavailable`).
This paragraph and everything above it stays OUTSIDE the `## Retro inputs`
section on purpose: `bin/check-retro.sh` validates that section as a closed
ledger and fails on any non-ledger prose inside it, so an explanation of the
mechanism cannot itself live inside the mechanism it explains.

## Retro inputs

- input: cycle-window — status: read — detail: `<N merge commits from <ref> (first-parent)>`
- input: review-artifacts — status: read — detail: `<N review artifacts in <dir>>`
- input: provenance — status: read — detail: `<N provenance files in <dir>>`
- input: specs — status: read — detail: `<N spec files in <dir>>`
- input: run-telemetry — status: empty — detail: `<0 run telemetry files in <dir>>`
- input: previous-retro — status: read — detail: `<N prior retro files in <dir>>`
- input: lessons — status: unavailable — detail: `<no path supplied via --lessons>`
- input: pr-metadata — status: unavailable — detail: `<gh not installed>`

## サマリ

`<2–4 行で「このサイクルで何が動いたか」を要約。観察事実ベース。>`

## Keep（続けたい良い動き）

- `<観察事実 — 出典 PR or review.md / lessons.md への参照>`
- `<...>`

## Problem（直面した課題 / 痛み）

- `<事象 / 影響範囲 — 出典>`
- `<...>`

## Try（次サイクルで試すこと）

- `<具体的アクション。担当ロール / 必要な変更ファイル / 期待される改善>`
- `<...>`

## 罠の点検（Comprehension Debt / Cognitive Surrender）

> ループが速くなるほど人間がコードから疎遠化（Comprehension Debt）し、判断を放棄する
> （Cognitive Surrender）。それを防ぐための自己点検。**省略不可**
> （`check-retro.sh` が必須化）。詳細・規範は `docs/loop-engineering/loop-traps.md`。
> **回答方式（AI attest・現運用）**: 人間へ丸投げする設問にせず、retro を書く agent 自身が
> artifact（生ログ・diff・実ファイル）を直読・裏取りして判断ごと回答を書き、検証しきれなかった
> 項目だけを「未検証・要人間判断」として明示的にエスカレートする（lessons.md 2026-07-13
> 「ゲート・自己点検の判断を人間に punt しない」の適用。v0.3.0 design note §6.3 S5 の先行運用）。
> **S4 引用・二段 attest（任意）**: 該当サイクルに S4 drift report（tasks/reviews/<task-id>-drift.md）があればその cross-provider verdict を引用し、検証しきれない項目は orchestrator が任意の二段 attest（## Orchestrator attest）で裏取りしてよい（quote-when-present・`## Orchestrator attest` は必須見出しにしない任意 convention）。

- **理解の負債**: 今サイクルで自分が読んでいない / 理解が薄い生成コードは？ 出典（PR / ファイル）付きで。`- (該当なし)` でもよいが、その場合「全 diff を実際に読んだ」と明言する。
- **レビュー基準の再言語化**: 今サイクルで「マージしてよい」と判断した基準を 1〜2 文で再言語化せよ。"AI / agent がそう言ったから" は不可。
- **未検証の自己申告**: agent が「完了」と言ったが証拠（テスト / ログ / QA / Codex verdict）で裏が取れていない項目は？ あれば次サイクルの Try か証拠取得に回す。

## Lesson 候補（ユーザー判断で `tasks/lessons.md` にマージ）

> agent はここに候補を **提示するだけ**で、`tasks/lessons.md` には書き込まない。
> ラベルは `[common]`（ターゲットリポジトリ非依存の汎用知見）/
> `[target-specific]`（このリポ固有の知見）の 2 値。
> ラベル無しの bare item は出してはいけない。
> **匿名化**: lesson には再発するパターンとその理由だけを書き、インシデント固有の識別情報は書かない。Source はこのリポジトリ内の成果物を指すか、n/a とする。
> この匿名化ルールは書く時点の規律であり、検出器ではない。すでに書かれてしまった識別情報を見つける機能はない。
> **モデル更新サイクル限定のヒント（scaffolding 監査）**: 実行モデルが前サイクルから変わった回のみ、`agents/*.md` の手順固定・禁止事項や loop-guard / contract yaml の bound から「旧モデルの弱さ由来の制約」の緩和候補をラベル付き候補 or issue 提案としてここに載せる（unhobbling・`docs/loop-engineering/model-tiering.md` §再評価トリガ）。監査を実行して正当な候補が 0 件だった場合は `## Notes` に `no scaffolding relaxation candidates` と明示すればよい（0 件は正当な結果・弱い候補を捏造しない）。モデル更新のないサイクルでは何も足さない。

- `[common]` `<lesson 文 — 1〜3 行>`
- `[target-specific]` `<lesson 文>`
- `<...>`

## Notes

- `<retro 生成時に skip / warning が出たもの。例: 「PR #9 は対応 review.md なし」>`
- `<入力欠損 / 認証エラー / 命名規約に外れた review ファイル等もここに記録>`
