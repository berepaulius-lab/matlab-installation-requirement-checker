#!/usr/bin/env node
/**
 * Windows requirement checker (Node/EXE)
 * - Creates a log immediately (local logs folder) and mirrors output to console
 * - Runs basic checks: OS, Java, .NET, compilers, disk, memory, internet
 * - Offers one-key auto-fix installs for missing Java/.NET/compilers using built-in curl/msiexec/winget
 * - Can be packaged into a standalone exe via `npm run build:exe`
 */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const os = require('os');
const readline = require('readline');

const SCRIPT_DIR = __dirname;
const LOG_DIR = path.join(SCRIPT_DIR, 'logs');
let AUTO_YES = false;

function parseArgs() {
  const args = process.argv.slice(2);
  const out = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--log-path' && args[i + 1]) {
      out.logPath = args[i + 1];
      i++;
    } else if (args[i] === '--auto' || args[i] === '--yes' || args[i] === '-y') {
      out.autoYes = true;
    }
  }
  return out;
}

function ensureLogFile(logPathArg) {
  if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
  let logPath = logPathArg;
  if (!logPath) {
    const existing = fs
      .readdirSync(LOG_DIR)
      .filter((f) => /^log-\d{3}\.txt$/i.test(f))
      .sort();
    const next = existing.length
      ? String(parseInt(existing[existing.length - 1].match(/\d+/)[0], 10) + 1).padStart(3, '0')
      : '001';
    logPath = path.join(LOG_DIR, `log-${next}.txt`);
  }

  const existed = fs.existsSync(logPath) && fs.statSync(logPath).size > 0;
  if (!fs.existsSync(logPath)) {
    fs.writeFileSync(logPath, '', 'utf8');
  }

  const header = existed
    ? `[INFO] Continuing log: ${logPath}`
    : `[INFO] Starting log in: ${logPath}\n(Everything printed to the screen will also be copied here.)`;
  fs.appendFileSync(logPath, header + os.EOL);
  console.log(header);
  return logPath;
}

let LOG_FILE = null;
function log(line) {
  const text = typeof line === 'string' ? line : JSON.stringify(line);
  if (LOG_FILE) {
    fs.appendFileSync(LOG_FILE, text + os.EOL, 'utf8');
  }
  console.log(text);
}

function run(cmd, args, options = {}) {
  const result = spawnSync(cmd, args, { encoding: 'utf8', shell: false, ...options });
  return {
    ok: result.status === 0,
    stdout: (result.stdout || '').trim(),
    stderr: (result.stderr || '').trim(),
    status: result.status,
    error: result.error,
  };
}

function promptYesNo(question, defaultYes = true) {
  if (AUTO_YES) {
    log(`[INFO] Auto mode: defaulting to "yes" for: ${question}`);
    return Promise.resolve(true);
  }
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const suffix = defaultYes ? ' [Y/n] ' : ' [y/N] ';
    rl.question(question + suffix, (answer) => {
      rl.close();
      const trimmed = (answer || '').trim().toLowerCase();
      if (!trimmed) return resolve(defaultYes);
      resolve(trimmed === 'y' || trimmed === 'yes');
    });
  });
}

function downloadFile(url, dest) {
  const res = run('curl', ['-L', url, '-o', dest]);
  return res.ok;
}

function installMsi(msiPath) {
  return run('msiexec', ['/i', msiPath, '/qn', '/norestart']);
}

function installExe(exePath, args = ['/quiet', '/norestart']) {
  return run(exePath, args, { shell: true });
}

function pauseForExit(message = 'Press Enter to close this window...') {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(message, () => {
      rl.close();
      resolve();
    });
  });
}

function checkOS() {
  let label = 'OS';
  let detail = os.version ? os.version() : '';
  let extra = '';
  try {
    const res = run('wmic', ['os', 'get', 'Caption,Version,OSArchitecture', '/value']);
    if (res.ok && res.stdout) {
      const parts = res.stdout
        .split(/\r?\n/)
        .filter(Boolean)
        .map((l) => l.split('='))
        .reduce((acc, [k, v]) => ({ ...acc, [k.trim()]: v.trim() }), {});
      detail = `${parts.Caption || 'Windows'} ${parts.Version || ''} ${parts.OSArchitecture || ''}`.trim();
    }
  } catch (e) {
    // ignore
  }
  if (!detail) {
    const res = run('ver', []);
    detail = res.stdout || 'Unknown Windows version';
  }
  const arch = os.arch();
  extra = `Architecture: ${arch}`;
  return { label, status: 'ok', detail: `${detail} (${extra})` };
}

function parseJavaVersion(text) {
  const match = text.match(/version\s+"([^"]+)"/i);
  return match ? match[1] : text.split(/\r?\n/)[0];
}

function checkJava() {
  const res = run('java', ['-version']);
  if (res.ok || res.stderr) {
    const raw = res.stderr || res.stdout;
    const ver = parseJavaVersion(raw);
    return { label: 'Java JDK', status: 'ok', detail: ver || 'detected' };
  }
  return { label: 'Java JDK', status: 'warn', detail: 'Not found on PATH' };
}

function checkDotNet() {
  const res = run('dotnet', ['--info']);
  if (res.ok) {
    const line = res.stdout.split(/\r?\n/).find((l) => l.toLowerCase().includes('version'));
    return { label: '.NET', status: 'ok', detail: line || 'detected' };
  }
  return { label: '.NET', status: 'warn', detail: 'Not found on PATH' };
}

function checkCompilers() {
  const compilers = [];
  const msvc = run('cl', []);
  if (msvc.ok) compilers.push('MSVC (cl)');
  const gcc = run('gcc', ['--version']);
  if (gcc.ok) compilers.push('GCC');
  const clang = run('clang', ['--version']);
  if (clang.ok) compilers.push('Clang');
  if (compilers.length === 0) return { label: 'C/C++ compiler', status: 'warn', detail: 'None found' };
  return { label: 'C/C++ compiler', status: 'ok', detail: compilers.join(', ') };
}

function checkInternet() {
  const hosts = ['1.1.1.1', 'example.com', 'cloudflare-dns.com'];
  for (const h of hosts) {
    const res = run('ping', ['-n', '1', h]);
    if (res.ok) return { label: 'Internet', status: 'ok', detail: `Reachable (${h})` };
  }
  return { label: 'Internet', status: 'warn', detail: 'No response from neutral hosts' };
}

function checkDisk() {
  try {
    const res = run('wmic', ["logicaldisk", "where", "DeviceID='C:'", "get", "FreeSpace,Size", "/value"]);
    if (res.ok && res.stdout) {
      const entries = res.stdout
        .split(/\r?\n/)
        .filter(Boolean)
        .map((line) => line.split('='))
        .reduce((acc, [k, v]) => ({ ...acc, [k.trim()]: v.trim() }), {});
      if (entries.FreeSpace && entries.Size) {
        const freeGb = Number(entries.FreeSpace) / (1024 ** 3);
        const totalGb = Number(entries.Size) / (1024 ** 3);
        return { label: 'Disk (C:)', status: 'ok', detail: `${freeGb.toFixed(1)} GB free of ${totalGb.toFixed(1)} GB` };
      }
    }
  } catch (e) {
    // ignore
  }
  return { label: 'Disk (C:)', status: 'warn', detail: 'Could not query free space' };
}

function checkMemory() {
  try {
    const res = run('wmic', ['OS', 'get', 'TotalVisibleMemorySize,FreePhysicalMemory', '/value']);
    if (res.ok && res.stdout) {
      const entries = res.stdout
        .split(/\r?\n/)
        .filter(Boolean)
        .map((line) => line.split('='))
        .reduce((acc, [k, v]) => ({ ...acc, [k.trim()]: v.trim() }), {});
      if (entries.TotalVisibleMemorySize && entries.FreePhysicalMemory) {
        const totalGb = Number(entries.TotalVisibleMemorySize) / (1024 ** 2);
        const freeGb = Number(entries.FreePhysicalMemory) / (1024 ** 2);
        return { label: 'Memory', status: 'ok', detail: `${freeGb.toFixed(1)} GB free of ${totalGb.toFixed(1)} GB` };
      }
    }
  } catch (e) {
    // ignore
  }
  const totalGb = os.totalmem() / (1024 ** 3);
  const freeGb = os.freemem() / (1024 ** 3);
  return { label: 'Memory', status: 'ok', detail: `${freeGb.toFixed(1)} GB free of ${totalGb.toFixed(1)} GB (approx)` };
}

async function attemptFixes(results) {
  const missing = results.filter((r) => r.status !== 'ok');
  if (missing.length === 0) return;
  log('[INFO] Missing items detected: ' + missing.map((m) => m.label).join(', '));
  const consent = await promptYesNo('Fix issues and install missing tools automatically?', true);
  log(`[INFO] Auto-fix consent: ${consent ? 'yes' : 'no'}`);
  if (!consent) return;

  for (const item of missing) {
    if (item.label === 'Java JDK') {
      await installJava();
    } else if (item.label === '.NET') {
      await installDotNet();
    } else if (item.label === 'C/C++ compiler') {
      await installCompiler();
    }
  }
}

async function installJava() {
  const url = 'https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.msi';
  const tmp = path.join(os.tmpdir(), 'jdk-installer.msi');
  log(`[INFO] Downloading Java (JDK 17) from ${url} ...`);
  if (!downloadFile(url, tmp)) {
    log('❌ Java download failed.');
    return;
  }
  const res = installMsi(tmp);
  log(res.ok ? '✅ Java install triggered (silent)' : `❌ Java install failed (code ${res.status ?? 'unknown'})`);
}

async function installDotNet() {
  const url = 'https://dotnet.microsoft.com/permalink/dotnet-runtime-latest-win-x64';
  const tmp = path.join(os.tmpdir(), 'dotnet-runtime.exe');
  log(`[INFO] Downloading .NET runtime from ${url} ...`);
  if (!downloadFile(url, tmp)) {
    log('❌ .NET download failed.');
    return;
  }
  const res = installExe(tmp, ['/quiet', '/norestart']);
  log(res.ok ? '✅ .NET install triggered (silent)' : `❌ .NET install failed (code ${res.status ?? 'unknown'})`);
}

async function installCompiler() {
  log('[INFO] Trying winget for MSVC Build Tools (silent)...');
  const winget = run('winget', ['install', '-e', '--id', 'Microsoft.VisualStudio.2022.BuildTools', '--silent', '--accept-package-agreements', '--accept-source-agreements']);
  if (winget.ok) {
    log('✅ Winget install triggered for MSVC Build Tools.');
    return;
  }
  log('[WARN] winget failed or is missing; skipping compiler auto-install.');
}

function formatResult(r) {
  const icon = r.status === 'ok' ? '✅' : r.status === 'warn' ? '⚠️' : '❌';
  return `${icon} ${r.label}: ${r.detail}`;
}

async function main() {
  const args = parseArgs();
  AUTO_YES = Boolean(args.autoYes);
  LOG_FILE = ensureLogFile(args.logPath);
  log('[INFO] Log will capture all output.');

  const proceed = await promptYesNo('Start full checks now?', true);
  log(`[INFO] User chose to ${proceed ? 'start' : 'cancel'} checks.`);
  if (!proceed) {
    log('❌ Checks were cancelled by user.');
    await pauseForExit();
    return;
  }

  const checks = [checkOS, checkInternet, checkJava, checkDotNet, checkCompilers, checkDisk, checkMemory];
  log('[INFO] Running checks...');
  const results = [];
  for (const fn of checks) {
    try {
      const r = fn();
      results.push(r);
      log(formatResult(r));
    } catch (err) {
      log(`❌ ${fn.name}: ${err.message || err}`);
    }
  }
  log('');
  log('Summary:');
  results.forEach((r) => log('  ' + formatResult(r)));
  log('');
  await attemptFixes(results);
  log(`Detailed log saved to: ${LOG_FILE}`);
  await pauseForExit();
}

main().catch((err) => {
  log(`❌ Unexpected error: ${err.message || err}`);
  process.exit(1);
});
