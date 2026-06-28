# Capsomnia

[English README](README.md)

Capsomnia は、Caps Lock を「スリープ抑止スイッチ」として使うための小さな macOS メニューバーアプリです。

Caps Lock がオンの間は `pmset` でシステムスリープを無効化し、Caps Lock をオフにすると通常のスリープ設定へ戻します。

## できること

- Caps Lock オン: `pmset -a disablesleep 1` を実行
- Caps Lock オフ: `pmset -a disablesleep 0` を実行
- メニューバーの緑の丸: スリープ抑止中
- メニューバーのグレーの丸: 通常のスリープ動作
- アプリ終了時は通常のスリープ動作へ戻す

ローカルで長時間動く AI コーディングエージェント、ビルド、ダウンロード、スクリプトなどを止めたくないときに使う想定です。

## 必要なもの

- macOS 14 以降
- Swift 6 toolchain
- インストール時の管理者権限

現時点ではソース配布です。インストールスクリプトがローカルでアプリをビルドします。

## インストール

```sh
git clone https://github.com/fuji-mak/Capsomnia.git
cd Capsomnia
./scripts/install.sh
```

インストーラが行うこと:

1. Swift 実行ファイルを release build する
2. アプリ本体を `~/Library/Application Support/Capsomnia/` に配置する
3. root 所有の固定 helper を `/Library/PrivilegedHelperTools/capsomnia-pmset` に配置する
4. 現在のユーザー向けに限定的な sudoers rule を追加する
5. LaunchAgent を配置して起動する

インストール後はログイン時に自動起動します。

## アンインストール

```sh
./scripts/uninstall.sh
```

LaunchAgent、アプリ本体、helper、sudoers rule を削除し、通常のスリープ動作へ戻します。

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

## トラブルシュート

インストール時に次のようなエラーが出る場合:

```text
install: /usr/local/sbin/INS...: No such file or directory
```

最新の `main` branch に更新してから、もう一度 `./scripts/install.sh` を実行してください。古い installer では helper を `/usr/local/sbin` に配置しており、このディレクトリが存在しない Mac で失敗することがありました。

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
