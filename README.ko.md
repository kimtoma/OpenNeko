# openNeko

[English](README.md) · [日本語](README.ja.md) · [简体中文](README.zh.md)

openNeko는 GPT와 대화하는 오픈소스 데스크탑 픽셀 고양이입니다. 화면 하단에 상주하면서 타이핑과 에이전트 상태 신호에 반응하고, 짧은 말풍선 답변을 제공합니다.

## 기능

- **GPT 대화**: 고양이를 짧게 클릭해서 말풍선 입력창으로 대화합니다.
- **OpenAI 호환 provider**: 기본 OpenAI GPT, 로컬 Ollama, 직접 입력한 `/v1/chat/completions` 엔드포인트.
- **상태 브리지**: HTTP로 `thinking`, `coding`, `success`, `error` 같은 상태를 보낼 수 있습니다.
- **타이핑 반응**: 키 내용은 읽지 않고, 키 입력 발생 사실만 사용합니다.
- **스킨/스프라이트**: 번들 스킨 5종, 외부 스킨 폴더, 스프라이트 추출 도구.
- **스킬**: 번들 및 사용자 `SKILL.md` 프롬프트를 메뉴/슬래시 명령으로 실행합니다.
- **이웃 고양이**: 같은 LAN의 다른 openNeko 인스턴스를 발견해 손님 고양이로 보여줍니다.

## 설치

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.ps1 | iex
```

두 설치 스크립트 모두 `git`과 Node.js `22.12+`가 필요합니다. 로그인 자동시작을 건너뛰려면 실행 전에 `OPENNEKO_NO_AUTOSTART=1`을 설정하세요.

## 소스에서 실행

```bash
git clone https://github.com/kimtoma/openNeko.git
cd openNeko
npm install
npm run build
npm start
```

실행 전에 `OPENAI_API_KEY`를 설정하거나, 앱 설정에서 API 키를 저장하세요.

## GPT Provider

- `openai`: `https://api.openai.com/v1`, 기본 모델 `gpt-4o-mini`, `OPENAI_API_KEY` 폴백.
- `ollama`: `http://localhost:11434/v1`, 기본 모델 `llama3.2`.
- `custom`: OpenAI 호환 엔드포인트 직접 입력.

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

스킬 본문은 현재 GPT provider의 system 지침으로 주입됩니다. 스크립트는 실행하지 않습니다.

## 개발

```bash
npm test
npm run build
```

Electron은 번들된 렌더러 파일을 로드하므로 `src/renderer/cat2d.js` 또는 `src/settings/settings.js` 수정 후에는 `npm run build`를 실행해야 합니다.

## 라이선스

MIT
