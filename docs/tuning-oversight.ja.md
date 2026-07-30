# チームが確認で止まる頻度を調整する

[English](tuning-oversight.md) | [日本語](tuning-oversight.ja.md)

セッションがどれくらい確認を求めるかは**働き方の好み**です。人によってもリポジトリによっても違い、このプロジェクトがそれを他人に代わって決める立場にはないので、プラグインには埋め込んでいません。このページは、どこが固定でどこがあなたの領分か、そして自分の答えをどこに置くかを説明します。

## 固定されているもの、あなたの領分のもの

**固定 — ループの完了ゲート。** タスクが完了とみなされるのは、QA が `READY_FOR_REVIEW` に達し、**かつ**クロスプロバイダのレビューが `READY_FOR_MERGE` に達したときだけです。これは会話ではなく board の status flag が担保しているので、個人設定で緩むことはありません。ループが自分でマージすることもありません — マージするのは人間であり、これも同じ設計によるものです。これは権限の話であって、確認の話ではありません。ループはあなたの代わりにマージできませんが、あるマージが会話上の停止に値するかどうかはこの後で扱う調整可能な層であり、そこを狭めても固定層はそのまま残ります。

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

ループを回して、コストに見合う場面でだけ確認してほしい場合:

```markdown
# Local overrides

The loop's own gate is sufficient oversight here: a task is done only when QA
and the cross-provider review are both green, and the loop never merges on its
own.

Do not add conversational gates on top of it:

- Do not ask before creating a branch or filing an issue for work I have already
  asked for. Follow the repo's convention and tell me what you chose.
- Do not stop to have a multi-file change set approved before starting. State
  what you are about to touch, then proceed.
- Do stop before a merge that changes what runs — in this repository that means
  anything under `bin/`, `agents/`, `skills/`, `templates/prompt-blocks/`,
  `CLAUDE.md`, or the workflow.
- A merge of records only — a retro, a board close-out, a provenance record —
  needs no stop: nothing takes effect and one command reverts it.
- Do stop before force-pushing, and before anything that destroys work git
  cannot restore.
```

上のパス一覧はこのリポジトリでの当てはめであって、基準そのものではありません — このブロックを貼り付ける前に、自分のリポジトリで実行される面に置き換えてください。

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

- **実行されるものを変えるマージ** — このリポジトリでは `bin/`、`agents/`、`skills/`、`templates/prompt-blocks/`、`CLAUDE.md`、ワークフローの配下です。**記録だけのマージ**（retro・board のクローズアウト・provenance レコード）は、上の例が停止を求めないのと同じ理由で停止不要です。
- **git が取り消せないもの** — force-push、untracked ファイルの削除、唯一のコピーを上書きする操作。ある手順が「先に退避したから安全」な場合、**退避が実際に成功したことを破壊の前に検証する**べきで、成功を仮定してはいけません

この最初の停止点は、マージが実行されるものを変えるかどうかで発火します。どのブランチへ入れるかでもありません。「マージ」という言葉でもありません。記録だけのマージには何かが有効になる瞬間がなく、保証人は人間であるその瞬間自体が存在しないので、そこで止めても確認のコストだけを払って何も買えません。

これを名指しすることは、運用者が自分に課している規律であって、ループが強制するルールではありません。個人設定がどこかで停止を求めること自体は止められませんが、実効果が生じるちょうどその点にだけこれを保つことが、責任を運用者が置くと決めた場所に留めます。どの瞬間に聞くのが安全に感じるかで説明責任が漂うのを防ぐためです。

**罠: 拡張子は signal ではありません。** 成果物が prompt content であるこのリポジトリでは、「ドキュメントに過ぎない」は安全な判定になりません — 基準は内容が実行されるかどうかであって、ファイルの呼び名ではありません。`templates/prompt-blocks/playbook-*.md` は `.md` で、生成された成果物で、ドキュメントのように読めますが、出荷される `agents/*.md` にスプライスされます。`bin/check-prompt-sync.sh` がそのスプライスを強制しているので、これは信じるしかない警告ではなく検証できる機構です。

## 限界

`CLAUDE.md` は context であって Claude が従わなければならない設定ではありません。これを通じた緩和も強化も、**確率を変えるだけで機構を変えません**。確実に成立させたいものは CI（このリポジトリ自身の check がそうしています）か hook に属します。

**このプロジェクトは hook を出荷しません。** hook は実行可能な設定であり、公開リポジトリはそれが既定で届く場所として不適切です。指示ではなく強制が欲しい場合は、**実行前に自分で読める自分の作業コピー**で hook を書いてください。

## 唯一のサンプル hook と、それが無効のまま出荷される理由

このプロジェクトは、有効な hook は今も出荷していません — `.claude-plugin/plugin.json` は何も登録せず、プラグインをインストールしても hook のロードパスには何も置かれません。出荷するのは、自分でインストールする、読める無効なサンプル一つ — `docs/interventions-reminder-hook.sample.sh` — です。これはまさに、上の「限界」の段落が「指示ではなく強制が欲しいなら自分で書け」と言っていたことそのものです。

### 何をするか

`UserPromptSubmit` イベントのたびに、このサンプルは現在のリポジトリの board にタスクが in-flight（進行中）かどうかを確認し、in-flight であればその瞬間を分類してメッセージに対応する前に task の interventions ファイルへ記録するよう、1 行のリマインダーを表示します — 従来は散文の指示としてしか存在しなかったものの機械版です。あなたのメッセージは一切読まず、あらゆる失敗経路で無音の no-op に縮退します。インストールするかどうかを決める前に、スクリプト自身のヘッダーコメントで契約全体を読んでください。

### 自分でインストールし、まず読む

サンプルを自分の hooks ディレクトリにコピーし、登録する前にスクリプトを読んでください。Claude Code の設定に次のようなエントリを追加します:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/interventions-reminder.sh"
          }
        ]
      }
    ]
  }
}
```

### 捕捉忠実度の非対称性を、正直に述べる

出荷時の既定では、trigger-1 捕捉の「その瞬間」という性質は指示の強度にとどまり、`skills/run/SKILL.md` にある一文の指示が担っています — 新しいうちは守られる指示です。サンプルを導入すると、同じ性質は毎回のプロンプト送信のたびに機械的に促されます。どちらの状態でも、すべての介入が記録されたことは証明しません: `bin/check-interventions.sh` が証明するのは記録が存在し整形式であることだけであり、すべての介入が記録されたことは証明しません。
