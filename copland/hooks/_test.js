// COPLAND OS -- selbsttest fuer guard + audit: node _test.js
'use strict';
const { spawnSync } = require('child_process');
const fs = require('fs'), path = require('path'), os = require('os');
const run = (script, obj) => spawnSync(process.execPath, [path.join(__dirname, script)], { input: JSON.stringify(obj), encoding: 'utf8' });
const ov = path.join(os.homedir(), '.claude', 'cache', 'guard-override');
let fail = 0;
const T = (name, want, obj) => {
  const r = run('copland-guard.js', obj);
  const ok = r.status === want;
  if (!ok) fail++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}  exit=${r.status} (erwartet ${want}) ${r.stderr.split('\n')[0] || ''}`);
};
const W = (p) => ({ tool_name: 'Write', tool_input: { file_path: p } });
const B = (c) => ({ tool_name: 'Bash', tool_input: { command: c } });

T('write seadrive', 2, W('C:\\Users\\me\\seadrive_root\\x.md'));
T('write normal', 0, W('C:\\Users\\me\\OneDrive\\00_System\\x.md'));
T('edit .env tools', 2, { tool_name: 'Edit', tool_input: { file_path: 'C:\\Users\\me\\OneDrive\\50_career\\Tools\\.env' } });
T('write privat-vault', 2, W('C:\\Users\\me\\OneDrive\\40_private\\Privat-Vault\\a.md'));
T('write 2fa', 2, W('C:\\Users\\me\\OneDrive\\30_venture\\Cash\\Etsy Shops\\etsy_2fa_backup_codes.txt'));
T('bash cat tabu (lesen)', 0, B('cat "C:\\Users\\me\\OneDrive\\40_private\\Privat-Vault\\a.md"'));
T('bash > chrome-passw', 2, B('echo x > "C:/Users/me/OneDrive/Random/Chrome-Passwörter.csv"'));
T('bash rm 20_work', 2, B('rm C:/Users/me/OneDrive/20_work/foo.pdf'));
T('bash mv 20_work (nur verschieben)', 0, B('mv C:/Users/me/OneDrive/20_work/a C:/Users/me/OneDrive/20_work/b'));
T('bash Remove-Item 90_Archiv', 2, B('Remove-Item -Recurse C:\\Users\\me\\OneDrive\\90_Archiv_Studium\\x'));
T('bash rm -rf bereichswurzel', 2, B('rm -rf C:/Users/me/OneDrive/30_venture'));
T('bash rm -rf bereichswurzel backslash', 2, B('rm -rf "C:\\Users\\me\\OneDrive\\30_venture\\"'));
T('bash rm -rf unterordner', 0, B('rm -rf C:/Users/me/OneDrive/30_venture/game/node_modules'));
T('bash git status', 0, B('git status'));
T('bash heredoc mit wort 2fa (freier text)', 0, B('cat > x.md <<EOF\nvault, 2fa, .env\nEOF'));
T('bash write mit seadrive im text', 0, B('echo "seadrive_root bleibt tabu" > notiz.md'));
T('bash sed -i seadrive', 2, B('sed -i s/a/b/ C:/Users/me/seadrive_root/x'));
T('kaputtes json', 0, 'xx');
fs.mkdirSync(path.dirname(ov), { recursive: true }); fs.writeFileSync(ov, 'seadrive_root\n');
T('override seadrive', 0, W('C:\\Users\\me\\seadrive_root\\x.md'));
fs.unlinkSync(ov);
T('nach override wieder gesperrt', 2, W('C:\\Users\\me\\seadrive_root\\x.md'));

// audit
const a1 = run('copland-audit.js', { tool_name: 'Write', cwd: 'C:\\Users\\me\\OneDrive\\00_System\\copland', tool_input: { file_path: 'C:\\Users\\me\\OneDrive\\00_System\\copland\\hooks\\test.md' } });
const a2 = run('copland-audit.js', { tool_name: 'Bash', cwd: 'C:\\Users\\me\\OneDrive\\10_uni\\hiwi-mad', tool_input: { command: 'ls -la' } });
const a3 = run('copland-audit.js', { tool_name: 'Bash', cwd: 'C:\\Users\\me\\OneDrive\\10_uni\\hiwi-mad', tool_input: { command: 'echo hi > out.txt' } });
console.log(`audit exits: ${a1.status} ${a2.status} ${a3.status}`);
console.log(fail ? `${fail} FEHLER` : 'alle tests ok');
process.exit(fail ? 1 : 0);
