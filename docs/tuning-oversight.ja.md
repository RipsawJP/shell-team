# チームが確認で止まる頻度を調整する

[English](tuning-oversight.md) | [日本語](tuning-oversight.ja.md)

セッションがどれくらい確認を求めるかは**働き方の好み**です。人によってもリポジトリによっても違い、このプロジェクトがそれを他人に代わって決める立場にはないので、プラグインには埋め込んでいません。このページは、どこが固定でどこがあなたの領分か、そして自分の答えをどこに置くかを説明します。

## 固定されているもの、あなたの領分のもの

**固定 — ループの完了ゲート。** タスクが完了とみなされるのは、QA が `READY_FOR_REVIEW` に達し、**かつ**クロスプロバイダのレビューが `READY_FOR_MERGE` に達したときだけです。これは会話ではなく board の status flag が担保しているので、個人設定で緩むことはありません。マージが人間を待つのも同じ設計によります。

**あなたの領分 — その周りでメインセッションがすること全部。** 編集前に変更セットを提示するか、ブランチ名を確認するか、issue を立てる前に聞くか、それとも黙って進めて選んだ結果を伝えるか。

## 止まり方は 2 種類あり、直し方が違う

セッション上は同じに見えますが、機構が別物です。

| 見える形 | 層 | 変更する場所 |
|---|---|---|
| 「issue を立てますか」「このブランチ名でいいですか」「変更セットを承認してください」 | Claude が従っている**指示** | `CLAUDE.local.md` |
| 「`Bash(git push …)` を許可しますか」等のツール権限プロンプト | **権限システム** | `.claude/settings.local.json` |

この区別が重要なのは、**強制力があるのは後者だけ**だからです。指示は Claude が weigh する context ですが、権限ルールは Claude の判断に関わらずクライアントが検査します。

## 個人設定の置き場所

Claude Code は広いスコープから狭いスコープへ読み込み、**後のファイルほど最後に読まれます**:

| スコープ | ファイル | 共有範囲 |
|---|---|---|
| 全プロジェクト | `~/.claude/CLAUDE.md` | 自分だけ・どこでも |
| このプロジェクト | `./CLAUDE.md` | 全員・git 経由 |
| この作業コピー | `./CLAUDE.local.md` | 自分だけ・ここだけ |

`CLAUDE.local.md` は最後に読まれるので、**広いルールを 1 つのリポジトリでだけ限定する**のに適した場所です。このリポジトリは `.claude/settings.local.json` とあわせてこれを gitignore しているので、そこに書いた内容が pull request に混ざることはありません。

## 例 — 確認を減らす

ループを回して、マージの判断だけしたい場合:

```markdown
# Local overrides

The loop's own gate is sufficient oversight here: a task is done only when QA
and the cross-provider review are both green, and merge waits for me.

Do not add conversational gates on top of it:

- Do not ask before creating a branch or filing an issue for work I have already
  asked for. Follow the repo's convention and tell me what you chose.
- Do not stop to have a multi-file change set approved before starting. State
  what you are about to touch, then proceed.
- Do stop before merging, before force-pushing, and before anything that
  destroys work git cannot restore.
```

## 例 — 確認を増やす

もっと早い段階で相談してほしいチームの場合:

```markdown
# Local overrides

- Before a change spanning more than one file, state the files, the base branch,
  whether it is additive or destructive, and the issue it serves. Wait.
- Before implementing a feature, agree the issue and the branch name first.
- Get agreement before pushing, opening or merging a pull request, or filing an
  issue.
```

## どちらの方向でも残す価値がある停止点

好みに関わらずコストに見合う停止が 2 つあります:

- **マージ** — ループがそこを中心に設計されているため
- **git が取り消せないもの** — force-push、untracked ファイルの削除、唯一のコピーを上書きする操作。ある手順が「先に退避したから安全」な場合、**退避が実際に成功したことを破壊の前に検証する**べきで、成功を仮定してはいけません

## 限界

`CLAUDE.md` は context であって Claude が従わなければならない設定ではありません。これを通じた緩和も強化も、**確率を変えるだけで機構を変えません**。確実に成立させたいものは CI（このリポジトリ自身の check がそうしています）か hook に属します。

**このプロジェクトは hook を出荷しません。** hook は実行可能な設定であり、公開リポジトリはそれが既定で届く場所として不適切です。指示ではなく強制が欲しい場合は、**実行前に自分で読める自分の作業コピー**で hook を書いてください。
