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
├── binding.conf.example         # 不活性な executor-binding specimen；binding.conf にリネームで opt-in
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

稼働ファイルを追跡せずに残した場合にループの **gates** が実際にどうなるかは、下記の
[1 チケットでチームを試す](#1-チケットでチームを試す) を参照してください——
このパラグラフは scope（範囲）についてのものであり、追跡そのものを丸ごとスキップし
た場合に何が起きるかについてではありません。

global ファイルにはもう 1 つ影響があります。あるパスが無視されるかを git に
問い合わせるもの——`git check-ignore` や、それを土台にしたチェック——もその
ファイルを読みます。したがってそうしたチェックは、global excludes の無い CI では
通るのに手元では落ちる、という形で食い違い得ます。無視挙動に関する assertion では
操作者の設定を継承せず、`git -c core.excludesFile=/dev/null …` のように明示的に
pin してください。

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

## タスククラスによる検証の価格付け

T-1065 以降に凍結するすべての spec は、凍結された intent block 内の 1 行で、
その deliverable の verification class を宣言する: トップレベルの bullet
`- verification-class: mechanism — <rationale>` または
`- verification-class: no-mechanism — <rationale>`。**`mechanism`** は、
そのタスクの diff が実行対象の surface（`bin/`、`tests/`、`templates/`
配下のいずれかのパス、CI workflow、または checker の semantics）に届き
うる場合の既定であり、このクラスでは検証プロトコル全体がこれまで通り
適用される: 既にマージ済みの spec すべてに対する **full-population** な
downstream-impact diff、CI と同等のステップ全部、そして spec 自身の
criteria 全体に対する mutation-probe マトリクスである。

**`no-mechanism`** は、実行対象の surface を一切変更しないタスク——
wording・prose・editorial・documentation の deliverable——のためのもの
であり、3 つのコストを引き下げる。downstream-impact の inventory は
**full-population** diff の代わりに **read-set** でスコープされた分析と
して行う: タスクが編集するパスのいずれかを読む merged criteria の集合を
機械的に導出し、その集合について base ref と HEAD の verdict を差分する。
CI の同等性検証は、タスクの diff が入力に届きうるステップに限って走らせる。
mutation probe は、そのタスクが追加・変更した `- check:` 行だけに対して
要求され、spec 全体には要求されない。`no-mechanism` の spec は、それに
対応して、full-population な sweep も、CI 相当ステップ全体の再実行も、
このタスクが変更しないメカニズムの挙動検証も行わないことを明示的な
non-goal として宣言する。

現時点の強制は**チェッカーではなく duty** である: この宣言は spec
完成時に著者役割が行い、両方の review gate と人間がそれを読む——
**機械的なチェッカーは出荷されない**。あるタスクが自ら宣言したクラスに
正直に属しているかどうかを判定するのは読解による判断であり、diff だけ
から機械的に検証できるものではないからである。

## 実行方法

```
/shell-team:run <作りたいもの>
```

ループは Plan → Specify → Implement → Validate → Review を回し、各フェーズゲートで
ボード（`<base>/todo.md`）の status flag を進め、マージ/プッシュの前に人間のために
一時停止します。

## 役割と executor の紐付け

`team-init` は不活性な `<base>/binding.conf.example`
（`<base>` は `bin/team-paths.sh --get base` で解決）をスキャフォールド
します——これは `templates/binding-template.conf` のコピーです。host の
`<base>/binding.conf` は**丸ごと**採用されます: 出荷時の既定に対する
per-role の merge・layering・fallback は存在しないため、6 つの
inner-loop 役割（`tech-lead`・`pm-spec`・`engineer`・`qa-verifier`・
`codex-reviewer`・`ui-designer`）それぞれに `bind` 行を 1 本ずつ、多くも
少なくもなく持つ必要があります。部分的なファイルは既定から補完される
のではなく refuse されます。6 役割すべてに executor を割り当てたいとき
に作成します:

1. `mv <base>/binding.conf.example <base>/binding.conf` ——`team-init` が
   まだ走っていない場合は、プラグイン自身の
   `templates/binding-template.conf`（プラグインのインストール先
   ディレクトリから解決される——自リポジトリ配下のパスではない）を
   手動で `<base>/binding.conf` へコピーする。**この 6 行はプレース
   ホルダーのモデルトークン**を持っています——`claude` 系の 5 行に
   `model-1`、`codex-reviewer` に `model-2`——これらは実在するモデルを
   指しません。これに依拠する前に**全ての行**を置き換えるか、変更しない
   役割の行は `templates/binding-default.conf` の実際の行を転記して
   ください（**下記の grammar example ではありません**——それは異なる
   値を持つ custom-binding の例示です）。1 行だけ編集して止めると、
   残り 5 役割にプレースホルダーの紐付けが resolution と telemetry に
   そのまま入ってしまいます。
2. `bind <role> <provider> <model> <effort|-> <adapter>` 行（役割ごとに
   1 行）を編集する。`effort` は位置的に必須で、「値なし」はフィールド
   を省略せず常にリテラル `-` で綴る（この「未設定」の綴り方は effort
   列だけのもの——model 列は常に英数字始まりが必要）。
3. `bash check-binding.sh --config <base>/binding.conf` ——プラグインを
   ロードしていれば `bin/` は `PATH` に載るので `bin/` 接頭辞なしで
   解決する。プラグインをロードしていないチェックアウト内では
   `bash bin/check-binding.sh ...` を使う。
4. `bash resolve-executor.sh --print-resolved`（step 3 と同じ
   `bin/`-on-`PATH` の注記）——6 役割すべての有効な紐付けを解決するが、
   **availability probe を一切行わない**。`resolve-executor.sh --role
   <role>` はさらに検査するが、その probe は紐付けられた provider に
   よって決まる: **out-of-process** な provider（`codex`）については
   `codex --version` が `PATH` 上で観測可能かを確認し、その read-only
   probe を実行する。**in-process** な provider（`claude`）については
   **availability の判定を一切行わない**——probe kind を表示するだけで、
   根拠を持てる判定（harness 自身のサブエージェント呼び出し失敗）を
   下すのは呼び出し側に委ねる。出荷時の既定では 6 役割のうち 5 つが
   `claude` に紐付いているため、`resolve-executor.sh --role
   codex-reviewer` だけが実際に何かを probe する唯一の呼び出しになる
   （下記の `executor-unavailable` 参照）。

実際の validator が受理する設定例——採用される config が持つべき
6 役割すべてを示す:

```
schema 1

bind tech-lead      claude opus   high claude-cli
bind pm-spec        claude opus   high claude-cli
bind engineer       claude sonnet -    claude-cli
bind qa-verifier    claude sonnet -    claude-cli
bind ui-designer    claude sonnet -    claude-cli
bind codex-reviewer codex  gpt-5  -    codex-cli
```

host の `<base>/binding.conf` が全く無い場合——設定していない通常の
ケース——`resolve-executor.sh` はプラグイン出荷時の既定
`templates/binding-default.conf` にフォールバックする。その `model` 列は
`codex-reviewer` に限り `provider-configured` を持つ——出荷時の Codex
呼び出しが model フラグを一切渡さないという境界を表す——それ以外の各役割
の列は、その役割自身の `agents/<role>.md`（プラグイン自身の agent
定義）の pin をそのまま持つ。

`resolve-executor.sh` の refusal 集合は閉じており、**5 つ**のトークンを
持つ——`usage` は不正な呼び出し（CLI 引数エラー）であり config の状態
ではないため、この adopter workflow の対象外です。残る 4 つが
config-condition refusal で、うち 3 つは通常の config 編集で到達しうる
が、4 つ目は出荷済みの 2 つの adapter がすでに双方満たしている契約であり、
どちらに紐付けても今日は到達できない:

- `binding-unresolved`（exit code `2`）— 有効な紐付けが well-formed で
  信頼できる形に解決しなかった場合。通常の編集で到達しうる原因は 2 つ:
  `<base>/binding.conf` に存在するものが通常ファイルでない場合
  （ディレクトリ・FIFO・dangling symlink など）——出荷時の既定へ黙って
  fallback することは決してなく、それは「本当に存在しない」場合専用
  ——、または config 自体が `check-binding.sh` 自身の grammar が refuse
  する形で malformed な場合、例えば `bind` 行のフィールド数が誤って
  いる、あるいは provider/adapter/role トークンが未知の場合。
  `resolve-executor.sh` はこの 2 つの原因を同じ 1 つのトークンに畳み込む
  ——`check-binding.sh --config <base>/binding.conf`（step 3）は malformed
  な行の場合、より具体的な原因を報告する。
- `capability-unsupported`（exit code `1`）— 役割が、紐付けられた
  adapter が宣言していない effort 値を要求した場合。
- `executor-unavailable`（exit code `1`）— `--role <role>` モードでのみ
  発生する（`--print-resolved`、上記 step 4、は決して発生させない）。
  かつ **out-of-process** な provider について、その probe コマンドが
  `PATH` 上で観測できない、またはその read-only 検査が失敗した場合に
  限る——例えば `codex`/`codex-cli` に紐付けたのに `Codex` CLI が入って
  いない場合。**in-process** な provider（`claude`）に対しては `--role`
  は availability の検査を一切行わないため、`claude` に紐付けた役割は
  probe 経路からはこの refusal に到達しない。
- `contract-violation`（exit code `1`）— write / propose の
  board-authority を持つ役割が、board-transition チャンネルを持たない
  adapter に紐付けられた場合に enforce される。出荷済みの 2 adapter
  （`claude-cli`・`codex-cli`）はいずれも `carries board-transition` を
  宣言しているため、どちらに紐付けても今日この refusal には到達しない
  ——将来出荷される adapter がそう宣言しない可能性があるため、closed
  set の一員として引き続き記載する。

各 adapter は自分自身の effort 語彙を宣言しており、共有リストは存在
しない: `claude-cli` は `low`・`medium`・`high`・`xhigh`・`max` を、
`codex-cli` は `none`・`minimal`・`low`・`medium`・`high`・`xhigh`・
`max` を受理する。

**正直な境界線**には 2 つの軸があり、これを混ぜることが誤解の元になる。
**呼び出しが行われるかどうか**——ここは binding が**それを参照する
ループにおいて**制御しており、rebind によって呼び出しを完全に止める
ことができる。`/shell-team:run` と `/shell-team:goal` のループでは、
各役割の executor があらゆる invocation の前に解決され、refusal は
何かにフォールバックするのではなくフェーズを停止させる blocker である:
通常の編集で `binding-unresolved`・`capability-unsupported`・
`executor-unavailable` に到達しうる（いずれも上記参照）。単体で使う
2 つの review 系コマンドは同じケースではなく、違いは 1 つの委譲ステップ
にある。`/shell-team:review` は reviewer を直接呼ぶだけで **binding を
一切参照しない**——rebind はこれに対してどちらの方向にも何の影響も
与えない。`/shell-team:review-response` も**自身の review ステップでは**
binding を参照しないが、最後のステップで採用した findings を
`/shell-team:run` に引き渡し、その pipeline は他の run と同様に
resolution を参照する——したがって rebind は `review-response` に
**そのステップ経由でのみ**到達し、refuse によってそれを停止させること
もある。review ステップ自体に resolution を配線することは issue
**#245** が追跡している。**行われる呼び出しがどう実行されるか**——
こちらで binding
が変えるのは、`resolve-executor.sh` が解決して報告する値と**テレメトリ**
が記録する値**だけ**であり（provider・model・effort・adapter のいずれも
同じ）、実行そのものは何も変わらない。したがって別 executor への
**呼び出し経路**は配線されない。この第 2 軸の具体例を 3 つ挙げる（網羅
ではなく例示）: 役割が走る **model** は今なおその役割自身の
`agents/<role>.md` の pin から来る（resolved row からではない）——
issue **#236** はその pin の退役を追跡するが、対象は `claude-cli` に
紐付く 5 役割のみで、`codex-reviewer` は意図的に除外される（その pin は
Codex CLI を呼び出す Claude 側の wrapper を設定するもので、レビューを
行うモデルではない）。宣言された **effort** は span に記録されるが
どの呼び出しにも適用されず、他に及ぶ影響は上記の `capability-unsupported`
refusal だけである——adapter 定義が宣言しているのは effort の*機構*で
あって、宣言は適用ではない。そして、どの **executor**（provider と
adapter）経由で役割が呼び出されるかは、どの役割についても resolution が
経路制御しておらず、これを追跡する issue も存在しない。持ち帰るべき
規則は、第 2 軸を列挙ではなく普遍形で述べたほうである: 紐付けられた値
はすべて**宣言された値であって、実行されたものの観測ではない**。

## 会話駆動での使い方（スラッシュコマンド無し）

やりたいことを普通の言葉で伝えて、メインの Claude セッションにチームへ委譲させる
こともできます（スラッシュコマンドを打たずに Codex レビューを得ているのと同じ
やり方）。そのモデルと会話例は [usage-conversational.ja.md](usage-conversational.ja.md)
を参照。フルループをチャットから確実に発火させるには、
[`templates/CLAUDE-routing-snippet.md`](../templates/CLAUDE-routing-snippet.md)
のオプトイン・ルーティングブロックを自リポジトリの `CLAUDE.md` にコピーして
ください — `team-init` はそれを自動で追加しません（`CLAUDE.md` に一切手を触れない）。
ルーティングポリシーを採用するかどうかはあなたの判断です。

## adopter 向けドキュメントの宣言

T-1061 以降に凍結するすべての spec は、凍結された intent block 内の 1 行で、
その deliverable が **user-visible capability**（adopter に見える機能）か
どうかを宣言する: トップレベルの bullet `- user-visible: yes — <rationale>`
または `- user-visible: no — <rationale>`。`yes` の宣言は次の 2 通りの
いずれか一方でのみ discharge される: acceptance criterion 側に indent
された `- adopter-surface: <ドキュメントの置き場所>` 行を持たせるか、spec
側にトップレベルの `- adopter-docs-waiver: <reason>` 行を持たせて「この
user-visible capability には adopter-docs 用の surface が無い」ことを
明示する——これは回避策ではなく、一級の結果である。`no` の宣言に対して
どちらかの marker を付けることは refuse される。これは `no` の宣言が
単独で pass することと対をなす原則である。

現時点の強制は**チェッカーではなく duty** である。タスクの最初の凍結時に、
coordinating session がこの宣言領域を自分で読み、宣言がちょうど 1 行・
rationale が非空であることを要求し、`yes` の場合は criterion 配下の
`- adopter-surface:` 行か非空の `- adopter-docs-waiver:` 行のいずれか一方
（両方は不可、`no` に付けるのも不可）を要求する。それ以外は凍結を refuse
し、spec を著者に差し戻す。**機械的なチェッカーはまだ出荷されていない。**
一度実装したが、scan のスコープ判定に独立した欠陥が 2 ラウンド連続で
見つかったため、T-1061 自身の pre-commitment に従って issue #250 へ切り
出した——refuse すべき spec を pass させるゲートを出荷することは、正直な
prose の duty を出荷することより悪い。したがって 3 回目のパッチではなく
再設計を待つ。境界はどちらの形でも変わらない: この sweep は spec が名付け
た surface を**開かない**——resolve も validate もしない。ある surface が
本当に adopter 向けかどうかは reviewing gates と人間の役割であり、
mechanical check の役割ではない。path の allowlist を作れば adopter の
リポジトリをこの repository のレイアウトに強制することになる。この duty
はタスクの bootstrap freeze でのみ適用され、すでに記録済みのハッシュの
re-freeze では適用されない。

## 1 チケットでチームを試す

チーム全体でどう導入するかを決める前に、実際のチケット 1 件でループを一度だけ試したいなら: **trial branch（お試し用ブランチ）** を作り、そこへ shell-team 本来の仕組みでスキャフォールドし、稼働ファイルをそのブランチ上でコミットし、ループを実行し、終わったらブランチを削除します。ループの gate は稼働ファイルが **tracked（追跡済み）** であることを前提にしており、このルートはその前提を回避せず尊重します——`git switch -c` に続けて `team-init` を実行するか、`team-init.sh` 自身の `--trial-branch <name>` フラグでその 2 つを 1 回にまとめます。

**セットアップ。**

```bash
git switch -c trial/one-ticket
team-init.sh .
git add "$(team-paths.sh --get base)" "$(team-paths.sh --get specs)"
git commit -m "chore: scaffold shell-team for a one-ticket trial"
```

`--get` 引数は両方とも重要です: デフォルトレイアウトでは同じディレクトリに解決されますが、レガシーな `tasks/` + `docs/specs/` レイアウトでは `docs/specs/` がベースディレクトリの外にあるため、2 つめの引数を落とすと specs ディレクトリが永久に未追跡のままになります——両方を使ってコミットしてください（単一ディレクトリをハードコードした形は使わないでください）。

上の 1 行目と `team-init.sh` の行は 1 ステップにまとめて実行することもできます: `team-init.sh --trial-branch trial/one-ticket .` は、スキャフォールドの前に `trial/one-ticket` を作成してそこへ切り替え、ターゲットが git work tree の中に無い、その work tree の root で無い、あるいはそのブランチが既に存在する場合は（exit 2・メッセージに対処法つきで）拒否します——2 つのコマンドを分けて実行する必要は無く、上記は分かりやすさのためです。`--trial-branch` を指定しない場合、`team-init.sh` は自身で git コマンドを一切実行せず、どのブランチにいるかも気にしません。

マシンの global excludes（`core.excludesFile`）がベースディレクトリを隠している場合、この普通の `git add` はその場で拒否されます。このお試し用ブランチに限って `git add -f "$(team-paths.sh --get base)" "$(team-paths.sh --get specs)"` で強制するか、[稼働ファイルの置き場所](#稼働ファイルの置き場所) にあるとおり、`team-paths.sh --get base` があなたの repo で解決するパスを root `.gitignore` に repo レベルで re-include してください（デフォルトレイアウトでは `!.shell-team/`、レガシーレイアウトでは `!tasks/`）——そうすれば通常の形が恒久的に効くようになります。

あとはいつも通り、このお試し用ブランチ上で `/shell-team:run <作りたいもの>` を実行します。

**後始末。** `<integration-branch>` にはあなた自身のリポジトリの integration branch を代入してください——この repository では `develop`、他の多くの repository では `main` です。

```bash
git switch <integration-branch>
git branch -D trial/one-ticket
```

**未マージ (unmerged)** のブランチを削除すると、そのブランチからしか到達できないコミット——スキャフォールドされたベースディレクトリ、ボード、spec、そのタスク自身の記録——がすべて失われ、それ以外は何も変わりません: 他のブランチの tip は動かず、本流の履歴も変わらず、お試し用ブランチにコミットしなかったファイルにも触れません。ブランチは設計上未マージのままなので `git branch -d` は拒否し、強制形の `git branch -D` が必要になります——これは何かが間違っている兆候ではなく、ここでは期待される通常の結果です。それらのコミットは、いずれガベージコレクションされるまで `git reflog` から復元可能なままです。

「未マージ」は「決して伝播しない」ことを意味しません。お試し用ブランチ上のコミットは、ブランチが一度もマージされなくても本流に届くことがあります——誰かがそれを `cherry-pick` するかもしれませんし、共有リモートへ `push` すれば自動化や別の人がそれを拾うかもしれません。お試し用ブランチは **ローカル (local)** に留め、もし push していたなら、ローカルのものを消すときに **remote copy（リモート側のコピー）** も一緒に削除してください——分離を支えているのはその discipline であり、未マージであることだけではありません。

稼働ファイルを一度もコミットしないまま——git 無視されているか、単に一度も追加していない状態で——ループを走らせることは**サポートされていません (not supported)**。理由は gate ごとに異なり、それぞれが実際に持つ失敗の形と、実際にそこへ到達するシナリオで述べます。1 つの一括した主張として述べるのではありません。

`bin/check-durability.sh` は**拒否 (refuses)** します。どちらの拒否に出会うかは、あなたが何をしたかによります。`<base>/durability-mode` ファイルが一切無い場合、デフォルトのモードは `tracked` であり、ループが必要とするすべての記録が、記録されたコミット内のどの blob にも解決しません: `not-in-recorded-commit`、あるいは作業ファイル自体も無ければ `missing-working-file` です。`untracked-opt-out` はより狭いケースです——`working-tree-only` を宣言する **mode file（モードファイル）** 自体がコミットされていない場合にのみ発火します。どちらにせよ、お試しは green な hand-off に到達しません。

`bin/check-pii-shapes.sh` は、ループ自身の記録を**一度も読まないまま (without having read)** clean を報告します。diff スコープのモードはコミット済みの変更しか見ず、`--all` モードは untracked だが ignore されていないファイルにしか届きません——**gitignored（git 無視された）** ベースディレクトリは **どちらのモードでも (neither mode)** 読まれません。これはまさに、base dir を git から外しておく方法そのものです。

`bin/check-intent.sh` は、それ自身に恒久的な存在を持たない台帳から答え続けます: frozen-intent のハッシュとその attestation はボード上に生きているので、**fresh（新規）** な clone やチェックアウト、あるいは `git clean -fdx`（その `-x` フラグが gitignore されたパスにまで届きます）は、それらを一度も持ちません。`git reset --hard` は **追跡されていないボードをそのまま残します (leaves an untracked)**——つまりそれらを取り除く操作ではありません。

そして、ベースディレクトリをリポジトリの外へ移すことも抜け道にはなりません: `bin/team-paths.sh` は絶対パスの `TEAM_RUN_BASE` をそのまま拒否するため、ベースディレクトリはリゾルバ自身の判断により **repo-relative（リポジトリ相対）** であり続けます。

## stacked-branch base-ref discriminator と borrowed-vocabulary sweep の宣言

T-1081 以降に凍結するすべての spec は、凍結された intent block 内の 1 行
（上記の `- user-visible:` / `- verification-class:` と同じ宣言領域）で
追加の宣言を持つ: トップレベルの bullet
`- base-ref-discriminator: <instantiate した two-arm 式>` または
`- base-ref-discriminator: not-applicable — <reason>`。これは stacked
branch 上の spec だけでなく、**最初の凍結を行うすべての spec** に必須
である。2 つの形は自由選択ではない: two-arm 式が値になるのは、いずれかの
criterion が base-side blob を読み、かつ branch が authoring time に
open な predecessor を持つ場合**のみ**である（分類は 1 回きりで、
predecessor が途中で merge されるような era の変化によって再分類される
ことはない）。それ以外のすべてのケース——base-side blob を一切読まない、
または open な predecessor が無い——では、branch 自身の実際の base ref
を名指しする `not-applicable — <reason>` を取る。

spec が 1 つ以上のまだ open な predecessor PR の上に stack され、その
criteria が base-side blob（stack 上のファイルの以前の状態、変更前の値）
を読む場合、そこに書く値は 1 つの two-arm 式であり、base-side blob を
読むすべての criterion で byte 単位で同一に spell される:

```
B=$(if git show-ref --verify --quiet refs/heads/<predecessor-branch>; then git merge-base "<predecessor-branch>" HEAD; elif git show-ref --verify --quiet refs/remotes/<remote>/<predecessor-branch>; then git merge-base "refs/remotes/<remote>/<predecessor-branch>" HEAD; else git merge-base "<integration-branch>" HEAD; fi)
```

これがそのままコピーすべき canonical な形である——以下の prose が説明して
いる local-branch-only の簡略形ではない: predecessor が remote-tracking ref
としてしか存在しない checkout では `elif` arm が取られ、その `merge-base` の
引数はフルパスの `refs/remotes/<remote>/<predecessor-branch>` である
（bare の `<predecessor-branch>` はその checkout では一切 resolve しない）。

`<predecessor-branch>` はこの spec 自身の branch が stack されている直近の
predecessor、`<integration-branch>` は**あなた自身のリポジトリの
integration branch** を指す parameter である——この repository では
`develop`、他の多くの repository では `main` であり、この repository の
convention に矯正されるのではなく自分の convention を代入する。第一の
arm は、predecessor が local branch として resolve する場合
`git merge-base "<predecessor-branch>" HEAD` であり、意図的に
predecessor branch tip の `rev-parse` ではない: この branch を切った後に
predecessor branch を進める rework round は、そのブランチの tip を動かす
が共通の祖先は動かさない。ここで "branch point" が意味するのはその共通の
祖先である。existence test が predecessor を remote-tracking ref として
しか見つけられなかった場合、同じ arm は
`git merge-base "refs/remotes/<remote>/<predecessor-branch>" HEAD` になる
——bare の predecessor 名ではなく、そのフルパスである。local branch を
持たない checkout では bare 名は resolve しない（`fatal: Not a valid
object name`）。fallback arm `git merge-base "<integration-branch>" HEAD`
は、predecessor が**どちらの namespace にも** resolve せず本当に消えて
いる時点——merge され削除された era——で取られる。arm の選択は明示的な
`git show-ref --verify --quiet` による branch-existence test で行う——
predecessor が local branch として resolve する場合は
`refs/heads/<predecessor-branch>` に対して、fresh clone や CI checkout
が fetch しただけで local に checkout していない remote-tracking ref
としてしか存在しない場合は `refs/remotes/<remote>/<predecessor-branch>`
に対して行い、この existence test は `refs/heads/` だけを前提にせず、
この checkout が実際に predecessor を持っている namespace のほうで
見つけなければならない——そして `2>/dev/null ||` チェーンでは行わない:
`||` チェーンは「predecessor branch が消えた」（fall back すべき想定
された era の変化）と「`git merge-base` が別の理由で失敗した」（fail
closed すべき場合）を区別できないためである。40 桁の commit literal は
どの criterion にも一切書かれない。

predecessor が**どちらの namespace にも** resolve しない checkout——
一度も fetch していない: shallow clone、`--single-branch` clone、または
child branch だけを fetch した CI checkout——は fallback arm が存在する
ための era ではない。predecessor が open な PR を持つかどうかは
repository の state of record（そのブランチが乗っている train）の事実
であり、この checkout がたまたま fetch した範囲の話では決してない。
したがってこのケースも `not-applicable` の宣言ではない: 凍結する前に
predecessor を fetch するか、route back すること——existence test の
不在が黙って選んでしまう arm で凍結してはならない。その不在は
existence test だけを見る限り genuine な merge と見分けがつかず、
そこを通り抜けて凍結することは禁じられている。

3 つの残余ケースが、同じ扱いで、回避策を講じるのではなく開示される:
1 つ目は、merge されずに削除された predecessor branch が fallback arm
に integration branch の tip を resolve させてしまい、それは branch
point ではない——それは stack 全体を無効化する route-back であり、
criterion で覆い隠すべきものではない。2 つ目は、この branch を切った後に
predecessor branch が rebase、force-push、または squash-merge された
場合で、これも同じ扱いの route-back であり、どちらの arm もこれを
生き延びるように再設計されてはいない——rebase と force-push は
predecessor の tip を動かし、記録済みの共通の祖先がその祖先でなくなる
可能性があり、squash merge は predecessor の変更を、その元の commit の
どれとも SHA を共有しない 1 つの commit として integration branch に
乗せてしまうため、era の変化による fallback が正しく発火した後でも
`merge-base` は本当の branch point より前の commit を resolve して
しまう——メカニズムは異なるが結果は同じである。

現時点の強制は上記の adopter-facing documentation の宣言と同じ足場で
**チェッカーではなく duty** である: タスクの最初の凍結時に coordinating
session がこの宣言領域を自分で読み、宣言が無い・2 つ以上ある・宣言領域外
に置かれている spec を refuse する。機械的なチェッカーはまだ出荷されて
いない。

この宣言と並行して、すべての spec の凍結時 premise sweep は、文字列
token の出現回数についてのすべての literal count premise——特に `= 0`
という premise——を `own-coinage`（このタスク自身が導入する literal）か
`borrowed`（他の document が既に coin した token: invariant-lock id、
status flag、grammar family name、その他の既存 vocabulary）のいずれかに
classify する。これは spec author の凍結時 duty である: borrowed な
token はすべて spec 自身の `## Assumptions` セクションに、それを確認する
measurement command と共に enumerate され、execution 能力を持つ側が凍結
前にその command を branch point の committed blob に対して live に実行
し、測定値を assumption の傍に記録する。「このタスクが導入する新しい
literal」だけに scope した sweep では不十分である——merged された sibling
task によって既に stack に持ち込まれた token を見逃してしまう——そして
測定されなかった borrowed-vocabulary count premise は broken check line
として扱われる。

## verification ceiling を宣言する

T-1093 以降、すべての spec は自分の凍結 intent block 内、上記の
`- user-visible:`・`- verification-class:`・`- base-ref-discriminator:` の
各 key が既に占めている宣言領域に、もう 1 行——top-level bullet
`- verification-ceiling: unit-and-static | real-environment — <rationale>`
——を追加で宣言する。これが **verification ceiling**（検証の天井）——この
spec に対して QA が実際に到達できる検証レベル——であり、green flag が
bare な green ではなく「このレベルまでは green」と読めるようにするために
存在する: `unit-and-static` は loop 自身の gate が unit test と static /
textual verification までしか届かず checkout の外には出られないことを、
`real-environment` は criterion が名指す実 runtime（storage put が queue
に流れ worker に届く経路・手動 deploy・cloud credential の裏でしか届かない
作業）を追加で exercise できることを意味する。

**どちらの値も all-or-nothing ではない。** 宣言された値は、個別に印が
付いていないすべての criterion について gate が何に到達したかを述べる。
宣言された ceiling より上に位置する criterion は、自分自身の indented
`- above-ceiling: <gate 通過後にこの criterion を所有する human>` サブ
箇条を持つ——ゲート通過後にそれを所有する human を名指しし、出荷済みの
`- adopter-surface:` idiom を再利用するのであって新しい free-text list
ではなく、1 つのサブ箇条が複数の criterion を代表することも決してない。
このサブ箇条は **どちらの宣言値の下でも** 利用可能であり、これが正直な
mixed case を可能にする: spec の criteria が複数の real-environment
capability class に、それぞれ異なる到達度でまたがる場合——例えば ある
criterion については gate が実際に exercise した staging の
storage-to-queue-to-worker path があり、別の criterion については gate が
届かない production deploy や credentialed な作業がある場合——は
`real-environment` を宣言して gate が到達した部分を表し、届かなかった方を
`- above-ceiling:` として印を付ける。どちらか一方の criterion を誤って
記述する値へ押し込まれることはない。

**exception set には floor があり、この対称性は「何も言わない」ために
使うことはできない。** 宣言された値は **少なくとも 1 つの criterion が
その値で verify されている** ことを attest しなければならない:
すべての criterion が `- above-ceiling:` と印付けられた
`real-environment` 宣言は refuse される——それは `unit-and-static` と
区別が付かず、読者に何も伝えないからである——その spec の正直な宣言は、
少なくとも 1 つの criterion が実際に verify されている最高の値である。
`unit-and-static` は floor であり、これ以上下げることはできないため、
残る唯一の degenerate case——floor でさえすべての criterion がその上に
ある場合——は refuse ではなく documented される: 宣言行は、宣言された値の
直後に固定 token `no criterion verified at this ceiling` を carry しなけ
ればならない。この token はその後 **そのまま verbatim で** QA の PASS
block の field と board の `READY_FOR_REVIEW` append の両方へ carry
forward される——spec を開かない読者にも、baseline coverage のように
見える bare な値ではなく、実際にその disclosure が読める行に届くように
するためである。

現時点の強制は、上記の宣言と同じ足場で **チェッカーではなく duty** で
ある: タスクの最初の凍結時に coordinating session がこの宣言領域を自分で
読み、ちょうど 1 つの conformant な `- verification-ceiling:` 行を要求し、
無い・重複している・closed vocabulary 外・vacuous な宣言——あるいは
宣言された ceiling を超える capability を明らかに要求している criterion
に `- above-ceiling:` サブ箇条でその所有者が名指しされていない場合——を
refuse して spec を author へ差し戻す。**機械的なチェッカーはまだ出荷され
ていない**——mismatch case は grep が決められる state ではなく human が
行う reading judgment であり、これはこのリポジトリの他の宣言領域 gate が
既に持つのと同じ disclosed-limitation pattern（issue #250）に乗る。この
duty はタスクの bootstrap freeze にのみ適用され、既に記録済みの hash の
re-freeze には適用されない。そして、宣言された ceiling が何を防ぐかに
ついての主張は一切していない——それは QA が到達したレベルを、後で
hand-off や board line を読む誰にとっても legible にするだけである。

## spec を誰が書くかを選ぶ（T-1091）

T-1091 以降、spec の著者を誰にするか自体が dispatch decision になった——
既存の `implement`/`verify` 軸と並ぶ第三の軸 `specify` で、`pm-authored` と
`operator-authored` の 2 値に閉じており、Plan で決め、同じ座で task の
board entry に記録する。

**`pm-authored` が出荷時デフォルト。** `pm-spec` が今まで通り spec を書く。
task の decision input が 1 つの session の context に集中していない、
ほとんどの task がこの形に当てはまる場合はこちらを選ぶ——formalization
（依頼をテスト可能な spec に変える作業）は `pm-spec` の比較優位である。

**`operator-authored` は judgment-density のボトルネックのため。** その
task の decision input——複数 repo にまたがる測定済みの事実、live 環境での
確認、インシデント履歴——が既に coordinating session 自身の context に
存在している場合はこちらへ routing する: `pm-spec` へ委譲する価値は算術的
にゼロになる——完全な hand-off package を書くこと自体が spec を書くこと
そのものであり、委譲は検証済みの一次情報を relayed な情報に変えるだけに
なる。このモードでは coordinating session（operator）が直接 spec を書き、
`pm-spec` は author ではなく **conformance formatter** として参加する——
check-intent と check-acs の grammar に整形するだけで、author が決めた
ことを書き換えることは決してなく、substantive な gap は自分の判断で
閉じずに author へ差し戻す。

**このガイドが防ぎたい anti-pattern。** `pm-spec` による authorship を
断ることは、loop の machinery まで置き去りにする理由にはならない。
凍結された intent block、board record、freeze sweep、2 つの review gate、
interventions ledger——これらは `pm-spec` が犯す間違いと同じくらい
operator が犯す間違いも捉える仕組みである。operator-authored な spec も
freeze sweep 以降は full loop がそのまま走る。`operator-authored` を選ぶ
のは spec を誰が書くかだけであり、machinery の残りが走るかどうかを選ぶ
ことでは決してない。

## Specify seam で spec review を elect する（T-1092）

`specify` と並んで、実装着手前に spec の **domain**（ドメイン）前提を
cross-provider の `codex-reviewer` に追加で 1 回読ませるかどうかを決める
第四の軸がある: `spec-review`——`none` と `cross-provider` の 2 値に閉じ、
`docs/loop-engineering/specify-seam-review.md` で定義・値付けされている。

**`none` が出荷時デフォルト。** 追加の pass は走らず、task には何の変化も
ない——通常の mechanism task は追加ラウンドの代償を払わない。

**この repo が自ら測定できない domain 前提に spec の正しさが依存する時、
`cross-provider` を elect する**——デプロイ順序の前提、本番で成立するとは
限らない rollback precondition、この repo の外にあるシステムについての
blast-radius claim 等。追加ラウンドは spec document 自体を読む——凍結
intent block とその declaration region であり、branch diff は決して読まない
——freeze sweep の後・`- intent-hash (v1)` を記録する前に走り、task の
review record 内の `## Spec review` セクションに `APPROVE` か
`REQUEST_CHANGES` を返す。`REQUEST_CHANGES` は spec 自身の author
（`pm-authored` モードでは `pm-spec`、`operator-authored` モードでは
operator）へ差し戻され、答えが返るまで freeze sweep は先へ進まない。

**保証すること・しないこと。** elect された spec review は loop の
**both gates**（`qa-verifier` の PASS と、実際に届いた変更に対する
`codex-reviewer` の APPROVE）のどちらでもなく、この軸の値に関わらず
両方とも引き続き必須であり、spec-review の APPROVE がどちらの代わりにも
なることはない。またこの読みは自身の入力を認証しない（cross-check する
2 つの条件テキストはどちらも agent が生成したものである)、読みが実際に
行われたことも検証しない、そして「domain 前提が健全である」ことを
reading judgment 以上の何かにすることもない。この軸はまだ一度も
end-to-end で発火していないため、間違って world について誤った spec の
実装をどれだけ防げるかは `undetermined`（未測定）である。

## oversight profile を選ぶ

host repo は host が自ら作成する `<base>/oversight.conf` で **oversight
profile**（監督プロファイル）を選択し、`bin/check-oversight.sh`（T-1103・
issue #343）が解決・検証する。profile は `autonomous` と
`governance-controlled` の 2 値に閉じ、`specify-seam`（Specify seam の
freeze）と `pre-merge`（`bin/close-out.sh` 自身の exit status）という 2 つの
閉じた **seam** 値を統制する。`- dispatch:` record も環境変数もタスクごとの
board field も、1 task だけ別の profile を選ぶことはできない——この宣言は
1 ファイルが持つ repository 単位のプロパティである。

**`autonomous` が出荷時デフォルト。** `<base>/oversight.conf` が一切無ければ
これに解決され、何も変わらない: 既存の seam に要件は増えず、既存 gate の
verdict も動かず、今日 conformant な board・spec・record は byte 単位で
conformant のまま。

**組織の IT governance が segregation of duties（職務分離）を課す時、
`governance-controlled` を宣言する**——変更は、それを作った当事者自身の
承認では前へ進めない、というルール。`<base>/oversight.conf` に `schema 1`・
`profile governance-controlled`・gate したい seam ごとの `seam` 行を書く。
宣言した seam はそれぞれ、task 自身の board entry 上に記録された conformant
な `- oversight-approval (<seam>): approver=<handle> — producer=<handle>
— approves=<anchor> — date=<YYYY-MM-DD> — record=<locator>` sub-bullet を
要求する。`approver` handle は ASCII normalization 後に `producer` handle と
異なっていなければならず、`approves=` anchor は gate 対象の artifact を
今なお指していなければならない——古くなった anchor も膨張した anchor も、
黙って受理されず refuse する。

**enrollment は蒸発しない。** board のどこかに——`## Active` でも `## Done`
でも、どの task でも、どちらの seam でも——過去の approval record が
1 つでも存在すれば、宣言が消えたことは `autonomous` へ黙って戻ることを
意味せず、`enrollment-vanished` として refuse する。governance から
抜ける唯一の正規の手段（**de-enrollment**）は、明示的な `profile
autonomous` 宣言——削除ではなく、diff で見える 1 ファイルの追加——である。
その根拠が意図的に **board 全体** であるのは、それが守っている profile が
1 task ではなく repository 全体のプロパティだからだ。

**この機構が保証すること・しないこと。** これは content anchor つきの
**self-declared conflict check** を出荷するのであって——git 管理された
workflow evidence として記録されるが、認証済みの segregation-of-duties
統制ではない。いかなる handle も **does not authenticate**（認証しない）:
署名も SSO/OIDC binding も directory lookup も無く、`producer=` に
記された当事者が実際の producer である保証も、`approver` が承認対象を
実際に読んだ保証も無い。board 記録は現行スナップショットにおける
best-effort な workflow evidence であって、tamper-evident でも独立して
retain された監査保管庫でもない——そうした保証が組織に必要なら、自前の
branch protection・commit signing・retention・削除監視という
**compensating controls**（補完的統制）と組み合わせること。2 つの seam は
この loop 自身の **callable transitions**（呼び出し可能な遷移点）であって、
組織の release や deployment の認可境界ではない: どちらの seam も
通らない直接 merge・cherry-pick・hotfix は gate されない。class-M の
mechanics-repair re-freeze も例外ではない——gate は version ベースで
class-blind なので、enroll すれば **mechanics-repair re-freeze** を含む
すべての freeze が record を要求される。opaque handle の比較が実際の
segregation-of-duties 統制を満たすかどうかは `undetermined`（未測定）で
あり、この repository のどの checker もそれを測定しない。

**自分の CI に何かを組み込む要件は無い。** `pre-merge` seam の実効性は
`bin/close-out.sh` 自身の exit status にあり、adopter は既にそこで
実行している——`check-oversight.sh --seam pre-merge` はここで、追加で
自前の CI にも組み込みたい host 向けのオプションとして文書化されているに
過ぎず、profile が機能するための前提条件では決してない。この checker の
`governance-controlled` arm は **fixture-exercised only**（fixture での
み検証済み）として出荷され、この repository では意図的に live run で
行使しない——ここで enroll すれば、coordinating session がその分離を
監査する機構自身の producer と approver を兼ねることになってしまう。
`qa-verifier` の PASS と `codex-reviewer` の APPROVE という **both gates**
はどちらの profile でも変わらず必須であり、oversight-profile approval
record がその代わりになることはどちらの向きにも無い。

## review-input fidelity を記録する

review record の verdict section が名指す各 executor pass は、1 つの
opaque な pass id の下に 4 つの情報を持ち、`bin/check-review-input.sh`
（T-1104・issue #335）がその grammar を fail-closed に検証する: pass の
**executor-invocation**（1 行に rendered された verbatim な argv）、
closed set `generation` / `confirmation` から選ぶ **pass-role**、先頭
token が `carried` / `not-carried` / `not-applicable` のいずれかで後に
非空の説明が続く **briefing-fidelity**、そしてその pass が publish した
**raw-capture** stem。1 つもこれらの field を持たない record — 今日
すでに commit されている全 record がこれに当たる — は exit 0 になる:
この要件は forward-only である。

**verbatim field が決して持ってはならないもの。** `executor-invocation`
の値は実際の argv であり、永続的に tracked な git history に残る。
environment dump や変数の展開値、credential・token・key・認証 header、
repository 外の absolute path outside the repository（特に
home-directory path や `$TMPDIR` session root）、あるいは operator や
account の identity を決して含んではならない。実際の argv が invoker の
home directory 配下の absolute path（特に `--cd` 引数）を含む場合は、
その path を repository root からの相対パスとして `<repo-root>` と記録
する——flag・他の引数・その順序はすべて verbatim のまま保つ。これは
recording convention であって checker が強制するものではない: checker
はこの field の内容を判定しないので、どちらの書き方でも record は
conformant である。`bin/check-pii-shapes.sh`
の diff-scoped CI step は現実の、しかし同じく有限な backstop であり
——named prefix・named root・長さの下限に基づく
**finite known-shape screen** であって、網羅的な secret 検出ではない
——ゆえに上記の field contract こそが、書く瞬間（それが安く済む唯一の瞬間）に適用
される一次的な統制である。

**この機構が閉じないもの。** 記録するのは what was invoked（何が
invoke されたか）であって、model が実際に何を受け取ったかでは決してない
——committed byte に対するいかなる判定も、briefing が executor の
context に届いた invocation と届かなかった invocation を見分けられない。
`pass-role` label の真偽も、記録された argv が実際に走った argv で
あることも検証しない。そして `raw-capture` field が名指す raw file が
**not present on disk**（disk 上に存在しない）ことも見抜けない——
`raw-capture` の値は構造上 untracked（`/.gitignore`）なので、何も指さ
ない stem もこの checker には conformant である。

## 運用ルール

- 前フェーズの status flag がボードに設定されるまで、次フェーズへ進めないこと。
- タスクが完了するのは Codex レビュアーが `READY_FOR_MERGE` を設定したときだけです — これには先に QA が通過していること（`READY_FOR_REVIEW`）が必要で、QA 通過とクロスプロバイダレビューの両方がクリアされなければなりません。
- レビュアーは意図的に別のモデルプロバイダ（Codex）で走ります — ループの中に必ず入れておくこと。
- エージェント間の共有状態はファイルだけです（メモリは共有されない）。ボード
  （`<base>/todo.md`）・各仕様（`<base>/specs/`）・ループ契約が唯一の真実源です。
