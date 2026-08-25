// COPLAND OS -- notify-wrapper: hook-json lesen, toast.ps1 detached starten
// events: Notification (toast + ton), Stop (nur ton)
'use strict';
try {
  const { spawn } = require('child_process');
  const path = require('path');
  const L = require('./copland-lib');
  const h = L.readHook() || {};

  const ev = h.hook_event_name || '';
  let title = 'COPLAND OS', msg = '', args = [];
  if (ev === 'Stop') {
    // nur ton -- stop kommt nach jeder antwort, toast waere nervig
    args.push('-NoToast');
    msg = 'antwort fertig';
  } else {
    msg = String(h.message || h.title || 'claude wartet auf input').replace(/\s+/g, ' ').slice(0, 200);
    const cwd = L.shortCwd(h.cwd || '');
    title = cwd && cwd !== '~' ? `COPLAND OS  ${cwd}` : 'COPLAND OS';
  }

  const ps = path.join(__dirname, 'copland-toast.ps1');
  const child = spawn('powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ps,
     '-Title', title, '-Message', msg, ...args],
    { detached: true, stdio: 'ignore', windowsHide: true });
  child.unref();
  process.exit(0);
} catch (e) {
  process.exit(0);
}
