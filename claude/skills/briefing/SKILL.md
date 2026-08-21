---
name: briefing
description: Morning briefing -- calendar (today/tomorrow), mails that need action, deadlines, open items and last work on one screen. Use for "/briefing", "briefing", "what's on today", "give me the overview".
---

# Briefing

A compact overview of the day, in the Copland tone (lowercase, direct, no
filler). Goal: read in 30 seconds. Needs the Google Calendar / Gmail MCP
connectors; if one is missing, say so in one line and skip that section.

## Steps

1. **Calendar**: events for today and tomorrow (`list_events`). Say it
   explicitly when a day is empty ("today: no events").
2. **Mail**: unread threads of the last 3 days (`search_threads`,
   `is:unread newer_than:3d`). Name only those that need a reply or an
   action (max. 5); newsletters/ads as one summary line.
3. **Reminders**: read `<root>/40_private/assistent/reminders.md` (or wherever
   you keep dated reminders) -- name due and soon-due entries. Add new
   deadlines that show up in mails there (format: `[yyyy-mm-dd] text (source)`).
4. **Open items**: `<root>/00_System/offene-punkte.md` -- only the prio-1 count
   and what changed since the last briefing.
5. **Last work**: the 3 most recent session folders under `~/.claude/projects`
   -- one line.

## Output format

```
briefing sat 15.08.

events      today: 14:00 meeting (uni) | tomorrow: free
mail        2 need a reply: mueller (invoice), institute (contract)
            12 more: newsletters/info
deadlines   [2026-08-20] tax form (mail from 12.08.)
open        prio 1: 3 items (unchanged)
last        work/office (yesterday), venture/game (yesterday)
```

Then at most 2 sentences of judgement/suggestion ("draft the mueller reply?").
