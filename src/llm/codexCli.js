const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
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

function buildCodexPrompt({ history, system, lang = 'en' }) {
  const sys = (system !== undefined && system !== null) ? system : persona(lang);
  return [
    'You are being invoked by openNeko as a conversational assistant.',
    'Do not run shell commands, inspect files, modify files, or mention Codex internals unless the user explicitly asks.',
    'Return only the final answer that should be shown in the openNeko chat bubble.',
    '',
    '<system>',
    sys,
    '</system>',
    '',
    formatPrompt(history),
  ].join('\n');
}

function codexExecArgs({ model, cwd, outFile, prompt }) {
  const args = [
    'exec',
    '--ignore-user-config',
    '--skip-git-repo-check',
    '--ephemeral',
    '--ignore-rules',
    '--sandbox',
    'read-only',
    '-C',
    cwd,
    '--output-last-message',
    outFile,
  ];
  if (model) args.push('--model', model);
  args.push(prompt);
  return args;
}

function classifyCodexFailure(code, output) {
  const msg = redactSecrets(output || '');
  if (/not logged in|login|auth|unauthorized|forbidden|ChatGPT/i.test(msg)) {
    return Object.assign(new Error(msg || 'Codex OAuth login required'), { code: 'AUTH' });
  }
  return Object.assign(new Error(`Codex CLI exited with ${code}${msg ? ': ' + msg.slice(0, 600) : ''}`), { code: 'CLI' });
}

class CodexCliProvider {
  constructor({ bin = 'codex', model = '', lang = 'en', cwd, timeoutMs = TIMEOUT_MS, spawnImpl = spawn, tmpDir = os.tmpdir() } = {}) {
    this.name = 'codex-cli';
    this.bin = bin || 'codex';
    this.model = model || '';
    this.lang = lang || 'en';
    this.cwd = cwd || os.homedir();
    this.timeoutMs = timeoutMs;
    this._spawn = spawnImpl;
    this._tmpDir = tmpDir;
  }

  async chat({ history, signal, system }) {
    if (signal && signal.aborted) throw abortError();
    const prompt = buildCodexPrompt({ history, system, lang: this.lang });
    const dir = fs.mkdtempSync(path.join(this._tmpDir, 'openneko-codex-'));
    const outFile = path.join(dir, 'last-message.txt');
    const args = codexExecArgs({ model: this.model, cwd: this.cwd, outFile, prompt });
    let child;
    let stdout = '';
    let stderr = '';
    let settled = false;

    return await new Promise((resolve, reject) => {
      const cleanup = () => {
        clearTimeout(timer);
        if (signal) signal.removeEventListener('abort', onAbort);
        fs.rmSync(dir, { recursive: true, force: true });
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
      }, this.timeoutMs);

      if (signal) signal.addEventListener('abort', onAbort, { once: true });
      try {
        child = this._spawn(this.bin, args, {
          cwd: this.cwd,
          env: { ...spawnEnv(process.env), NO_COLOR: '1', TERM: process.env.TERM || 'xterm-256color' },
          stdio: ['ignore', 'pipe', 'pipe'],
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
          settle(reject, classifyCodexFailure(code, stderr || stdout));
          return;
        }
        let text = '';
        try { text = fs.readFileSync(outFile, 'utf8').trim(); } catch { text = ''; }
        if (!text) {
          settle(reject, Object.assign(new Error('빈 응답'), { code: 'CLI' }));
          return;
        }
        settle(resolve, { text });
      });
    });
  }
}

module.exports = { CodexCliProvider, buildCodexPrompt, codexExecArgs, classifyCodexFailure };
