# Capsomnia

<p align="center">
  <img src="resources/CapsomniaIcon.svg" alt="Capsomnia 아이콘" width="128" height="128">
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/releases/latest/download/Capsomnia.pkg"><img alt="Capsomnia.pkg 다운로드" src="https://img.shields.io/badge/Download-Capsomnia.pkg-b7ff3c?style=for-the-badge&labelColor=111111"></a>
  <a href="https://capsomnia.com/ko/"><img alt="웹사이트" src="https://img.shields.io/badge/Website-Open-b7ff3c?style=for-the-badge&labelColor=111111"></a>
</p>

<p align="center">
  <a href="https://github.com/fuji-mak/Capsomnia/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/fuji-mak/Capsomnia/ci.yml?branch=main&style=flat-square&label=CI&labelColor=111111&color=b7ff3c"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-b7ff3c?style=flat-square&labelColor=111111">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-b7ff3c?style=flat-square&labelColor=111111">
  <a href="LICENSE"><img alt="MIT 라이선스" src="https://img.shields.io/badge/License-MIT-b7ff3c?style=flat-square&labelColor=111111"></a>
</p>

현재 버전: `1.0.2`

[English README](README.md) · [日本語 README](README.ja.md) · [简体中文 README](README.zh-Hans.md)

Capsomnia는 Caps Lock을 MacBook 덮개를 닫은 채 작업할 때 쓰는 물리 잠자기 방지 스위치로 바꿔 주는 작은 macOS 메뉴 막대 앱입니다.

로컬 작업을 계속 돌리고 싶을 때 Caps Lock을 켜세요. 평소 잠자기 동작으로 돌아가려면 Caps Lock을 끄면 됩니다.

AI 에이전트를 돌리거나 모바일로 접속하는 등, 오래 걸리거나 원격으로 진행하는 작업에 유용합니다.

Capsomnia 자체는 네트워크 요청을 보내지 않고, 텔레메트리를 수집하거나 계정을 요구하지도 않습니다.

<p align="center">
  <img src="resources/caps-lock-on.jpg" alt="켜진 Caps Lock 표시등" width="560">
</p>

<p align="center">
  <em>이 작은 불이 켜져 있는 동안 Mac은 잠들지 않습니다.</em>
</p>

## 빠르게 시작하기

필요한 환경:

- macOS 14 이상을 실행하는 Apple silicon Mac
- 설치할 때 사용할 관리자 권한

서명된 패키지 설치 방법:

1. [GitHub Releases](https://github.com/fuji-mak/Capsomnia/releases/latest)에서 `Capsomnia.pkg`를 다운로드합니다.
2. 패키지를 열고 설치 프로그램의 안내를 따릅니다.

릴리스 패키지는 Developer ID로 서명하고 Apple 공증을 받았습니다. 패키지는 `/Applications`에 `Capsomnia.app`을 설치하고 서명된 네이티브 잠자기 제어 helper와 허용 범위를 좁힌 sudoers 규칙을 추가합니다. 이어서 LaunchAgent를 시작합니다. 설치가 끝나면 Capsomnia가 열리고, 이후에는 로그인할 때 자동으로 시작됩니다.

패키지 빌드와 설치에 쓰는 스크립트도 [`scripts/build-pkg.sh`](scripts/build-pkg.sh)와 [`scripts/notarize-pkg.sh`](scripts/notarize-pkg.sh)에 공개되어 있습니다.

## 소스에서 빌드하기

개발자용 소스 설치도 지원하며 Swift 6 툴체인이 필요합니다.

```sh
git clone https://github.com/fuji-mak/Capsomnia.git
cd Capsomnia
./scripts/install.sh
```

소스 설치 프로그램은 `Capsomnia.app`을 로컬에서 빌드해 `~/Applications/`에 넣고, 같은 helper와 sudoers 규칙을 설치한 뒤 사용자 LaunchAgent를 시작합니다.

## 작동 방식

- Caps Lock 켜기: MacBook 덮개를 닫아도 AI 에이전트와 다른 작업이 중단되지 않게 합니다. Codex Mobile 같은 도구로 원격 조작도 계속할 수 있습니다. 현재 상태는 Caps Lock 표시등으로 바로 확인할 수 있습니다.
- Caps Lock 끄기: 평소 잠자기 동작으로 돌아갑니다.
- Caps Lock을 켠 채 덮개 닫기: 외부 디스플레이가 연결되어 있지 않을 때만 디스플레이를 끄고 작업은 계속 돌립니다.
- 앱 종료: 평소 잠자기 동작으로 돌아갑니다.

오래 걸리는 로컬 작업, AI 코딩 에이전트, SSH 세션, 빌드, 다운로드, 무인 스크립트를 실행할 때 유용합니다.

## 사용 시 주의 사항

- 통풍이 잘되는 곳에서 안정적인 전원을 연결해 사용하세요.
- 잠자기 방지 기능을 켠 채 덮개를 닫으면 발열과 배터리 소모가 늘어날 수 있습니다.
- 중요한 작업을 Capsomnia에만 맡기거나 백업 대신 사용하지 마세요.
- 사용이 끝나면 Caps Lock을 끄고 평소 잠자기 동작으로 돌아왔는지 확인하세요.
- Capsomnia 사용에 따른 책임은 사용자에게 있습니다. 모든 Mac과 macOS 버전, 모든 환경에서 호환된다고 보장하지 않습니다.

## 설정

Capsomnia를 처음 실행하면 Caps Lock 스위치의 작동 방식을 안내하고 다음 항목을 선택할 수 있습니다.

- 메뉴 막대에 점을 표시할지 여부
- 외부 디스플레이가 연결되어 있지 않을 때 덮개를 닫으면 디스플레이를 끌지 여부
- 로그인할 때 Capsomnia를 열지 여부
- 영어, 일본어, 중국어(간체) 또는 한국어

나중에 Capsomnia를 다시 열어 같은 설정을 바꿀 수 있습니다.

입력 모니터링 권한은 필요하지 않습니다. Capsomnia는 로컬 Caps Lock 상태만 250밀리초마다 확인합니다. 이전 버전에서 입력 모니터링을 허용했다면 시스템 설정에서 끌 수 있습니다.

패키지로 설치했다면 `/Applications/Capsomnia.app`, 소스에서 설치했다면 `~/Applications/Capsomnia.app`에서 Capsomnia를 열 수 있습니다. 메뉴 막대 항목을 표시해 두었다면 그곳에서도 열 수 있습니다.

## `caffeinate`와 무엇이 다른가요?

`caffeinate`는 MacBook 덮개가 열린 상태에서 유휴 잠자기를 막을 때 유용합니다. 하지만 덮개를 닫는 것은 다른 문제입니다. 일반적인 `caffeinate` assertion만으로는 덮개를 닫은 상태에서 로컬 작업이 계속 실행된다고 장담하기 어렵습니다.

Capsomnia는 덮개를 닫아도 열어 둔 상태와 마찬가지로 작업을 이어 갑니다. Caps Lock의 연두색 표시등이 현재 상태를 눈에 보이게 알려 줍니다.

## 업데이트

패키지로 설치했다면 [GitHub Releases](https://github.com/fuji-mak/Capsomnia/releases/latest)에서 최신 패키지를 다운로드해 실행하세요.

소스에서 설치했다면 기존 clone을 다음과 같이 업데이트합니다.

```sh
cd Capsomnia
git pull
./scripts/install.sh
```

설치 스크립트는 앱 번들, helper, sudoers 규칙, LaunchAgent를 현재 버전으로 덮어씁니다.

## 제거

패키지로 설치한 경우:

```sh
/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

소스에서 설치한 경우:

```sh
~/Applications/Capsomnia.app/Contents/Resources/uninstall.sh
```

소스 clone에서는 다음 명령을 실행해도 같습니다.

```sh
./scripts/uninstall.sh
```

제거 프로그램은 LaunchAgent를 내리고 Capsomnia를 멈춘 다음, `/Applications` 또는 `~/Applications`의 `Capsomnia.app`, helper, sudoers 규칙을 삭제하고 평소 잠자기 동작으로 되돌립니다. 관리자 인증이 필요할 수 있습니다.

## 보안 모델

Capsomnia의 메뉴 막대 앱은 root로 실행되지 않습니다. 시스템 잠자기 설정을 바꾸려면 관리자 권한이 필요하므로, Capsomnia는 작고 기능이 고정된 네이티브 helper를 비밀번호 없는 `sudo`로 호출합니다. 이 helper는 컴파일된 실행 파일이며 셸을 실행하거나 셸 시작 파일을 불러오지 않습니다.

패키지로 설치한 앱 파일, helper, 시스템 LaunchAgent의 소유자는 `root:wheel`입니다. 패키지의 helper도 앱과 같은 Developer ID로 서명합니다. Capsomnia는 설정을 바꿀 때마다 실제 `SleepDisabled` 상태를 확인하고 이후에도 10초마다 점검합니다. helper가 변경을 적용하지 못하거나, 상태를 확인할 수 없거나, 설정이 어긋나면 요청한 상태가 활성화된 것처럼 표시하지 않습니다. 대신 메뉴 막대의 점을 빨간색으로 바꾸고 5초 뒤 다시 시도합니다. 평소 메뉴 막대 아이콘을 숨겨 두었더라도 오류가 발생하면 빨간 점이 잠시 나타납니다.

Capsomnia는 입력 모니터링 권한을 요청하지 않으며 키보드 이벤트도 읽지 않습니다. macOS가 깨우기 작업을 한꺼번에 처리할 수 있도록 타이머 허용 오차를 두고, 로컬 Caps Lock 상태만 250밀리초마다 확인합니다.

설치 후 macOS에 "Taketo Fujimaki" 백그라운드 항목이 표시될 수 있습니다. 이 항목은 로그인할 때 Capsomnia를 시작하고 충돌 후 다시 실행하는 LaunchAgent입니다. 끄면 자동 시작과 충돌 복구가 중단될 수 있습니다.

충돌 복구가 꺼져 있거나 작동하지 않는 상태에서 Capsomnia를 강제로 종료하면 마지막 시스템 잠자기 설정이 남을 수 있습니다. 이때는 아래 수동 복구 명령으로 평소 잠자기 동작을 되돌리세요.

앱이 호출할 수 있는 명령은 다음 세 개뿐입니다.

```sh
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset on
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset off
sudo -n /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
```

sudoers 규칙은 정확히 이 세 명령으로 제한됩니다. helper는 `on`, `off`, `display-sleep`만 받아들이며 다음 명령만 호출합니다.

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset displaysleepnow
```

## 로그와 문제 해결

로그는 다음 경로에 기록됩니다.

```text
~/Library/Logs/Capsomnia/
```

잠자기 방지 상태 확인:

```sh
pmset -g | grep SleepDisabled
```

평소 잠자기 동작으로 수동 복구:

```sh
sudo pmset -a disablesleep 0
```

LaunchAgent 다시 시작:

```sh
launchctl bootout "gui/$(id -u)" /Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist
launchctl bootstrap "gui/$(id -u)" /Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist
```

소스에서 설치했다면 `$HOME/Library/LaunchAgents/com.github.fuji-mak.capsomnia.plist`를 대신 사용하세요.

Capsomnia의 LaunchAgent는 앱이 충돌하는 등 정상적으로 종료되지 않았을 때만 앱을 다시 시작합니다. Capsomnia는 시작할 때 현재 Caps Lock 상태를 읽고 그에 맞는 잠자기 설정을 다시 적용합니다. 메뉴에서 정상적으로 종료하면 앱이 다시 시작되지 않습니다.

helper 권한 확인:

```sh
sudo -n -l /Library/PrivilegedHelperTools/capsomnia-pmset on \
  /Library/PrivilegedHelperTools/capsomnia-pmset off \
  /Library/PrivilegedHelperTools/capsomnia-pmset display-sleep
```

helper 권한 확인에 실패하면 `./scripts/install.sh`를 다시 실행하세요. Capsomnia는 Caps Lock 상태를 250밀리초마다 확인하므로 실제 표시등을 바꾼 뒤 메뉴 막대의 점이 갱신되기까지 약 0.25초가 걸릴 수 있습니다.

## 프로젝트 상태

Capsomnia 1.0.0은 첫 번째 안정 공개 버전입니다. 릴리스 기록은 [CHANGELOG.md](CHANGELOG.md), 보안 취약점 신고 방법은 [SECURITY.md](SECURITY.md)에서 확인하세요.

## 라이선스

MIT
