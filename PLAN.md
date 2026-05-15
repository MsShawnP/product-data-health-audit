# PLAN — Product Data Health Audit Improvements

**Tier:** Medium
**Source:** Full 4-phase audit (2026-05-15)
**Current phase:** Session 3 complete, Session 4 (optional) remains

---

## Session 1: Publication Hygiene (Moves 1 + 2 + 5)

### Decomposition

**Goal:** Make the public repo clean enough that a technical reviewer who clones it sees professional hygiene, not dev scaffolding.

**Steps:**

- [x] **S1.1: Update .gitignore with all new rules**
    - Depends on: none
    - Add generated output rules: `output/charts/`, `output/*.xlsx`, `output/*.pdf`, `quarto/*.html`, `quarto/*.pdf`
    - Add dev script rules: `R/_*`, `working/`, `inspect_db.py`
    - Add sensitive file patterns: `.env`, `.env.*`, `.Renviron`, `*.pem`, `*.key`, `*.pfx`, `credentials*`
    - Done when: `grep -c "output/charts" .gitignore` returns 1, `grep -c "R/_" .gitignore` returns 1, `grep -c ".Renviron" .gitignore` returns 1

- [x] **S1.2: Remove tracked generated files from git index**
    - Depends on: S1.1
    - `git rm -r --cached output/charts/` (1,674 files including chart PNGs, HTML interactives, RDS objects, and 1,224 font/JS/CSS dependency files)
    - `git rm --cached output/cinderhaven_audit.xlsx output/compliance_timeline.pdf output/scorecard.pdf output/PHASE1_DATA_FINDINGS.md output/canonical_numbers.md`
    - `git rm --cached quarto/report.html quarto/report.pdf quarto/dashboard.html quarto/tearsheet.pdf` (if tracked)
    - Done when: `git ls-files -- "output/charts/" | wc -l` returns 0 AND files still exist on disk (not deleted, just untracked)

- [x] **S1.3: Remove tracked dev scripts from git index**
    - Depends on: S1.1
    - `git rm --cached` all `R/_*.R`, `R/_*.py`, `working/*`, `inspect_db.py`
    - Done when: `git ls-files -- "R/_*" "working/" "inspect_db.py" | wc -l` returns 0

- [x] **S1.4: Delete stale root-level dashboard.qmd**
    - Depends on: none
    - Verify `quarto/dashboard.qmd` is the canonical copy (referenced by pipeline)
    - Delete root `dashboard.qmd` (keep root `dashboard.css` only if `quarto/dashboard.qmd` references it via relative path)
    - Done when: `ls dashboard.qmd` fails; `quarto/dashboard.qmd` still exists; no broken references in pipeline

- [x] **S1.5: Fix CI workflow**
    - Depends on: none (independent of git cleanup)
    - Add `submodules: recursive` to checkout step
    - Add Python 3 setup step (`actions/setup-python@v5`)
    - Add `./setup.sh` step before R pipeline
    - Add top-level `permissions: contents: read`
    - Done when: YAML parses without error (`python -c "import yaml; yaml.safe_load(open('.github/workflows/render.yml'))"`) and all four additions present in the file

- [x] **S1.6: Move process docs to docs/process/**
    - Depends on: none
    - Create `docs/process/`
    - Move: `cinderhaven_full_report_prose_v2.md`, `executive_tearsheet_prose.md`, `excel_workbook_content.md`, `phase7_shareable_artifacts_content.md`, `phase8_writing_deliverables.md`, `quarto_report_scope_final.md`
    - Keep at root: `README.md`, `data_generation_log.md` (referenced by README)
    - Done when: `ls docs/process/ | wc -l` returns 6; root has only `README.md`, `data_generation_log.md`, `AUDIT.md`, `PLAN.md` as .md files

- [x] **S1.7: Update README**
    - Depends on: S1.4 (stale dashboard gone), S1.6 (docs moved)
    - Update directory tree to match actual post-cleanup structure
    - Remove "Companion artifacts" section (placeholder links are worse than omission — re-add when URLs exist)
    - Add Windows note: "requires bash — on Windows use WSL or Git Bash" to setup instructions
    - Done when: every directory/file listed in README tree exists on disk; no `[link]` or `[GitHub link]` placeholders remain

**Parallel execution map:**
```
S1.1 ──→ S1.2 (depends on .gitignore)
     ──→ S1.3 (depends on .gitignore)
S1.4 (independent)
S1.5 (independent)
S1.6 (independent)
          S1.4 + S1.6 ──→ S1.7 (depends on both)
```

S1.1 goes first (everything else flows from it or is independent). S1.4, S1.5, S1.6 can run in parallel with S1.2/S1.3.

## Session 2: Single Source of Truth (Moves 3 + 4)

- [x] Compute velocity in 02_build_frames.R as canonical frame (F12)
- [x] Remove velocity computation from 06_excel_workbook.R (48 lines removed)
- [x] Remove velocity computation from dashboard.qmd (50 lines removed, reads pre-built frame)
- [x] Consolidate dollar_short → alias to fmt_dollar_short from 00_theme.R
- [x] Delete shadow palettes in 05_supporting_charts.R, alias to canonical colors
- [x] Replace 11 theme_audit() calls with theme_cinderhaven()
- [ ] Move read_p helper into 00_theme.R, delete 9 copies (deferred — low leverage)
- [x] Add stopifnot(nrow(...) > 0) after each frame in 02_build_frames.R
- [x] Wrap source() calls in tryCatch in run_all.R
- [x] Fix hardcoded path in 00_theme.R self-test block
- [ ] Add critical assertions to 03_verify.R (deferred — verify script is informational)

## Session 3: Live Demo + Optimization (Moves 6 + 7)

- [ ] Redeploy Shiny calculator to shinyapps.io (needs credentials — user action)
- [x] Add GitHub Pages deployment to CI (assembles _site/ from pipeline outputs)
- [x] Combine two report.qmd renders into one (omit --to, both formats in single pass)
- [x] Enable freeze: auto in _quarto.yml
- [x] Parallelize three independent PDF renders in run_all.R (mclapply on Unix, sequential on Windows)

## Session 4 (Optional): Parameterize (Move 8)

- [ ] Extract company-specific values into config file
- [ ] Make report prose template-aware
- [ ] Add second demo company or blank template mode
- [ ] Update README to describe reusability
