# Lailara LLC — Shared Project Instructions

Project-specific CLAUDE.md files extend or override anything here.

---

## Design System

Read `../lailara-design-system/LAILARA_DESIGN_SYSTEM.md` before any visual work — colors, typography, layout, components, charts, voice, interactions. It is the single source of truth. Do not guess at hex values, font choices, spacing, component states, or chart rules from memory. Open the file and use what it specifies.

If the design system repo is not cloned as a sibling directory, clone it:
```
git clone https://github.com/MsShawnP/lailara-design-system.git
```

---

## Learnings

`docs/solutions/` contains structured knowledge docs (bug fixes, design patterns, best practices) with YAML frontmatter for searchability. Check this directory before investigating a problem — a prior solution may already be documented.

---

Never write secrets, tokens, or passwords into tracked files, READMEs, or commit messages — use environment variables and secret stores only.
