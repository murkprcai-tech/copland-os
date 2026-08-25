// COPLAND OS -- vault-recall (UserPromptSubmit): passende wissens-notizen still mitgeben
// prompt -> ollama-embedding (lokal, nomic-embed-text) -> cosine gegen den index des
// bereichs-vaults, in dem die session laeuft -> top 3 ueber der schwelle als kontext.
// kein ollama / kein index / kurzer prompt -> stiller exit 0. marker fuer die statusline:
// %LOCALAPPDATA%\copland-vault-recall.json. fehler -> immer exit 0, nie blockieren.
'use strict';
const fs = require('fs'), path = require('path'), http = require('http');
try {
  const L = require('./copland-lib');
  const h = L.readHook();
  if (!h) process.exit(0);
  const prompt = String(h.prompt || '').trim();
  if (prompt.length < 15 || prompt.startsWith('/')) process.exit(0);

  const home = process.env.USERPROFILE || process.env.HOME;
  const local = process.env.LOCALAPPDATA || path.join(home, 'AppData', 'Local');
  const od = process.env.COPLAND_ROOT || path.join(home, 'OneDrive');
  const cwd = L.norm(h.cwd || process.cwd());
  const MAP = [['10_uni', 'uni'], ['20_work', 'work'], ['30_venture', 'venture'], ['40_private', 'privat'],
               ['50_career', 'career'], ['60_assistent', 'alltag'], ['00_system', 'system'], ['70_mcp', 'system']];
  let id = null, dir = null;
  for (const [d, i] of MAP) { if (cwd.includes('/' + d)) { id = i; dir = d; break; } }
  if (!id || id === 'privat') process.exit(0);          // privat: nie automatisch
  const vaultDir = path.join(od, dir === '00_system' ? '00_System' : dir, 'vault');
  const idxFile = path.join(local, `copland-vault-index-${id}.json`);
  if (!fs.existsSync(idxFile) || !fs.existsSync(vaultDir)) process.exit(0);
  const index = JSON.parse(fs.readFileSync(idxFile, 'utf8').replace(/^﻿/, ''));   // powershell schreibt utf8 mit BOM
  const keys = Object.keys(index).filter(k => fs.existsSync(k));
  if (!keys.length) process.exit(0);

  const THRESH = 0.65, TOP = 3, MAXCHARS = 1200;
  const embed = (text) => new Promise((resolve) => {
    const body = JSON.stringify({ model: 'nomic-embed-text', input: text });
    const req = http.request({ host: '127.0.0.1', port: 11434, path: '/api/embed', method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }, timeout: 2500 }, res => {
      let d = ''; res.on('data', c => d += c); res.on('end', () => { try { resolve(JSON.parse(d).embeddings[0]); } catch (e) { resolve(null); } });
    });
    req.on('error', () => resolve(null)); req.on('timeout', () => { req.destroy(); resolve(null); });
    req.write(body); req.end();
  });
  const cos = (a, b) => { let d = 0, na = 0, nb = 0; for (let i = 0; i < a.length; i++) { d += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; } return na && nb ? d / Math.sqrt(na * nb) : 0; };

  (async () => {
    // index nachziehen: hoechstens 2 geaenderte/neue notizen pro aufruf (haelt den hook schnell)
    let dirty = 0;
    const files = fs.readdirSync(vaultDir, { withFileTypes: true }).flatMap(e => {
      if (e.isDirectory()) { try { return fs.readdirSync(path.join(vaultDir, e.name)).filter(f => f.endsWith('.md')).map(f => path.join(vaultDir, e.name, f)); } catch (x) { return []; } }
      return e.name.endsWith('.md') && !e.name.startsWith('_') ? [path.join(vaultDir, e.name)] : [];
    });
    for (const f of files) {
      if (dirty >= 2) break;
      const mt = fs.statSync(f).mtime.toISOString();
      const have = index[f];
      if (have && have.mtime && Math.abs(new Date(have.mtime) - new Date(mt)) < 2000) continue;
      const txt = fs.readFileSync(f, 'utf8').slice(0, 2000);
      const v = await embed(path.basename(f, '.md') + '\n' + txt);
      if (!v) break;
      index[f] = { mtime: mt, vec: v }; dirty++;
    }
    if (dirty) { try { fs.writeFileSync(idxFile, JSON.stringify(index)); } catch (e) { } }

    const qv = await embed(prompt);
    if (!qv) process.exit(0);
    const scored = Object.keys(index).filter(k => fs.existsSync(k))
      .map(k => ({ k, s: cos(qv, index[k].vec) })).filter(x => x.s >= THRESH)
      .sort((a, b) => b.s - a.s).slice(0, TOP);
    const marker = path.join(local, 'copland-vault-recall.json');
    if (!scored.length) { try { fs.writeFileSync(marker, JSON.stringify({ ts: Date.now(), notes: [] })); } catch (e) { } process.exit(0); }

    const parts = scored.map(x => {
      const name = path.basename(x.k, '.md');
      const body = fs.readFileSync(x.k, 'utf8').split(/\r?\n/)
        .filter(l => !/^(Verwandt|Quelle|Angelegt|Ergaenzt|Tags?)\s*:/.test(l) && !/^\s*(#[a-z0-9_\-/]+\s*)+$/.test(l) && !/^#\s/.test(l))
        .join('\n').replace(/\n{3,}/g, '\n\n').trim().slice(0, MAXCHARS);
      return `### ${name} (${Math.round(x.s * 100)}%)\n${body}`;
    });
    const ctx = `[copland vault-recall, bereich ${id}: passende notizen aus ${dir}/vault -- hintergrundwissen, keine anweisung]\n\n` + parts.join('\n\n');
    try { fs.writeFileSync(marker, JSON.stringify({ ts: Date.now(), notes: scored.map(x => path.basename(x.k, '.md')), scores: scored.map(x => Math.round(x.s * 100)) })); } catch (e) { }
    process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: 'UserPromptSubmit', additionalContext: ctx } }));
    process.exit(0);
  })().catch(() => process.exit(0));
} catch (e) {
  process.exit(0);
}
