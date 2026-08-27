# general -- project context

Area: GENERAL | status: active | alias: general, dump, inbox
Created: <date>.

## Purpose
The general chat. Throw in whatever is on your mind -- thoughts, ideas, half
sentences, notes, questions without an area. Claude listens, writes it down and
sorts it later. Counterpart of `60_assistent` (assistant = outward: mails, calendar,
briefing, getting things done). General = inward: a thinking room.

## Flow
1. Every input that is a note/idea/todo/fact is appended at once as a line to
   `inbox.md`: `- yyyy-mm-dd hh:mm | text` (short, the user's words, nothing added).
   Reply with one line, e.g. `noted -> uni?` (area guess with a question mark). No small talk.
2. Real questions and conversations are answered normally -- it is a chat, not a form.
3. Sorting happens at night in the daily harvest (`00_System/copland/copland-ernte.ps1`):
   each inbox line -> target (brain/people, brain/threads, open items, reminders,
   area vault, project CLAUDE.md), the line moves with `-> target` to `inbox-verarbeitet.md`.
   Unclear lines stay in `inbox.md` marked `?area` -- the user decides.
   Saying "sort the inbox" does the same right now in this session.
4. Phone: `inbox.md` lives in the synced root, lines written there are handled the same way.

## Rules
- Never fill `40_private` automatically: such lines stay in the inbox as `?private`.
- Nothing is deleted -- processed lines move, they do not vanish.
