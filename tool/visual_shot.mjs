// 视觉测试截图工具：用 CDP 驱动无头 Chrome 访问本地 Flutter Web，
// 逐个状态截图保存到 screenshots/ 目录。
// 用法：先启动 `flutter run -d web-server --web-port 8437`，再 `node tool/visual_shot.mjs`
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const BASE = 'http://127.0.0.1:8437';
const OUT_DIR = join(import.meta.dirname, '..', 'screenshots');
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PORT = 9333;
const USER_DATA = join(tmpdir(), 'kawuxing-shot-profile');

const states = [
  ['01_空状态.png', ''],
  ['02_听牌_卡五星.png', '#h=0,1,2,6,7,8,3,5,9,10,11,13,13'],
  ['03_打牌建议_14张.png', '#h=0,1,2,3,5,6,7,8,9,10,11,13,13,17'],
  ['04_差1张进听.png', '#h=0,1,2,3,4,5,9,10,12,13,13,13,18'],
  ['05_副露省录_11张.png', '#h=0,1,2,3,4,5,9,10,11,13,13'],
  ['06_已胡牌_14张.png', '#h=0,1,2,3,4,5,6,7,8,9,10,11,13,13'],
  ['07_张数有误.png', '#h=0,0,1'],
];

mkdirSync(OUT_DIR, { recursive: true });
rmSync(USER_DATA, { recursive: true, force: true });

const chrome = spawn(CHROME, [
  '--headless=new',
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${USER_DATA}`,
  '--no-first-run',
  '--disable-gpu',
  '--hide-scrollbars',
  '--window-size=412,915',
  'about:blank',
], { stdio: 'ignore' });
chrome.on('exit', (c) => { console.error('chrome exited', c); process.exit(1); });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitPort() {
  for (let i = 0; i < 60; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/json/version`);
      if (r.ok) return;
    } catch {}
    await sleep(500);
  }
  throw new Error('chrome devtools port timeout');
}

async function newTab() {
  const r = await fetch(`http://127.0.0.1:${PORT}/json/new?about:blank`, { method: 'PUT' });
  if (!r.ok) throw new Error('create tab failed ' + r.status);
  return (await r.json()).webSocketDebuggerUrl;
}

function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let seq = 0;
  const pending = new Map();
  const waiters = [];
  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    } else if (msg.method) {
      for (let i = waiters.length - 1; i >= 0; i--) {
        if (waiters[i].event === msg.method) {
          waiters[i].resolve(msg.params);
          waiters.splice(i, 1);
        }
      }
    }
  });
  const api = {
    ready: new Promise((res, rej) => {
      ws.addEventListener('open', () => res());
      ws.addEventListener('error', (e) => rej(new Error('ws error')));
    }),
    send(method, params = {}) {
      const id = ++seq;
      ws.send(JSON.stringify({ id, method, params }));
      return new Promise((res) => pending.set(id, res));
    },
    waitEvent(event, timeoutMs = 60000) {
      return new Promise((resolve, reject) => {
        const w = { event, resolve };
        waiters.push(w);
        setTimeout(() => {
          const i = waiters.indexOf(w);
          if (i >= 0) { waiters.splice(i, 1); reject(new Error('timeout ' + event)); }
        }, timeoutMs);
      });
    },
    close: () => ws.close(),
  };
  return api;
}

async function flutterReady(cdp) {
  for (let i = 0; i < 60; i++) {
    const r = await cdp.send('Runtime.evaluate', {
      expression: "!!document.querySelector('flutter-view flt-glass-pane, flutter-view')",
    });
    if (r?.result?.value === true) return true;
    await sleep(500);
  }
  return false;
}

async function main() {
  await waitPort();
  const cdp = connect(await newTab());
  await cdp.ready;
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width: 412, height: 915, deviceScaleFactor: 2, mobile: true,
  });

  let first = true;
  for (const [file, hash] of states) {
    const url = BASE + '/' + hash;
    const loaded = cdp.waitEvent('Page.loadEventFired');
    await cdp.send('Page.navigate', { url });
    await loaded;
    if (!(await flutterReady(cdp))) {
      console.error('flutter 未就绪: ' + file);
      continue;
    }
    await sleep(first ? 4000 : 2500); // 等待首帧渲染稳定
    first = false;
    const shot = await cdp.send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(join(OUT_DIR, file), Buffer.from(shot.data, 'base64'));
    console.log('已保存', file);
  }
  cdp.close();
  chrome.kill();
  process.exit(0);
}

main().catch((e) => { console.error(e); chrome.kill(); process.exit(1); });
