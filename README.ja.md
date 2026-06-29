# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia icon" width="128" height="128">
</p>

[English README](README.md)

現在のバージョン: `0.2.0`

Capsomnia は、Caps Lock を「スリープ抑止スイッチ」として使うための小さな macOS メニューバーアプリです。

Caps Lock がオンの間は `pmset` でシステムスリープを無効化し、Caps Lock をオフにすると通常のスリープ設定へ戻します。

## できること

- Caps Lock オン: `pmset -a disablesleep 1` を実行
- Caps Lock オフ: `pmset -a disablesleep 0` を実行
- メニューバーの緑の丸: スリープ抑止中
- メニューバーのグレーの丸: 通常のスリープ動作
- 初回起動時の設定: メニューバーの丸を表示するか、ログイン時に起動するかを選択
- アプリ終了時は通常のスリープ動作へ戻す

ローカルで長時間動く AI コーディングエージェント、ビルド、ダウンロード、スクリプトなどを止めたくないときに使う想定です。

## なぜ `caffeinate` ではなく Capsomnia か

`caffeinate` は、Mac を開いたまま放置するときの idle sleep 抑止には便利です。一方で MacBook の蓋を閉じる場合は別で、通常の `caffeinate` assertion だけではローカルジョブの継続を安定して期待できません。

Capsomnia は `pmset -a disablesleep 1` を使い、システムスリープ自体を無効化します。蓋を閉じても明示的にローカル処理を続けたい用途に向いています。

## 安全上の注意

- 蓋閉じでのバックグラウンド作業は想定用途です。SSH、スマホからの agent 操作、ビルド、ダウンロード、長時間ジョブなどに使えます。
- スリープ抑止中の蓋閉じ運用では、発熱やバッテリー消費が増えることがあります。
- Mac を放置する場合は、通気、電源、実行時間を見て使ってください。
- Capsomnia は手動スイッチです。Caps Lock オンは「動かし続ける」、Caps Lock オフは「通常のスリープ動作」です。

## 必要なもの

- macOS 14 以降
- Swift 6 toolchain
- インストール時の管理者権限

現時点ではソース配布です。インストールスクリプトがローカルで `Capsomnia.app` をビルドします。

## インストール

```sh
git clone https://github.com/fuji-mak/Capsomnia.git
cd Capsomnia
./scripts/install.sh
```

インストーラが行うこと:

1. Swift 実行ファイルを release build する
2. `Capsomnia.app` をビルドして `~/Applications/` に配置する
3. root 所有の固定 helper を `/Library/PrivilegedHelperTools/capsomnia-pmset` に配置する
4. 現在のユーザー向けに限定的な sudoers rule を追加する
5. LaunchAgent を配置して起動する

インストール後はログイン時に自動起動します。
初回起動時に小さな設定画面が開き、メニューバーの丸を表示するか、ログイン時に Capsomnia を起動するかを選べます。設定画面はメニューバー項目から開き直せます。

## アンインストール

```sh
./scripts/uninstall.sh
```

LaunchAgent、`~/Applications/Capsomnia.app`、helper、sudoers rule を削除し、通常のスリープ動作へ戻します。

## セキュリティモデル

メニューバーアプリ本体は root では動きません。ただしシステムのスリープ設定変更には権限が必要なため、固定 helper を passwordless `sudo` 経由で呼び出します。

アプリが呼び出せるのは次の 2 コマンドだけです。

```sh
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset on
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset off
```

sudoers rule はこの 2 コマンドに限定されています。helper も `on` と `off` だけを受け付け、内部では次の `pmset` だけを実行します。

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

## ログ

ログはここに出力されます。

```text
~/Library/Logs/Capsomnia/
```

## Web サイトの編集

GitHub Pages のサイトは `docs/` にあります。HTML は Tailwind CSS のユーティリティクラスで書かれています。

```sh
npm install
npm run build:site
```

主に触るファイル:

- `docs/index.html`: ページ構造と Tailwind クラス
- `docs/styles.input.css`: サイト変数、補助 CSS、Tailwind の入力
- `docs/styles.css`: 生成された CSS
- `docs/capsomnia.js`: 言語切替、コピー処理

## トラブルシュート

スリープ抑止状態を確認する:

```sh
pmset -g | grep disablesleep
```

LaunchAgent を再起動する:

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
```

メニューバーの丸がすぐに反応しない場合でも、Capsomnia は 1 秒ごとに Caps Lock 状態を確認する fallback を持っています。

## ライセンス

MIT

## プロジェクトの状態

Capsomnia は初期公開版です。リリース履歴は [CHANGELOG.md](CHANGELOG.md)、脆弱性報告の方針は [SECURITY.md](SECURITY.md) を参照してください。
