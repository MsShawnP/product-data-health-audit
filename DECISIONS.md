# Decisions

## 2026-05-15: Parameterize pipeline via config.yml, not full templating

**Decision:** The R pipeline reads `output_prefix` and `company.short_name` from `config.yml`. Quarto front matter (title, subtitle, author, date) and report prose stay as manual per-engagement updates.

**Rationale:** The analytical pipeline (charts, Excel workbook, data frames) is genuinely reusable across companies. But narrative interpretation — "8 SKUs drive half your chargeback costs" — is always custom. Pretending otherwise with Jinja-style templates would be dishonest for a portfolio piece and would produce worse output than writing prose per engagement.

**What this means:** To run for a new company, update `config.yml` + `.Renviron`, populate the Postgres database, rewrite Quarto prose, run `Rscript R/run_all.R`. The pipeline, charts, and workbook structure carry over unchanged.

## 2026-05-15: SQLite to Postgres migration (resolved during merge)

**Decision:** Accepted the main branch's migration from SQLite to Postgres. Removed `data.database` from `config.yml` since the connection is now via `DATABASE_URL` in `.Renviron`.

**Rationale:** The Postgres migration happened on main while the improvement PR was open. Database connection is an infrastructure concern managed via environment variables, not a config.yml parameter.
