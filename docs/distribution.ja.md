# 配布とインストール

[![English](https://img.shields.io/badge/lang-English-lightgrey?style=flat-square)](distribution.md)
[![日本語](https://img.shields.io/badge/lang-日本語-1f6feb?style=flat-square)](distribution.ja.md)

`shell-team` は 2 つの host 向けに配布されるプラグインです: **Claude Code**（v0.1.0 以降）と **Codex CLI**。プラグインのインストールはマシンごとに 1 回だけで、`bin/` ヘルパーはどちらの host からでも到達できます。Codex CLI host 上で Codex が dispatch できるロールは、`bin/gen-codex-agents.sh` が既定で生成する 5 つ（`tech-lead`・`pm-spec`・`engineer`・`qa-verifier`・`code-reviewer`）で、生成されないロールは Claude Code のロールのままです。`/shell-team:<skill>` の slash command 面は Claude Code の仕組みです。マシンごとでは**ない**のは、その 5 ロール向けに Codex がこれらを dispatch するために使う生成済みカスタムエージェントで、これは適用先リポジトリそのものの root から、**リポジトリごと**に生成されます — 詳細は [Codex CLI から shell-team を使う](adopting.ja.md#codex-cli-から-shell-team-を使う) を参照。

> バージョニング: `v0.0.1` はプラグイン化前のベースライン（5 エージェントの単一パスパイプライン、`bin/install` によるスナップショットコピー）です。`v0.1.0` からプロジェクトはプラグイン兼 Loop Engineering フレームワークになりました。`v0.0.x → v0.1.x` の境界では破壊的変更が許容されます。

## インストール

このリポジトリは**プラグインであると同時に、それ自身のマーケットプレイス**です（manifest は `.claude-plugin/` 内）。マーケットプレイス名は `ripsawjp` です。プラグインのインストールは、使っている host（**Claude Code** でも **Codex CLI** でも）にかかわらず、マシンごとに 1 回だけです。

**Claude Code の場合:**

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

**Codex CLI の場合:**

```
codex plugin marketplace add RipsawJP/shell-team
codex plugin add shell-team@ripsawjp
```

そのうえで、リポジトリそのものの root から、Codex が dispatch するカスタムエージェントを生成します — **リポジトリごと**であり、マシンごとではありません:

```
bash "<plugin root>/bin/gen-codex-agents.sh" --out-dir .codex/agents
```

リポジトリの trust・sandbox の writable roots・network 許可など、ここでは触れないセットアップの残りは [Codex CLI から shell-team を使う](adopting.ja.md#codex-cli-から-shell-team-を使う) を参照してください。

**Claude Code** では、プラグインの各エージェントは `/shell-team:<agent>`、スキルは `/shell-team:<skill>`（例: `/shell-team:run`）として解決されます。**Codex CLI** では、代わりに role の生成済みカスタムエージェントが Codex 自身の `spawn_agent` tool で dispatch されます — 詳細は [Codex CLI から shell-team を使う](adopting.ja.md#codex-cli-から-shell-team-を使う) を参照。どちらの host でも、`bin/` スクリプトは `bash "<plugin root>/bin/<script>"` として起動します——プラグインが有効でも `PATH` に載るとは限りません。`<plugin root>` は自ホストの報告値から読んでください（[adopting.ja.md](adopting.ja.md) の "Locate the installed plugin root" 手順を参照）。

## ターゲットリポジトリへの導入

インストール後、リポジトリのプロジェクトごとのデータを 1 回初期化します。すべては単一のベースディレクトリ配下に作られます（デフォルトは `.shell-team/`。`TEAM_RUN_BASE` で上書き可。既存のレガシー `tasks/`+`docs/specs/` レイアウトは検出され再利用される）: `.shell-team/{todo.md, loops/shell-team.contract.yaml, runs/, retros/, reviews/, specs/}` に加えて自己完結した `.shell-team/.gitignore`。ホストルートには手を触れません — `CLAUDE.md` の編集も**無し**、ルート `.gitignore` の変更も**無し**（[adopting.ja.md](adopting.ja.md) 参照）:

```text
/shell-team:team-init
```

Codex CLI host では、同じ host-neutral な scaffolder を、適用先リポジトリそのものの root から直接実行します:

```text
bash "<plugin root>/bin/team-init.sh" .
```

`team-init` は冪等です — 再実行しても既存ファイルはスキップし、ホストルートのファイルは決して変更しません。ターゲットリポジトリに置かれるのはプロジェクトの**データ**だけで、ベースディレクトリ（todo/specs/loops/runs/retros/reviews）に閉じます。フレームワーク本体（agents/skills/scripts/templates）は、新しいプラグインバージョンをインストールした時点でマシンごとに 1 回更新されます — Codex CLI host では、適用先リポジトリごとに生成されたカスタムエージェント自身の再生成と drift check がその後さらに必要です — 詳細は下の `## アップデート` を参照。

## このリポジトリを開発 / dogfood する

**このプラグイン自身のリポジトリ内**で作業するときは、インストールせずに作業ディレクトリからロードします:

```bash
claude --plugin-dir ./
```

`agents/*`・`skills/*`・`bin/*` を編集したら `/reload-plugins` で変更を反映します（スキル本体の編集はライブ反映）。このリポジトリはもう `.claude/agents/` のコピーを保持していません — `--plugin-dir ./` が dogfood の経路です。

## サンドボックス有効時の permission 設定

Claude Code セッションが **sandbox 有効**で動いているとき、Codex 別プロバイダレビュー経路（`code-reviewer`）が機能するのは、そのセッションの設定が Codex の呼び出しを sandbox の**外側**に置いている場合だけです。関係する設定層は 2 つあり、混同してはいけません——公式の Claude Code permissions / sandboxing ドキュメントを参照してください。

- **`sandbox.excludedCommands`**（主要な層）——このパターンに一致するコマンドは sandbox の**外側**で走ります。実際に `sandbox_apply: Operation not permitted` の失敗を直すのはこの層です。
- **`permissions.allow`**（補助的・任意の層）——一致する Bash 呼び出しの permission プロンプトを抑制するだけです。単独では sandbox から何も除外しないため、`permissions.allow` のルールだけを足しても sandbox の失敗は直りません。

**一致のルールは Claude Code 2.1.278 で変わりました。** それ以前は `sandbox.excludedCommands` のパターンはコマンドラインの先頭トークンだけに一致していたため、行末にシェルのリダイレクトが付いていても `codex exec …` 行は除外対象のままでした。Claude Code 2.1.278 はこれを変更し、コマンドの**すべての部分**が一致したときだけ除外されるようになりました（先頭トークンだけではありません。計測日 2026-09-24、Claude Code **2.1.281**、codex-cli **0.156.1**）。このプラグインが出荷していた `codex exec` ブロックはどれも `> "<jsonl の生パス>" 2>&1` で終わっていたため、2.1.278 以降ではこのリダイレクトが一致しない 2 つめの部分となり、呼び出し全体が sandbox の**内側**で走っていました——うるさく失敗する形（`workspace routing discovery failed` → `turn.failed`、exit 1、最終メッセージのファイルは書かれない）か、静かに失敗する形（exit 0、`Unable to determine.` のような判断不能文、イベントストリームに `sandbox_apply` エラー）のいずれかです。リダイレクトを持たない裸の形は、2.1.278 以降でも、それより前のどのバージョンでも sandbox の外側で走り、正常に完了します。出荷される `codex exec` ブロックは今はすべて、自分自身の `-o` キャプチャだけを書く単一の裸コマンドです——リダイレクトも、標準入力のリダイレクトも、コマンド置換も、connector もありません。これにより `"codex *"` の除外パターンが呼び出し全体に再び一致します。

`.claude/settings.local.json` に `sandbox.excludedCommands` の形を追加すると、直接 `codex` を呼ぶ経路がカバーされます。対応する `permissions.allow` エントリは、承認プロンプトを黙らせるだけの任意の利便機能です:

```json
{
  "sandbox": {
    "excludedCommands": [
      "codex *"
    ]
  },
  "permissions": {
    "allow": [
      "Bash(codex *)"
    ]
  }
}
```

**キャプチャされる `.jsonl` の出所が変わりました。** 出荷される `codex exec` ブロックはもう自分の出力をリダイレクトしないため、キャプチャされるペアの `.jsonl` 側はシェルのリダイレクトでは作られません。`codex exec` は実行のたびに、自分自身のイベントストリーム記録——`rollout-<timestamp>-<thread_id>.jsonl` ファイル——を自分自身の状態ディレクトリ `${CODEX_HOME:-$HOME/.codex}/sessions/<YYYY>/<MM>/<DD>/` に書きます。これはこのプラグインが何をするかとは無関係です。`bin/codex-capture.sh --publish` は任意の 1 フラグ `--thread-id <id>` を取り、そのスレッドの rollout 記録を bit-for-bit で publish 対象の `.jsonl` に取り込みます。そのレコードが完了した実行を示さない場合（成功したコマンドが無い、終端イベントが無い、最終メッセージが null、または error が null でない）は、verdict として publish せずに拒否します。`CODEX_HOME` は Codex CLI 自身のホームディレクトリの上書き先で、未設定のときは `$HOME/.codex` にフォールバックします。

**ここで検証できること。** 呼び出しの**形**——出荷される `codex exec` 行がすべて、引数の後に他の部分を持たない単一の裸コマンドであり、`"codex *"` の除外パターンに構造的に一致すること——は、このリポの CI（`tests/codex-skeleton-hygiene/run.sh` の `agentmd-bare-codex-present`、`agentmd-no-trailing-operator` とそれぞれの mutation 対照ケース）が機械的に検証する構造的事実です。この形の呼び出しが Claude Code 2.1.278 以降で**実行時に実際に sandbox の外側で走るか**は、このホストでの sandbox 有効・実セッションのライブプローブ（計測日 2026-09-24、Claude Code **2.1.281**、codex-cli **0.156.1**）で確認済みです：Codex は自分自身のコマンドを実行し、`-o` キャプチャが書かれ、`<sandbox_violations>`・`sandbox_apply`・`workspace routing discovery failed` のいずれも現れませんでした。同じプローブを修正前の出荷形（末尾のリダイレクトつき）で走らせると、うるさい失敗が再現しました。このプローブと rollout の証跡は、この変更を行ったタスクのこのリポジトリ自身の provenance 記録に残っています。

Codex CLI host 側でも同様に、cross-provider レビューの `claude -p` 行（`templates/prompt-blocks/host-dispatch.md`）は host 側、つまり Codex sandbox の外側で実行します。sandbox の内側からの実行では host 側の Claude セッションを使えないためです（host 自身の Claude Code CLI がログイン済みでも同じです）。この行が `Not logged in` を返すのは、host がログアウトしているのではなく sandbox 内で実行されたことの兆候です。sandbox の外側で再実行するか、外側で実行する経路が無い場合は正確なエラーとともに `BLOCKED` として報告してください——別の executor に差し替えることはありません。

## アップデート

`.claude-plugin/plugin.json` の `version` を bump してコミットし、各マシンで実行します:

**Claude Code の場合:**

```text
/plugin marketplace update ripsawjp
```

`version` を省略すると、プラグインは固定リリースではなく最新のコミット SHA を追従します。

**Codex CLI の場合:**

```
codex plugin marketplace upgrade ripsawjp
```

`codex plugin list` に載っていることは最新であることを意味しません: スキップする前に、その `VERSION` 列を実行したいリリースと比較してください。古ければ `codex plugin add shell-team@ripsawjp` を再実行します。いずれの場合も、リポジトリそのものの root から、適用先リポジトリごとに generator を再実行して確認します（checker は `--out-dir` しか読まないため）:

```
bash "<plugin root>/bin/gen-codex-agents.sh" --out-dir .codex/agents
bash "<plugin root>/bin/check-codex-agents.sh"
```

全体の手順とその自身のチェックは [Codex CLI から shell-team を使う](adopting.ja.md#codex-cli-から-shell-team-を使う) を参照してください。

## バージョン系統

**shell-team は単一のリリース線として配布されます。** `main` がリリースを担い、`develop` がその統合ブランチです。`plugin.json` の version は通常の `0.x.y` リリーススケジュールに従って進みます。

**Claude Code** では、`#ref` を付けない既定の `plugin marketplace add RipsawJP/shell-team` は default branch（`main`）の HEAD から marketplace manifest を解決するため、素の install は常に最新リリースを得ます。`/plugin marketplace update` はその ref を再取得し version を比較します。

**Codex CLI** host では、同等の読み取りは `codex plugin list` です: その `VERSION` 列を、実行したいリリースと比較してください。実際に「インストール済み」を意味する STATUS 値は、単にリストに現れることではなく、正確に `installed, enabled` という文字列です。

以前の並行配布体制（ref で pin する凍結 v0.2 系を v0.3 と併存させる構成）は廃止したので、pin・切り替え・backport の対象となる別系統はもうありません。チェックアウト上の `claude --plugin-dir ./` dogfood 経路は変わりません。

## ホスト限定のスケジューリング

インナーループ（`/shell-team:run`）と `/goal` ランタイムループは、デフォルトで**手動トリガ** — オペレータが起動します。Loop 契約のサーフェスは `trigger.type: schedule`（`manual`・`event` と並ぶ第一級の enum 値）を介して**時間駆動**のケイデンスを表現することもできますが、フレームワークは**スケジューラを同梱しておらず**、自動で何かを有効化することもありません。スケジューリングはアウターループの中で最も可搬性が低い部分なので、**ホスト限定かつオプトイン**です: クロックは自分のホスト側で配線し、フレームワークは変更されません。

ホストオペレータが `schedule` トリガを駆動する 2 つの方法:

- **環境の `/loop` + `ScheduleWakeup`**（エージェントランタイムがそれらを提供する場合に推奨）。これらは**環境のプリミティブであって、リポジトリのスクリプトではありません** — このプラグインに `skills/loop/` は存在しないので、フレームワークがそれらを自己呼び出しすることはできません。ケイデンスは環境側で駆動し（例: `/loop 30m /shell-team:run …`）、意図を文書化するためにループ契約の `trigger.type: schedule` を設定してください。
- **OS スケジューラ（cron / `launchctl` / systemd timer）**が、**あなたが所有する**小さなホスト側ラッパー（ここでは同梱しない）を呼ぶ方法。説明用で有効化されていないサンプルは [`loop-engineering/loop-cron.crontab.example`](loop-engineering/loop-cron.crontab.example) を参照。

**`manual` は常にフォールバックです。** ホストのスケジューリングは薄く、取り外し可能なレイヤーです。crontab の行 / LaunchAgent を削除する（または `/loop` の使用をやめる）だけで、ループは以前とまったく同じように手で実行でき、**リポジトリ内部の挙動は一切変わりません**。ホストのクロックを取り除いても契約ファイルは書き換わりません。`trigger.type: schedule` のまま残された契約は有効で手動実行可能で、オペレータは新しい意図を反映するために任意で `manual` に編集し直せます。ホストは多様なので（cron か launchd か systemd か CI スケジューラかエージェントランタイムの `/loop` か）、この配線は**可搬ではありません**。よって文書化はするものの、同梱や自動有効化は決してしません。スケジュールされたトリガが実際に発火するかどうかはホストランタイムの挙動であり、このリポジトリの CI ではなく、実機ホストでの dogfood によって検証されます。

## エアギャップ / ロックされた CI でのフォールバック（vendoring）

`/plugin install` が使えない環境（CI ランナーでマーケットプレイスにアクセスできない等）では、`bin/install` がエージェントファイルをターゲットリポジトリにスナップショットコピーするフォールバックを提供します。

これはレガシーな避難経路です — プラグイン経路を優先してください。

このリポジトリのチェックアウトも、どちらの host（Claude Code でも Codex CLI でも）でも `<plugin root>` として機能し、インストールもアップグレードも一切不要です。詳細は [Codex CLI から shell-team を使う](adopting.ja.md#codex-cli-から-shell-team-を使う) を参照してください。
