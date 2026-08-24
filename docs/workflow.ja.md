# ワークフロー詳細

[![English](https://img.shields.io/badge/lang-English-lightgrey?style=flat-square)](workflow.md)
[![日本語](https://img.shields.io/badge/lang-日本語-1f6feb?style=flat-square)](workflow.ja.md)

## フェーズ境界（status flag）

```
   pm-spec                engineer              qa-verifier            codex-reviewer
      │                      │                      │                       │
      ▼                      ▼                      ▼                       ▼
  READY_FOR_ARCH ──► READY_FOR_ENG ──► READY_FOR_QA ──► READY_FOR_REVIEW ──► READY_FOR_MERGE
      ▲                                       │                       │
      └─────────── REWORK (engineer) ◄────────┘ ◄─────────────────────┘
```

`tech-lead` は非自明な作業では `pm-spec` の前に入り、Routing Map を生成します。status flag は書きません。

`ui-designer` は **`pm-spec` と `engineer` の間、ただし UI 作業のときだけ**入ります（画面・コンポーネント・スタイル・視覚的/UX 変更）。engineer が実装の拠り所とする design note（`<specs dir>/design-note-T-NNN.md`）を生成し、`tech-lead` と同様に status flag は**書きません**（ボードは `READY_FOR_ARCH` のまま。design note の存在が engineer のゲートになる）。UI を伴わないタスクでは `ui-designer` はまったく参加しません。利用可能なときは `frontend-design` Skill を使い、無いときは内蔵ガイダンスへ縮退します（黙ってではなく明示して） — `frontend-design` は任意依存であってハード依存ではありません。

## タスク適性 — フルループが向くタスク

**第一の分岐 — 最終検証面がループ内で閉じるか？**

- **ループ内で閉じる**（正しさが*機械検証*＝テスト・lint・実行/出力照合で確定する）: PM → Engineer → QA → Codex のフルループが**適合**する。QA と Codex が受け入れ条件を経験的・静的に確認できるため、FAIL は人間が結果を見る前にループ内で捕まる。
- **ループ内で閉じない**（最終ゲートが*人間の目視・実機レンダラ・主観評価*＝スライド/PDF レイアウト・ピクセル単位の UI 仕上げ・文章のトーン等）: フルループは**非適合、または限定適用にとどまる**。QA は人間の目視を代替できず、ループ構造では人間目視ゲートが終盤にしか現れないため、目視 FAIL の手戻りが 1 周分になり同一コードパスを何周も空回りしうる（実運用で観測: 1 件の視覚系タスクで rework 10 ラウンド超・人間が本当の問題に気づくまで）。

**視覚出力タスクの暫定運用**（専用の短サイクル/変形ループが作られるまでのつなぎ）: そうしたタスクを 1 回のフルループに乗せ**ない**。代わりに短い手動サイクル（implement→render→人間確認）を回し、人間が毎ターン実機のレンダリング結果を見る。spec / QA は完了ゲートではなく補助に回す。

> この第一分岐は、接地済み AI evaluator の OOD-novelty / 人間ゲート判定基準と同型である: 機械的に接地できない検証面は人間へエスカレーションされる。

## フェーズをスキップしてよい場面

| 状況 | 許容されるショートカット |
|-----------|------------------|
| 1 行のタイポ修正やコメント修正 | `tech-lead` は直接 `engineer` へスキップしてよい |
| 非 UI タスク（CI/bash/バックエンド/docs/config、または非視覚的なフロントエンド編集） | `ui-designer` は参加しない — `[Design]` フェーズ無し |
| テストのみの変更（不足テストの追加） | `pm-spec` をスキップ。`engineer` + `qa-verifier` + `codex-reviewer` |
| 他人の PR をレビューする | `/review` を使う — `codex-reviewer` のみが走る |
| 自分の PR に返ってきたレビュー指摘に対応する | `/review-response` を使う — 受領した指摘を Codex で評価し、リスクゲート（決定論フロアがリスクの高い指摘を人間確認へ強制）を通してから、採用分を `shell-team` に渡す |
| 仕様のみ（コードはまだ無し） | `pm-spec` の後で停止。タスクは `READY_FOR_ARCH`（仕様記述済）で一時停止 |
| すでに spec が書かれている（`specify — operator-authored`。出荷時デフォルトの `pm-authored` ではない） | `pm-spec` はスキップしない——author ではなく conformance formatter として走る。[spec を誰が書くかを選ぶ](adopting.ja.md#spec-を誰が書くかを選ぶt-1091)を参照 |
| spec review が elect されている（`spec-review — cross-provider`。出荷時デフォルトの `none` ではない） | フェーズは何もスキップされない——Specify seam で、freeze sweep の後・intent hash を記録する前に、追加の `codex-reviewer` パスが spec document の domain 前提を読む。`REQUEST_CHANGES` は Implement が始まる前に spec 自身の author へ差し戻される。[Specify seam で spec review を elect する](adopting.ja.md#specify-seam-で-spec-review-を-elect-するt-1092)、`docs/loop-engineering/specify-seam-review.md` を参照 |

`/review` と `/review-response` の違い: `review` は現ブランチ diff の *新規* Codex レビューを生成する。`review-response` は PR に**すでに返ってきた**レビュー指摘をトリアージする — 指摘を評価しリスクゲートに通し、（リスクの高い指摘への GO を得たら）採用分を `shell-team` で実装させる。互いを置き換えるものではない。

## 引き継ぎ契約

メインセッションでの各エージェントの引き継ぎブロックには、以下を含めなければなりません:
- タスク ID
- 新しい status flag
- 触れたファイル（read-only ロールの場合は読んだファイル）
- 次のエージェントにとって注目すべき点を 1 文で

このブロックがエージェント間の*唯一*信頼できるチャネルです — メモリは共有されません。

spec が `- verification-ceiling:` 宣言（T-1093）を持つ場合、
`READY_FOR_REVIEW` の hand-off には宣言された値——spec から verbatim に
transcribe されたものであり、決して invent されない——が追加で載る。
これにより flag は bare な green ではなく「このレベルまでは green」と
読める。同じ行は board 自身のその hand-off の記録にも乗る。文法と、それが
何を保証し何を保証しないかは
[verification ceiling を宣言する](adopting.ja.md#verification-ceiling-を宣言する)
を参照。

3 つの機械的に検出可能な地点——same-class-2 のカウントが 2 に達した時、spec
pre-commitment の factual trigger が発火した時、loop-guard の `STOP:`
escalation——のそれぞれで、loop はあなたへの hand-off を組み立てる前に
**means-ends reflection**（T-1095、issue #346）を実行する: 4 つの固定質問に
書面で答え、(1) タスク自身の never-dropped 項目がすべて green のまま、
(2) findings が対象とするのがすでに名前の付いた auxiliary component（複数
ある場合は pre-commitment に記録された drop order 順）のみ、(3) その中で
最も早い component に対して pre-priced disposition が存在する——の 3 条件
がすべて成り立つ場合に限り、その disposition は loop 自身の権限で execute
され、その 4 つの答えを根拠として board に記録される——安く見える別の
patch と並ぶ一選択肢として escalate されるのではない。この 3 条件のいずれか
が成り立たない場合、disposition 自体が破壊的・不可逆な場合、または
finding set が空か未分類の場合は、あなたへの escalation が引き続き必須と
なる。3 つの standing human gate——マージ前の batch GO、スプリントプラン
ニングの承認、破壊的・不可逆な操作——は変わらない。これはこの 3 地点で
loop があなたに割り込むか否かだけを変える。この reflection がこれまでの
ところ拠って立つ唯一の worked example は
[`docs/loop-engineering/means-ends-reflection.md`](loop-engineering/means-ends-reflection.md)
を参照。

## 言語 — 会話をミラーする

チームの出力は**ユーザーの会話言語をミラーします**: `/shell-team:run` や `/goal` が
パイプラインを駆動するとき、オーケストレータは各サブエージェントのプロンプトの
先頭に、ユーザーが会話している言語と同じ言語で応答するよう指示する 1 行ディレクティブを
付加します（不明なときは英語をデフォルト）。これは**ゼロコンフィグ**です — 言語
設定ファイルも環境変数も無く、ホストの `CLAUDE.md` にも手を触れません。フレーム
ワークは汎用のまま保たれ、導入者は単に自分の言語で会話するだけでオプトインでき
ます。明示的な上書き（例: 英語でチャットしつつチーム出力は日本語）はありません。

**機械パースされるトークンは英語のまま逐語で保持され、決して翻訳されません**:
status flag（`READY_FOR_ARCH` … `READY_FOR_MERGE`、`BLOCKED`、`REWORK`）、判定
ラベル（`PASS` / `FAIL` / `APPROVE` / `REQUEST_CHANGES`）、各エージェントの固定の
引き継ぎ見出し/キー。これらは `check-handoff.sh`・`goal-state.sh`（no-progress
シグネチャ）・`check-acs.sh` によって grep されるため、翻訳するとパイプラインが
壊れます。散文は会話言語に従いますが、契約トークンは従いません。

**サイクルごとに生成される成果物**（`scrum-master` が書く retro）も同じゼロコンフィグ規則に
従います: これらにも別建ての言語設定はありません。`bin/check-retro.sh` は retro の*構造*だけを
検証し、`<!-- retro-section: keep|problem|try|traps|lessons -->` という言語に依存しない
マーカーに基づきます — マーカーの隣の見出しテキストは自由なので、日本語でも英語でも他の
どんな言語で書かれた retro でも同じ構造チェックを通ります。出荷される（英語の）雛形は
`docs/templates/retro-template.md` を、マーカー契約以前に書かれた retro の移行手順は
そのファイルの移行注記を参照してください。`bin/gen-loop-replay.sh` が生成する run-replay
ページも同じクラスに入ります: operator が書いた `label` テキストはページ内に逐語で
表示され、ページ自身の UI 辞書は英日どちらの言語も持ちますが、機械トークン（rail の
5 つの `READY_FOR_*` 停止点、判定ラベル）は逐語の英語のままです — 出荷される
`templates/loop-replay.html` 自体は、他の出荷ファイルと同様に英語で書かれた出荷物です。

**既知の制約**: ミラーが保証されるのは **SKILL 駆動の経路**（`/shell-team:run`・`/goal`）
だけで、そこではオーケストレータがディレクティブを注入します。エージェントを
**直接 / スタンドアロン**で起動する（`@engineer` 等）と、ミラーは**保証されません** —
Bash を持たない `pm-spec` / `tech-lead` は会話言語を自己解決できません（設計上、
env も config ファイルも無い）。`codex-reviewer` はスタンドアロンの `/review` で
タスクプロンプトの言語に従うことで、これを部分的に緩和します。

## Codex CLI クイックリファレンス

```bash
# バージョン確認 — codex-reviewer と drift-evaluator が毎ラウンド実行し、
# その出力を verdict の `- Codex CLI:` 行に転記する
codex --version

# 構造化されたブランチレビュー（推奨・正典形。
# トップレベル `codex review` に --json は無いため `codex exec` 配下の `review` サブコマンドを使う）
codex exec --sandbox read-only --cd <repo> review --base <base> --json -o <out-file>

# `codex review` が使えないときのフォールバック
codex exec --ephemeral --json "<prompt>"

# 疑わしいファイルへの敵対的セカンドパス
codex exec --ephemeral --json "Play devil's advocate on <file>. What could break this?"
```

## 規約

- **ブランチ**: engineer はタスクの feature ブランチ上で直接作業する（worktree は並列実装で orchestrator が opt-in した時のみ）— この repository の命名規則は `CONTRIBUTING.md` を参照
- **仕様**: `<specs dir>/T-XXX-<slug>.md`、slug はタイトルの kebab-case、`<specs dir>` は `team-paths.sh --get specs`（プラグインが読み込まれていれば `PATH` 上にある。そうでなければ `bin/team-paths.sh`）
- **レビュー成果物**: `<reviews dir>/T-XXX.md`（curated verdict + severity ledger）と Codex 生トレース `<reviews dir>/T-XXX-codex-*.{txt,jsonl}`、`<reviews dir>` は `team-paths.sh --get reviews`（プラグインが読み込まれていれば `PATH` 上にある。そうでなければ `bin/team-paths.sh`）
- **PR 本文の diff 統計**（file/line counts）: PR 作成時に `git diff --stat <base>...HEAD` を実行して取得し、マージ直前に再測定する — QA の hand-off スナップショットから転記しない。レビュー記録と disposition のコミットが QA の後に乗るため、数字が黙って古くなる（retro で実際に観測された）
- **機能タスクの一部として `.claude/agents/*` を決して編集しない** — それはチーム設定作業であり、専用のタスク ID を通す
