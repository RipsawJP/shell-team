# 既存のリポジトリを local record mode に移す

このページは、すでにリポジトリで shell-team を動かしている adopter 向けです。このリリースで既存の環境に何が変わるか、今のまま使い続ける方法、1 つのクローンを local record mode に移す方法、元に戻す方法、結果の確かめ方を扱います。モード自体の説明は adopting ガイドに 1 か所だけあり、このページはその説明へリンクして、繰り返しません。

## このリリースで変わったこと

既定は変わりません。`shell-team.mode` のキーが無いクローンは `tracked` 記録モードで、これはループがこれまでずっと動いてきたモードです。`local` 記録モードはクローンごとの任意の選択です。

新しいキーは `shell-team.mode` で、クローンごとに、そのクローン自身の git config に設定します。モードの説明と setup が報告する内容の表は、adopting ガイドの [記録を git に載せない: local record mode](adopting.ja.md#記録を-git-に載せない-local-record-mode) の節に 1 か所だけあります。このページはそれを繰り返さず、リンクで示します。

既存の adopter が気づきうること:

- `bin/team-setup.sh` は base dir をモード別に報告します。`local` モードでは、追記する ignore の行を示し、無視されている base dir は `Already in place:` に並べ、すでに HEAD でコミットされている base dir は `Remains the operator's decision:` に並べます。`tracked` モードの報告は変わりません。
- `bin/team-init.sh` は、記録モードについての 2 行を、どのモードでも、最後の `Next:` の行の直前に出すようになりました。1 行目は運用ファイルが既定でコミットされること（モード `tracked`）を述べ、2 行目は記録を git に載せないクローン向けに `git config shell-team.mode local` を示します。
- `bin/check-pii-shapes.sh --paths <file>…` は、指名したファイルだけをスキャンします。`local` モードでは、ロールが自分の記録に対してこれを使います。既定モードと `--all` モードは、無視されていて tracked でもない base dir を読まず、記録を 1 つも読まないまま clean と報告してしまうためです。
- `local` モードでは、hand-off はボード・spec・レビュー記録を作業コピーに書き、コミットしません。engineer の実装とテストは、これまでどおりコミットされます。
- `local` モードでは、`bin/team-commit.sh` は base dir 配下の名指しされたパスを拒否し、`bin/check-durability.sh` は記録がコミットされたかを確認する代わりに `skipped:` の行を出します。
- `isolation: worktree` と `bin/land-worktree.sh` は `local` モードではサポート外です。無視された base dir は linked worktree へ引き継がれないためです。この制限は run スキルと adopting ガイドに書かれています。`bin/land-worktree.sh` はモードを読まないので、そのスクリプトがモードを理由に拒否することはなく、この組み合わせを避けるのはあなたの側です。
- Codex CLI host では、このリリースでロールのプロンプトが変わったため、以前のバージョンで生成した `.codex/agents/shell-team-*.toml` は新しく生成し直した内容と一致しません。`.codex/agents` を再生成するまで、`bin/check-codex-agents.sh` はそれぞれをずれていると報告します。
- セットアップは 2 つのプロンプトで進みます。すでに shell-team があるリポジトリでは `update shell-team`、無いリポジトリでは `set up shell-team` です。どちらも同じフローを実行し、ignore ファイルは編集せず、モードも変えません。

## tracked モードのまま使う

`tracked` モードのまま使うなら、モードについては何もしません。`shell-team.mode` のキーが無いクローン、またはちょうど `local` ではない値のクローンは `tracked` です。

host でプラグインを upgrade し、shell-team を使っているリポジトリごとに `update shell-team` と入力します。両 host のコマンドは [配布ガイドのアップデートの節](distribution.ja.md#アップデート) にあり、プロンプトを 2 回目に実行しても何も変わりません。

Codex CLI host では、このプロンプトがずれた `.codex/agents` も再生成します。手で行うなら、リポジトリの root から `bash "<plugin root>/bin/gen-codex-agents.sh" --out-dir .codex/agents` を実行し、`bash "<plugin root>/bin/check-codex-agents.sh"` で確認します。配布ガイドの説明どおりです。

`tracked` モードでは、ほかに必要なことはありません。base dir はコミットされたままで、耐久性ゲートは記録がコミットされたかを引き続き確認します。

## クローンを local モードに移す

記録を git に載せたくないクローンごとに、次の順で行います。どの手順もクローンごとです。

1. クローンの中から 1 度だけ、`git config shell-team.mode local` でモードを宣言します。値はそのクローン自身の `.git/config` に保存されます。global や system の git config の値が `local` を選ぶことはありません。
2. クローンの `info/exclude`（`git rev-parse --git-path info/exclude` が指すファイル）に ignore の行を足します。既定の base dir なら行は `/.shell-team/` で、`printf '%s\n' '/.shell-team/' >> "$(git rev-parse --git-path info/exclude)"` で追記できます。代替は root `.gitignore` の行ですが、これは共有されます。その行を引き継ぐクローンはすべて `local` も宣言しなければならず、宣言なしで行だけを持つクローンは、base dir が無視された `tracked` のクローンであり、setup はそれを妨げているルールとして報告します。
3. `update shell-team` と入力します。報告はモードに従うようになります。無視されている base dir は `Already in place:` に並び、まだ無視されていない base dir は、追記する行を示す `Required:` 項目になり、すでにコミットされている base dir は次の節で扱います。
4. それ以降、ループは記録を作業コピーに書き、コミットしません。engineer の実装とテストは、これまでどおりコミットされます。`isolation: worktree` は `local` モードではサポート外なので指定しないでください。既定の non-worktree の engineer の経路には影響しません。
5. 記録はこの作業コピーにしか存在しません。fresh な clone にはそれらがなく、`tracked` モードで始まります。

## base dir がすでにコミットされている場合

ignore ルールは git がすでに追跡しているファイルには適用されないので、base dir が HEAD でコミットされているクローンでは、`info/exclude` に行を足しても何も隠れません。

`local` モードでは、`update shell-team` はそのような base dir を `Remains the operator's decision:` に並べます。項目は、ディレクトリが tracked であること、tracked のままにするかはあなたの判断であることを述べ、`info/exclude` の行は出さず、コマンドも示しません。このページも示しません。

tracked のままにするなら、記録ファイルへの編集は `git status` に変更ありとして現れ、`bin/team-commit.sh` は、モードが `local` の間、tracked かどうかにかかわらず base dir 配下のあらゆるパスのコミットを拒否する（class `local-mode`、exit 2、何も stage されない）ので、ループがそれらをコミットすることはありません。

tracked でなくすなら、それはあなた自身が行ってコミットする変更で、プラグインは何も行いません。HEAD に base dir が含まれなくなれば `info/exclude` の行が効き、setup はそのディレクトリを `Already in place:` に並べます。すでにコミットされた記録は、履歴と、そのコミットより前に作られたクローンに残ります。

## shell-team を使う人と使わない人が混在するチーム

一部のメンバーだけが shell-team を使う場合、使う人はそれぞれ自分のクローンで `shell-team.mode local` を宣言し、ignore の行を自分の `info/exclude` に置きます。どちらもクローンごとの設定で、push されることはありません。

誰も base dir をコミットしない限り、共有リポジトリには base dir が含まれません。そのため shell-team を使わないメンバーには記録ファイルが見えず、fresh な clone は無視するものが何も無い `tracked` モードで始まります。

ignore の行を root `.gitignore` に置くのは、全員が `local` を宣言する場合だけにしてください。その行は共有され、宣言なしでそれを引き継いだクローンは base dir が無視された `tracked` のクローンになり、setup はそれを妨げているルールとして報告します。

## tracked モードに戻す

そのクローンで既定のモードをもう一度宣言します:

```bash
git config shell-team.mode tracked
```

ちょうど `local` ではない値はすべて `tracked` と読まれるので、値を設定するだけで足ります。キー自体は残してかまいません。

`tracked` モードに戻ったあと base dir がまだ無視されていれば、setup は `Required:` の下で、妨げているルールを報告します。ignore の出どころと行、`git add` コマンド、該当するなら再包含の行です。ignore の行を変えるか、setup が示す再包含の行を足すかを決め、setup が出す `git add` コマンドで記録をコミットしてください。setup 自身は何もコミットしません。

クローンが `local` だった間に書かれた記録は作業コピーに残り、それをコミットしたものは何もありません。記録が git に入るのは、あなたがコミットしたときだけです。`tracked` モードでは `bin/check-durability.sh` はすぐに実行され、コミットされていない記録を `not-durable` と報告します。

## 結果を確かめる

宣言されたモードは `bin/team-mode.sh` で読みます。`local` か `tracked` を出し、git が config を読めない場合は exit 2 で終わり、ループは `BLOCKED` で止まります。

```bash
bash "<plugin root>/bin/team-mode.sh"
git status --short
```

`git status` は、無視された記録については何も示しません。base dir がコミットされているクローンでは、編集した記録を変更ありとして示します。

`local` モードでは、`bin/check-durability.sh` は通常の `--phase`・`--task`・`--ref` 引数を渡したとき `check-durability: skipped: shell-team.mode is local — no durability observation was made` を出して exit 0 で終わります。skipped は何も観測しなかったという意味で、記録が durable だという意味ではありません。

もう一度 `update shell-team` と入力します。base dir が `Already in place:` に並んでいれば ignore の行は効いており、2 回目の実行では何も変わりません。

Codex CLI host では、`.codex/agents` を再生成したあと、`bin/check-codex-agents.sh` はそれを in sync と報告します。
