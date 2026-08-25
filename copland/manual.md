COPLAND OS -- MANUAL                                  stand: 2026-08-16

WAS DU HIER KANNST
  an einem projekt arbeiten ............. [1]-[5] (ordner-dekade)
  letzte session fortsetzen ............. [r] nach der projektwahl
  wichtige frage an mehrere kis ......... /rat   (klein: /dual)
  tag planen: termine, mails, fristen ... [a]  oder  /briefing
  stand der session festhalten .......... /merken
  input ins wissenssystem einarbeiten ... /einarbeiten
  dokument bauen und als pdf ansehen .... [6] werkstatt
  alles auf einen blick ................. [h] terminal, darin [b] browser
  limits und token nachsehen ............ panel rechts (alt+g = grafik)
  was claude nach aussen kann ........... [p] verbindungen (70_mcp)
  copland von ueberall nach vorn holen .. win+` (quake-mode)
  diktieren statt tippen ................ /voice, dann leertaste halten
  musik steuern (spotify) ............... [u] player, panel seite 3 zeigt an
  schnell in einen ordner springen ...... z <name> in der shell (zoxide)
  notizen im terminal (eigenes obsidian)  [v] vault

LAUNCHER
  menue in drei spalten nebeneinander: bereiche | ambient | werkzeug.
  startseite: digital rain unten rechts, laeuft bis tastendruck.
  fehlt etwas (claude, codex, ollama, ccusage), meldet es sich in rot.
  [z] geht in jedem untermenue zurueck.

LAUNCHER -- HINGEHEN
  [1]-[5]  bereich waehlen (1=10_uni ... 5=50_career)
           puls hinter dem bereich: ** heute, * gestern, . woche
  [s]      systemraum 00_System (gespraeche ueber die umgebung)
  [a]      alltag: bereich 60_assistent (allzweck-ort, brain), startet mit /briefing
  [6]      werkstatt: ordner-browser -- ziffer = ordner rein / datei oeffnen, [z] hoch, [i] index (maus)
           [i] browser-uebersicht   [e] explorer   [z] zurueck
  [0]      shell ohne claude
  [o]      lokale ki ohne internet (ollama)
           [enter] gpt-oss 20b   [2] qwen3 14b   [3] gemma3 12b (bilder)

LAUNCHER -- NACHSEHEN
  [h]      hub, der EINE uebersichts-screen: bereiche/projekte mit
           stand, git-verlauf, offene punkte, balance, skills.
           [b] darin oeffnet die kommandozentrale im browser
           (gauges, donut, heatmap, lebens-graph, timeline)
  [w]      wired: vollbild-ambient (uhr, limits, rain), jede taste beendet
  [p]      verbindungen: mcp-server, claude.ai-connectoren, cli-tools
           mit status (laeuft / anmeldung noetig / aus). [b] browser-
           seite 70_mcp\mcp.html, [v] tabelle, [e] explorer
  token-charts: panel seite 2 (alt+g) und browser-hub

LAUNCHER -- REST
  [c] chats: alle sessions, [nr] fortsetzen, [d nr] papierkorb, [s text] filter
  [b] config-backup     [m] dieses manual      [q] beenden
  [enter]               letzte session fortsetzen (claude --continue im letzten projekt)
  puls-spalte: ** heute, * gestern, . diese woche

VAULT [v] (wissens-notizen im terminal, obsidian-kompatibel)
  EIN vault je lebensbereich: <bereich>\vault (10_uni\vault, 30_venture\vault,
  00_System\vault = systemwissen, 60_assistent\vault = alltag ...). [v] fragt
  zuerst den bereich ([1]-[5], [a], [s]), ^w wechselt spaeter (ctrl gedrueckt halten -- blosse buchstaben gehen in den filter). normale
  .md-dateien, [[name]] = wikilink; zeigt ein link in einen anderen bereich,
  steht das dahinter ("(uni)") und beim folgen wechselt der vault mit.
  EIN bildschirm, drei spalten: liste | notiz | kontext (backlinks,
  ausgehend, aehnlich, tags). nichts springt: liste links bleibt,
  die notiz in der mitte folgt der auswahl sofort, kontext rechts steht.
  tippen        filtert die liste live (name + volltext); esc loescht
  ^f            semantik-modus: filtertext wird per ollama-embedding
                verglichen (nomic-embed-text, offline)
  pfeile / rad  waehlen bzw. notiz scrollen   tab = spalte wechseln
  maus          klick auf listeneintrag zeigt, klick auf [[link]] oder
                kontext-eintrag folgt (windows terminal; sonst tastatur)
  enter         in der kontextspalte: link folgen (fehlt die notiz,
                wird sie angelegt)
  kontext rechts = mini-graph (eingehend, [knoten], ausgehend, ~ aehnlich, # tags),
  nicht fokussierte spalten gedimmt, regen unten rechts wenn platz.
  ^g            ascii-graph vollbild (2 ebenen)   ^b browser-landkarte:
                force-graph im browser (vault\_graph.html, klick =
                notiz rechts, ziehen/zoomen, f = einpassen)
  ^e editor     ^d daily note   ^n neue notiz   ^x link-ideen
  ^r neu lesen  esc = zurueck zum launcher (bei leerem filter)
  index-cache %LOCALAPPDATA%\copland-vault-index.json
  zwei spalten (liste | notiz); tab oeffnet rechts den kontext-graph.
  vault-recall: bei jeder eingabe sucht ein hook still die 2-3 passendsten
  notizen des bereichs-vaults (ollama, offline, schwelle 65%) und gibt sie
  claude als hintergrund mit -- die statusline zeigt dann "vault: ...".
  kostet ~0,5-1,3k tokens nur wenn etwas passt; 40_private nie.
  claude als bibliothekar: /notiz oder "merk dir X als notiz" ->
  legt an, verlinkt beidseitig; die tagesstart-ernte traegt selten
  auch fachwissen von gestern als verlinkte notiz nach

SESSION STARTEN (direktstart: zwei tasten statt vier)
  nach der bereichswahl (karte zeigt je projekt aktivitaet + stand):
  [1]-[9]  projekt -- startet SOFORT claude neu
  [enter]  ganzer bereich          [n]  neues projekt (ordner + CLAUDE.md)
  anderer modus? VORHER als praefix druecken, dann die ziffer:
  [r] letzte fortsetzen   [s] session-liste   [c] chatgpt/codex
  die fusszeile zeigt den gewaehlten modus, [z] geht zurueck

SKILLS -- TAEGLICH
  /rat           frage parallel an mehrere kis (claude, codex, freie
                 stimmen), synthese + widersprueche
  /dual          dieselbe aufgabe an claude UND codex, beste antwort
  /briefing      termine, wichtige mails, fristen, offene punkte,
                 letzte arbeit -- liegt in 60_assistent
  /merken        session-stand in claude.md festhalten

SKILLS -- WISSEN PFLEGEN
  /einarbeiten   input (text/datei/url) analysieren und einsortieren
  /destillieren  entruempeln: veraltete verweise, redundanz, drift
  /neudenken     system vom zweck her hinterfragen, umbau-einschaetzung

SKILLS -- CODE
  /code-review   aenderungen auf bugs pruefen
  /simplify      code vereinfachen
  /security-review   sicherheits-check der aenderungen

SKILLS -- LAEUFT VON SELBST
  /loop          befehl im intervall wiederholen (lokal, laptop an)
  /schedule      cloud-agent nach zeitplan (auch bei laptop zu)
  pdf-agent      bei pdf-arbeit automatisch, pdf -> markdown
  ablage: ~\.claude\skills\ und ~\.claude\commands\

TABS (der kern-workflow)
  ^ (taste unter esc)   neuer tab mit auswahlmenue
  alt+rechts/links      zwischen tabs switchen
  ctrl+shift+w          pane/tab schliessen
  win+`                 copland von ueberall einblenden (quake-mode)
  tab-titel = bereich/projekt, terminal startet maximiert

SHELL-TOOLS (in [0] und jeder powershell)
  z <name>     zoxide: springt in bekannte ordner (lernt mit)
  ctrl+r       fzf: fuzzy-suche in der befehls-historie
  ctrl+t       fzf: fuzzy-dateisuche im aktuellen ordner
  tippen       psreadline: gedimmte auto-vorschlaege aus der historie

PANEL (rechts, laeuft in jedem tab mit, refresh 60s, [q] schliesst)
  zwei seiten, wechsel mit pfeiltasten (g = grafik von ueberall):
  seite 1 limits   claude, codex, rat, system; unten mini-spotify (track + pegel)
  seite 2 grafik   token-kurve claude/codex, modell-split, heatmap

MUSIK [u] (vollbild-spotify-player)
  space = play/pause, n/b oder pfeile = next/prev, hoch/runter + enter = bibliothek
  abspielen, r = bibliothek neu laden, q = zurueck. steuert die spotify-app direkt
  (media-session, kein api-key). bibliothek pflegt claude per zuruf
  ("aktualisiere meine spotify-bibliothek"); optional web-api: client-id nach
  ~\.claude\cache\spotify-client-id.txt, dann spielt enter direkt ab (premium)
  5h- und 7d-limit als balken mit reset-zeit, rot ab 80%
  darunter das modell-eigene wochenfenster von der usage-api (cache 5min)
  unterm 5h-balken: burn-kurve der letzten ~30 min (braille)
  rat-block: nur stimmen, die heute benutzt wurden (sonst eine zeile);
  release-hinweis nur, wenn ein claude-code-update aussteht;
  burn-kurve erst ab 40% des 5h-fensters (schwellwert-prinzip)
  ki-dienste: stoerungen von anthropic/openai nur im stoerfall in rot,
  still darunter die neuesten versionen (cc x.y | codex x.y)
  ausserdem: uhr, datum, wetter, ort der letzten session, modell + ctx

STIMME UND MODI
  /voice     diktat an/aus; leertaste halten = aufnehmen,
             loslassen = direkt abschicken
  /config    sprache, effort, modell aendern
  shift+tab  modus durchschalten (normal / plan / bypass)
             standard ist bypass, ausnahme: claude-safe fragt nach
  /rewind    dateiaenderungen einer session zurueckdrehen
  /compact   kontext zusammenfassen, wenn ctx% hoch ist
  /rename    session benennen (setzt auch den tab-titel)

GOOGLE, HANDY, TON
  gmail + kalender per zuruf: "check meine mails", "was steht diese
  woche an", "leg termin X an" -- vor senden/loeschen fragt claude
  handy: claude-app am gleichen account, jede laptop-session verbindet
  sich automatisch (code-tab: mitlesen + weiterschreiben, laptop an).
  /mobile zeigt den qr-code, im browser claude.ai/code
  ton am laptop wenn input gebraucht wird, dazu push in die app

ASSISTENT + BRAIN (60_assistent)
  [a] ist der allzweck-ort: hier darf alles gefragt werden, claude
  kennt den gesamtstand. brain\ = querwissen, das in JEDER session
  geladen wird (verfassung): personen, entscheidungen, vorlieben,
  laufende faeden. pflege: sofort beim auftreten + /merken.
  tagesstart-ernte: der launcher startet 1x pro tag (erster start)
  versteckt claude -p, das die sessions von gestern ins brain
  destilliert, erinnerungen ergaenzt und STATE neu baut
  (copland-ernte.ps1, log: %LOCALAPPDATA%\copland-ernte.log).
  laptop ist nur an, wenn der nutzer arbeitet -> ereignis statt uhrzeit.

STATE
  00_System\STATE.md = maschinenzustand fuer claude (projekte, zurufe,
  staende, verbindungen, fristen -- ein read). generiert von
  copland-state.ps1; trigger: tab-start, git-commit, /merken.
  nie von hand editieren.

WERKSTATT (dokumente mit claude bauen)
  00_System\werkstatt\html\  quellen      pdf\  exporte, gleicher name
  INDEX.html = klickbarer ordnerbaum im browser (maus), vorschau oeffnet in den standard-apps
  [6] ist ein ordner-browser: ordner zuerst, dann dateien; [+] blaettert, [e] explorer im aktuellen ordner
  im ordner stundenzettel\: [n] baut einen monat aus monate\<jjjj-mm>.txt (pdf oeffnet sich)
  [i] baut INDEX.html neu = klickbarer ordnerbaum im browser (maus)

DATEIEN
  launcher, panel, state, hub   00_System\copland\*.ps1
  statusline, theme, notify-ton, settings   ~\.claude\
  dieses manual                 00_System\copland\manual.md
  volle bausteine-tabelle       00_System\copland\CLAUDE.md
  schrift departure mono 12, statusline = [wired] BEREICH | ordner,
  alle weiteren details stehen rechts im panel
