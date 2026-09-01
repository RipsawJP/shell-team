# shell-team を自リポジトリに導入する

[![English](https://img.shields.io/badge/lang-English-lightgrey?style=flat-square)](adopting.md)
[![日本語](https://img.shields.io/badge/lang-日本語-1f6feb?style=flat-square)](adopting.ja.md)

このリポジトリでは **shell-team** プラグインを動かせます。spec-first
（仕様優先）の PM → Engineer → QA → Codex-Reviewer パイプラインで、
フェーズ間の引き継ぎはすべてファイル経由です。プラグイン本体のインストールは
中央に 1 回だけ。導入する各リポジトリが持つのは、`team-init` が
スキャフォールドするリポジトリごとの*インスタンス*だけです。

## 稼働ファイルの置き場所

`team-init` はすべてを**単一のベースディレクトリ**配下にスキャフォールドする
ので、プラグインのフットプリントが本流ツリーに散らばることはありません。
デフォルトのベースは `.shell-team/` で、環境変数 `TEAM_RUN_BASE` で上書きできます。
レガシーな `tasks/` + `docs/specs/` レイアウトを既に使っているリポジトリでは、
それを検出してそのまま再利用します（どちらのレイアウトが有効かはリゾルバ
`bin/team-paths.sh` が判断します）。

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
下記の運用ルールを自分の `CLAUDE.md` にコピーするか——どちらもあなたの判断に
委ねられており、プラグインが勝手に編集することはありません。

base dir を git に載せない方法は 2 つあり、効く範囲が違います。repo 自身の
`.gitignore` に `.shell-team/` を書けば、その repo だけに効き、取り消しも容易
です。一方、global excludes（`git config --global core.excludesFile`）に
入れると、マシン上の *すべての* repo で base dir が隠れます。後から「この repo
ではボードを追跡したい」と決めた repo も例外になりません。しかも症状は間接的で、
ボードが `git status` に現れなくなるだけです。1 つの repo だけ復帰させたい
ときは、その repo の root `.gitignore` に `!.shell-team/` を追記してください。
repo 側のパターンが global ファイルより優先されます。このリポジトリ自身も
まさにその理由でこの行を持っており、`.shell-team/` を global に無視している
操作者の環境でも、自分の base dir は追跡されたままになります。

なお、このパラグラフが述べているのは無視設定の効く範囲だけです。稼働ファイルを
追跡せずに残したときにループの **gates** が実際にどうなるかは、下記の
[1 チケットでチームを試す](#1-チケットでチームを試す) を参照してください。

global ファイルにはもう 1 つ影響があります。あるパスが無視されるかを git に
問い合わせるもの（`git check-ignore` や、それを土台にしたチェック）も、この
ファイルを読みます。そのため global excludes の無い CI では通るのに手元では
落ちる、という食い違いが起き得ます。無視挙動に関する assertion では操作者の
設定を継承せず、`git -c core.excludesFile=/dev/null …` のように明示的に
pin してください。

セッションがどれくらい確認で止まるかも、同じくあなたの判断です。出荷物では
なく作業コピーごとに設定します。詳細は
[tuning-oversight.ja.md](tuning-oversight.ja.md) を参照してください。

## `AGENTS.md` — クロスツール向けポインタ doc

`team-init` は **`<base>/AGENTS.md`** もスキャフォールドします。任意の
ツールやエージェント（Claude・Codex レビュアー・別のアシスタント）に、
*このリポジトリが作業状態をどこに保持しているか*を伝える可搬な doc です。
中身は、タスクボードと status-flag の連鎖、各仕様、`project_status`
スナップショット、デバイスごとの MEMORY.md インデックスに関する注意、そして
レビューがクロスプロバイダ（Codex）であるという事実です。

ただし、これは**ポインタ/ミラーであって真実源ではありません**。進捗ログ・
完了履歴・日付付きエントリは一切持ちません。実際の状態は `<base>/todo.md`・
各仕様・`project_status` にあります。現在の真実はそれらを読んでください。
`AGENTS.md` が伝えるのは、どのファイルを読むべきかだけです。

**配置とトレードオフ。** このファイルはベースディレクトリ配下
（`<base>/AGENTS.md`）に置かれ、リポジトリのルートには**置かれません**。
`team-init` がホストルートに決して手を触れないからです。その帰結として、
*ルート*の `AGENTS.md` 規約を自動検出するツールは、これを**自動では拾いません**。
ホストルート不可侵の保証を守るための意図的なトレードオフであり、`AGENTS.md` は
自動ロードされるルート規約ファイルとしてではなく、純粋に可搬なポインタ doc と
して扱われます。あるツールにこれを読ませたい場合は、そのツールに
`<base>/AGENTS.md` を明示的に指し示してください。

## タスククラスによる検証の価格付け

T-1065 以降に凍結するすべての spec は、凍結された intent block 内の 1 行で
その deliverable の verification class を宣言する。書式はトップレベルの
bullet `- verification-class: mechanism — <rationale>` または
`- verification-class: no-mechanism — <rationale>` である。

**`mechanism`** が既定になるのは、そのタスクの diff が実行対象の surface
（`bin/`、`tests/`、`templates/` 配下のいずれかのパス、CI workflow、または
checker の semantics）に届きうる場合である。このクラスでは検証プロトコル
全体がこれまで通り適用される。すなわち、既にマージ済みの spec すべてに
対する **full-population** な downstream-impact diff、CI と同等のステップ
全部、そして spec 自身の criteria 全体に対する mutation-probe マトリクス
である。

**`no-mechanism`** は、実行対象の surface を一切変更しないタスク
（wording・prose・editorial・documentation の deliverable）のためのもので、
3 つのコストを引き下げる。第一に、downstream-impact の inventory は
**full-population** diff の代わりに **read-set** でスコープされた分析に
なる。タスクが編集するパスのいずれかを読む merged criteria の集合を機械的に
導出し、その集合について base ref と HEAD の verdict を差分する。第二に、
CI の同等性検証は、タスクの diff が入力に届きうるステップに限って走らせる。
第三に、mutation probe はそのタスクが追加・変更した `- check:` 行だけに
要求され、spec 全体には要求されない。対応して `no-mechanism` の spec は、
full-population な sweep も、CI 相当ステップ全体の再実行も、このタスクが
変更しないメカニズムの挙動検証も行わないことを、明示的な non-goal として
宣言する。

2 アーム構成の sweep はこれに加えて、両アームが走る前に一度だけ
（sweep ごとに一度）、gitignore 対象の `.shell-team/runs` corpus の
snapshot を base アームへステージングする。これを行わないと、この
corpus を読む criterion は diff とは無関係な理由で base アーム側の
FAIL を報告する。

現時点の強制は**チェッカーではなく duty** である。この宣言は spec 完成時に
著者役割が行い、両方の review gate と人間がそれを読む。**機械的なチェッカーは
出荷されない**。あるタスクが自ら宣言したクラスに正直に属しているかどうかは
読解による判断であり、diff だけから機械的に検証できるものではないからである。

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
します。これは `templates/binding-template.conf` のコピーです。host の
`<base>/binding.conf` は**丸ごと**採用されます。出荷時の既定に対する
per-role の merge・layering・fallback は存在しないので、6 つの
inner-loop 役割（`tech-lead`・`pm-spec`・`engineer`・`qa-verifier`・
`codex-reviewer`・`ui-designer`）それぞれに `bind` 行を 1 本ずつ、多くも
少なくもなく持たせる必要があります。部分的なファイルは既定から補完され
ず、refuse されます。6 役割すべてに executor を割り当てたいときに、次の
手順で作成します:

1. `mv <base>/binding.conf.example <base>/binding.conf` を実行する。
   `team-init` がまだ走っていない場合は、プラグイン自身の
   `templates/binding-template.conf` を手動で `<base>/binding.conf` へ
   コピーする（このパスはプラグインのインストール先ディレクトリから
   解決される。自リポジトリ配下のパスではない）。**この 6 行が持つのは
   プレースホルダーのモデルトークン**です。`claude` 系の 5 行に
   `model-1`、`codex-reviewer` に `model-2` と書かれていますが、いずれも
   実在するモデルを指しません。これに依拠する前に**全ての行**を置き換えて
   ください。変更しない役割の行には `templates/binding-default.conf` の
   実際の行を転記します（**下記の grammar example からは転記しないで
   ください**。あれは異なる値を持つ custom-binding の例示です）。1 行
   だけ編集して止めると、残り 5 役割のプレースホルダー紐付けが
   resolution と telemetry にそのまま入ってしまいます。
2. `bind <role> <provider> <model> <effort|-> <adapter>` 行（役割ごとに
   1 行）を編集する。`effort` は位置的に必須で、「値なし」はフィールド
   を省略せず常にリテラル `-` で綴る。この「未設定」の綴り方は effort
   列だけのもので、model 列は常に英数字始まりが必要。
3. `bash check-binding.sh --config <base>/binding.conf` を実行する。
   プラグインをロードしていれば `bin/` は `PATH` に載るので `bin/`
   接頭辞なしで解決する。プラグインをロードしていないチェックアウト内
   では `bash bin/check-binding.sh ...` を使う。
4. `bash resolve-executor.sh --print-resolved` を実行する（step 3 と
   同じ `bin/`-on-`PATH` の注記が当てはまる）。これは 6 役割すべての
   有効な紐付けを解決するが、**availability probe を一切行わない**。
   `resolve-executor.sh --role <role>` はさらに検査するが、その probe の
   中身は紐付けられた provider によって決まる。**out-of-process** な
   provider（`codex`）については、`codex --version` が `PATH` 上で
   観測可能かを確認する read-only probe を実行する。**in-process** な
   provider（`claude`）については **availability の判定を一切行わない**。
   probe kind を表示するだけで、根拠を持てる判定（harness 自身の
   サブエージェント呼び出し失敗）を下すのは呼び出し側に委ねる。出荷時の
   既定では 6 役割のうち 5 つが `claude` に紐付いているため、実際に何かを
   probe する呼び出しは `resolve-executor.sh --role codex-reviewer`
   だけになる（下記の `executor-unavailable` 参照）。

実際の validator が受理する設定例を示します。採用される config が持つべき
6 役割がすべて入っています:

```
schema 1

bind tech-lead      claude opus   high claude-cli
bind pm-spec        claude opus   high claude-cli
bind engineer       claude sonnet -    claude-cli
bind qa-verifier    claude sonnet -    claude-cli
bind ui-designer    claude sonnet -    claude-cli
bind codex-reviewer codex  gpt-5  -    codex-cli
```

host の `<base>/binding.conf` が全く無い場合（設定していない通常の
ケース）、`resolve-executor.sh` はプラグイン出荷時の既定
`templates/binding-default.conf` にフォールバックする。その `model` 列
のうち `codex-reviewer` の行だけは `provider-configured` を持つ。これは
出荷時の Codex 呼び出しが model フラグを一切渡さないという境界を表す。
それ以外の各役割の列は、その役割自身の `agents/<role>.md`（プラグイン
自身の agent 定義）の pin をそのまま持つ。

`resolve-executor.sh` の refusal 集合は閉じており、トークンは **5 つ**。
うち `usage` は不正な呼び出し（CLI 引数エラー）であって config の状態
ではないため、この adopter workflow の対象外です。残る 4 つが
config-condition refusal で、3 つまでは通常の config 編集で到達しえます。
4 つ目は出荷済みの 2 つの adapter がすでに双方満たしている契約なので、
どちらに紐付けても今日は到達できません:

- `binding-unresolved`（exit code `2`）— 有効な紐付けが well-formed で
  信頼できる形に解決しなかった場合。通常の編集で到達しうる原因は 2 つ
  ある。1 つは `<base>/binding.conf` に存在するものが通常ファイルでない
  場合（ディレクトリ・FIFO・dangling symlink など）。このとき出荷時の
  既定へ黙って fallback することは決してない——fallback は「本当に存在
  しない」場合専用である。もう 1 つは config 自体が malformed で、
  `check-binding.sh` 自身の grammar が refuse する場合。例えば `bind`
  行のフィールド数が誤っている、あるいは provider/adapter/role トークン
  が未知の場合がこれに当たる。`resolve-executor.sh` はこの 2 つの原因を
  同じ 1 つのトークンに畳み込むので、malformed な行のより具体的な原因は
  `check-binding.sh --config <base>/binding.conf`（step 3）が報告する。
- `capability-unsupported`（exit code `1`）— 役割が、紐付けられた
  adapter が宣言していない effort 値を要求した場合。
- `executor-unavailable`（exit code `1`）— `--role <role>` モードでのみ
  発生する（上記 step 4 の `--print-resolved` は決して発生させない）。
  発生するのは **out-of-process** な provider について、その probe
  コマンドが `PATH` 上で観測できない、またはその read-only 検査が失敗
  した場合に限る。例えば `codex`/`codex-cli` に紐付けたのに `Codex` CLI
  が入っていない場合である。**in-process** な provider（`claude`）に
  対しては `--role` は availability の検査を一切行わないため、`claude`
  に紐付けた役割は probe 経路からはこの refusal に到達しない。
- `contract-violation`（exit code `1`）— write / propose の
  board-authority を持つ役割が、board-transition チャンネルを持たない
  adapter に紐付けられた場合に enforce される。出荷済みの 2 adapter
  （`claude-cli`・`codex-cli`）はいずれも `carries board-transition` を
  宣言しているため、どちらに紐付けても今日この refusal には到達しない。
  将来出荷される adapter がそう宣言しない可能性があるため、closed set の
  一員として引き続き記載する。

各 adapter は自分自身の effort 語彙を宣言しており、共有リストは存在
しない: `claude-cli` は `low`・`medium`・`high`・`xhigh`・`max` を、
`codex-cli` は `none`・`minimal`・`low`・`medium`・`high`・`xhigh`・
`max` を受理する。

**正直な境界線**には 2 つの軸があり、これを混ぜることが誤解の元になる。

第 1 の軸は**呼び出しが行われるかどうか**。ここは binding が**それを
参照するループにおいて**制御しており、rebind によって呼び出しを完全に
止められる。`/shell-team:run` と `/shell-team:goal` のループでは、
各役割の executor があらゆる invocation の前に解決される。refusal は
何かにフォールバックせず、フェーズを停止させる blocker である。通常の
編集で `binding-unresolved`・`capability-unsupported`・
`executor-unavailable` に到達しうる（いずれも上記参照）。単体で使う
2 つの review 系コマンドも、自身の review ステップで binding を
参照する。`/shell-team:review` は reviewer を呼び出す直前に
`codex-reviewer` の executor を解決し、`/shell-team:review-response`
も自身のクロス評価ステップの前に同じことを行う。どちらでも refusal は
フォールバックせずコマンドを停止させる blocker であり、rebind は
run に届くのとまったく同じようにこれらにも届く。
`/shell-team:review-response` はさらにもう 1 つの経路でも resolution
に到達する — 採用した findings を `/shell-team:run` へ引き渡す最後の
ステップである。残る 2 つのコマンド `/shell-team:loop-triage` と
`/shell-team:team-init` は紐付けられた役割を 1 つも呼び出さない
（invoke no bound role）ので、そこには resolution が解決すべきものが
無い。

第 2 の軸は**行われる呼び出しがどう実行されるか**。こちらで binding が
変えるのは、`resolve-executor.sh` が解決して報告する値と**テレメトリ**が
記録する値**だけ**であり（provider・model・effort・adapter のいずれも
同じ）、実行そのものは何も変わらない。つまり別 executor への
**呼び出し経路**は配線されない。この第 2 軸の具体例を 3 つ挙げる（網羅ではなく
例示）。まず、役割が走る **model** は今なおその役割自身の
`agents/<role>.md` の pin から来る（resolved row からではない）。issue
**#236** がその pin の退役を追跡するが、対象は `claude-cli` に紐付く
5 役割のみで、`codex-reviewer` は意図的に除外される（その pin は Codex
CLI を呼び出す Claude 側の wrapper を設定するもので、レビューを行う
モデルではない）。次に、宣言された **effort** は span に記録されるが
どの呼び出しにも適用されず、他に及ぶ影響は上記の `capability-unsupported`
refusal だけである。adapter 定義が宣言しているのは effort の*機構*で
あって、宣言は適用ではない。最後に、どの **executor**（provider と
adapter）経由で役割が呼び出されるかは、どの役割についても resolution が
経路制御しておらず、これを追跡する issue も存在しない。持ち帰るべき
規則は、第 2 軸を列挙ではなく普遍形で述べたほうである。すなわち、
紐付けられた値はすべて**宣言された値であって、実行されたものの観測では
ない**。

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
どうかを宣言する。書式はトップレベルの bullet
`- user-visible: yes — <rationale>` または `- user-visible: no — <rationale>`
である。`yes` の宣言を discharge する形は 2 通りのいずれか一方に限られる。
acceptance criterion 側に indent された
`- adopter-surface: <ドキュメントの置き場所>` 行を持たせるか、spec 側に
トップレベルの `- adopter-docs-waiver: <reason>` 行を持たせて「この
user-visible capability には adopter-docs 用の surface が無い」ことを明示
するかである。waiver は回避策ではなく、一級の結果として扱われる。`no` の
宣言にどちらかの marker を付けることは refuse される。これは `no` の宣言が
単独で pass することと対をなす原則である。

現時点の強制は**チェッカーではなく duty** である。タスクの最初の凍結時に、
coordinating session がこの宣言領域を自分で読み、宣言がちょうど 1 行・
rationale が非空であることを要求する。`yes` の場合はさらに、criterion
配下の `- adopter-surface:` 行か非空の `- adopter-docs-waiver:` 行の
いずれか一方を要求する（両方は不可、`no` に付けるのも不可）。満たさない
spec は凍結を refuse して著者に差し戻す。**機械的なチェッカーはまだ出荷
されていない。** 一度実装したが、scan のスコープ判定に独立した欠陥が
2 ラウンド連続で見つかったため、T-1061 自身の pre-commitment に従って
issue #250 へ切り出した。refuse すべき spec を pass させるゲートを出荷
することは、正直な prose の duty を出荷することより悪い。したがって
3 回目のパッチではなく再設計を待つ。境界はどちらの形でも変わらない。
この sweep は spec が名付けた surface を**開かない**——resolve も
validate もしない。ある surface が本当に adopter 向けかどうかの判定は
reviewing gates と人間の役割であり、mechanical check の役割ではない。
path の allowlist を作れば、adopter のリポジトリをこの repository の
レイアウトに強制することになってしまう。この duty はタスクの bootstrap
freeze でのみ適用され、すでに記録済みのハッシュの re-freeze では適用され
ない。

## 1 チケットでチームを試す

チーム全体でどう導入するかを決める前に、実際のチケット 1 件でループを一度だけ試したいなら、**trial branch（お試し用ブランチ）** を使います。ブランチを作り、そこへ shell-team 本来の仕組みでスキャフォールドし、稼働ファイルをそのブランチ上でコミットし、ループを実行し、終わったらブランチを削除する——という流れです。ループの gate は稼働ファイルが **tracked（追跡済み）** であることを前提にしており、このルートはその前提を回避せず尊重します。`git switch -c` に続けて `team-init` を実行するか、`team-init.sh` 自身の `--trial-branch <name>` フラグでその 2 つを 1 回にまとめます。

**セットアップ。**

```bash
git switch -c trial/one-ticket
team-init.sh .
git add "$(team-paths.sh --get base)" "$(team-paths.sh --get specs)"
git commit -m "chore: scaffold shell-team for a one-ticket trial"
```

`--get` 引数は両方とも重要です。デフォルトレイアウトでは同じディレクトリに解決されますが、レガシーな `tasks/` + `docs/specs/` レイアウトでは `docs/specs/` がベースディレクトリの外にあるため、2 つめの引数を落とすと specs ディレクトリが永久に未追跡のままになります。必ず両方を使ってコミットしてください（単一ディレクトリをハードコードした形は使わないでください）。

上の 1 行目と `team-init.sh` の行は 1 ステップにまとめられます。`team-init.sh --trial-branch trial/one-ticket .` は、スキャフォールドの前に `trial/one-ticket` を作成してそこへ切り替えます。ターゲットが git work tree の中に無い、その work tree の root で無い、あるいはそのブランチが既に存在する場合は、exit 2 とメッセージ（対処法つき）で拒否します。2 つのコマンドを分けて実行する必要は無く、上記は分かりやすさのために分けています。`--trial-branch` を指定しない場合、`team-init.sh` は自身で git コマンドを一切実行せず、どのブランチにいるかも気にしません。

マシンの global excludes（`core.excludesFile`）がベースディレクトリを隠している場合、この普通の `git add` はその場で拒否されます。対処は 2 つあります。このお試し用ブランチに限るなら `git add -f "$(team-paths.sh --get base)" "$(team-paths.sh --get specs)"` で強制します。恒久的に通常の形を効かせたいなら、[稼働ファイルの置き場所](#稼働ファイルの置き場所) にあるとおり、`team-paths.sh --get base` があなたの repo で解決するパスを root `.gitignore` に repo レベルで re-include してください（デフォルトレイアウトでは `!.shell-team/`、レガシーレイアウトでは `!tasks/`）。

あとはいつも通り、このお試し用ブランチ上で `/shell-team:run <作りたいもの>` を実行します。

**後始末。** `<integration-branch>` にはあなた自身のリポジトリの integration branch を代入してください——この repository では `develop`、他の多くの repository では `main` です。

```bash
git switch <integration-branch>
git branch -D trial/one-ticket
```

**未マージ (unmerged)** のブランチを削除すると、そのブランチからしか到達できないコミット（スキャフォールドされたベースディレクトリ、ボード、spec、そのタスク自身の記録）がすべて失われます。それ以外は何も変わりません。他のブランチの tip は動かず、本流の履歴も変わらず、お試し用ブランチにコミットしなかったファイルにも触れません。ブランチは設計上未マージのままなので `git branch -d` は拒否し、強制形の `git branch -D` が必要になります。これは何かが間違っている兆候ではなく、ここでは期待どおりの通常の結果です。削除したコミットは、いずれガベージコレクションされるまで `git reflog` から復元できます。

ただし「未マージ」は「決して伝播しない」ことを意味しません。お試し用ブランチ上のコミットは、ブランチが一度もマージされなくても本流に届くことがあります。誰かが `cherry-pick` するかもしれませんし、共有リモートへ `push` すれば自動化や別の人が拾うかもしれません。お試し用ブランチは **ローカル (local)** に留め、もし push していたなら、ローカルのものを消すときに **remote copy（リモート側のコピー）** も一緒に削除してください。分離を支えているのはその discipline であり、未マージであることだけではありません。

稼働ファイルを一度もコミットしないまま（git 無視されているか、単に一度も追加していない状態で）ループを走らせることは**サポートされていません (not supported)**。理由は gate ごとに異なるので、1 つの一括した主張ではなく、それぞれが実際に持つ失敗の形と、実際にそこへ到達するシナリオで述べます。

`bin/check-durability.sh` は**拒否 (refuses)** します。どちらの拒否に出会うかは、あなたが何をしたかによります。`<base>/durability-mode` ファイルが一切無い場合、デフォルトのモードは `tracked` であり、ループが必要とするすべての記録が、記録されたコミット内のどの blob にも解決しません。この場合の refusal は `not-in-recorded-commit`、作業ファイル自体も無ければ `missing-working-file` です。`untracked-opt-out` はより狭いケースで、`working-tree-only` を宣言する **mode file（モードファイル）** 自体がコミットされていない場合にのみ発火します。どちらにせよ、お試しは green な hand-off に到達しません。

`bin/check-pii-shapes.sh` は、ループ自身の記録を**一度も読まないまま (without having read)** clean を報告します。diff スコープのモードはコミット済みの変更しか見ず、`--all` モードは untracked だが ignore されていないファイルにしか届きません。**gitignored（git 無視された）** ベースディレクトリは **どちらのモードでも (neither mode)** 読まれないのです。これはまさに、base dir を git から外しておく方法そのものです。

`bin/check-intent.sh` は、それ自身に恒久的な存在を持たない台帳から答え続けます。frozen-intent のハッシュとその attestation はボード上に生きているので、**fresh（新規）** な clone やチェックアウト、あるいは `git clean -fdx`（その `-x` フラグは gitignore されたパスにまで届きます）は、それらを一度も持ちません。なお `git reset --hard` は **追跡されていないボードをそのまま残します (leaves an untracked)**。つまりそれらを取り除く操作ではありません。

そして、ベースディレクトリをリポジトリの外へ移すことも抜け道にはなりません。`bin/team-paths.sh` は絶対パスの `TEAM_RUN_BASE` をそのまま拒否するため、ベースディレクトリはリゾルバ自身の判断により **repo-relative（リポジトリ相対）** であり続けます。

## stacked-branch base-ref discriminator と borrowed-vocabulary sweep の宣言

T-1081 以降に凍結するすべての spec は、凍結された intent block 内の 1 行
（上記の `- user-visible:` / `- verification-class:` と同じ宣言領域）に
追加の宣言を持つ。書式はトップレベルの bullet
`- base-ref-discriminator: <instantiate した two-arm 式>` または
`- base-ref-discriminator: not-applicable — <reason>` である。これは
stacked branch 上の spec だけでなく、**最初の凍結を行うすべての spec** に
必須である。2 つの形は自由選択ではない。two-arm 式が値になるのは、
いずれかの criterion が base-side blob を読み、かつ branch が authoring
time に open な predecessor を持つ場合**のみ**である（分類は 1 回きりで、
predecessor が途中で merge されるような era の変化によって再分類される
ことはない）。それ以外のすべてのケース——base-side blob を一切読まない、
または open な predecessor が無い——では、branch 自身の実際の base ref
を名指しする `not-applicable — <reason>` を取る。

spec が 1 つ以上のまだ open な predecessor PR の上に stack され、その
criteria が base-side blob（stack 上のファイルの以前の状態、変更前の値）
を読む場合、そこに書く値は 1 つの two-arm 式であり、base-side blob を
読むすべての criterion で byte 単位で同一に spell する:

```
B=$(if git show-ref --verify --quiet refs/heads/<predecessor-branch>; then git merge-base "<predecessor-branch>" HEAD; elif git show-ref --verify --quiet refs/remotes/<remote>/<predecessor-branch>; then git merge-base "refs/remotes/<remote>/<predecessor-branch>" HEAD; else git merge-base "<integration-branch>" HEAD; fi)
```

これがそのままコピーすべき canonical な形であり、以下の prose が説明して
いる local-branch-only の簡略形ではない。predecessor が remote-tracking
ref としてしか存在しない checkout では `elif` arm が取られ、その
`merge-base` の引数はフルパスの
`refs/remotes/<remote>/<predecessor-branch>` になる（bare の
`<predecessor-branch>` はその checkout では一切 resolve しない）。

`<predecessor-branch>` はこの spec 自身の branch が stack されている直近の
predecessor を、`<integration-branch>` は**あなた自身のリポジトリの
integration branch** を指す parameter である。後者はこの repository では
`develop`、他の多くの repository では `main` であり、この repository の
convention に矯正されるのではなく自分の convention を代入する。

第一の arm は、predecessor が local branch として resolve する場合の
`git merge-base "<predecessor-branch>" HEAD` である。意図的に
predecessor branch tip の `rev-parse` にしていない。この branch を切った
後に predecessor branch を進める rework round は、そのブランチの tip を
動かすが共通の祖先は動かさない。ここで "branch point" が意味するのは
その共通の祖先である。existence test が predecessor を remote-tracking
ref としてしか見つけられなかった場合、同じ arm は
`git merge-base "refs/remotes/<remote>/<predecessor-branch>" HEAD` になる。
bare の predecessor 名ではなくフルパスを使うのは、local branch を持たない
checkout では bare 名が resolve しないからである（`fatal: Not a valid
object name`）。fallback arm `git merge-base "<integration-branch>" HEAD`
が取られるのは、predecessor が**どちらの namespace にも** resolve せず
本当に消えている時点——merge され削除された era——である。

arm の選択は、明示的な `git show-ref --verify --quiet` による
branch-existence test で行う。predecessor が local branch として resolve
する場合は `refs/heads/<predecessor-branch>` に対して、fresh clone や
CI checkout が fetch しただけで local に checkout していない
remote-tracking ref としてしか存在しない場合は
`refs/remotes/<remote>/<predecessor-branch>` に対して行う。つまりこの
existence test は `refs/heads/` だけを前提にせず、この checkout が実際に
predecessor を持っている namespace のほうで見つけなければならない。
そして `2>/dev/null ||` チェーンでは行わない。`||` チェーンは
「predecessor branch が消えた」（fall back すべき想定された era の変化）
と「`git merge-base` が別の理由で失敗した」（fail closed すべき場合）を
区別できないためである。40 桁の commit literal はどの criterion にも
一切書かれない。

predecessor を一度も fetch しておらず**どちらの namespace でも** resolve
しない checkout——shallow clone、`--single-branch` clone、または child
branch だけを fetch した CI checkout——は、fallback arm が存在するための
era ではない。predecessor が open な PR を持つかどうかは repository の
state of record（そのブランチが乗っている train）の事実であって、この
checkout がたまたま fetch した範囲の話では決してない。したがってこの
ケースも `not-applicable` の宣言にはならない。凍結する前に predecessor
を fetch するか、route back すること。existence test の不在が黙って
選んでしまう arm で凍結してはならない。その不在は existence test だけを
見る限り genuine な merge と見分けがつかないので、そこを通り抜けて凍結
することは禁じられている。

残余ケースが 3 つあり、いずれも回避策を講じるのではなく開示される。
最初のケースは、merge されずに削除された predecessor branch。fallback
arm に integration branch の tip を resolve させてしまうが、それは
branch point ではない。これは stack 全体を無効化する route-back であり、
criterion で覆い隠すべきものではない。残る 2 つは、この branch を切った
後に predecessor branch が rebase・force-push された場合と、
squash-merge された場合。どちらも同じ扱いの route-back であり、どちらの
arm もこれを生き延びるようには再設計されていない。rebase と force-push
は predecessor の tip を動かし、記録済みの共通の祖先がその祖先でなく
なる可能性がある。squash merge は predecessor の変更を、その元の commit
のどれとも SHA を共有しない 1 つの commit として integration branch に
乗せてしまうため、era の変化による fallback が正しく発火した後でも
`merge-base` は本当の branch point より前の commit を resolve してしまう。
メカニズムは異なるが結果は同じである。

現時点の強制は、上記の adopter-facing documentation の宣言と同じ足場で
**チェッカーではなく duty** である。タスクの最初の凍結時に coordinating
session がこの宣言領域を自分で読み、宣言が無い・2 つ以上ある・宣言領域外
に置かれている spec を refuse する。機械的なチェッカーはまだ出荷されて
いない。

この宣言と並行して、すべての spec の凍結時 premise sweep は、文字列
token の出現回数についてのすべての literal count premise——特に `= 0`
という premise——を 2 つに classify する。`own-coinage`（このタスク自身
が導入する literal）か、`borrowed`（他の document が既に coin した
token: invariant-lock id、status flag、grammar family name、その他の
既存 vocabulary）かである。これは spec author の凍結時 duty である。
borrowed な token はすべて spec 自身の `## Assumptions` セクションに、
それを確認する measurement command と共に enumerate する。そして
execution 能力を持つ側が凍結前にその command を branch point の
committed blob に対して live に実行し、測定値を assumption の傍に記録
する。「このタスクが導入する新しい literal」だけに scope した sweep では
不十分で、merged された sibling task によって既に stack に持ち込まれた
token を見逃してしまう。測定されなかった borrowed-vocabulary count
premise は broken check line として扱われる。

## verification ceiling を宣言する

T-1093 以降、すべての spec は自分の凍結 intent block 内、上記の
`- user-visible:`・`- verification-class:`・`- base-ref-discriminator:` の
各 key が既に占めている宣言領域に、もう 1 行を追加で宣言する。top-level
bullet
`- verification-ceiling: unit-and-static | real-environment — <rationale>`
である。これが **verification ceiling**（検証の天井）——この spec に
対して QA が実際に到達できる検証レベル——であり、green flag を bare な
green ではなく「このレベルまでは green」と読めるようにするために存在
する。`unit-and-static` は、loop 自身の gate が unit test と static /
textual verification までしか届かず checkout の外には出られないことを
意味する。`real-environment` は、criterion が名指す実 runtime（storage
put が queue に流れ worker に届く経路・手動 deploy・cloud credential の
裏でしか届かない作業）を追加で exercise できることを意味する。

**どちらの値も all-or-nothing ではない。** 宣言された値は、個別に印が
付いていないすべての criterion について gate が何に到達したかを述べる。
宣言された ceiling より上に位置する criterion は、自分自身の indented
`- above-ceiling: <gate 通過後にこの criterion を所有する human>` サブ
箇条を持つ。ゲート通過後にそれを所有する human を名指しするもので、
出荷済みの `- adopter-surface:` idiom を再利用する（新しい free-text
list ではない）。1 つのサブ箇条が複数の criterion を代表することも決して
ない。このサブ箇条は**どちらの宣言値の下でも**利用可能であり、これが
正直な mixed case を可能にする。spec の criteria が複数の
real-environment capability class に、それぞれ異なる到達度でまたがる
場合——例えば、ある criterion については gate が実際に exercise した
staging の storage-to-queue-to-worker path があり、別の criterion に
ついては gate が届かない production deploy や credentialed な作業がある
場合——は、`real-environment` を宣言して gate が到達した部分を表し、
届かなかった方に `- above-ceiling:` の印を付ける。どちらか一方の
criterion を誤って記述する値へ押し込まれることはない。

**exception set には floor があり、この対称性は「何も言わない」ためには
使えない。** 宣言された値は、**少なくとも 1 つの criterion が
その値で verify されている**ことを attest しなければならない。すべての
criterion が `- above-ceiling:` と印付けられた `real-environment` 宣言は
refuse される。それは `unit-and-static` と区別が付かず、読者に何も伝え
ないからである。その spec の正直な宣言は、少なくとも 1 つの criterion が
実際に verify されている最高の値である。`unit-and-static` は floor で
あり、これ以上は下げられない。そのため残る唯一の degenerate case
——floor でさえすべての criterion がその上にある場合——は refuse ではなく
documented される。すなわち宣言行は、宣言された値の直後に固定 token
`no criterion verified at this ceiling` を carry しなければならない。
この token はその後**そのまま verbatim で**、QA の PASS block の field と
board の `READY_FOR_REVIEW` append の両方へ carry forward される。spec を
開かない読者にも、baseline coverage のように見える bare な値ではなく、
実際にその disclosure が読める行が届くようにするためである。

現時点の強制は、上記の宣言と同じ足場で**チェッカーではなく duty** で
ある。タスクの最初の凍結時に coordinating session がこの宣言領域を自分で
読み、ちょうど 1 つの conformant な `- verification-ceiling:` 行を要求
する。無い・重複している・closed vocabulary 外・vacuous な宣言、あるいは
宣言された ceiling を超える capability を明らかに要求している criterion
に `- above-ceiling:` サブ箇条でその所有者が名指しされていない場合は、
refuse して spec を author へ差し戻す。**機械的なチェッカーはまだ出荷
されていない**。mismatch case は grep が決められる state ではなく human
が行う reading judgment であり、このリポジトリの他の宣言領域 gate が
既に持つのと同じ disclosed-limitation pattern（issue #250）に乗る。この
duty はタスクの bootstrap freeze にのみ適用され、既に記録済みの hash の
re-freeze には適用されない。そして、宣言された ceiling が何を防ぐかに
ついての主張は一切していない。それは QA が到達したレベルを、後で
hand-off や board line を読む誰にとっても legible にするだけである。

## spec を誰が書くかを選ぶ（T-1091）

T-1091 以降、spec の著者を誰にするか自体が dispatch decision になった。
既存の `implement`/`verify` 軸と並ぶ第三の軸 `specify` で、`pm-authored`
と `operator-authored` の 2 値に閉じている。Plan で決め、同じ座で task の
board entry に記録する。

**`pm-authored` が出荷時デフォルト。** `pm-spec` が今まで通り spec を書く。
task の decision input が 1 つの session の context に集中していない場合
——ほとんどの task がこれに当てはまる——はこちらを選ぶ。formalization
（依頼をテスト可能な spec に変える作業）は `pm-spec` の比較優位である。

**`operator-authored` は judgment-density のボトルネックのためにある。**
その task の decision input——複数 repo にまたがる測定済みの事実、live
環境での確認、インシデント履歴——が既に coordinating session 自身の
context に存在している場合はこちらへ routing する。このとき `pm-spec` へ
委譲する価値は算術的にゼロになる。完全な hand-off package を書くこと自体
が spec を書くことそのものであり、委譲は検証済みの一次情報を relayed な
情報に変えるだけになるからだ。このモードでは coordinating session
（operator）が直接 spec を書き、`pm-spec` は author ではなく
**conformance formatter** として参加する。check-intent と check-acs の
grammar に整形するだけで、author が決めたことを書き換えることは決して
なく、substantive な gap は自分の判断で閉じずに author へ差し戻す。

**このガイドが防ぎたい anti-pattern。** `pm-spec` による authorship を
断ることは、loop の machinery まで置き去りにする理由にはならない。
凍結された intent block、board record、freeze sweep、2 つの review gate、
interventions ledger——これらは `pm-spec` が犯す間違いと同じくらい
operator が犯す間違いも捉える仕組みである。operator-authored な spec も
freeze sweep 以降は full loop がそのまま走る。`operator-authored` が選ぶ
のは spec を誰が書くかだけで、machinery の残りが走るかどうかを選ぶこと
では決してない。

## Specify seam で spec review を elect する（T-1092）

`specify` と並んで第四の軸がある。実装着手前に spec の **domain**
（ドメイン）前提を cross-provider の `codex-reviewer` に追加で 1 回
読ませるかどうかを決める `spec-review` で、`none` と `cross-provider` の
2 値に閉じ、`docs/loop-engineering/specify-seam-review.md` で定義・
値付けされている。

**`none` が出荷時デフォルト。** 追加の pass は走らず、task には何の変化
もない。通常の mechanism task は追加ラウンドの代償を払わない。

**この repo が自ら測定できない domain 前提に spec の正しさが依存する時、
`cross-provider` を elect する。** デプロイ順序の前提、本番で成立すると
は限らない rollback precondition、この repo の外にあるシステムについての
blast-radius claim などがこれに当たる。追加ラウンドが読むのは spec
document 自体——凍結 intent block とその declaration region——であり、
branch diff は決して読まない。freeze sweep の後・`- intent-hash (v1)` を
記録する前に走り、task の review record 内の `## Spec review` セクション
に `APPROVE` か `REQUEST_CHANGES` を返す。`REQUEST_CHANGES` は spec 自身
の author（`pm-authored` モードでは `pm-spec`、`operator-authored`
モードでは operator）へ差し戻され、答えが返るまで freeze sweep は先へ
進まない。

**保証すること・しないこと。** elect された spec review は loop の
**both gates**（`qa-verifier` の PASS と、実際に届いた変更に対する
`codex-reviewer` の APPROVE）のどちらでもない。この軸の値に関わらず
両 gate は引き続き必須であり、spec-review の APPROVE がどちらの代わりに
なることもない。またこの読みは自身の入力を認証しない（cross-check する
2 つの条件テキストはどちらも agent が生成したものである)。読みが実際に
行われたことも検証しないし、「domain 前提が健全である」ことを reading
judgment 以上の何かにすることもない。この軸はまだ一度も end-to-end で
発火していないため、world について誤った spec の実装をどれだけ防げるかは
`undetermined`（未測定）である。

## oversight profile を選ぶ

host repo は、host が自ら作成する `<base>/oversight.conf` で **oversight
profile**（監督プロファイル）を選択し、`bin/check-oversight.sh`（T-1103・
issue #343）がそれを解決・検証する。profile は `autonomous` と
`governance-controlled` の 2 値に閉じ、`specify-seam`（Specify seam の
freeze）と `pre-merge`（`bin/close-out.sh` 自身の exit status）という
2 つの閉じた **seam** 値を統制する。`- dispatch:` record も環境変数も
タスクごとの board field も、1 task だけ別の profile を選ばせることは
しない。この宣言は 1 ファイルが持つ repository 単位のプロパティである。

**`autonomous` が出荷時デフォルト。** `<base>/oversight.conf` が一切無け
ればこれに解決され、何も変わらない。既存の seam に要件は増えず、既存
gate の verdict も動かず、今日 conformant な board・spec・record は byte
単位で conformant のまま。

**組織の IT governance が segregation of duties（職務分離）を課す時、
`governance-controlled` を宣言する。** 職務分離とは「変更は、それを
作った当事者自身の承認では前へ進めない」というルールである。
`<base>/oversight.conf` に `schema 1`・`profile governance-controlled`・
gate したい seam ごとの `seam` 行を書く。宣言した seam はそれぞれ、task
自身の board entry 上に記録された conformant な
`- oversight-approval (<seam>): approver=<handle> — producer=<handle>
— approves=<anchor> — date=<YYYY-MM-DD> — record=<locator>` sub-bullet を
要求する。`approver` handle は ASCII normalization 後に `producer`
handle と異なっていなければならない。`approves=` anchor は gate 対象の
artifact を今なお指していなければならず、古くなった anchor も膨張した
anchor も、黙って受理されず refuse される。

**enrollment は蒸発しない。** board のどこかに——`## Active` でも
`## Done` でも、どの task でも、どちらの seam でも——過去の approval
record が 1 つでも存在すれば、宣言が消えたことは `autonomous` へ黙って
戻ることを意味せず、`enrollment-vanished` として refuse される。
governance から抜ける唯一の正規の手段（**de-enrollment**）は、明示的な
`profile autonomous` 宣言である。削除ではなく、diff で見える 1 ファイル
の追加になる。その根拠が意図的に **board 全体** なのは、それが守って
いる profile が 1 task ではなく repository 全体のプロパティだからだ。

**この機構が保証すること・しないこと。** これが出荷するのは content
anchor つきの **self-declared conflict check** である。git 管理された
workflow evidence として記録されるが、認証済みの segregation-of-duties
統制ではない。いかなる handle も **does not authenticate**（認証しない）。
署名も SSO/OIDC binding も directory lookup も無く、`producer=` に
記された当事者が実際の producer である保証も、`approver` が承認対象を
実際に読んだ保証も無い。board 記録は現行スナップショットにおける
best-effort な workflow evidence であって、tamper-evident でも独立して
retain された監査保管庫でもない。そうした保証が組織に必要なら、自前の
branch protection・commit signing・retention・削除監視という
**compensating controls**（補完的統制）と組み合わせること。2 つの seam
はこの loop 自身の **callable transitions**（呼び出し可能な遷移点）で
あって、組織の release や deployment の認可境界ではない。どちらの seam
も通らない直接 merge・cherry-pick・hotfix は gate されない。class-M の
mechanics-repair re-freeze も例外ではない。gate は version ベースで
class-blind なので、enroll すれば **mechanics-repair re-freeze** を含む
すべての freeze が record を要求される。opaque handle の比較が実際の
segregation-of-duties 統制を満たすかどうかは `undetermined`（未測定）で
あり、この repository のどの checker もそれを測定しない。

**自分の CI に何かを組み込む要件は無い。** `pre-merge` seam の実効性は
`bin/close-out.sh` 自身の exit status にあり、adopter は既にそこで
実行している。`check-oversight.sh --seam pre-merge` はここで、追加で
自前の CI にも組み込みたい host 向けのオプションとして文書化されている
に過ぎず、profile が機能するための前提条件では決してない。この checker
の `governance-controlled` arm は **fixture-exercised only**（fixture
でのみ検証済み）として出荷され、この repository では意図的に live run で
行使しない。ここで enroll すれば、coordinating session がその分離を
監査する機構自身の producer と approver を兼ねることになってしまうから
である。`qa-verifier` の PASS と `codex-reviewer` の APPROVE という
**both gates** はどちらの profile でも変わらず必須であり、
oversight-profile approval record がその代わりになることはどちらの向き
にも無い。

## close-out の pre-flip gate

`bin/close-out.sh` はボードへ書き込む前に、タスクの Active flag を読む
（T-1107、issue #53）。その flag が既に `READY_FOR_MERGE`——
`codex-reviewer` が APPROVE 時に書く唯一の状態——でない限り、close-out は
exit 1 で refuse し、ボードのパス・ソース行・見つかった flag を名指しし、
ボードファイルは byte 単位で無変更のまま残る。`READY_FOR_ARCH` /
`READY_FOR_ENG` / `READY_FOR_QA` / `READY_FOR_REVIEW` / `BLOCKED` /
`REWORK` のいずれかにまだあるタスクは、黙って昇格されるのではなく refuse
される。修正は、本来 `READY_FOR_MERGE` を書くはずのレビューが実際に走っ
た後に、ボード上の flag を 1 箇所書き換えるだけでよい。

別件として、`close-out.sh --issue N` は手動での GitHub issue クローズ手順
を出力する（`develop` へのマージは issue を自動クローズし**ない**ため）。
`--issue` が省略された場合——あるいは空文字列で渡された場合——は、代わりに
1 行のノート（`close-out: note: no --issue given`）を出力し、operator が
その手順の存在を知れるようにする（何も出力しない代わりに）。ノートと手順
は 1 つの条件の厳密な補集合であり、同じ実行で両方発火することも、両方
沈黙することもない。出力されたノートは disclosure であって gate ではない
——close-out を refuse せず、stdout を読まない operator には、どちらに
せよ何も伝わらない。

## 中継される件数は自分の導出コマンドを伴う

`bin/check-count-claims.sh`（T-1113、issue #397）はタスク自身の
`## Active` board entry から `- count: <label> — <value> — command: <cmd>`
sub-bullet を読み、malformed または重複した行を refuse し——`--no-exec`
を付けない限り——conformant な各行のコマンドを再実行し、測定された出力が
宣言値と食い違えば refuse する。`bin/close-out.sh` はこれを無条件に、
`--no-exec` モードで delegate する: 文法検証のみなので、`- count:` 行を
一切持たない entry はそのまま close-out でき、出荷時既定パスに新しい実行
面はゼロのまま。`--no-exec` を付けずに実行するのは operator が明示的に
選ぶ別の操作であり——このプロジェクト自身の凍結・レビュー済み spec とは
違い、board entry はタスクのライフサイクル中いつでもどのロールからも
編集され得るため——対象の board が index/HEAD に対する未コミット変更を
持つ tracked path であれば stderr に警告を出す（refuse は決してせず、
exit status も変えない）。

## review-input fidelity を記録する

review record の verdict section が名指す各 executor pass は、1 つの
opaque な pass id の下に 4 つの情報を持ち、`bin/check-review-input.sh`
（T-1104・issue #335）がその grammar を fail-closed に検証する。4 つと
は、pass の **executor-invocation**（1 行に rendered された verbatim な
argv）、closed set `generation` / `confirmation` から選ぶ **pass-role**、
先頭 token が `carried` / `not-carried` / `not-applicable` のいずれかで
後に非空の説明が続く **briefing-fidelity**、そしてその pass が publish
した **raw-capture** stem である。これらの field を 1 つも持たない
record——今日すでに commit されている全 record がこれに当たる——は exit 0
になる。この要件は forward-only である。

**verbatim field が決して持ってはならないもの。** `executor-invocation`
の値は実際の argv であり、永続的に tracked な git history に残る。
だから environment dump や変数の展開値、credential・token・key・認証
header、repository 外の absolute path（特に home-directory path や
`$TMPDIR` session root）、operator や account の identity を決して含んで
はならない。実際の argv が invoker の home directory 配下の absolute
path（特に `--cd` 引数）を含む場合は、その path を repository root から
の相対パスとして `<repo-root>` と記録する。flag・他の引数・その順序は
すべて verbatim のまま保つ。これは recording convention であって
checker が強制するものではない。checker はこの field の内容を判定しない
ので、どちらの書き方でも record は conformant である。
`bin/check-pii-shapes.sh` の diff-scoped CI step は現実の、しかし同じく
有限な backstop である。named prefix・named root・長さの下限に基づく
**finite known-shape screen** であって、網羅的な secret 検出ではない。
ゆえに上記の field contract こそが、書く瞬間（それが安く済む唯一の瞬間）
に適用される一次的な統制である。

**この機構が閉じないもの。** 記録するのは what was invoked（何が
invoke されたか）であって、model が実際に何を受け取ったかでは決してない。
committed byte に対するいかなる判定も、briefing が executor の context
に届いた invocation と届かなかった invocation を見分けられない。
`pass-role` label の真偽も、記録された argv が実際に走った argv である
ことも検証しない。そして `raw-capture` field が名指す raw file が
**not present on disk**（disk 上に存在しない）ことも見抜けない。
`raw-capture` の値は構造上 untracked（`/.gitignore`）なので、何も指さ
ない stem もこの checker には conformant である。

## freeze 時にリリースバージョンを導出する

すべての freeze——タスクの最初の freeze も、class-M mechanics-repair
re-freeze を含むあらゆる re-freeze も——で、coordinating session はその
freeze の `- intent-hash` 行を追加する前に、spec 自身が持つ 2 つの宣言
から release tier を re-derive する: `- user-visible:` 行と
`- verification-class:` 行である。この derivation は `CONTRIBUTING.md`
の `## What a version number encodes` が定める headline test と
default-reachability test を jointly（両方同時に）適用する。
`- user-visible: yes` という宣言は derivation の **trigger** であって
verdict では決してなく、derived tier は `MAJOR` / `MINOR` / `PATCH` の
いずれか 1 つである。

結果はタスク自身の board entry 上に `- version-derivation` sub-bullet
として、`- version-derivation (v<N>, YYYY-MM-DD):` という形で記録され
る。その closed な field 群——`verdict=`・`derived=`・`headline=`・
`default-reach=`——は 1 つの free-form な `grounds:` field より前に置か
れ、後続の checker がこの family を present なときだけ検証できるように
しつつ、この行を一切持たない entry も引き続き pass する。両者の間にある
`premise=` field は self-contained であることが要求される: それは
expected tier と、その planning approval が承認された根拠の両方を運び、
後の読者が開けない approval への裸の pointer には決してならない。
repository に承認済みの planning premise が記録されていない場合——
adopter が一度も設定していない場合の既定の姿——比較対象がそもそも無く、
これは freeze を拒否する理由には決してならず、record は
`verdict=no-premise-on-record` として書かれ続ける。

derived tier が repository の承認済み planning premise と一致しない場
合、freeze はそのタスクへのそれ以上の作業の前に停止し、deviation
notice を発行する: 英語で述べられ、裸の "proceed?" では決してなく、3 つ
の必須要素——作業が exceeds the approved estimate（承認済みの見積りを
超えたこと）、continue-or-stop の問い、そして根拠を伴う recommendation
——のすべてを運ぶ。この停止は not a fourth human gate（第 4 の human
gate ではない）: これは re-enters the existing planning-approval gate
（既存の planning-approval gate に再突入する）——このループがすでに宣言
している 3 つの standing human gate のうちの 1 つ——である。derived
tier が承認済み premise と一致しないということは、その approval が
lapse した（失効した）ことを意味するからである。新しい status flag も
新しい phase も追加されない。

現時点の強制は**チェッカーではなく duty** である: coordinating session
がこの derivation を自ら読む行為として実行し、no mechanical checker ships for it yet（機械的なチェッカーはまだ出荷されていない）。

## 運用ルール

- 前フェーズの status flag がボードに設定されるまで、次フェーズへ進めないこと。
- タスクが完了するのは、Codex レビュアーが `READY_FOR_MERGE` を設定したときだけです。それには先に QA が通過していること（`READY_FOR_REVIEW`）が必要で、QA 通過とクロスプロバイダレビューの両方がクリアされなければなりません。
- レビュアーは意図的に別のモデルプロバイダ（Codex）で走ります。ループの中に必ず入れておくこと。
- エージェント間の共有状態はファイルだけです（メモリは共有されない）。ボード
  （`<base>/todo.md`）・各仕様（`<base>/specs/`）・ループ契約が唯一の真実源です。
