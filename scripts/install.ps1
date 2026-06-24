# openNeko Windows installer (source checkout + bundled Electron).
#
# One-liner:
#   irm https://github.com/kimtoma/openNeko/releases/latest/download/openneko-install.ps1 | iex
#
# Options:
#   $env:OPENNEKO_REF              default: main
#   $env:OPENNEKO_DIR              default: %LOCALAPPDATA%\openNeko
#   $env:OPENNEKO_NO_AUTOSTART=1   skip Startup shortcut

$ErrorActionPreference = 'Stop'

$Repo = 'https://github.com/kimtoma/openNeko.git'
$Ref  = if ($env:OPENNEKO_REF) { $env:OPENNEKO_REF } else { 'main' }
$Dir  = if ($env:OPENNEKO_DIR) { $env:OPENNEKO_DIR } else { Join-Path $env:LOCALAPPDATA 'openNeko' }

function Say($m) { Write-Host "> $m" -ForegroundColor Cyan }
function Err($m) { Write-Host "! $m" -ForegroundColor Red }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Err "git is required. Install it from https://git-scm.com and rerun."; exit 1
}
if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Err "Node.js and npm are required. Install Node 22.12+ and rerun."; exit 1
}
node -e "const [maj,min]=process.versions.node.split('.').map(Number); process.exit(maj > 22 || (maj === 22 && min >= 12) ? 0 : 1)"
if ($LASTEXITCODE -ne 0) { Err "Node 22.12+ is required (current: $(node -v))."; exit 1 }

if (Test-Path (Join-Path $Dir '.git')) {
  Say "Updating existing install: $Dir"
  git -C $Dir fetch --depth 1 origin $Ref
  git -C $Dir checkout -f $Ref
  git -C $Dir reset --hard "origin/$Ref"
} else {
  Say "Cloning: $Repo ($Ref) -> $Dir"
  New-Item -ItemType Directory -Force -Path (Split-Path $Dir) | Out-Null
  git clone --depth 1 --branch $Ref $Repo $Dir
  if ($LASTEXITCODE -ne 0) { Err "Clone failed. Check repository access and branch name."; exit 1 }
}

Say "Installing dependencies"
Push-Location $Dir
npm install --no-fund --no-audit
Say "Building renderer bundles"
npm run build
Pop-Location

$ElectronBin = Join-Path $Dir 'node_modules\electron\dist\electron.exe'
if (-not (Test-Path $ElectronBin)) { Err "Electron binary not found: $ElectronBin"; exit 1 }

$Startup = [Environment]::GetFolderPath('Startup')
$Lnk = Join-Path $Startup 'openNeko.lnk'
if ($env:OPENNEKO_NO_AUTOSTART -ne '1') {
  Say "Registering login autostart: $Lnk"
  $ws = New-Object -ComObject WScript.Shell
  $sc = $ws.CreateShortcut($Lnk)
  $sc.TargetPath = $ElectronBin
  $sc.Arguments = "`"$Dir`""
  $sc.WorkingDirectory = $Dir
  $sc.WindowStyle = 7
  $sc.Save()
}

Say "Launching openNeko"
Start-Process -FilePath $ElectronBin -ArgumentList "`"$Dir`"" -WorkingDirectory $Dir

@"

openNeko installed.

Recommended setup:
  - Set OPENAI_API_KEY in your environment or add it in openNeko Settings.
  - Typing reactions on Windows do not require extra OS permissions, though
    security software may ask about global keyboard monitoring.

Manage:
  - Quit: tray icon -> quit
  - Disable autostart: Remove-Item "$Lnk"
  - Remove app: disable autostart, then Remove-Item -Recurse -Force "$Dir"

Install path: $Dir
"@ | Write-Host
