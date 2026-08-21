---
name: dual
description: Dual mode -- give the same task to Claude and Codex (GPT) in parallel, compare the answers and synthesise the best. Use for important decisions, texts, analyses, reviews -- or when the user says "dual", "ask both", "what does codex think".
---

# dual -- claude + codex in parallel

Two models, one task, one synthesised answer.

## 1. Formulate the task
Turn `$ARGUMENTS` or the conversation context into a precise, self-contained
prompt (Codex does not see the chat history -- put everything it needs in).

**Privacy:** Codex gets NO private content -- nothing from private folders,
no mail/calendar data, no plain-text secrets. When in doubt, abstract the task.

## 2. Start Codex in the background
```bash
codex exec --skip-git-repo-check "<task>"
```
Run it with `run_in_background: true` so you can work in parallel.

## 3. Work out your own answer
While Codex runs: solve the task yourself, completely. Do not wait for Codex
or lean on it.

## 4. Compare and synthesise
Read the Codex result, then:
- Where do both agree? (= high confidence)
- Where do they contradict? Who has the better argument?
- What did one see that the other missed?

## 5. Output
The synthesised answer first, then a short block:

```
dual
claude   ...one-line core claim
gpt      ...
differ:  ...or "agree"
```
