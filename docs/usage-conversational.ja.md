# 会話駆動での使い方 — スラッシュコマンド無しでチームを動かす

[![English](https://img.shields.io/badge/lang-English-lightgrey?style=flat-square)](usage-conversational.md)
[![日本語](https://img.shields.io/badge/lang-日本語-1f6feb?style=flat-square)](usage-conversational.ja.md)

shell-team は、毎回 `/shell-team:run …` と打ち込んで操作する必要は
ありません。日常的に想定している使い方は、すでに Codex でのクロスプロバイダ
レビューでやっているのと同じモデルです。**やりたいことを普通の言葉で伝えれば、
メインの Claude セッションがチーム** — `pm-spec`・`engineer`・`qa-verifier`・
`codex-reviewer` — **に委譲してループを回します**。

このガイドでは、その会話駆動モデルと委譲の仕組み、そして信頼性を高めるための
オプトイン手順 1 つを説明します。

## モデル

- **あなたは会話する。Claude がルーティングする。** 「export コマンドに `--json`
  フラグを追加して」→ Claude が非自明な変更だと認識し、shell-team ループ（Plan →
  Specify → Implement → Validate → Review）を回し、マージ前にあなたへ一時停止します。
- これは Codex レビュアーと同じ仕組みです。クロスプロバイダレビューを得るのに
  スラッシュコマンドを打つ必要はなく、レビューを依頼すれば `codex-reviewer`
  エージェントに委譲されます。dev-team の各エージェントも同様に動きます（各
  エージェントの `description` フィールドが、メインセッションにいつそこへ
  ルーティングすべきかを伝えます）。
- スラッシュコマンドも引き続き使えますし、明示的にやりたいときには便利です
  （`/shell-team:run …`、`/shell-team:review`）。会話駆動の
  ルーティングは置き換えではなく追加です。

## セットアップ（オプトイン・リポジトリごとに 1 回）

個々のエージェントへの会話ルーティングは標準で動きます（`description` 駆動）。
**フルループ**を普通の会話から確実に発火させ、かつチームの「X はループに回す」
ポリシーを明文化するには、[`templates/CLAUDE-routing-snippet.md`](../templates/CLAUDE-routing-snippet.md)
のルーティングブロックを自リポジトリの `CLAUDE.md` にコピーしてください。

`team-init` はこれを**あえて自動で書きません**（`CLAUDE.md` には一切手を触れない）。
ルーティングポリシーをプロジェクト指示に加えるかどうかはあなたの判断です。
これが無くてもメインセッションは個々のエージェントへ委譲できますが、**ループ
全体**をゲート付きで回すのは CLAUDE.md に明記されているほうが確実です。

## 会話例

**1. 機能追加 → フルの shell-team ループ**

> **あなた:** `/users` API エンドポイントにページネーションを追加して — ページ
> サイズ 50、安定した並び順、OpenAPI ドキュメントも更新。
>
> **Claude:** これは仕様と複数ファイルが必要なので、チームを回します。tech-lead →
> pm-spec（受入条件）→ engineer → qa-verifier → codex-reviewer の順でルーティング
> します。マージ前には必ず一時停止します。
> *(ループを実行し、各ゲートでボードの status flag を進め、READY_FOR_MERGE を
> 報告してあなたの GO を待つ。)*

**2. 「これだけレビューして」 → codex-reviewer のみ**

> **あなた:** いまプッシュした差分にセカンドオピニオンをもらえる？
>
> **Claude:** クロスプロバイダレビュアー（Codex）に委譲します。*(`codex-reviewer`
> を起動し、所見つきで APPROVE / REQUEST_CHANGES を返す。)*

**3. 仕様だけ → pm-spec**

> **あなた:** まだ実装しないで — 新しい課金 webhook の仕様と受入条件だけ書いて。
>
> **Claude:** pm-spec にルーティングします。*(解決された specs ディレクトリ配下に
> 仕様を書き、タスクを READY_FOR_ARCH に設定。コードは書かない。)*

**4. 「次は何？」 → loop-triage（read-only）**

> **あなた:** 次は何を拾えばいい？
>
> **Claude:** トリアージを回します。*(`loop-triage` スキル →
> `discover-work.sh` を起動。失敗中の CI・open PR・ラベル付き issue を走査し、
> ボード候補行を*提案*する。提案ファイルを書くだけで、ボードは決して編集しない —
> 昇格はあなたの判断。)*

## 委譲の仕組み

- **各エージェント**（全 8 体: `tech-lead`・`pm-spec`・`engineer`・`qa-verifier`・
  `codex-reviewer`・`scrum-master`、加えて条件付き参加の `ui-designer`〔UI 作業時〕と
  `triage-orchestrator`〔外側ループ triage〕）は、`description` フロントマターに基づいて
  メインセッションから起動されます — Codex のレビュアーが使うのと同じ能動的
  メカニズムです。
- **フルループは `run` スキルに存在**し、個々のエージェントには存在しません。
  フェーズゲート・loop-guard の BUDGET/STOP・フェーズごとのテレメトリを強制する
  のはこのスキルです。したがって「エージェントに委譲する」（例: 単発レビュー）と
  「ゲート付きループ全体を回す」は別物です。ルーティングスニペットは、非自明な
  作業には単発のエージェント呼び出しではなく*ループ*を使うよう、メインセッション
  に指示します。
- **共有状態はファイルだけ。** エージェントはメモリを共有しません。ボード
  （`.shell-team/todo.md`）・仕様（`.shell-team/specs/`）・ループ契約が真実源です。
  パスは `team-paths.sh` が解決し、Bash を持たないエージェントにはオーケストレータ
  が注入します。

> オーケストレータ向けの注意: 環境変数は別々の Bash ツール呼び出しをまたいで
> **保持されません**。あるステップで解決済みパスが必要なときは、同じ呼び出し内で
> `$(team-paths.sh --get KEY)` で取得してください — 以前に export した `$TEAM_*`
> に頼らないこと。（bin スクリプトは自己解決するので、ほぼ自動で処理されます。）

## それでもスラッシュコマンドを使う場面

- 明示的に / スクリプト的にやりたい: `/shell-team:run <request>`。
- フルパイプライン無しのクイックレビュー: `/shell-team:review`。
- 新しいリポジトリにループを導入する: `/shell-team:team-init`。

会話駆動ルーティングと明示的なスラッシュコマンドは自由に併用できます — その場に
合うほうを使ってください。
