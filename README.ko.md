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
- 건강 알림: 50분 넘게 계속 타이핑하면 스트레칭·눈 휴식·물 마시기를 권함 (하루 최대 6번, 일반 설정에서 끄기)
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
  유료 구독이 없다면 **설정 → AI → 로컬 모델 설치**에서 Mac의 메모리와 여유 공간을 확인하고, Ollama 설치를 안내한 뒤 맞는 모델을 받아 바로 연결합니다 (Apple Silicon 전용).
- 로컬 OpenAI 호환: LM Studio, llama.cpp, vLLM 등에 연결합니다.
- Apple 온디바이스 모델: macOS 26 이상, Apple Intelligence가 켜진 Mac에서 내장 모델로 대답합니다 (다운로드·키 불필요). 앱은 여전히 macOS 14에서 동작하고, 이 프리셋만 사용 불가로 표시됩니다.
- Gemini API 키: `GEMINI_API_KEY` 또는 `GOOGLE_API_KEY`를 사용합니다.
- Claude API 키: `ANTHROPIC_API_KEY`를 사용합니다.
- 사용자 지정: OpenAI 호환 Base URL, API 키, 모델을 직접 입력합니다.

저장된 API 키는 `settings.json`이 아니라 macOS Keychain에 저장됩니다.

## 고양이 도구

"3분 타이머 맞춰줘"처럼 타이머, 리마인더, 텍스트 복사, 웹페이지 열기를 부탁할 수 있어요. 모델이 동작을 제안하면 고양이가 먼저 물어보고, 말풍선을 눌러야 실행돼요. 타이머와 리마인더는 OpenNeko가 켜져 있는 동안 동작합니다. AI 설정의 **고양이 도구**에서 끌 수 있어요.

## 선택한 텍스트

아무 앱에서나 텍스트를 선택하고 **서비스 → openNeko: 설명하기 / 번역하기 / 요약하기**를 고르면(오른쪽 클릭 → 서비스도 가능) 고양이가 현재 AI 연결로 말풍선에 답해요. 보낸 텍스트만 사용합니다. 설치 직후 메뉴가 안 보이면 한 번 로그아웃했다 들어오세요.

## 음성 입력

채팅창의 🎤 버튼을 한 번 누르고 말하면 돼요. 2초쯤 말을 멈추거나 버튼을 다시 누르면 끝나고, Esc를 누르면 취소하고 원래 쓰던 글로 돌아가요. 음성은 이 맥 안에서만 인식하고(macOS 기기 내 음성 인식), 채팅창에 글자로 들어가서 보내기 전에 고칠 수 있어요. 이 맥이 해당 언어를 기기 안에서 인식할 수 없으면 서버로 보내지 않고 음성 입력이 꺼진 채로 있어요. 처음 쓸 때 마이크와 음성 인식 권한을 물어봐요.

## 먼저 말 걸기

고양이가 먼저 하는 말(쉬자는 알림, 점심·퇴근 인사, 기억 제안, 이웃 고양이, 루틴, 새 기능 소개)은 모두 한 곳의 규칙을 거쳐요. 메뉴의 **수다 정도**에서 조용히(하루 3번), 보통(8번), 수다쟁이(15번)를 고를 수 있어요. 에이전트 알림과 루틴은 횟수에 들어가지 않아요. 회의 앱(Zoom, Teams, FaceTime, Webex)이 앞에 있거나 Keynote, PowerPoint, 동영상 앱이 화면을 꽉 채우고 있으면 제안은 건너뛰고 루틴은 기다려요. 제안 직후에 "그만"이라고 답하면 그런 종류의 말은 꺼지고, 수다 정도 메뉴에서 다시 켤 수 있어요.

## 기억

고양이는 `~/.openneko/memory/`에 평범한 마크다운 파일 세 개를 둬요.

- `soul.md`: 고양이의 성격과 말투. 나만 고칠 수 있고, 비워두면 기본 성격을 써요.
- `user.md`: 나에 대한 오래 가는 사실. 고양이가 말풍선으로 "기억해도 될까?" 하고 묻고, 눌러야 한 줄 추가돼요.
- `memory.md`: 요즘 맥락. 고양이가 알아서 적어요(말풍선을 누르면 취소). 4KB쯤 넘으면 오래된 줄은 `archive/YYYY-MM.md`로 옮겨지고, 지워지는 건 없어요.

지난 대화 얘기를 꺼내면 로컬 대화 기록을 검색해서 관련된 대화를 최대 3개까지 프롬프트에 붙여요. 메뉴의 **기억 노트**(또는 설정 > 내 프로필)에서 파일을 보고 고칠 수 있어요. 로컬 모델은 항상 기억을 쓰고, 클라우드 AI에는 보낼 범위(전부, 성격만, 보내지 않기)를 고를 수 있어요. 비밀번호, 키, 카드번호처럼 보이는 내용은 저장하지 않아요.

## 작업 맡기기

채팅 말풍선에 `/task 할 일`을 입력하고 프로젝트 폴더를 고르면, 고양이가 로컬 Claude Code CLI에 그 폴더 안에서만 작업을 맡깁니다. 폴더 안 파일 읽기·수정은 허용되고, 그 밖의 동작(셸 명령, 네트워크)은 승인 요청으로 돌아와요. 말풍선을 눌러 이번 작업에 한해 허락하거나 거절할 수 있습니다. 홈·루트·시스템 폴더는 거부합니다. 모든 단계는 `~/Library/Application Support/openNeko/agent-activity.jsonl`에 기록되고 `/tasklog`로 열 수 있어요. `/task stop`으로 취소합니다.

## 루틴

설정 → AI → 루틴에서 평일 아침 브리핑이나 하루 마무리처럼 정한 시간에 고양이가 할 일을 맡길 수 있어요(OpenNeko가 켜져 있을 때 동작). 폴더가 없는 루틴은 현재 AI 연결로 말풍선에 답하고, 폴더를 고른 루틴은 그 폴더에서 Claude Code를 읽기 전용으로 실행해요(예: 어제 커밋 요약). 그 밖의 동작은 먼저 물어봐요. 루틴은 하루에 한 번만 돌고, 맥이 잠든 사이 놓친 루틴은 2시간 안에 깨어나면 실행돼요.

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

### 에이전트 알림

Claude Code나 Codex가 작업을 끝내거나 승인이 필요할 때 고양이가 알려줍니다.
설정 > 일반 > 에이전트 알림에서 스니펫을 복사하세요.

- Claude Code (`~/.claude/settings.json`): `Notification` 훅이 `waiting`을,
  `Stop` 훅이 `done`을 보냅니다.
- Codex (`~/.codex/config.toml` 맨 위): `notify` 명령이 `done`을 보냅니다.

브리지는 `waiting`, `needs_input`, `attention`(고양이가 확인을 요청하고 10분간
유지)과 `done`, `finished`, `complete`(`success`로 표시)도 받습니다. OpenNeko는
이 파일들을 직접 수정하지 않습니다.

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
