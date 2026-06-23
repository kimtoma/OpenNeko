const os = require('node:os');
const { spawn } = require('node:child_process');
const { formatPrompt, persona, redactSecrets } = require('./format');
const { spawnEnv } = require('./pathEnv');

const TIMEOUT_MS = 120000;
const OUTPUT_LIMIT = 12000;

function appendLimited(cur, chunk) {
  const next = cur + String(chunk || '');
  return next.length > OUTPUT_LIMIT ? next.slice(next.length - OUTPUT_LIMIT) : next;
}

function abortError() {
  return Object.assign(new Error('aborted'), { name: 'AbortError' });
}

function companionRules(service) {
  return [
    `You are being invoked by openNeko through ${service}.`,
    'Answer as a small desktop AI companion in the current openNeko persona.',
    'Do not run shell commands, inspect files, modify files, or mention CLI internals unless the user explicitly asks.',
    'Return only the final answer that should be shown in the openNeko chat bubble.',
  ].join('\n');
}

function buildInlinePrompt({ service, history, system, lang = 'en' }) {
  const sys = (system !== undefined && system !== null) ? system : persona(lang);
  return [
    companionRules(service),
    '',
    '<system>',
    sys,
    '</system>',
    '',
    formatPrompt(history),
  ].join('\n');
}

function buildClaudeSystem({ system, lang = 'en' }) {
  const sys = (system !== undefined && system !== null) ? system : persona(lang);
  return [sys, '', companionRules('Claude Code CLI')].join('\n');
}

function claudePrintArgs({ model, prompt, system }) {
  const args = [
    '--safe-mode',
    '--no-session-persistence',
    '--output-format',
    'text',
    '--permission-mode',
    'dontAsk',
    '--tools',
    '',
    '--system-prompt',
    system,
    '-p',
    prompt,
  ];
  if (model) args.unshift('--model', model);
  return args;
}

function geminiPromptArgs({ model, prompt }) {
  const args = [
    '--prompt',
    prompt,
    '--output-format',
    'text',
    '--approval-mode',
    'plan',
    '--skip-trust',
  ];
  if (model) args.unshift('--model', model);
  return args;
}

function classifyCliFailure(service, code, output) {
  const msg = redactSecrets(output || '');
  if (/not logged in|login|auth|unauthorized|forbidden|api key|oauth|credentials/i.test(msg)) {
    return Object.assign(new Error(msg || `${service} login required`), { code: 'AUTH' });
  }
  return Object.assign(new Error(`${service} exited with ${code}${msg ? ': ' + msg.slice(0, 600) : ''}`), { code: 'CLI' });
}

function runTextCli({ service, bin, args, cwd, timeoutMs = TIMEOUT_MS, spawnImpl = spawn, signal }) {
  if (signal && signal.aborted) throw abortError();
  let child;
  let stdout = '';
  let stderr = '';
  let settled = false;

  return new Promise((resolve, reject) => {
    const cleanup = () => {
      clearTimeout(timer);
      if (signal) signal.removeEventListener('abort', onAbort);
    };
    const settle = (fn, value) => {
      if (settled) return;
      settled = true;
      cleanup();
      fn(value);
    };
    const onAbort = () => {
      if (child && !child.killed) child.kill('SIGTERM');
      settle(reject, abortError());
    };
    const timer = setTimeout(() => {
      if (child && !child.killed) child.kill('SIGTERM');
      settle(reject, Object.assign(new Error('응답 시간 초과'), { code: 'ETIMEDOUT' }));
    }, timeoutMs);

    if (signal) signal.addEventListener('abort', onAbort, { once: true });
    try {
      child = spawnImpl(bin, args, {
        cwd,
        env: { ...spawnEnv(process.env), NO_COLOR: '1', TERM: process.env.TERM || 'xterm-256color' },
        stdio: ['ignore', 'pipe', 'pipe'],
        shell: process.platform === 'win32',
      });
    } catch (e) {
      settle(reject, e);
      return;
    }
    if (child.stdout) child.stdout.on('data', (b) => { stdout = appendLimited(stdout, b); });
    if (child.stderr) child.stderr.on('data', (b) => { stderr = appendLimited(stderr, b); });
    child.on('error', (e) => settle(reject, e));
    child.on('close', (code) => {
      if (settled) return;
      if (code !== 0) {
        settle(reject, classifyCliFailure(service, code, stderr || stdout));
        return;
      }
      const text = stdout.trim();
      if (!text) {
        settle(reject, Object.assign(new Error('빈 응답'), { code: 'CLI' }));
        return;
      }
      settle(resolve, { text });
    });
  });
}

class ClaudeCliProvider {
  constructor({ bin = 'claude', model = '', lang = 'en', cwd, timeoutMs = TIMEOUT_MS, spawnImpl = spawn } = {}) {
    this.name = 'claude-cli';
    this.bin = bin || 'claude';
    this.model = model || '';
    this.lang = lang || 'en';
    this.cwd = cwd || os.homedir();
    this.timeoutMs = timeoutMs;
    this._spawn = spawnImpl;
  }

  async chat({ history, signal, system }) {
    const prompt = formatPrompt(history);
    const sys = buildClaudeSystem({ system, lang: this.lang });
    const args = claudePrintArgs({ model: this.model, prompt, system: sys });
    return runTextCli({
      service: 'Claude Code CLI',
      bin: this.bin,
      args,
      cwd: this.cwd,
      timeoutMs: this.timeoutMs,
      spawnImpl: this._spawn,
      signal,
    });
  }
}

class GeminiCliProvider {
  constructor({ bin = 'gemini', model = '', lang = 'en', cwd, timeoutMs = TIMEOUT_MS, spawnImpl = spawn } = {}) {
    this.name = 'gemini-cli';
    this.bin = bin || 'gemini';
    this.model = model || '';
    this.lang = lang || 'en';
    this.cwd = cwd || os.homedir();
    this.timeoutMs = timeoutMs;
    this._spawn = spawnImpl;
  }

  async chat({ history, signal, system }) {
    const prompt = buildInlinePrompt({ service: 'Gemini CLI', history, system, lang: this.lang });
    const args = geminiPromptArgs({ model: this.model, prompt });
    return runTextCli({
      service: 'Gemini CLI',
      bin: this.bin,
      args,
      cwd: this.cwd,
      timeoutMs: this.timeoutMs,
      spawnImpl: this._spawn,
      signal,
    });
  }
}

module.exports = {
  ClaudeCliProvider,
  GeminiCliProvider,
  buildInlinePrompt,
  buildClaudeSystem,
  claudePrintArgs,
  geminiPromptArgs,
  classifyCliFailure,
};
