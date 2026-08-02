# `/goal` — ランタイム自己検証ループ

[![English](https://img.shields.io/badge/lang-English-lightgrey?style=flat-square)](goal-loop.md)
[![日本語](https://img.shields.io/badge/lang-日本語-1f6feb?style=flat-square)](goal-loop.ja.md)

`/shell-team:goal <task>` は、1 つのタスクを独自のケイデンスで「完了」まで
駆動します: 階層化された**完了ゲート**が完全に green になるか、`loop-guard.sh` が
STOP を返すまで、tick ごとに 1 回の **implement → verify** 試行を繰り返します。
これは以前の実現可能性スパイクの GO(partial) 配線スケッチの実装です。スキル本体は
`skills/goal/SKILL.md` です。

## `/goal` をいつ使うか（タスク適性）

`/goal` は有界ですが無料ではありません: 向かないタスクでもループは壊れず
（`loop-guard.sh` が STOP します）、あなたにエスカレーションされる前に
イテレーションを消費するだけです。開始する**前に**フィルタしてください。
次の **4 つすべて**を満たすタスクがループに向いています:

1. **繰り返し発生する / バックログ形** — 同種の作業が繰り返し発生する
   （テスト修正・lint 負債・docstring 追加など）ため、ループを組む
   セットアップコストが回収できる。
2. **客観的に検証可能** — 「完了」を人間の目なしに完了ゲートで判定できる:
   機械検証可能な受入条件（`check-acs.sh` 用の `check:` 行）か、
   `qa-verifier` が実行ベースで検証できる挙動であること。
3. **検証が実行より安い** — 階層化ゲートが 1 試行を、その試行のコストより
   安く判定できる。検証自体に長い人間レビューが要るなら、ゲートは自力で
   green になれない。
4. **コンテキストに収まる** — 1 回の implement → verify 試行が単一の作業
   コンテキストに収まる。tick ごとにクロスリポジトリの調査をやり直す
   ようなタスクは停滞し `STOP:no_progress` を踏む。

1 つでも欠けるなら、人間ペースの `/shell-team:run` 1 回で流す方を選んでください。
この基準はこのリポジトリのプリミティブと 1:1 に対応します — #2 ⇔ 機械検証
可能な AC、#3 ⇔ ゲートの「安い決定的検証を先に」という順序、#4 ⇔ 「同じ
失敗形状の反復＝停滞」という `no_progress` シグネチャの前提。
（基準の言い回しは Claude Code ループに関する実践知見
<https://x.com/mnilax/status/2074880097597689957>（2026-07）に倣っています。）

## 既存プリミティブをどう組み合わせるか

| 関心事 | プリミティブ | 役割 |
|---|---|---|
| ケイデンス | 環境の `/loop` + `ScheduleWakeup` | tick ごとにドライバを再発火（OS スケジューラ版は[ホスト限定のスケジューリング](../distribution.ja.md#ホスト限定のスケジューリング)） |
| バウンド（暴走 STOP） | `bin/loop-guard.sh` + `goal.contract.yaml` | イテレーション / 実時間 / no-progress |
| 完了（tick ごとのジャッジ） | `check-acs.sh` → `check-intent.sh`（spec が凍結 intent ブロックを持つ場合のみ） → `check-provenance.sh` → `qa-verifier` → `codex-reviewer` | 決定的 → 決定的（条件付き） → 決定的 → 判断 → クロスプロバイダ、それぞれ独立 |
| tick をまたぐ状態 | `bin/goal-state.sh` + `<runs>/goal-<task>.state` | ループ開始時刻・イテレーション・前回の失敗シグネチャ |
| テレメトリ | `bin/log-run.sh` | サブエージェント呼び出しごとに 1 span（`loop_id=goal`）。event 行は goal loop 自身ではなく `/shell-team:run` から来る。`bin/gen-loop-replay.sh` がどちらの行種別も replay ページとして読み戻す |

完了シグナルは**階層化**されており、単一の小さなモデルではありません — まず決定的な
`check-acs`（無料、誤った「完了っぽい」が無い）、次に `check-intent`（spec が凍結
intent ブロックを持つ場合のみ）と `check-provenance`、次に `qa-verifier`、そして
クロスプロバイダの `codex-reviewer`。これは文字どおりの `/goal`「1 つの小さな
モデルが毎ターン判断する」という枠組みより強力です。

## 有界性（なぜ暴走できないか）

`loop-guard.sh` がキルスイッチであり、モデル自身の判断ではありません:

- **イテレーション上限**（`budget.max_iterations`） — 常時オンのハードバウンド。
- **実時間上限**（`budget.max_wallclock_min`） — **ドライバが tick ごとに
  `--elapsed-min` を渡すからこそ**強制されます（永続化されたループ開始時刻から
  `goal-state.sh elapsed-min` で導出）。`loop-guard.sh` は `ELAPSED_MIN=0` を
  デフォルトとするので、`--elapsed-min` が省略されると上限は無効になります —
  `/goal` ドライバは常にこれを渡します。（これは元の実現可能性スパイクの Codex
  レビューが指摘したギャップで、`/goal` がそれを塞ぎます。）
- **no-progress**（`stop.no_progress: true`） — 判定ハッシュは**正規化された
  失敗シグネチャ**です（判定ラベル + AC id のみ。タイムスタンプやトークン数の
  ような揮発的な散文は `goal-state.sh signature` が剥がす）。よって同じ失敗形状の
  2 tick は、イテレーション予算を使い切る代わりに `STOP:no_progress` を発動します。
- **fail-closed** — 読み取れない/壊れた契約は `STOP:guard_error` を返します。

`token`/`usd` は**決して**ハード STOP のレバーではありません（`max_usd: 0` =
未追跡）。実際のバウンドはイテレーション + 実時間で、これはエピックの非ゴールに
沿っています。

## 人間ゲート

`/goal` は green まで駆動して**停止**します — マージ・プッシュ・タグ付けは決して
しません。それらは人間ゲートのまま残ります（契約の `human_gate: [merge, push]`）。

## CI でテストされるもの・されないもの（正直なスコープ）

- **CI でテストされる**: `goal-state.sh`（ユニットスイート `tests/goal-state/`）・
  `goal.contract.yaml` の lint（`check-contract.sh`）・再利用するプリミティブが
  変更されていないこと。
- **CI でテストされない**: `/loop`/`ScheduleWakeup` のケイデンス、および
  end-to-end の implement→verify→stop の挙動。これらは、スキルが自己呼び出し
  できないプリミティブを使って**ランタイム**で走るため、end-to-end の挙動は
  **dogfood** 実行と外部証跡で確認され、テストスイートでは確認されません。
  ランタイムループは、本プロジェクトの初期のランタイム限定受入条件が扱われたのと
  同じように扱ってください — CI の外で検証する。

## 状態ファイル

`<runs>/goal-<task-id>.state`（runs ディレクトリは gitignore 済）は `start_epoch`・
`iteration`・`prev_sig` を保持します。run ごとの揮発的な状態であり、決して
コミットされません。
