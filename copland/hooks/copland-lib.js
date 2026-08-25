// COPLAND OS -- gemeinsame helfer fuer guard + audit (node, kein npm)
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const OD = process.env.COPLAND_ROOT || path.join(HOME, 'OneDrive');

// stdin komplett lesen und als json parsen; bei fehler null
function readHook() {
  try {
    const raw = fs.readFileSync(0, 'utf8');
    if (!raw.trim()) return null;
    return JSON.parse(raw);
  } catch (e) { return null; }
}

// pfad normalisieren: backslash -> slash, kleinbuchstaben
function norm(p) { return String(p || '').replace(/\\/g, '/').toLowerCase(); }

// schreibende tools
const WRITE_TOOLS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);

// schreibende bash-befehle (heuristik)
const WRITE_CMD = /(^|[\s;&|(])(rm|rmdir|del|erase|mv|cp|move|copy|mkdir|touch|tee|sed\s+-i|git\s+rm|git\s+mv|git\s+clean|remove-item|move-item|copy-item|rename-item|new-item|set-content|add-content|out-file|clear-content|truncate|>|>>)(\s|$)/i;

function isWriteCmd(cmd) { return WRITE_CMD.test(String(cmd || '')); }

// loeschende befehle
const DEL_CMD = /(^|[\s;&|(])(rm|rmdir|del|erase|git\s+rm|git\s+clean|remove-item|clear-content)(\s|$)/i;
function isDelCmd(cmd) { return DEL_CMD.test(String(cmd || '')); }

// rekursives loeschen
const RECURSIVE_DEL = /(rm\s+(-[a-z]*r[a-z]*\s+|-[a-z]*f[a-z]*\s+-[a-z]*r)|remove-item[^;|&]*-recurse|rmdir\s+\/s|rd\s+\/s)/i;
function isRecursiveDel(cmd) { return RECURSIVE_DEL.test(String(cmd || '')); }

// tabu-pfad-fragmente (schreiben gesperrt, lesen frei)
const TABU = [
  'seadrive_root',
  'chrome-passw',            // Chrome-Passwoerter.csv (umlaut-varianten)
  'privat-vault',
  'personal vault',
  'etsy_2fa',
  '2fa',
  '50_career/tools/.env',
];

// bereichswurzeln (rekursives loeschen gesperrt)
const AREAS = ['00_system', '10_uni', '20_work', '30_venture', '40_private', '50_career', '90_archiv_studium'];

// loeschen in diesen bereichen gesperrt
const NO_DELETE = ['20_work', '90_archiv_studium'];

// override: ~/.claude/cache/guard-override, juenger als 10 min, eine zeile pro fragment
function overrides() {
  try {
    const f = path.join(HOME, '.claude', 'cache', 'guard-override');
    const st = fs.statSync(f);
    if (Date.now() - st.mtimeMs > 10 * 60 * 1000) return [];
    return fs.readFileSync(f, 'utf8').split(/\r?\n/).map(s => norm(s.trim())).filter(Boolean);
  } catch (e) { return []; }
}

function isOverridden(target) {
  const t = norm(target);
  return overrides().some(o => t.includes(o) || o.includes(t));
}

// pfad-artige tokens eines befehls (enthalten / oder \ oder eine dateiendung)
// -> tabu-fragmente nur dagegen pruefen, nicht gegen freien text (sonst blockt
//    schon ein heredoc, in dem das wort "2fa" vorkommt)
function pathTokens(cmd) {
  return String(cmd || '').split(/[\s"'`|;&<>()]+/)
    .filter(t => /[\/\\]/.test(t) || /\.[a-z0-9]{1,5}$/i.test(t))
    .map(norm);
}

// cwd kurz: bereich/projekt relativ zu OneDrive
function shortCwd(cwd) {
  const c = norm(cwd), o = norm(OD);
  let rel = c.startsWith(o) ? c.slice(o.length).replace(/^\//, '') : c;
  const parts = rel.split('/').filter(Boolean);
  return parts.length ? parts.slice(0, 2).join('/') : '~';
}

function pad2(n) { return String(n).padStart(2, '0'); }

module.exports = { readHook, norm, pathTokens, WRITE_TOOLS, isWriteCmd, isDelCmd, isRecursiveDel,
  TABU, AREAS, NO_DELETE, isOverridden, shortCwd, pad2, HOME, OD };
