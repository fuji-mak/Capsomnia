# Capsomnia・cpsm・MacReady 配布準備

現在の配布版は **Capsomnia 4.0.0 / cpsm 0.1.1 / MacReady 0.1.1** です。
**本人の確認が済むまで公開しません。** 候補pkgを作る工程と、Appleへの公証提出・
GitHubへの公開工程は別です。ビルドしてもメインで使用中のアプリは置き換えません。

## リポジトリと役割

| ローカルリポジトリ | 作品と管理対象 | 公開先 |
| --- | --- | --- |
| `Capsomnia` | アプリ・helper | 既存 `fuji-mak/Capsomnia` |
| `cpsm` | CLI・capsomnia Skill・CapsomniaControl・同梱Tools配布 | `fuji-mak/cpsm`（Public、CLI初版公開済み） |
| `MacReady` | CLI・macready Skill・MacStateCore | `fuji-mak/MacReady`（Public、CLI初版公開済み） |

各作品に作者と関連作品への導線を設け、cpsmは「Capsomnia CLI & Skill」と表記します。
MacReadyはアプリ非依存の独立した作品です。Skillは製品ごとに共通本文を1つ持ち、
`~/.agents/skills/` に配置し、Claude Code用のリンクを自動作成します。

アプリが利用する共通ライブラリだけを `Vendor/` に版数・SHA-256・ライセンス付きで
取り込みます。アプリのビルドに他リポジトリの配置やネット接続は不要です。
変更は元リポで行い `python3 scripts/sync-vendor.py` で更新します。
`python3 scripts/sync-vendor.py --check` はコピーの一致をオフライン検証します。

## 配布物

以下は `dist/distribution/` からの相対パスです。

| 配布物 | 内容 | 導入先 |
| --- | --- | --- |
| `capsomnia/Capsomnia.pkg` | アプリ・helper・LaunchAgent | `/Applications` ほか既存の配置先 |
| `cpsm/Capsomnia-Tools.pkg` | cpsm＋MacReady＋両Skill | `/usr/local/bin` と `~/.agents/skills/` |
| `cpsm/cpsm.pkg` | cpsm＋capsomnia Skill | 同上 |
| `macready/MacReady.pkg` | macready＋macready Skill | 同上 |

単体・同梱で同じcomponent pkgを使うため、導入先とreceipt識別子が一致します。
どちらから更新しても同じCLI／Skillを更新します。既存の管理対象Skillを更新し、ユーザーが編集したSkillとの競合は保持して停止します。公開配布するのは上記product pkgで、`components/` は組立用です。
CLI／Skillを削除してもアプリは残り、アプリを削除してもCLI／Skillは残ります。
削除方法は各READMEを参照してください。

互換性:

- Capsomnia配布pkg: Apple silicon、macOS 14以降（従来どおり）。IntelではmacOS
  13.5以降でアプリをソースからビルドできます。
- cpsm／MacReady pkg: Apple silicon＋Intelのuniversal、macOS 13.5以降。
- cpsm 0.1.0: 公開版ではCapsomnia 4.0.0以降が必要。wire protocolは1。
  以前のローカルCLI対応版3.5.0も同じプロトコルですが、公開済み3.5.0は非対応です。
- MacReady 0.1.0: アプリ・sudo・常駐なし。CPU/GPU実温度は未対応でnullを返します。

## ビルド

3リポジトリを同じ親フォルダに置き、Capsomnia内で実行します。

```sh
./scripts/prepare-distribution.sh
```

既存Developer ID Application／Installer証明書で署名した候補を作ります。
Appleの署名タイムスタンプ取得は行いますが、公証・インストール・公開は行いません。
全体チェックサムは `dist/distribution/SHA256SUMS.txt`、各配布フォルダにも
公開用のチェックサムを用意します。

別配置なら `CPSM_REPO=/path/to/cpsm MACREADY_REPO=/path/to/MacReady` を指定します。
別証明書は `APP_SIGN_ID`／`PKG_SIGN_ID`、未署名検証は `SKIP_SIGNING=true` を使います。
出力先は第1引数で指定できます。

同梱Toolsのビルド・公証スクリプトとインストーラ素材はcpsm側で管理します。
Toolsだけ更新する場合はcpsm側の `scripts/build-tools-pkg.sh` を使います。

テストは各リポジトリで `swift test`。ビルドスクリプトはpkgを展開し、同梱バイナリの
署名とSkillの一致を確認します。電源状態を変える実機テストは通常の自動テストから除外しています。

## 本人が試す確認版

`dist/distribution/preview/` にはローカル取得先を設定した確認版アプリ、両CLI、
同じ署名済みTools.pkg、起動・復帰用commandを置きます。アプリ本体のみ確認用の
ad-hoc署名です。公開用pkgと区別してください。

1. `Start Preview.command` を開くと使用中のアプリを終了し、確認版を起動します。
   保存設定は共有しますがメインアプリのファイルは置換しません。
   アプリを切り替えるため、現在の一時タイマーは終了します。
2. 詳細設定の右下「Capsomnia CLI & Skillをダウンロード」を押し、確認ダイアログで「インストール」を選ぶ。
   ローカル確認版は新形式のTools.pkgを使用します。公開版はHTTPSと署名検証を使用します。
3. macOS認証後に設定画面が元の位置へ戻り、完了時に「完了しました」と表示されること、導入先選択がないことを確認。
   アプリ内導入は形式2のTools.pkgが必要です。公開済み旧形式では導入を始めません。
4. 確認版フォルダで以下を実行できます。

```sh
./cpsm --app "$PWD/Capsomnia CLI Preview.app" status --json
./cpsm --app "$PWD/Capsomnia CLI Preview.app" settings get
./macready status --json
```

タイマー設定→GUIの残り時間→cancel、充電器接続前後のMacReady表示も確認対象です。
`cpsm off`／OFFへのtoggle／タイマー満了はMacをスリープさせるため、作業終了時に
確認してください。`Restore Installed App.command` でメインアプリへ戻れます。

## 本人の公開承認後

1. READMEの候補版表記とCHANGELOGを実際の公開日に合わせて更新。
2. 候補の内容を確定し、必要なcommit・PR／tagを作成。cpsmとMacReadyは
   Publicリポジトリへソースをpushし、tag／Releaseを作成します。Capsomniaの既存ブランチ保護は維持します。
3. Appleへ公証を提出してstaple・Gatekeeper検証。既存の認証profileを明示します。

```sh
NOTARY_PROFILE=capsomnia-notary ./scripts/notarize-distribution.sh
```

この手順はAppleへpkgをアップロードします。GitHubへの公開は行いません。
公証でpkgの内容が変わるため、チェックサムも再生成します。

4. `fuji-mak/cpsm` と `fuji-mak/MacReady` の各 `v0.1.1` を公開。
   固定名pkg・版数入りpkg・各SHA256SUMS.txtを添付。cpsm側には同梱版の
   `Capsomnia-Tools.pkg`、`Capsomnia-Tools-0.1.1.pkg`、`Tools-SHA256SUMS.txt`も添付します。
   Skillはリポジトリ内でも取得可能です。
5. cpsm側の同梱Toolsが取得できる状態で、Capsomnia `v4.0.0` に本体pkgを添付して公開。
   `Info.plist` の取得先は以下のcpsm最新リリースURLです。Toolsの更新にアプリの再公開は不要です。
   cpsmの最新リリースには同名の同梱pkgを必ず添付し、対応するCapsomniaとの互換性を確認します。

   `https://github.com/fuji-mak/cpsm/releases/latest/download/Capsomnia-Tools.pkg`

6. 公開URLのHTTP応答、ダウンロード後の署名・チェックサム、アプリからの実取得を確認。
   作者プロフィールと各作品の相互リンクを揃えたうえで告知。

公開URLでの実取得は、本人確認と公開が済んでから検証する項目です。
