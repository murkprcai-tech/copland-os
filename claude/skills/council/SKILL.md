---
name: council
description: The Council -- ask the same question in parallel to Claude, GPT (Codex CLI), Nemotron, Llama and Qwen, compare the answers, show a synthesis plus where they disagree. Use for important decisions, or when the user says "council", "ask everyone", "ask the council".
---

# The Council

Voices: Claude (you), Codex/GPT (`codex` CLI), Nemotron (OpenRouter free tier),
Llama 3.3 (Groq free tier), Qwen (OpenRouter free tier); optional Gemini Flash
and Mistral. All non-Claude voices run on free tiers (0 EUR). The helper
`copland/copland-rat.ps1` reports voices whose API key is missing -- only use
the ones that are configured. Default council: claude + gpt + nemotron + qwen.

## Steps

1. **Write the task yourself** -- precise, self-contained (the other models do
   not see this chat). Same wording for everyone.
2. **Start all voices in the background** (`run_in_background`):
   - Codex: `codex exec --skip-git-repo-check "<task>"`
   - Nemotron: `pwsh -NoProfile -File "<root>/00_System/copland/copland-rat.ps1" -Ki nemotron -Prompt "<task>"`
     (Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File ...`)
   - Groq: same with `-Ki groq`; Qwen: `-Ki qwen`; Gemini: `-Ki gemini`; Mistral: `-Ki mistral`
3. **Work out your own answer first**, before reading the others.
4. **Compare and synthesise**: build the best overall answer; adopt good points
   from the others and mark them.
5. **Output**: the synthesised answer, then a compact block:

```
the council
claude    ...one-line core claim
gpt       ...
nemotron  ...
llama     ...
disagree: ...where they contradict each other (1-2 lines, or "unanimous")
```

## Rules

- **Privacy**: third-party models get NOTHING private -- no personal folders,
  mail or calendar content, secrets, or real names from private life.
  Anonymise the task if needed.
- **Failure**: if a voice does not answer (no key, limit, timeout), note it in
  one line and continue with the rest. Never block.
- **Limits** (free tiers): Nemotron ~50/day, Groq ~1000/day, Gemini ~1500/day,
  Mistral ~500/day. The panel shows remaining calls; skip a voice when low.
- For quick second opinions `/dual` (Claude + GPT only) is enough.
