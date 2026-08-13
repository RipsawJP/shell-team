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
  `.shell-team/loops/`, `CLAUDE.md`, or the workflow.
- A merge of records only — a retro, a board close-out, a provenance record —
  needs no stop: nothing takes effect and one command reverts it.
- Do stop before force-pushing, and before anything that destroys work git
  cannot restore.
```

上のパス一覧はこのリポジトリでの当てはめであって、基準そのものではありません — このブロックを貼り付ける前に、自分のリポジトリで実行される面に置き換えてください。置き換える対象には、機構的に強制されていない面も含みます。スクリプトが解析するわけではないが、自分のエージェントが行動の前に読むよう指示されている追跡対象ファイルも、その一つです。

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

- **実行されるものを変えるマージ** — このリポジトリでは `bin/`、`agents/`、`skills/`、`templates/prompt-blocks/`、`.shell-team/loops/`、`CLAUDE.md`、ワークフローの配下です。これらのパスは**機構的に強制されている**面 — 実行されるスクリプト、出荷される prompt、checker が解析する contract — であって、基準が届く範囲はそれより広いです。`.shell-team/test-recipe.md` は、このリポジトリ自身の `CLAUDE.md` がスイート実行前に読むことを要求する追跡対象の**助言的な指示ソース**で、機構的に強制するものが何も無いまま、変更をマージすればエージェントのその後の挙動が変わります。この一覧は 2 つの強制強度を意図的に混在させており、支配するのは一覧の所属ではなく基準 — そのマージが実行されるものを変えるか — のほうです。**記録だけのマージ**（retro・board のクローズアウト・provenance レコード）は、上の例が停止を求めないのと同じ理由で停止不要です。
- **git が取り消せないもの** — force-push、untracked ファイルの削除、唯一のコピーを上書きする操作。ある手順が「先に退避したから安全」な場合、**退避が実際に成功したことを破壊の前に検証する**べきで、成功を仮定してはいけません

この最初の停止点は、マージが実行されるものを変えるかどうかで発火します。どのブランチへ入れるかでもありません。「マージ」という言葉でもありません。記録だけのマージには何かが有効になる瞬間がなく、保証人は人間であるその瞬間自体が存在しないので、そこで止めても確認のコストだけを払って何も買えません。

これを名指しすることは、運用者が自分に課している規律であって、ループが強制するルールではありません。個人設定がどこかで停止を求めること自体は止められませんが、実効果が生じるちょうどその点にだけこれを保つことが、責任を運用者が置くと決めた場所に留めます。どの瞬間に聞くのが安全に感じるかで説明責任が漂うのを防ぐためです。

**罠: 拡張子は signal ではありません。** 成果物が prompt content であるこのリポジトリでは、「ドキュメントに過ぎない」は安全な判定になりません — 基準は内容が実行されるかどうかであって、ファイルの呼び名ではありません。`templates/prompt-blocks/playbook-*.md` は `.md` で、生成された成果物で、ドキュメントのように読めますが、出荷される `agents/*.md` にスプライスされます。`bin/check-prompt-sync.sh` がそのスプライスを強制しているので、これは信じるしかない警告ではなく検証できる機構です。

## 凍結された intent block を誰が再凍結してよいか

凍結された intent block はループが判定される正典なので、既定では**何が変わったかに関わらず**、都度の人間 GO なしには動きません。この既定は箱出しのまま無条件で、下の例外を自分から選び取らない限り今日のままです。

再凍結には 2 つのクラスがあり、委譲できるのは片方だけです。**class-B** の再凍結——Goal 文・Non-goals・criterion の prose・Input space のいずれかに触れるデルタ——は常にあなた自身の GO が要ります。凍結 intent はあなた自身の決定の記録であり、それが望むことを書き換えられるのはあなただけだからです。**class-M**（mechanics repair）の再凍結——`- check:` 行だけに閉じたデルタで、コマンドとして壊れている・空虚・別の凍結済み criterion や自分自身の prose と測定済みで矛盾している行の修復——だけは、代わりにあなた自身の `CLAUDE.local.md` に記録された standing grant を根拠にできます。そこに grant の記録が無ければ、出荷時の既定は変わりません: どちらのクラスの再凍結も都度の人間 GO のままです。

class-M の境界は `bin/check-refreeze-class.sh` が機械判定します: 2 つの intent block の行数が同じで、少なくとも 1 行が異なり、異なる行すべてが両側とも `- check:` 行である場合にのみ `mechanics` を報告します——それ以外は `class-b`（または structural エラー）で、通常の都度手続きに戻ります。grant は以下を、あなた自身の checkout の `CLAUDE.local.md` に置いてください（出荷ファイルには絶対に置きません——このプロジェクトはあなたの grant の転記を出荷しませんし、あなたに代わって捏造することもありません）:

```markdown
# Local overrides

Re-freezing a frozen intent block: you hold a standing grant for class-M
(mechanics repair) re-freezes only — a delta confined to `- check:` lines,
repairing a line that is broken as a command, vacuous, or measured-contradictory
with another frozen criterion or with its own prose.

- Take the class-M path only when `check-refreeze-class.sh` reports `mechanics`
  (it needs both spec files as positional arguments). Record the class, the
  trigger, the superseded hash, the differing-line count, and every replaced
  line with its replacement verbatim on the board, and attest before you freeze.
- Class B — anything touching the Goal sentence, Non-goals, a criterion's prose,
  or Input space — still stops and asks me, every time.
- Tell the cross-provider reviewer that a class-M re-freeze happened. If it
  rejects the delta, restore the superseded block and treat this grant as
  suspended until I say otherwise.
```

クラス、トリガー（`broken-as-command` / `vacuous` / `contradictory`）、置き換えられたハッシュ、差分行数を `lines=<n>` として、そして番号付きの `old[i]:`/`new[i]:` ペアをちょうど `<n>` 組——置き換えられた行 1 本につき 1 組で、複数行の代表を 1 組だけで済ませない——、そして grant 自体を、board 自身の `- refreeze-class` sub-bullet に記録してください——このリポジトリが使う正確な形は `CONTRIBUTING.md` の「Re-freezing a frozen intent block」節にあります。class-M の再凍結が起きたことをクロスプロバイダのレビュアーに伝えてください: レビュアーの必須項目がそれを差し戻すことができ、置き換えられたブロックをバイト単位で新しい ratified バージョンとして復元し、あなた自身のレビューが済むまで grant を停止します。

### class-M の境界は機械的、発火条件はそうではない

`bin/check-refreeze-class.sh` はデルタが `- check:` 行だけに閉じていることを証明します。それは確かに機械的で、そしてそれが証明するものの全てでもあります。置き換えた行がその criterion の prose の意味をまだ保っているかは証明しません——その読み取り判断はクロスプロバイダのレビュアーの必須項目、そしてループのレベルでは S4 に残ります。そして、そもそも class-M の path をループが本当に踏んだかも証明しません: その分岐を取るかどうかは運用者の instruction ファイルが担っており、それは context であって強制ではありません——この文書自身の[限界](#限界)節がすでに `CLAUDE.md` に適用している「確率を変えるだけで機構を変えない」という限界と同じです。

1 つの限界は修正されずに開示されています: 2 つの異なる criterion の間で `- check:` 行を 2 本純粋に**入れ替える**と `mechanics`（テストケース `crc-blindspot-swapped-checks`）に分類されます——どの criterion にその行が属するかが変わっているにも関わらずです。これはこのチェッカーが見えない意味の変化です。check 行がどの criterion にネストしているかを一切パースしないためです。これを閉じるには、このプロジェクトが作らない 2 つ目の criterion-structure-aware なパーサが要ります。既知の挙動として固定してあります。grant があっても人間に残る 3 つのことがあります: **grant 自体**（権限の委譲はあなたが与えるものです）、上の swap のケースが具体例である**残余リスクの受容**、そして**grant を取り消す決定**です。

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
