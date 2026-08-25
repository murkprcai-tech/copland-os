// COPLAND OS -- guard: schreibsperre auf tabu-pfade (PreToolUse)
// lesen bleibt frei. block = exit 2 + meldung auf stderr.
// freigabe: ~/.claude/cache/guard-override (eine zeile pro pfad-fragment, gilt 10 min)
// fehler -> immer durchlassen (exit 0), nie die session blockieren.
'use strict';
try {
  const L = require('./copland-lib');
  const h = L.readHook();
  if (!h) process.exit(0);

  const tool = h.tool_name || '';
  const inp = h.tool_input || {};
  const block = (what, why) => {
    process.stderr.write(
      `copland-guard: ${why} -- ${what}\n` +
      `freigabe: datei ~/.claude/cache/guard-override mit dem pfad anlegen (gilt 10 min)\n`);
    process.exit(2);
  };

  // --- datei-tools ---
  if (L.WRITE_TOOLS.has(tool)) {
    const p = L.norm(inp.file_path || inp.notebook_path || '');
    if (!p) process.exit(0);
    for (const t of L.TABU) {
      if (p.includes(t) && !L.isOverridden(p)) block(p, `schreibzugriff auf tabu-pfad gesperrt`);
    }
    process.exit(0);
  }

  // --- bash ---
  if (tool === 'Bash') {
    const cmd = String(inp.command || '');
    const c = L.norm(cmd);
    if (!L.isWriteCmd(cmd)) process.exit(0);

    // tabu-pfade nur bei schreibenden befehlen, nur in pfad-artigen tokens
    const toks = L.pathTokens(cmd);
    for (const t of L.TABU) {
      const hit = toks.find(k => k.includes(t));
      if (hit && !L.isOverridden(hit)) block(hit, `schreibender befehl auf tabu-pfad gesperrt`);
    }
    // loeschen in 20_work / 90_archiv
    if (L.isDelCmd(cmd)) {
      for (const a of L.NO_DELETE) {
        if (c.includes(a) && !L.isOverridden(a)) block(a, `loeschen in diesem bereich gesperrt`);
      }
    }
    // rekursives loeschen auf bereichswurzeln: rm -rf .../10_uni oder .../10_uni/
    if (L.isRecursiveDel(cmd)) {
      for (const a of L.AREAS) {
        const re = new RegExp(`onedrive/${a}/?(["'\\s]|$)`, 'i');
        if (re.test(c) && !L.isOverridden(a)) block(a, `rekursives loeschen einer bereichswurzel gesperrt`);
      }
    }
    process.exit(0);
  }
  process.exit(0);
} catch (e) {
  process.exit(0);
}
