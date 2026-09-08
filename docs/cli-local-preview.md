## ローカル確認版

本番公開・リリース・通常版の置き換えは行いません。MacReadyも同じTools.pkgから導入できます。

Capsomnia・cpsm・MacReadyの3リポジトリを同じ親フォルダに置いてビルドします（`CPSM_REPO`／`MACREADY_REPO`で変更可）。

ビルド:

```sh
scripts/build-local-cli-preview.sh
```

出力は `dist/cli-preview/` です。

1. `Start Preview.command` を開きます。通常版の常駐を一時停止し、確認版だけを起動します。通常版アプリとhelperは削除・置換しません。
2. 確認版の「詳細設定」で右下の「Capsomnia CLI & Skill」を押し、確認ダイアログで「インストール」を選びます。
   ローカルの更新版Tools.pkgを取得し、macOS認証後にアプリ内でインストールします。
   CLIは `/usr/local/bin/cpsm` と `/usr/local/bin/macready`、Skillは `~/.agents/skills/` に配置され、
   Claude Code用のリンクも自動作成されます。導入先の選択はありません。
3. 同じフォルダで以下を実行します。

```sh
./cpsm --app "$PWD/Capsomnia CLI Preview.app" status --json
./cpsm --app "$PWD/Capsomnia CLI Preview.app" timer set 2h
./cpsm --app "$PWD/Capsomnia CLI Preview.app" timer status --json
./cpsm --app "$PWD/Capsomnia CLI Preview.app" timer cancel
./cpsm --app "$PWD/Capsomnia CLI Preview.app" settings get
```

CLIの既定の接続先は `/Applications/Capsomnia.app` です。今回の確認では `--app` で確認版を指定してください。アプリが未起動ならCLIが自動起動します。古い通常版との同時起動はできないため、最初に `Start Preview.command` を使います。

`off` とOFFへの `toggle` はMacをスリープさせます。実際のスリープは作業終了時に試してください。ONへの `toggle` は起こし続ける状態にします。

タイマーは今回限りで、指定するとONになり既存タイマーを置き換えます。解除するとONを維持します。保存済みタイマー設定は変わらず、次のOFF→ONで再び使われます。今回限りのタイマーはメモリ上のため、アプリを終了すると終了します。

確認版は通常版と設定・helperを共有します。CLIで変更した設定は通常版にも残ります。ショートカットは読み取りのみで、登録・変更はGUI専用です。

確認を終えたら `Restore Installed App.command` を開くと通常版へ戻せます。

## Skill

専用pkgには `cpsm`・`macready` と、それぞれのSkillが入っています。Skillは `~/.agents/skills/` の `capsomnia`・`macready` フォルダに配置され、`~/.claude/skills/` にはそれぞれへのリンクを作成します。導入後、エージェント側で新しいセッションを開始してください。Capsomniaのローカル確認中は、エージェントに確認版のアプリパスと `--app` の指定も伝えてください。

インストールをせずCLI自体を試す場合は、同じフォルダの `cpsm` を上記のコマンドで使えます。

## MacReady

MacReadyはCapsomniaの起動・インストールなしで、そのまま試せます。

```sh
cd ~/projects/Capsomnia/dist/cli-preview
./macready
./macready status --json
```

電源・残量・充電中かどうか・バッテリー温度・macOSの熱状態・蓋・外部ディスプレイ・スリープ抑止設定を読み取ります。CPU/GPU温度は初版では未対応です。充電器を抜き差しした前後などに再実行して、実際の状態と一致するか確認してください。取得不能な値はunknown/nullで返します。

ソースと出力仕様は独立したMacReadyリポジトリの `README.md`、Skillは同リポジトリの `skills/macready/SKILL.md` です。

## 今回確認する動作

- `--help`、`--version`、入力エラーはアプリを起動せず処理する
- 状態確認・設定取得ができ、GUIと設定変更が同期する
- `timer set`の残り時間がGUIにも表示される
- `timer cancel`でONを保ち、保存設定は変更されない
- OFF・タイマー満了時にCaps Lockとスリープ抑止を解除してスリープする
- `doctor`で取得できない状態や同期不一致を確認できる

## 配布

通常の `scripts/build-app.sh` / `scripts/build-pkg.sh` はCLI・Skillを同梱しません。専用pkgはcpsmリポジトリの `scripts/build-tools-pkg.sh` で別に生成します。ローカル版は `SKIP_SIGNING=true` で作る未署名の検証用pkgです。

アプリはInfo.plistの `CapsomniaToolsPackageURL` を取得先として使います。ローカル確認版のみfile URLを設定し、配布用は cpsmの `releases/latest/download/Capsomnia-Tools.pkg`を使います（公開済み旧形式pkgはアプリ内導入では拒否します。更新版pkgの公開は本人確認後です）。HTTPS取得では既存の更新処理と同様にCapsomniaの署名と導入形式を検証してから、macOS認証を経てインストールします。署名済み候補版もローカルで作成できます。Appleへの公証提出と公開は本人確認後に行います。全体の配布準備は `docs/distribution.md` を参照してください。
