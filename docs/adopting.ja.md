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

## stacked-branch base-ref discriminator と borrowed-vocabulary sweep の宣言

T-1081 以降に凍結するすべての spec は、凍結された intent block 内の 1 行
（上記の `- user-visible:` / `- verification-class:` と同じ宣言領域）で
追加の宣言を持つ: トップレベルの bullet
`- base-ref-discriminator: <instantiate した two-arm 式>` または
`- base-ref-discriminator: not-applicable — <reason>`。これは stacked
branch 上の spec だけでなく、**最初の凍結を行うすべての spec** に必須
である——base-side blob を一切読まない spec にとっては後者の形が正しい
答えになる。

spec が 1 つ以上のまだ open な predecessor PR の上に stack され、その
criteria が base-side blob（stack 上のファイルの以前の状態、変更前の値）
を読む場合、そこに書く値は 1 つの two-arm 式であり、base-side blob を
読むすべての criterion で byte 単位で同一に spell される:

```
B=$(if git show-ref --verify --quiet refs/heads/<predecessor-branch>; then git merge-base "<predecessor-branch>" HEAD; else git merge-base "<integration-branch>" HEAD; fi)
```

`<predecessor-branch>` はこの spec 自身の branch が stack されている直近の
predecessor、`<integration-branch>` は**あなた自身のリポジトリの
integration branch** を指す parameter である——この repository では
`develop`、他の多くの repository では `main` であり、この repository の
convention に矯正されるのではなく自分の convention を代入する。第一の
arm は `git merge-base "<predecessor-branch>" HEAD` であり、意図的に
predecessor branch tip の `rev-parse` ではない: この branch を切った後に
predecessor branch を進める rework round は、そのブランチの tip を動かす
が共通の祖先は動かさない。ここで "branch point" が意味するのはその共通の
祖先である。fallback arm `git merge-base "<integration-branch>" HEAD` は、
predecessor branch がもはや resolve しなくなった時点——merge され削除さ
れた era——で取られる。arm の選択は明示的な `git show-ref --verify
--quiet` による branch-existence test で行い、`2>/dev/null ||` チェーン
では行わない: `||` チェーンは「predecessor branch が消えた」（fall back
すべき想定された era の変化）と「`git merge-base` が別の理由で失敗した」
（fail closed すべき場合）を区別できないためである。40 桁の commit
literal はどの criterion にも一切書かれない。1 つの残余ケースは engineer
して回避するのではなく開示される: merge されずに削除された predecessor
branch は fallback arm に integration branch の tip を resolve させてしま
い、それは branch point ではない——それは stack 全体を無効化する
route-back であり、criterion で覆い隠すべきものではない。

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

## 運用ルール

- 前フェーズの status flag がボードに設定されるまで、次フェーズへ進めないこと。
- タスクが完了するのは Codex レビュアーが `READY_FOR_MERGE` を設定したときだけです — これには先に QA が通過していること（`READY_FOR_REVIEW`）が必要で、QA 通過とクロスプロバイダレビューの両方がクリアされなければなりません。
- レビュアーは意図的に別のモデルプロバイダ（Codex）で走ります — ループの中に必ず入れておくこと。
- エージェント間の共有状態はファイルだけです（メモリは共有されない）。ボード
  （`<base>/todo.md`）・各仕様（`<base>/specs/`）・ループ契約が唯一の真実源です。
