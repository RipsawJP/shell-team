# 配布とインストール

[![English](https://img.shields.io/badge/lang-English-lightgrey?style=flat-square)](distribution.md)
[![日本語](https://img.shields.io/badge/lang-日本語-1f6feb?style=flat-square)](distribution.ja.md)

`shell-team` は **Claude Code プラグイン**（v0.1.0 以降）として配布されます。マシンごとに 1 回インストールすれば、チームのサブエージェント・スキル・`bin/` ヘルパーが**すべて**のリポジトリで使えるようになります — リポジトリごとのコピーは不要です。

> バージョニング: `v0.0.1` はプラグイン化前のベースライン（5 エージェントの単一パスパイプライン、`bin/install` によるスナップショットコピー）です。`v0.1.0` からプロジェクトはプラグイン兼 Loop Engineering フレームワークになりました。`v0.0.x → v0.1.x` の境界では破壊的変更が許容されます。

## インストール

このリポジトリは**プラグインであると同時に、それ自身のマーケットプレイス**です（manifest は `.claude-plugin/` 内）。マーケットプレイス名は `ripsawjp` です。

```text
# 1) マーケットプレイスを追加
/plugin marketplace add RipsawJP/shell-team

# 2) プラグインをインストール
/plugin install shell-team@ripsawjp
```

CLI での同等コマンド:

```bash
claude plugin marketplace add RipsawJP/shell-team
claude plugin install shell-team@ripsawjp --scope user
```

プラグインの各エージェントは `/shell-team:<agent>`、スキルは `/shell-team:<skill>`（例: `/shell-team:run`）として解決され、`bin/` スクリプトはプラグイン有効時に `PATH` に追加されます。

## ターゲットリポジトリへの導入

インストール後、リポジトリのプロジェクトごとのデータを 1 回初期化します。すべては単一のベースディレクトリ配下に作られます（デフォルトは `.shell-team/`。`TEAM_RUN_BASE` で上書き可。既存のレガシー `tasks/`+`docs/specs/` レイアウトは検出され再利用される）: `.shell-team/{todo.md, loops/shell-team.contract.yaml, runs/, retros/, reviews/, specs/}` に加えて自己完結した `.shell-team/.gitignore`。ホストルートには手を触れません — `CLAUDE.md` の編集も**無し**、ルート `.gitignore` の変更も**無し**（[adopting.ja.md](adopting.ja.md) 参照）:

```text
/shell-team:team-init
```

`team-init` は冪等です — 再実行しても既存ファイルはスキップし、ホストルートのファイルは決して変更しません。ターゲットリポジトリに置かれるのはプロジェクトの**データ**だけで、ベースディレクトリ（todo/specs/loops/runs/retros/reviews）に閉じます。フレームワーク本体（agents/skills/scripts/templates）はプラグイン側に残ります — 1 回更新すれば、すべてのリポジトリが恩恵を受けます。

## このリポジトリを開発 / dogfood する

**このプラグイン自身のリポジトリ内**で作業するときは、インストールせずに作業ディレクトリからロードします:

```bash
claude --plugin-dir ./
```

`agents/*`・`skills/*`・`bin/*` を編集したら `/reload-plugins` で変更を反映します（スキル本体の編集はライブ反映）。このリポジトリはもう `.claude/agents/` のコピーを保持していません — `--plugin-dir ./` が dogfood の経路です。

## アップデート

`.claude-plugin/plugin.json` の `version` を bump してコミットし、各マシンで:

```text
/plugin marketplace update ripsawjp
```

`version` を省略すると、プラグインは固定リリースではなく最新のコミット SHA を追従します。

## バージョン系統

**shell-team は単一のリリース線として配布されます。** `main` がリリースを担い、`develop` がその統合ブランチです。`plugin.json` の version は通常の `0.x.y` リリーススケジュールに従って進みます。`#ref` を付けない既定の `plugin marketplace add RipsawJP/shell-team` は default branch（`main`）の HEAD から marketplace manifest を解決するため、素の install は常に最新リリースを得ます。`/plugin marketplace update` はその ref を再取得し version を比較します。以前の並行配布体制（ref で pin する凍結 v0.2 系を v0.3 と併存させる構成）は廃止したので、pin・切り替え・backport の対象となる別系統はもうありません。チェックアウト上の `claude --plugin-dir ./` dogfood 経路は変わりません。

## ホスト限定のスケジューリング

インナーループ（`/shell-team:run`）と `/goal` ランタイムループは、デフォルトで**手動トリガ** — オペレータが起動します。Loop 契約のサーフェスは `trigger.type: schedule`（`manual`・`event` と並ぶ第一級の enum 値）を介して**時間駆動**のケイデンスを表現することもできますが、フレームワークは**スケジューラを同梱しておらず**、自動で何かを有効化することもありません。スケジューリングはアウターループの中で最も可搬性が低い部分なので、**ホスト限定かつオプトイン**です: クロックは自分のホスト側で配線し、フレームワークは変更されません。

ホストオペレータが `schedule` トリガを駆動する 2 つの方法:

- **環境の `/loop` + `ScheduleWakeup`**（エージェントランタイムがそれらを提供する場合に推奨）。これらは**環境のプリミティブであって、リポジトリのスクリプトではありません** — このプラグインに `skills/loop/` は存在しないので、フレームワークがそれらを自己呼び出しすることはできません。ケイデンスは環境側で駆動し（例: `/loop 30m /shell-team:run …`）、意図を文書化するためにループ契約の `trigger.type: schedule` を設定してください。
- **OS スケジューラ（cron / `launchctl` / systemd timer）**が、**あなたが所有する**小さなホスト側ラッパー（ここでは同梱しない）を呼ぶ方法。説明用で有効化されていないサンプルは [`loop-engineering/loop-cron.crontab.example`](loop-engineering/loop-cron.crontab.example) を参照。

**`manual` は常にフォールバックです。** ホストのスケジューリングは薄く、取り外し可能なレイヤーです。crontab の行 / LaunchAgent を削除する（または `/loop` の使用をやめる）だけで、ループは以前とまったく同じように手で実行でき、**リポジトリ内部の挙動は一切変わりません**。ホストのクロックを取り除いても契約ファイルは書き換わりません。`trigger.type: schedule` のまま残された契約は有効で手動実行可能で、オペレータは新しい意図を反映するために任意で `manual` に編集し直せます。ホストは多様なので（cron か launchd か systemd か CI スケジューラかエージェントランタイムの `/loop` か）、この配線は**可搬ではありません**。よって文書化はするものの、同梱や自動有効化は決してしません。スケジュールされたトリガが実際に発火するかどうかはホストランタイムの挙動であり、このリポジトリの CI ではなく、実機ホストでの dogfood によって検証されます。

## エアギャップ / ロックされた CI でのフォールバック（vendoring）

`/plugin install` が使えない環境（CI ランナーでマーケットプレイスにアクセスできない等）では、`bin/install` がエージェントファイルをターゲットリポジトリにスナップショットコピーするフォールバックを提供します。これはレガシーな避難経路です — プラグイン経路を優先してください。
