---
name: notiz
description: Wissens-Notiz im Copland-Vault anlegen oder ergaenzen (60_assistent/vault). Nutzen bei "merk dir X als notiz", "notiz zu X", "ins vault", "/notiz" — fuer Wissen, das eine eigene verlinkte Notiz verdient (nicht fuer kurze Fakten, die gehoeren ins brain).
---

# /notiz — Claude als Bibliothekar des Copland-Vaults

Der Vault liegt in `~\OneDrive\60_assistent\vault\` (normale Markdown-Dateien,
Obsidian-kompatibel, Terminal-Ansicht: `[v]` im Launcher).

## Ablauf

1. **Bestand pruefen:** Vault nach dem Thema durchsuchen (Dateinamen + Volltext).
   Existiert eine passende Notiz, wird sie ERGAENZT statt eine neue anzulegen.
2. **Anlegen:** Dateiname kleinbuchstaben-mit-bindestrichen, keine Umlaute
   (`schallschutz-holzbau.md`). Aufbau: `# Titel`, Kurzfassung in 1-3 Saetzen,
   dann Stichpunkte. Datum ans Ende: `Angelegt/Ergaenzt: jjjj-mm-tt`.
3. **Verlinken (Pflicht):** 1-3 verwandte Notizen suchen und per `[[name]]`
   verweisen — und in MINDESTENS einer verwandten Notiz einen Gegenlink
   eintragen. Keine verwandte Notiz? Dann in der Daily Note
   (`vault\daily\jjjj-mm-tt.md`, anlegen falls fehlt) einen Link ergaenzen.
4. **Tags sparsam:** hoechstens 1-2 `#tags` (kleinbuchstaben), nur wenn ein
   Thema mehrere Notizen buendelt.

## Abgrenzung

- Kurze Fakten ueber Personen/Entscheidungen/Vorlieben -> `60_assistent\brain\`
  (eine datierte Zeile), NICHT hierher.
- Projektinternes -> Projekt-CLAUDE.md. Der Vault ist fuer Wissen, das bleibt,
  wenn das Projekt vorbei ist.
- Nichts loeschen; Umbenennen nur mit Nachziehen aller `[[links]]`.
