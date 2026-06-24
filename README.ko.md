# openNeko

[English](README.md) · [日本語](README.ja.md) · [简体中文](README.zh.md)

openNeko는 AI Agent와 대화하는 오픈소스 데스크탑 픽셀 고양이입니다. 화면 하단에 상주하면서 타이핑과 에이전트 상태 신호에 반응하고, 선택한 Agent, 클라우드 모델, 로컬 모델로 짧은 말풍선 답변을 제공합니다.

## 기능

- **AI Agent 대화**: 고양이를 짧게 클릭해서 말풍선 입력창으로 대화합니다.
- **OAuth 우선 연결**: OpenAI/Codex, Claude, Gemini CLI 로그인부터 사용하고, 필요한 경우에만 API 키를 입력합니다.
- **로컬 모델**: Ollama와 로컬 OpenAI 호환 서버를 클라우드 API 키 없이 연결할 수 있습니다.
- **AI Agent 상태 브리지**: HTTP 상태 이벤트와 Cursor, Claude Code CLI, Codex CLI/App, Antigravity, Gemini, Kiro 같은 에이전트 프로세스 활동에 반응합니다.
- **타이핑 반응**: 키 내용은 읽지 않고, 키 입력 발생 사실만 사용합니다.
- **스킨/스프라이트**: 번들 스킨 5종, 외부 스킨 폴더, 스프라이트 추출 도구.
- **스킬**: 번들 및 사용자 `SKILL.md` 프롬프트를 메뉴/슬래시 명령으로 실행합니다.
- **이웃 고양이**: 같은 LAN의 다른 openNeko 인스턴스를 발견해 손님 고양이로 보여줍니다.

## 설치

macOS:

```bash
curl -fsSL https://github.com/kimtoma/openNeko/releases/latest/download/openneko-install.sh | bash
```

Windows PowerShell:

```powershell
irm https://github.com/kimtoma/openNeko/releases/latest/download/openneko-install.ps1 | iex
```

두 설치 스크립트 모두 `git`과 Node.js `22.12+`가 필요합니다. 로그인 자동시작을 건너뛰려면 실행 전에 `OPENNEKO_NO_AUTOSTART=1`을 설정하세요. 온보딩에서도 **컴퓨터 켤 때 자동 실행**을 켜거나 끌 수 있고, 나중에 설정에서 다시 바꿀 수 있습니다.

설치 스크립트는 GitHub Releases 자산으로 배포되어 다운로드 수로 설치 관심도를 볼 수 있습니다. GitHub CLI 권한이 있으면 아래 명령으로 확인하세요:

```bash
bash scripts/metrics.sh
```

앱 형태로 배포하려면 네이티브 설치 파일을 빌드하세요:

```bash
npm run dist      # macOS DMG
npm run dist:win  # Windows NSIS 설치 파일
```

## 소스에서 실행

```bash
git clone https://github.com/kimtoma/openNeko.git
cd openNeko
npm install
npm run build
npm start
```

API 키 없이 쓰려면 먼저 지원 CLI에 로그인하세요: `codex login`, `claude`, `gemini`. Ollama와 로컬 OpenAI 호환 엔드포인트는 설정에서 추가할 수 있습니다.

## AI Provider

- `chatgpt-oauth`: 로컬 Codex CLI의 OpenAI 로그인 사용. `codex login` 필요.
- `claude-oauth`: 로컬 Claude Code 로그인 사용.
- `gemini-oauth`: 로컬 Gemini CLI Google 로그인 사용.
- `ollama`: 로컬 Ollama 서버 사용.
- `local-openai`: LM Studio, llama.cpp, vLLM 같은 로컬 OpenAI 호환 서버.
- `gemini`: Google AI Studio Gemini API 키 사용.
- `claude`: Anthropic API 키 사용.
- `custom`: OpenAI 호환 엔드포인트 직접 입력. 서버가 요구할 때만 API 키를 넣으면 됩니다.

API 키는 가능한 경우 Electron `safeStorage`로 암호화 저장합니다.

## 상태 브리지

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

디버그 엔드포인트는 `/health`, `/anim`, `/capture`입니다. 두 번째 인스턴스는 `OPENNEKO_PORT=48801`로 실행하세요.

## 스킬

사용자 스킬 경로:

```text
~/.openneko/skills/<skill-id>/SKILL.md
```

스킬 본문은 현재 AI provider의 system 지침으로 주입됩니다. 스크립트는 실행하지 않습니다.

## 개발

```bash
npm test
npm run build
```

Electron은 번들된 렌더러 파일을 로드하므로 `src/renderer/cat2d.js` 또는 `src/settings/settings.js` 수정 후에는 `npm run build`를 실행해야 합니다.

## 라이선스

MIT
