# shell-team を自リポジトリに導入する

[![English](https://img.shields.io/badge/lang-English-lightgrey?style=flat-square)](adopting.md)
[![日本語](https://img.shields.io/badge/lang-日本語-1f6feb?style=flat-square)](adopting.ja.md)

このリポジトリは **shell-team** プラグイン — spec-first（仕様優先）で
ファイルベースの引き継ぎによって駆動される PM → Engineer → QA → Codex-Reviewer
パイプライン — を動かせます。プラグイン本体は中央に置かれ（1 回インストールする
だけ）、導入する各リポジトリは `team-init` がスキャフォールドするリポジトリ
ごとの*インスタンス*だけを持ちます。

## 稼働ファイルの置き場所

`team-init` はすべてを**単一のベースディレクトリ**配下にスキャフォールドします。
そのためプラグインのフットプリントが本流ツリーに散らばることはありません。
デフォルトのベースは `.shell-team/` で、環境変数 `TEAM_RUN_BASE` で上書きできます。
既にレガシーな `tasks/` + `docs/specs/` レイアウトを使っているリポジトリは検出され
再利用されます（どのレイアウトが有効かはリゾルバ `bin/team-paths.sh` が判断）。

```
<base>/                          # デフォルトは .shell-team/
├── todo.md                      # タスクボード / 引き継ぎ契約（status flag）
├── loops/
│   └── shell-team.contract.yaml   # ループの TRIGGER/SCOPE/ACTION/BUDGET/STOP 契約
├── specs/                       # 各タスクの仕様 + 受入条件
├── runs/                        # run ごとのテレメトリ（<base>/.gitignore で git 無視）
├── retros/                      # レトロスペクティブ
├── reviews/                     # クロスプロバイダレビュー成果物
├── AGENTS.md                    # クロスツール向けポインタ doc（下記参照）— 真実源ではない
├── test-recipe.md               # repo 固有のテスト実行レシピ（engineer/QA が最初に読み、
│                                #   確立した手順を追記。--force でも上書きされない）
└── .gitignore                   # 自己完結。runs/ テレメトリを無視
```

**ホストルートには手を触れません。** `team-init` はあなたの `CLAUDE.md` を編集せず、
ルートの `.gitignore` にも追記しません。テレメトリは自己完結した
`<base>/.gitignore` で無視されます。ベースディレクトリ全体を git 無視にするか、
そして下記の運用ルールを自分の `CLAUDE.md` にコピーするかは、あなたの判断です。
プラグインがそれらの編集を勝手に行うことはありません。

base dir を git に載せない場合、その方法 2 つは効く範囲が違います。repo 自身の
`.gitignore` に `.shell-team/` を書く方法はその repo だけに効き、取り消しも容易
です。global excludes（`git config --global core.excludesFile`）に入れる方法は
マシン上の *すべての* repo で base dir を隠します——後から「この repo では
ボードを追跡したい」と決めた repo も含めてです。しかもその症状は間接的で、単に
ボードが `git status` に現れなくなるだけです。1 つの repo だけ復帰させるには、
その repo の root `.gitignore` に `!.shell-team/` を追記してください。repo 側の
パターンが global ファイルより優先されます。このリポジトリ自身もまさにその理由で
その行を持っており、`.shell-team/` を global に無視している操作者の環境でも自分の
base dir は追跡されたままになります。

global ファイルにはもう 1 つ影響があります。あるパスが無視されるかを git に
問い合わせるもの——`git check-ignore` や、それを土台にしたチェック——もその
ファイルを読みます。したがってそうしたチェックは、global excludes の無い CI では
通るのに手元では落ちる、という形で食い違い得ます。無視挙動に関する assertion では
操作者の設定を継承せず、`git -c core.excludesFile=/dev/null …` のように明示的に
pin してください。

`team-init` 自身もこれをチェックします。スキャフォールド完了後、git が解決済みの
base dir を無視対象と報告した場合、そのディレクトリ名と、その規則が有効な間はループの
commit ステップが「何もコミットしていないのに成功した」と報告してしまう旨を説明する
advisory な警告を stderr に出力します。これはエラーではありません——上記のとおり
base dir を無視することは対応済みの構成であり——`team-init` はどちらの場合も
exit 0 のままです。警告は、ループの最初の記録が黙ってコミットされないまま終わる前に
気づいてもらうためだけのものです。git 自身が無視/非無視のいずれとも判定できない場合
(破損した、あるいは到達不能なリポジトリなど) は、推測せずにその旨を伝え、報告すべき
ことが何もない場合は静かなままです。

セッションがどれくらい確認で止まるかも同じくあなたの判断で、出荷物ではなく
作業コピーごとに設定します。詳細は
[tuning-oversight.ja.md](tuning-oversight.ja.md) を参照してください。

## `AGENTS.md` — クロスツール向けポインタ doc

`team-init` は **`<base>/AGENTS.md`** もスキャフォールドします。これは、任意の
ツールやエージェント（Claude・Codex レビュアー・別のアシスタント）に対して
*このリポジトリが作業状態をどこに保持しているか* — タスクボードと status-flag の
連鎖・各仕様・`project_status` スナップショット・デバイスごとの MEMORY.md
インデックスに関する注意・レビューがクロスプロバイダ（Codex）であるという事実 —
を伝える可搬な doc です。

これは**ポインタ/ミラーであって真実源ではありません**。進捗ログ・完了履歴・日付
付きエントリは一切持ちません。実際の状態は `<base>/todo.md`・各仕様・
`project_status` に置かれます。現在の真実はそれらを読んでください — `AGENTS.md` は
どのファイルを読むべきかを伝えるだけです。

**配置とトレードオフ。** これはベースディレクトリ配下（`<base>/AGENTS.md`）に置かれ、
リポジトリのルートには**置かれません** — `team-init` がホストルートに決して手を
触れないからです。その帰結として、*ルート*の `AGENTS.md` 規約を自動検出する
ツールは、これを**自動では拾いません**。これは意図的なトレードオフです — ホスト
ルート不可侵の保証を守り、`AGENTS.md` を自動ロードされるルート規約ファイルでは
なく、純粋に可搬なポインタ doc として扱います。あるツールにこれを読ませたい
場合は、そのツールに `<base>/AGENTS.md` を明示的に指し示してください。

## 実行方法

```
/shell-team:run <作りたいもの>
```

ループは Plan → Specify → Implement → Validate → Review を回し、各フェーズゲートで
ボード（`<base>/todo.md`）の status flag を進め、マージ/プッシュの前に人間のために
一時停止します。

## 会話駆動での使い方（スラッシュコマンド無し）

やりたいことを普通の言葉で伝えて、メインの Claude セッションにチームへ委譲させる
こともできます（スラッシュコマンドを打たずに Codex レビューを得ているのと同じ
やり方）。そのモデルと会話例は [usage-conversational.ja.md](usage-conversational.ja.md)
を参照。フルループをチャットから確実に発火させるには、
[`templates/CLAUDE-routing-snippet.md`](../templates/CLAUDE-routing-snippet.md)
のオプトイン・ルーティングブロックを自リポジトリの `CLAUDE.md` にコピーして
ください — `team-init` はそれを自動で追加しません（`CLAUDE.md` に一切手を触れない）。
ルーティングポリシーを採用するかどうかはあなたの判断です。

## 運用ルール

- 前フェーズの status flag がボードに設定されるまで、次フェーズへ進めないこと。
- タスクが完了するのは Codex レビュアーが `READY_FOR_MERGE` を設定したときだけです — これには先に QA が通過していること（`READY_FOR_REVIEW`）が必要で、QA 通過とクロスプロバイダレビューの両方がクリアされなければなりません。
- レビュアーは意図的に別のモデルプロバイダ（Codex）で走ります — ループの中に必ず入れておくこと。
- エージェント間の共有状態はファイルだけです（メモリは共有されない）。ボード
  （`<base>/todo.md`）・各仕様（`<base>/specs/`）・ループ契約が唯一の真実源です。
