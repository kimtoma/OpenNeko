const os = require('node:os');
const path = require('node:path');

// GUI로 띄운 앱은 로그인 셸 PATH를 다 못 물려받을 수 있다(특히 macOS .app).
// npm/git처럼 installer와 updater가 쓰는 실행 파일을 찾기 쉽게 알려진 bin 경로를 보강한다.
// 로그인 셸을 spawn하지 않는다; 정적 목록이라 동기·무해.
function extraDirs(homedir, platform) {
  if (platform === 'win32') {
    const appdata = process.env.APPDATA || path.join(homedir, 'AppData', 'Roaming');
    const localapp = process.env.LOCALAPPDATA || path.join(homedir, 'AppData', 'Local');
    return [
      path.join(appdata, 'npm'),                        // npm 전역 (.cmd 샤임 위치)
      path.join(localapp, 'Microsoft', 'WindowsApps'),  // winget / Store 앱
      path.join(homedir, '.local', 'bin'),
    ];
  }
  return [
    '/opt/homebrew/bin', '/opt/homebrew/sbin',
    '/usr/local/bin',
    path.join(homedir, '.local', 'bin'), path.join(homedir, 'bin'),
  ];
}

// 플랫폼별 구분자(`;`=win, `:`=그 외). 테스트 위해 platform 주입 가능.
function augmentPath(currentPath, homedir = os.homedir(), platform = process.platform) {
  const sep = platform === 'win32' ? ';' : ':';
  const extra = extraDirs(homedir, platform);
  const cur = (currentPath || '').split(sep).filter(Boolean);
  const seen = new Set(cur);
  const prepend = extra.filter((d) => !seen.has(d));
  return [...prepend, ...cur].join(sep);
}

// spawn 옵션에 바로 펼쳐 쓸 env. 기존 env 보존 + PATH만 보강.
function spawnEnv(baseEnv = process.env, platform = process.platform) {
  return { ...baseEnv, PATH: augmentPath(baseEnv.PATH, os.homedir(), platform) };
}

module.exports = { augmentPath, spawnEnv };
