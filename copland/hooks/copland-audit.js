// COPLAND OS -- audit: protokolliert schreibende aktionen (PostToolUse)
// ziel: 00_System/log/audit-JJJJ-MM.md, eine zeile je aktion
// format: HH:mm | bereich/projekt | tool | datei oder befehl (100 zeichen)
'use strict';
try {
  const fs = require('fs');
  const path = require('path');
  const L = require('./copland-lib');
  const h = L.readHook();
  if (!h) process.exit(0);

  const tool = h.tool_name || '';
  const inp = h.tool_input || {};
  let what = '';

  if (L.WRITE_TOOLS.has(tool)) {
    what = String(inp.file_path || inp.notebook_path || '').replace(/\\/g, '/');
    const o = L.OD.replace(/\\/g, '/');
    if (what.toLowerCase().startsWith(o.toLowerCase())) what = what.slice(o.length).replace(/^\//, '');
  } else if (tool === 'Bash') {
    const cmd = String(inp.command || '');
    if (!L.isWriteCmd(cmd)) process.exit(0);
    what = cmd.replace(/\s+/g, ' ').trim().slice(0, 100);
  } else {
    process.exit(0);
  }

  const d = new Date();
  const dir = path.join(L.OD, '00_System', 'log');
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `audit-${d.getFullYear()}-${L.pad2(d.getMonth() + 1)}.md`);
  if (!fs.existsSync(file)) {
    fs.writeFileSync(file, `# audit ${d.getFullYear()}-${L.pad2(d.getMonth() + 1)} -- schreibende aktionen (generiert von copland-audit.js)\n\n`);
  }
  // tagesmarke, wenn neuer tag
  const day = `${d.getFullYear()}-${L.pad2(d.getMonth() + 1)}-${L.pad2(d.getDate())}`;
  const tail = fs.readFileSync(file, 'utf8');
  let line = '';
  if (!tail.includes(`## ${day}`)) line += `\n## ${day}\n`;
  line += `${L.pad2(d.getHours())}:${L.pad2(d.getMinutes())} | ${L.shortCwd(h.cwd || process.cwd())} | ${tool} | ${what}\n`;
  fs.appendFileSync(file, line);
  process.exit(0);
} catch (e) {
  process.exit(0);
}
