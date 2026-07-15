# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia icon" width="128" height="128">
</p>

<p align="center">
  <a href="README.zh-CN.md"><img alt="简体中文 README" src="https://img.shields.io/badge/README-ZH--CN-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="README.md"><img alt="English README" src="https://img.shields.io/badge/README-EN-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="https://fuji-mak.github.io/Capsomnia/"><img alt="Website" src="https://img.shields.io/badge/Website-Open-b7ff3c?style=for-the-badge&labelColor=111111"></a>
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/fuji-mak/Capsomnia/ci.yml?branch=main&style=flat-square&label=CI&labelColor=111111&color=b7ff3c"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-b7ff3c?style=flat-square&labelColor=111111">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-b7ff3c?style=flat-square&labelColor=111111">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-b7ff3c?style=flat-square&labelColor=111111"></a>
</p>

現在のバージョン: `1.5.0`

[简体中文 README](README.zh-CN.md) · [English README](README.md) · [セキュリティ](SECURITY.md)

## コミュニティ改良版

これは [fuji-mak/Capsomnia](https://github.com/fuji-mak/Capsomnia) のコミュニティ改良版です。原作者の著作権表示と MIT ライセンスを維持しています。

主な変更点は、ネイティブのメニューバー UI、直接操作できる「蓋を閉じてもMacをスリープさせない」スイッチ、中国語・英語・日本語対応、蓋を閉じている間の確実な画面スリープ、Codex/Claude のタスク完了後の自動スリープです。主操作だけを目立たせ、補助設定は標準のチェックマークで表示します。状態は塗りつぶし円と中空円、エラーは赤で示します。

**Macを閉じてもAIは動き続け、すべてのタスクが終わったらMacが自分で眠ります。** 自動スリープは初期状態でオンです。蓋が閉じていることと、認識できたすべての Codex/Claude セッションおよびサブエージェントの停止を確認してから、5分間待ってスリープします。

この 1.5.0 カスタム版は、ソースまたはローカルでビルドした未署名パッケージ（payload は ad-hoc 署名）だけで提供します。原作者の Developer ID や Apple 公証は使用していません。公式 1.0.0 の署名・公証はこのカスタム版には適用されません。

**Capsomnia** は、MacBook の蓋を閉じてもローカル処理を止めないための小さな macOS アプリです。

作業を走らせ続けたいときは「蓋を閉じてもMacをスリープさせない」をオン。通常のスリープ動作に戻したいときはオフにします。

AIエージェントの実行、モバイル接続、その他長時間の実行や遠隔での作業に有効です。

<p align="center">
  <img src="resources/caps-lock-on.jpg" alt="Caps Lock ランプ点灯" width="560">
</p>

<p align="center">
  <em>メニューバーが黄緑色なら、作業継続モードです。</em>
</p>

## クイックスタート

必要なもの:

- Apple silicon Mac（macOS 14以降）
- インストール時の管理者権限

ローカルでビルドしたパッケージでインストール:

1. ローカルでビルドするか、このカスタムソースと一緒に提供された `Capsomnia-1.5.0-cn-unsigned.pkg` を使用する
2. パッケージを開き、セキュリティ方針に従って出所を確認してからインストーラに従う

このカスタム版のパッケージは未署名で、payload に ad-hoc 署名を使います。パッケージは `Capsomnia.app` を `/Applications` に配置し、ネイティブ privileged helper、限定的な sudoers rule、LaunchAgent を設定します。公式 1.0.0 パッケージは Developer ID 署名と Apple 公証済みでしたが、その保証はこのカスタム版には適用されません。

パッケージのビルドとインストール処理は [`scripts/build-pkg.sh`](scripts/build-pkg.sh) と [`scripts/notarize-pkg.sh`](scripts/notarize-pkg.sh) で公開しています。

## ソースからビルド

開発者向けのソースインストールも利用できます。こちらは Swift 6 toolchain が必要です。

このカスタム版のソースディレクトリで実行します。

```sh
./scripts/install.sh
```

ソースインストーラはローカルで `Capsomnia.app` をビルドし、`~/Applications/` に配置します。あわせて、同じ helper、sudoers rule、ユーザー LaunchAgent を設定します。

## できること

- 「有効」オン: MacBookの蓋を閉じてもAIエージェントなどの処理が途切れないようにします。
- 「有効」オフ: 通常のスリープ動作に戻ります。
- 有効中に蓋を閉じた時: 作業を走らせたまま、設定に応じて画面を継続的にスリープ状態へ戻します。
- Codex/Claude のタスク完了時: 蓋が閉じていることと、認識できたすべてのセッションおよびサブエージェントの停止を確認した後、5分待ってMacをスリープさせます。一時キャンセルは今回だけに適用されます。
- 権限待ちまたは状態が不完全な場合: Hook がタスク終了を確実に示せない限り、スリープさせません。実行中の可能性がある状態を時間切れだけで終了扱いにはしません。
- 低バッテリー保護: 電源未接続、機能オン、蓋が閉じている状態でバッテリーが10%以下になると、通常のスリープ設定を復元してMacをスリープさせます。
- アプリ終了時: 通常のスリープ動作へ戻します。

長時間動くローカルジョブ、AI コーディングエージェント、SSH、ビルド、ダウンロード、放置スクリプトなどを止めたくないときに使う想定です。

## 設定

Capsomnia に独立した設定ウインドウはありません。常に表示されるメニューバー項目から次を設定します。

- 作業継続モードを有効にするか
- Codex/Claude のタスク完了後に自動スリープするか（初期状態でオン）
- 蓋を閉じたら画面をオフにするか
- ログイン時に起動するか
- 简体中文・英語・日本語のどれを使うか

同じメニューの最下部から Capsomnia を終了できます。

入力監視の許可は不要です。Capsomniaはキーボードイベントを読み取りません。以前のバージョンで入力監視を許可した場合は、システム設定から無効にできます。

Codex のライフサイクル Hook は通常の確認・信頼フローに従います。有効化後、Codex の `/hooks` で Capsomnia のコマンドを確認して信頼してください。信頼できるイベントを受け取るまでは、安全側に倒してタスク完了による自動スリープを行いません。

パッケージインストール後は `/Applications/Capsomnia.app`、ソースインストール後は `~/Applications/Capsomnia.app` から起動します。日常の設定には常時表示されるメニューバー項目を使います。

## なぜ `caffeinate` ではなく Capsomnia か

`caffeinate` は、Mac を開いたまま放置するときの idle sleep 抑止には便利です。一方で MacBook の蓋を閉じる場合は別で、通常の `caffeinate` assertion だけではローカルジョブの継続を安定して期待できません。

Capsomnia は蓋を閉じた状態であっても蓋を開いている状態と同じように処理を続行し、メニューバーに現在の状態を表示します。

## 安全上の注意

- スリープ抑止中の蓋閉じ運用では、発熱やバッテリー消費が増えることがあります。
- Mac を放置する場合は、通気、電源、実行時間を見て使ってください。
- Capsomnia は手動スイッチです。「有効」オンは「動かし続ける」、オフは「通常のスリープ動作」です。

## アップデート

このカスタム版はローカルでパッケージをビルドするか、ソースインストーラを使って更新してください。公式 GitHub Release の署名・公証状態をこの版に適用しないでください。

ソースインストールの場合は、既存 clone から更新できます。

```sh
cd Capsomnia
git pull
./scripts/install.sh
```

インストールスクリプトは、app bundle、helper、sudoers rule、LaunchAgent を現在のバージョンで上書きします。

## アンインストール

パッケージインストールの場合:

```sh
/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

ソースインストールの場合:

```sh
~/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

ソース clone から実行する場合は、これと同じです。

```sh
./scripts/uninstall.sh
```

アンインストーラは LaunchAgent を unload し、Capsomnia を停止し、`/Applications` または `~/Applications` の `Capsomnia.app`、helper、sudoers rule を削除し、通常のスリープ動作へ戻します。管理者認証が必要になることがあります。

## セキュリティモデル

メニューバーアプリ本体は root では動きません。ただしシステムのスリープ設定変更には権限が必要なため、固定ネイティブhelperをpasswordless `sudo`経由で呼び出します。helperはコンパイル済み実行ファイルで、shellの起動やshell初期化ファイルの読み込みは行いません。

パッケージで配置するアプリとhelperは`root:wheel`所有です。LaunchAgentは現在のユーザーだけに設定され、ほかのアカウントを自動で起動・設定しません。ローカル未署名ビルドではアプリとhelperをad-hoc署名で封印し、Developer ID署名は別途設定した正式配布ビルドでのみ使用します。継続実行が有効な間は、切替直後、画面の復帰時、さらに60秒ごとの予備確認で実際の`SleepDisabled`状態を検証します。主スイッチをオフにすると定期確認も停止します。helperが変更できない、状態を確認できない、設定が外部要因でずれた場合は、要求した状態を有効として表示せず、メニューバーの丸を赤色にして5秒後に再同期します。

Capsomnia 本体はネットワーク通信を行わず、テレメトリを収集せず、アカウントも必要としません。

Capsomniaは入力監視を要求せず、キーボードイベントも読み取りません。

インストール後、macOS がバックグラウンド項目の追加を通知する場合があります。これはログイン時に Capsomnia を起動し、クラッシュ後に復帰するための LaunchAgent です。無効にすると、自動起動とクラッシュ復帰が効かなくなることがあります。

クラッシュ復帰が無効または利用できない状態でCapsomniaを強制終了すると、最後のシステムスリープ設定が残る場合があります。その場合は下記の手動復旧コマンドで通常状態へ戻してください。

アプリが呼び出せるのは次の 4 コマンドだけです。

```sh
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset on
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset off
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset sleep-now
```

sudoers rule はこの 4 コマンドに限定されています。helper も `on`、`off`、`display-sleep`、`sleep-now` だけを受け付け、内部では次の `pmset` だけを実行します。

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset displaysleepnow
/usr/bin/pmset sleepnow
```

## ログとトラブルシュート

ログはここに出力されます。

```text
~/Library/Logs/Capsomnia/
```

スリープ抑止状態を確認する:

```sh
pmset -g | grep SleepDisabled
```

通常のスリープ動作へ手動で戻す:

```sh
sudo pmset -a disablesleep 0
```

LaunchAgent を再起動する:

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist"
```

パッケージ版とソース版のどちらも `$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist` を使います。

Capsomnia の LaunchAgent は、アプリがクラッシュした場合など正常終了でないときだけアプリを再起動します。起動時に「有効」設定を読み直し、対応するスリープ設定を再適用します。通常の「終了」は正常終了なので、アプリは再起動しません。

helper 権限を確認する:

```sh
sudo -n -l /Library/PrivilegedHelperTools/capsomnia-pmset on \
  /Library/PrivilegedHelperTools/capsomnia-pmset off \
  /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep \
  /Library/PrivilegedHelperTools/capsomnia-pmset sleep-now
```

helper 権限の確認に失敗する場合は、`./scripts/install.sh` をもう一度実行してください。「有効」の変更後、Capsomniaは実際のシステムスリープ状態をすぐに適用・確認します。

## プロジェクトの状態

Capsomnia 1.4.0では「有効」だけに目立つスイッチを残し、自動スリープなどの補助機能はネイティブのチェックマークで表示します。リリース履歴は [CHANGELOG.md](CHANGELOG.md)、脆弱性報告の方針は [SECURITY.md](SECURITY.md) を参照してください。

## ライセンス

MIT
