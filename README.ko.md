# OpenNeko

[English](README.md) | 한국어 | [日本語](README.ja.md) | [简体中文](README.zh.md)

OpenNeko는 AI 에이전트를 위한 네이티브 macOS 데스크탑 픽셀 고양이입니다. 데스크탑 위를 걸어다니고, 키 내용을 읽지 않은 채 타이핑에 반응하며, 로컬 에이전트 상태를 감지하고, 짧은 답변이 필요할 때 작은 대화 말풍선을 엽니다.

현재 앱은 이전 Electron 프로토타입을 Swift와 SwiftUI 기반 macOS 앱으로 포팅한 버전입니다.

## 주요 기능

- 투명한 항상 위 데스크탑 고양이
- 번들 스킨, 외부 스킨 폴더, 커스텀 스킨 가져오기
- 키 내용을 읽지 않는 타이핑 반응
- Cursor, Codex, Gemini, Claude, Antigravity, Kiro 같은 로컬 AI 에이전트 활동 감지
- 작은 대화 말풍선, 슬래시 명령, 스킬 프롬프트
- 대화 기록 창과 답변 클릭 복사
- 같은 로컬 네트워크의 이웃 고양이 방문
- 자동화를 위한 로컬 HTTP 상태 브리지
- 로그인 시 자동 실행, 언어, 소리, 스킨, AI, 프로필, 이웃 설정
- ZIP 및 DMG 릴리스 패키징 스크립트

## 요구 사항

- macOS 14 이상
- Xcode
- XcodeGen
- 선택 사항: 기본 OpenAI 로그인 provider용 Codex CLI 로그인
- 선택 사항: Claude 또는 Gemini 로그인 provider용 CLI 로그인
- 선택 사항: Gemini, Claude, OpenAI 호환 엔드포인트용 API 키

## 소스에서 실행

```bash
xcodegen generate
swift test
./script/build_and_run.sh
```

Xcode로 직접 빌드:

```bash
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration Debug build
```

Codex 데스크탑 Run 액션은 `./script/build_and_run.sh`에 연결되어 있습니다.

## 첫 실행

`OpenNeko.app`을 열면 첫 실행 온보딩이 표시됩니다. 주요 기능, 스킨 선택, 고양이 이름, 권한, 로그인 시 자동 실행, AI 연결, 완료 안내 순서로 진행됩니다.

타이핑 반응에는 입력 모니터링 권한이 필요합니다. OpenNeko는 keydown 활동만 감지하며 사용자가 입력한 텍스트를 읽지 않습니다.

## AI Provider

OpenNeko는 다음 provider preset을 지원합니다.

- OpenAI 로그인 (Codex): 로컬 Codex CLI 로그인 세션을 사용합니다.
- Claude 로그인: 로컬 Claude CLI 로그인 세션을 사용합니다.
- Gemini 로그인: Gemini CLI의 Google 로그인 세션을 사용합니다.
- Ollama: 로컬 Ollama OpenAI 호환 서버에 연결합니다.
- 로컬 OpenAI 호환: LM Studio, llama.cpp, vLLM 등에 연결합니다.
- Gemini API 키: `GEMINI_API_KEY` 또는 `GOOGLE_API_KEY`를 사용합니다.
- Claude API 키: `ANTHROPIC_API_KEY`를 사용합니다.
- 사용자 지정: OpenAI 호환 Base URL, API 키, 모델을 직접 입력합니다.

저장된 API 키는 `settings.json`이 아니라 macOS Keychain에 저장됩니다.

## 스킬

번들 및 사용자 스킬은 `SKILL.md`로 저장되는 프롬프트 지시문입니다. 스킬 안의 스크립트는 실행되지 않습니다.

- 번들 스킬: `App/Resources/skills/builtin/`
- 사용자 스킬: `~/.openneko/skills/<id>/SKILL.md`

설정 창, 메뉴바 스킬 메뉴, 대화 입력창의 슬래시 명령 목록에서 스킬을 실행할 수 있습니다.

## 커스텀 스킨

스킨 설정 화면은 두 가지 커스텀 스킨 경로를 제공합니다.

- 고양이 사진으로 요청 파일 만들기: 사진, 메타데이터, 현재 manifest, 생성 프롬프트가 담긴 `.openneko-skin-request` 패키지를 저장합니다.
- 완성된 `.openneko-skin`, `.zip`, 또는 스킨 폴더 가져오기

완성 스킨에는 `manifest.json`, `openneko-skin.json`, manifest 파일명과 일치하는 투명 PNG 프레임이 들어갑니다. 가져온 스킨은 아래 위치에 설치됩니다.

```text
~/Library/Application Support/openNeko/skins/<id>/
```

## 상태 브리지

OpenNeko는 기본적으로 `127.0.0.1:48800`에서 대기합니다.

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

디버그 엔드포인트:

- `GET /health`
- `GET /anim`
- `GET /pos`
- `GET /debug/position`
- `GET /capture`
- `GET /debug/settings`
- `POST /debug/settings/apply`
- `GET /debug/agent`
- `POST /debug/drag`
- `POST /debug/typing`

다른 로컬 포트 사용:

```bash
OPENNEKO_PORT=48801 /path/to/OpenNeko.app/Contents/MacOS/OpenNeko
```

## 패키징

릴리스 전 로컬 체크:

```bash
scripts/release-preflight.sh local
scripts/release-preflight.sh distribution
scripts/release-preflight.sh notarized
```

ZIP 및 DMG 패키지 생성:

```bash
scripts/package-macos.sh
```

생성물 위치:

- `dist/OpenNeko-macOS-Release.zip`
- `dist/OpenNeko-macOS-Release.dmg`

패키지 검증:

```bash
scripts/verify-macos-package.sh
```

`distribution`과 `notarized` 체크에는 서명 머신의 Developer ID Application 인증서와 Apple 공증 자격 증명이 필요합니다.

## Electron에서 마이그레이션

네이티브 앱은 이전 Electron `settings.json`을 아래 위치에서 읽습니다.

```text
~/Library/Application Support/openNeko/
```

선택한 스킨, AI provider preset/base URL/model, 온보딩 상태, 로그인 시 자동 실행, 언어, 소리, 웹 검색, 사용자 프로필, 이웃 설정, peer ID를 유지합니다.

Electron `safeStorage` API 키 암호문은 가져오지 않습니다. AI 설정 화면에서 API 키를 다시 저장하면 macOS Keychain에 저장됩니다.

## 라이선스

OpenNeko는 MIT License로 배포됩니다.
