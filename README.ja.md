# shell-team

[![English](https://img.shields.io/badge/lang-English-lightgrey?style=flat-square)](README.md)
[![日本語](https://img.shields.io/badge/lang-日本語-1f6feb?style=flat-square)](README.ja.md)

[![CI](https://github.com/RipsawJP/shell-team/actions/workflows/check-handoff.yml/badge.svg)](https://github.com/RipsawJP/shell-team/actions/workflows/check-handoff.yml)
[![version](https://img.shields.io/badge/version-2.0.0-1f6feb?style=flat-square)](https://github.com/RipsawJP/shell-team/tags)
[![Claude Code plugin](https://img.shields.io/badge/Claude_Code-plugin-d97757?style=flat-square)](docs/distribution.md)
[![reviewer: Codex](https://img.shields.io/badge/reviewer-Codex_cross--provider-10a37f?style=flat-square)](#設計上の選択)
![bin: zero-dep bash](https://img.shields.io/badge/bin-zero--dep_bash-2ea043?style=flat-square)

## なぜ作っているのか

**正直なところ、私は楽がしたい。**

AI に実装を頼んだあとも、人間が毎工程を監督し、コードを読み、修正を指示し、最後に正しさを判断する。それでは、思ったほど楽になっていない。

shell-team は、人間が毎回参加しなくても AI が仕様化・実装・検証・修復まで進められないかを、実際の開発で試している個人プロジェクトです。人間をゼロにすることや、Loop Engineering / Graph Engineering といった特定の型に従うこと自体が目的ではありません。使える考え方を使い、私の作業が減り、その楽があとで高くつかなければ、それでよいと考えています。

背景にある個人的な考えは、[「正直なところ、私は楽がしたい — Loop Engineering? Graph Engineering? 名前は、まあ、どうでもいい」](docs/essays/i-just-want-less-work.ja.md) にまとめています。

![shell-team の概念図 — Plan → Spec → Build → Test → Codex Review → Merge を BUDGET/STOP ガードで囲み、telemetry・triage・retro・lessons がループに還流する](docs/images/shell-team-concept.png)

## shell-team とは

任意のリポジトリに開発チームを投入する Claude Code **プラグイン**です。**PM・Tech Lead・Engineer・QA・Codex による別プロバイダ Reviewer**（＋ UI 作業時のみ参加する UI Designer・＋ Scrum-Master）が、Spec 駆動ワークフローと明示的なハンドオフゲートに従います。

- **plan → specify →（必要時のみ design）→ implement → validate → cross-provider review** を強制し、各境界に status flag を置く。
- Reviewer は **Codex CLI（OpenAI）** 経由で動き、実装チームとは別のモデルファミリーから最終チェックを行う。
- 各実行を明示的な Loop 契約（BUDGET/STOP）で bound し、`/goal` が同じガードレールの下で 1 タスクを完了まで駆動する。
- 各フェーズのテレメトリと retro / lessons を、次の実行へ還流させる。
- プラグインとして一度導入すれば全リポで使え、リポごとのコピーやバージョンドリフトを避けられる。

プロジェクトがここまでどう進化したかは [docs/history.ja.md](docs/history.ja.md) を参照してください。

## 前提

- Claude Code（プラグイン対応バージョン、v2.1.x 以降）。
- Codex CLI のインストールと認証。Codex プラグインがあれば `/codex:setup` を 1 回、なければ https://developers.openai.com/codex/cli を参照。
- **サンドボックス有効なセッションでは追加設定が必要**。Codex レビュー経路の sandbox 除外（`sandbox.excludedCommands`）と permission の設定は [docs/distribution.md#sandbox-enabled-permission-settings](docs/distribution.md#sandbox-enabled-permission-settings) を参照。

## インストール

このリポは「プラグイン本体」と「自前マーケットプレイス（`ripsawjp`）」を兼ねる。マシンごとに 1 回だけ：

```text
/plugin marketplace add RipsawJP/shell-team
/plugin install shell-team@ripsawjp
```

その後、適用先リポの per-repo データを 1 回初期化（単一 base dir `.shell-team/` にボード＋既定 Loop 契約を scaffold。host root の `CLAUDE.md` / `.gitignore` は改変しない。冪等。詳細は [docs/adopting.md](docs/adopting.md)）：

```text
/shell-team:team-init
```

**`.shell-team/` を git に載せるかを最初に決めてください。** プラグインはルートの `.gitignore` を編集しないため、base dir は repo 内で *untracked* として現れます（無視されるのは中の run テレメトリのみ。自己完結した `<base>/.gitignore` による）。どちらの選択も想定されており、プラグインが代わりに決めることはありません：

- **追跡する** — ボード・spec・レビュー成果物がバージョン管理された project record になる（このリポ自身がこの形でドッグフードしている）
- **git に載せない** — 自分の repo の `.gitignore` に `.shell-team/` を追記する（その repo だけに効き、取り消しも容易）。作業する全 repo で載せたくない場合は global excludes（`git config --global core.excludesFile`）に入れる。ただし global 側はマシン全体に効くため、後から「この repo ではボードを追跡したい」と決めた repo でも base dir が隠れる。その 1 repo だけ復帰させるには root の `.gitignore` に `!.shell-team/` を書く（repo 側のパターンが global ファイルより優先される）。このリポ自身もその行を持っている。ツール側へのもう 1 つの影響は [docs/adopting.md](docs/adopting.md) を参照

詳細・更新・エアギャップ用フォールバックは [docs/distribution.md](docs/distribution.md) を参照。

## 使い方

shell-team の既定の使い方は**会話駆動 — やりたいことをそのまま話すだけ**。チャットで何かを頼むときと同じ:

```text
build sha と uptime を返す /healthz を shell-team で追加して
```

メインの Claude セッションが非自明な依頼を認識し、チームのループ（Plan → Specify → Implement → Validate → Review）を回して、マージ前には必ず一時停止してあなたを待つ — スラッシュコマンドを打たずに Codex による別プロバイダレビューが得られるのと同じ経路です。会話モデルの詳細・追加の会話例・チャットから**フルループ**を確実に発火させるための唯一の opt-in ステップは [docs/usage-conversational.md](docs/usage-conversational.md) を参照。

明示的に使いたいときは、エージェントやスキルを単体でも起動できます:

```text
# フルパイプライン（明示スラッシュコマンド）
/shell-team:run build sha と uptime を返す /healthz を追加して

# 別プロバイダによる独立レビューだけ
/shell-team:review auth と入力バリデーションを重点的に

# 自分の PR に返ってきたレビュー指摘に対応 — Codex 評価 + リスクゲートを通し、採用分を shell-team に流す
/shell-team:review-response PR #N のレビューに対応して

# このリポをチーム運用向けに scaffold（リポごとに 1 回）
/shell-team:team-init

# 候補作業を発見（CI 失敗 / open PR / loop-triage issue）— 提案のみ、ボードは編集しない
/shell-team:loop-triage

# board のタスク 1 件を self-paced ループで完了まで運ぶ（層状ゲート: check-acs → check-intent（spec が凍結 intent ブロックを持つ場合のみ） → check-provenance → QA → Codex・loop-guard で bound）
/shell-team:goal T-XXX

# エージェントを直接指名
@shell-team:pm-spec この依頼を仕様に落として
@shell-team:engineer T-XXX に着手して
```

## フルループが向くタスク（適性）

**第一の分岐 — 最終検証面がループ内で閉じるか？**

- **ループ内で閉じる**（正しさが*機械検証*＝テスト・lint・実行/出力照合で確定する）: PM → Engineer → QA → Codex のフルループが**適合**する。QA と Codex が受け入れ条件を経験的・静的に確認できるため、FAIL は人間が結果を見る前にループ内で捕まる。
- **ループ内で閉じない**（最終ゲートが*人間の目視・実機レンダラ・主観評価*＝スライド/PDF レイアウト・ピクセル単位の UI 仕上げ・文章のトーン等）: フルループは**非適合、または限定適用にとどまる**。QA は人間の目視を代替できず、ループ構造では人間目視ゲートが終盤にしか現れないため、目視 FAIL の手戻りが 1 周分になり同一コードパスを何周も空回りしうる（実運用で観測: 1 件の視覚系タスクで rework 10 ラウンド超・人間が本当の問題に気づくまで）。

**視覚出力タスクの暫定運用**（専用の短サイクル/変形ループが作られるまでのつなぎ）: そうしたタスクを 1 回のフルループに乗せ**ない**。代わりに短い手動サイクル（implement→render→人間確認）を回し、人間が毎ターン実機のレンダリング結果を見る。spec / QA は完了ゲートではなく補助に回す。

> この第一分岐は、接地済み AI evaluator の OOD-novelty / 人間ゲート判定基準と同型である: 機械的に接地できない検証面は人間へエスカレーションされる。

## 構成

```
.
├── .claude-plugin/
│   ├── plugin.json                  # プラグイン manifest（name, version）
│   └── marketplace.json             # 自前マーケットプレイス（ripsawjp）
├── agents/
│   ├── tech-lead.md                 # オーケストレーター（read-only、Routing Map を返す）
│   ├── pm-spec.md                   # 仕様起票
│   ├── ui-designer.md               # UI 作業時のみデザイン担当（frontend-design Skill・任意依存）
│   ├── engineer.md                  # 実装（既定 non-worktree・並列時のみ opt-in 隔離）
│   ├── qa-verifier.md               # テスト実行 / 受け入れ条件チェック
│   ├── codex-reviewer.md            # Codex CLI 別プロバイダレビュー
│   ├── scrum-master.md              # retro / lessons 生成
│   └── triage-orchestrator.md       # 外側ループの triage 統合（propose-only）
├── skills/
│   ├── run/SKILL.md            # /shell-team:run <依頼>
│   ├── goal/SKILL.md                # /shell-team:goal（自己検証ランタイムループ）
│   ├── review/SKILL.md              # /shell-team:review
│   ├── review-response/SKILL.md     # /shell-team:review-response（受領レビュー指摘のトリアージ）
│   ├── team-init/SKILL.md           # /shell-team:team-init（リポを scaffold）
│   └── loop-triage/SKILL.md         # /shell-team:loop-triage（作業を発見）
├── bin/                             # プラグイン有効時すべて PATH に載る
│   ├── check-handoff.sh             # tasks/todo.md ハンドオフ linter
│   ├── check-contract.sh            # Loop 契約スキーマ linter
│   ├── loop-guard.sh                # 実行時 BUDGET/STOP enforcement
│   ├── log-run.sh / check-run.sh    # テレメトリ writer + JSONL lint
│   ├── gen-loop-replay.sh           # run のテレメトリを HTML リプレイページに描画
│   ├── discover-work.sh             # read-only triage 発見エンジン
│   ├── team-init.sh                 # 適用先リポ scaffolder
│   └── install                      # 旧 vendoring フォールバック
├── templates/                       # team-init が使う generic scaffold
├── docs/
│   ├── essays/                      # プロジェクトの背景にある個人的な essay
│   ├── workflow.md                  # フェーズ図 + ハンドオフ契約
│   ├── distribution.md              # install / update / dogfood
│   └── history.md                   # プロジェクトの進化の記録
└── .shell-team/                     # このリポ自身の per-repo データ（board, specs, loops, retros, reviews）
```

## フェーズフロー

```
[Plan]      tech-lead       → Routing Map
[Specify]   pm-spec         → docs/specs/<slug>.md   READY_FOR_ARCH
[Design]    ui-designer     → （UI 時のみ）design note  新フラグなし
[Implement] engineer        → コード + テスト          READY_FOR_QA
[Validate]  qa-verifier     → 実行 + 条件チェック       READY_FOR_REVIEW
[Review]    codex-reviewer  → Codex CLI の判定         READY_FOR_MERGE
```

`[Design]` は**条件付き**（UI 作業時のみ `ui-designer` が参加）。新しい status flag は持たず、design note の存在で順序を担保する。`frontend-design` Skill は任意依存（未インストール時は内蔵指針に縮退モード明示で fallback）。

ハンドオフ契約とショートカットは [docs/workflow.md](docs/workflow.md) を参照。

## 運用ループ

上記エージェントのパイプラインが **inner loop**。その外側に運用規律の **outer loop** を被せる：

- **Loop 契約** — 各ループは TRIGGER/SCOPE/ACTION/BUDGET/STOP/REPORT を `tasks/loops/*.contract.yaml` に宣言し、`bin/check-contract.sh` で lint。BUDGET ＋ STOP は必須。
- **実行時ガードレール** — `bin/loop-guard.sh` が契約の BUDGET/STOP を実行時に強制（fail-closed な暴走 / 課金 kill-switch）。
- **テレメトリ** — `/shell-team:run` が各フェーズで 1 `--span` 行、各ハンドオフで 1 `--event` 行（イベント語彙: `handoff|rework|gate|human|release`）を `bin/log-run.sh` で emit、`bin/check-run.sh` が JSONL を lint、`bin/gen-loop-replay.sh` がどちらの行種別も run-replay ページとして描画し直す（[run のリプレイ](#run-のリプレイ)参照）。run 横断のロールアップが、1 run ずつでは見えない系統的な問題も浮かび上がらせる。
- **オプトイン triage** — `/shell-team:loop-triage`（`bin/discover-work.sh`）は read-only：CI 失敗 / open PR / ラベル付き issue を見つけて todo 候補を*提案*する（ボードは編集しない）。
- **モデルルーティング** — エージェントの役割はモデル tier（計画 / 実行 / 別プロバイダレビュー）に振り分けられ、コストが各役割の判断負荷に追従する。モデル環境やコスト構造が変わればいつでも再評価する明示トリガ付き。

この運用規律がどう進化したかは [docs/history.ja.md](docs/history.ja.md) を参照。

## 役割と executor の紐付け

6 つの inner-loop 役割 — `tech-lead`・`pm-spec`・`engineer`・`qa-verifier`・
`codex-reviewer`・`ui-designer` — は、`<base>/binding.conf`
（`<base>` は `bin/team-paths.sh --get base` で解決）を通じて、それぞれ
executor（provider + model + effort + adapter）を host が個別に割り当て
られます。host 設定が無い場合、`bin/resolve-executor.sh` はプラグイン
出荷時の既定である `templates/binding-default.conf` にフォールバックします
——これが**出荷時の既定**で、存在する場合の `<base>/binding.conf` が
resolver の優先する host override です。両者は決して同じファイルでは
ありません。

1. スキャフォールドされた `<base>/binding.conf.example`（`team-init` が
   `templates/binding-template.conf` から書き出す）を
   `<base>/binding.conf` にリネームする——`team-init` がまだ走っていない
   場合は、プラグイン自身の `templates/binding-template.conf`（プラグイン
   のインストール先ディレクトリから解決される——自リポジトリ配下の
   パスではない）を手動でコピーする。
2. `bind <role> <provider> <model> <effort|-> <adapter>` 行（役割ごとに
   1 行）を編集して割り当てたい executor を指定する。`effort` は
   位置的に必須で、「値なし」はフィールドを省略せず常にリテラル `-` で
   綴る（この「未設定」の綴り方は effort 列だけのもの——model 列は
   常に英数字始まりが必要）。
3. `bash check-binding.sh --config <base>/binding.conf`（exit `0` =
   valid）で検証し、`bash resolve-executor.sh --print-resolved` で
   有効な紐付けを確認する——プラグインをロードしていれば `bin/` は
   `PATH` に載るのでどちらも `bin/` 接頭辞なしで解決する。プラグインを
   ロードしていないチェックアウト内では、それぞれ `bin/` を付けて
   実行する。`--print-resolved` は **availability probe を一切行わない**
   ので、これだけでは紐付けた executor が実際に到達可能かを確認できない
   ——それには `resolve-executor.sh --role <role>` が必要。

実際の validator が受理する設定例:

```
schema 1

bind tech-lead      claude opus   high claude-cli
bind pm-spec        claude opus   high claude-cli
bind engineer       claude sonnet -    claude-cli
bind qa-verifier    claude sonnet -    claude-cli
bind ui-designer    claude sonnet -    claude-cli
bind codex-reviewer codex  gpt-5  -    codex-cli
```

**正直な境界線**: rebind すると `resolve-executor.sh` が**解決する**
executor と**テレメトリ**が記録する値が変わる。ただし別 executor への
**呼び出し経路**が配線されるわけでは**ない**——役割の実際の呼び出しは、
その役割自身が固定するモデル値を今なお経由する。それを変える退役は
issue **#236**。reviewer 行自身の出荷時の既定とその理由は
[設計上の選択](#設計上の選択) を参照。

## run のリプレイ

1 run のテレメトリ（span 行 + event 行）は、1 枚の自己完結した HTML ページとしてリプレイできる — ネットワークも外部アセットもビルドステップも不要で、`file://` URL からそのまま開ける。

生成コマンド:

```bash
bash gen-loop-replay.sh <run-id>
```

（プラグインをロードしていれば `bin/` は `PATH` に載るので、`bash gen-loop-replay.sh` はそこから解決される — 実行ビットには依存しない。`bin/` 接頭辞も自前の `PATH` 設定も不要。）ページは `<runs>/replay-<run-id>.html` に生成される。ここでの `<runs>` は、このリポジトリで `bin/team-paths.sh --get runs` が解決するディレクトリで、すでに `git-ignore` 済みなので ignore ファイルに追記する必要はない。別の場所に書き出したいときは `--out <path>` を渡す。

**注意**: board-flag のレールが点灯するのは、その run の `handoff` イベントが board flag を裸のトークンとして `--label` に載せている場合だけ（`READY_FOR_ARCH` … `READY_FOR_MERGE`）— この convention がどこで作られるかは `skills/run/SKILL.md` を参照。それらのラベルが無い run（依然として大多数のケース）では、代わりに empty-state のキャプションが表示される。

自分の run がまだ無い場合は、レールが実際に点灯するコミット済みの fixture を試せる（下の fixture パスはこのリポジトリ自身のものなので、shell-team のチェックアウトルートから実行すること）:

```bash
bash bin/gen-loop-replay.sh 20260801T000000Z-flagrail --runs-dir tests/gen-loop-replay/fixtures/flag-rail --out /tmp/replay-demo.html
```

このデモでは `--out` が必須 — 省略するとページが `tests/` 配下の fixture ディレクトリにデフォルトで書き出され、untracked ファイルが残ってしまう。

## 設計上の選択

- **read-only オーケストレーター**：`tech-lead` は計画のみ。実行はメインセッションが Routing Map に従って行う。
- **最小権限**：PM は read + spec 書き込みのみ、QA は read + bash のみ、Reviewer はコードを変更できない。
- **真実源はファイルのみ**：`tasks/todo.md` ＋ status flag がエージェント間の単一の真実源。
- **単一 base dir・host root 不変**：適用先リポは全ての運用ファイルを単一 base dir 配下に保つ（既定 `.shell-team/`、`bin/team-paths.sh` が解決。`TEAM_RUN_BASE` で上書き可）。`team-init` は host の `CLAUDE.md` / root `.gitignore` を決して編集しない。このリポ自身も同じ既定レイアウトで動くので、自分の board・specs・retros も `.shell-team/` 配下にある。resolver は、base dir 集約より前にチームを導入したリポのために legacy な `tasks/` + `docs/specs/` レイアウトも今なお検出・対応する——本ドキュメント群が `tasks/…` / `docs/specs/…` と書いている箇所は、その legacy レイアウトでの同じ artifact を指す。[docs/adopting.md](docs/adopting.md) 参照。
- **Engineer は既定で non-worktree**：編集は現在の feature ブランチに直接着地する。並列実装時のみ orchestrator が起動時に `isolation: worktree` を opt-in。
- **別プロバイダレビューの Codex 紐付けは「出荷時の既定」**：`codex-reviewer` は既定で Codex CLI に紐付けられている。理由は、同一ファミリーのモデルによるレビューはそのモデル自身の盲点を共有してしまうため。host が自分の `binding.conf` で `codex-reviewer` を同一ファミリーの executor に **rebind** することは可能で、その場合は解決される executor とテレメトリに記録される値が変わる——ただし別 executor の呼び出し経路自体が配線されるわけではなく、そのような rebind が存在する場合ループは別プロバイダレビューを構造的に保証しない。Codex CLI が使えない場合は Claude にフォールバックせず `BLOCKED` を返す。

## バージョニング

リリース履歴は **[CHANGELOG.ja.md](CHANGELOG.ja.md)**（English: [CHANGELOG.md](CHANGELOG.md)）へ — リリースごとに 1 エントリ、新しい順で最新リリースからプラグイン化前のベースライン（v0.0.1）まで。ライン方針の要約: `v0.0.x → v0.1.x` の境界で破壊的変更を許容し、以降の各リリースは安定版 v0.2.0（痕跡集約）基線の上で運用ループを深掘りしてきた。

## 開発 / dogfood

このリポ内で作業する場合は、作業ディレクトリからプラグインをロードする：

```bash
claude --plugin-dir ./       # 編集後は /reload-plugins
```
