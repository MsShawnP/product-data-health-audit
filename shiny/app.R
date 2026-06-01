# shiny/app.R — Data Debt Calculator
#
# Standalone tool. Not specific to any company. The default inputs are a
# reference catalog of 50 SKUs and 4 retailers; change them to match
# your own and the rest of the page updates.
#
# Cost model (3 components):
#   chargebacks_yr   = C (user input)
#   stalled_launch   = N (1 - P) * A * launch_share * (delay_days / 365)
#   shelf_loss       = N (1 - P) * A * deauth_diff_rate
# Constants below were calibrated so the reference defaults reproduce the
# ~$430k total that appears in the case study.

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(ggplot2)
  library(dplyr)
  library(scales)
  library(htmltools)
})

# ---- palette (Lailara Design System v2) ----------------------------------
PAL <- list(
  canvas     = "#f5f3ee",
  red        = "#cc100a",
  red_light  = "#ee8880",
  chicago    = "#1f2e7a",
  chicago_lt = "#8e9ad0",
  hk         = "#158f75",
  hk_dark    = "#0c6552",
  tokyo      = "#b82d4a",
  tokyo_lt   = "#e68a9a",
  sg         = "#ee8a2a",
  sg_dark    = "#7a3d10",
  ink        = "#0d0d0d",
  text       = "#333333",
  text_sec   = "#595959",
  reference  = "#666666",
  gridline   = "#d9d9d9",
  surface    = "#f2f2f2",
  # Backward-compatible aliases
  navy       = "#1f2e7a",
  coral      = "#b82d4a",
  teal       = "#158f75",
  blue       = "#1f2e7a",
  blue_muted = "#8e9ad0",
  text_muted = "#595959",
  bg_pale    = "#d9d9d9",
  bg_paler   = "#f2f2f2",
  white      = "#f5f3ee"
)

# ---- model constants -----------------------------------------------------
LAUNCH_SHARE   <- 0.25     # share of failing SKUs in a launch window in any year
DELAY_DAYS     <- 40       # calibrated so N=50 defaults reproduce the ~$430k case-study total
DEAUTH_DIFF    <- 0.0010   # incremental annual deauth rate attributable to low data quality
TODAY          <- Sys.Date()
GS1_SUNRISE    <- as.Date("2027-12-31")
FSMA_204       <- as.Date("2028-07-20")

# ---- model functions -----------------------------------------------------
cost_components <- function(N, R, C, P, A) {
  failing <- N * (1 - P)
  stalled <- failing * A * LAUNCH_SHARE * (DELAY_DAYS / 365)
  shelf   <- failing * A * DEAUTH_DIFF
  list(chargebacks = C, stalled = stalled, shelf = shelf,
       total = C + stalled + shelf)
}

scale_projection <- function(N, R, C, P, A, factor) {
  # Both SKU count and chargebacks grow with scale; per-SKU defect rate
  # holds. Retailer count is held — increasing it is a separate lever.
  cc <- cost_components(N * factor, R, C * factor, P, A)
  cc$total
}

debt_density <- function(N, C, A) {
  rev <- N * A
  if (rev <= 0) return(NA_real_)
  C / (rev / 1e6)
}

density_band <- function(d) {
  if (is.na(d))         list(label = "—",         color = PAL$text_muted, body = "Set inputs to see your density score.")
  else if (d <  1000)   list(label = "Healthy",   color = PAL$teal,      body = "Below $1,000 per $1M of revenue. The data is clean enough that defects don't show up in chargeback dollars.")
  else if (d <  3000)   list(label = "Typical",   color = PAL$blue_muted,body = "$1,000–$3,000 per $1M is typical for specialty food and CPG without a managed product data process.")
  else if (d <  5000)   list(label = "Elevated",  color = PAL$coral,     body = "$3,000–$5,000 per $1M means defects are concentrated in the SKUs that move volume.")
  else                  list(label = "Serious",   color = PAL$red,       body = "Above $5,000 per $1M. The catalog is paying chargebacks at a rate that materially affects net margin.")
}

readiness_band <- function(P) {
  if (P >= 0.9) list(label = "Likely ready",
                     color = PAL$teal,
                     body  = "Your pass rate clears the bar. Maintain it through the GS1 transition window.")
  else if (P >= 0.7) list(label = "On track",
                          color = PAL$blue_muted,
                          body  = "Failing SKUs are a manageable workload. Address them before Q4 2027.")
  else if (P >= 0.4) list(label = "At risk",
                          color = PAL$coral,
                          body  = "Less than 50% passing. The failing SKUs are blockers for both compliance transitions.")
  else list(label = "Not ready",
            color = PAL$red,
            body  = "The catalog is not in a state to participate in either transition. Cleanup needs to start now.")
}

# Cost-of-Delay model: cumulative cost as a function of months waited.
# Three components compound: chargebacks accrue monthly, shelf loss scales
# linearly with time, and an emergency-remediation multiplier kicks in as
# the deadline approaches.
emergency_mult <- function(months_waited, months_to_deadline) {
  remaining <- months_to_deadline - months_waited
  if (remaining > 12)      1.0
  else if (remaining > 6)  1.4
  else if (remaining > 3)  1.9
  else if (remaining > 0)  2.6
  else                     3.5    # past the deadline
}

cost_of_delay <- function(N, R, C, P, A) {
  cc <- cost_components(N, R, C, P, A)
  base_fix_hours    <- 52           # from the methodology appendix
  base_hourly_rate  <- 60           # generic clerical rate
  base_fix_cost     <- base_fix_hours * base_hourly_rate

  months_to_deadline <- as.numeric(GS1_SUNRISE - TODAY) / 30
  ts <- 1:24
  data.frame(
    month = ts,
    chargebacks_accrued  = (cc$chargebacks / 12) * ts,
    shelf_loss_accrued   = (cc$shelf       / 12) * ts,
    stalled_accrued      = (cc$stalled     / 12) * ts,
    fix_cost = vapply(ts, function(t) {
      base_fix_cost * emergency_mult(t, months_to_deadline)
    }, numeric(1))
  ) |>
    mutate(total_cost = chargebacks_accrued + shelf_loss_accrued +
                        stalled_accrued + fix_cost)
}

# URL for the case-study link in the top-right of the navbar. Points at the
# rendered HTML report on the project's GitHub Pages site.
CASE_STUDY_URL <- "https://audit.lailarallc.com/quarto/report.html"

dollar_short <- function(x) {
  vapply(x, function(v) {
    if (is.na(v))            "—"
    else if (abs(v) >= 1e6)  sprintf("$%.2fM", v / 1e6)
    else if (abs(v) >= 1e3)  sprintf("$%.0fk", v / 1e3)
    else paste0("$", formatC(round(v), big.mark = ",", format = "d"))
  }, character(1))
}

theme_calc <- function() {
  theme_minimal(base_size = 12, base_family = "Source Sans 3") +
    theme(
      plot.background    = element_rect(fill = PAL$canvas, color = NA),
      panel.background   = element_rect(fill = PAL$canvas, color = NA),
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = PAL$gridline, linewidth = 0.3),
      axis.text          = element_text(color = PAL$text_sec),
      axis.title         = element_text(color = PAL$text_sec, size = 11),
      plot.title         = element_text(family = "Playfair Display",
                                         face = "bold", color = PAL$ink,
                                         hjust = 0, size = 14),
      plot.subtitle      = element_text(color = PAL$text_sec, hjust = 0,
                                         size = 11, margin = margin(b = 6)),
      plot.caption       = element_text(color = PAL$text_sec, hjust = 0,
                                         size = 9, face = "italic",
                                         margin = margin(t = 6)),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      legend.position = "none"
    )
}

# =========================================================================
# UI
# =========================================================================

theme_bs <- bs_theme(
  version = 5,
  bg = PAL$canvas, fg = PAL$text,
  primary = PAL$chicago,
  secondary = PAL$chicago_lt,
  success = PAL$hk,
  warning = PAL$tokyo,
  danger = PAL$red,
  base_font = font_google("Source Sans 3", local = FALSE),
  heading_font = font_google("Playfair Display", local = FALSE)
) |>
  bs_add_rules(sprintf("
    .stat-card { background: %s; border-radius: 2px; padding: 14px 16px;
                 border-left: 4px solid %s; }
    .stat-card .stat-num { font-family: 'Playfair Display', Georgia, serif;
                           font-size: 1.8rem; font-weight: 700; color: %s;
                           line-height: 1.0; }
    .stat-card .stat-lbl { color: %s; font-size: 0.85rem; margin-top: 2px; }
    .stat-card .stat-sub { color: %s; font-size: 0.75rem; margin-top: 6px; }
    .lead-num { font-family: 'Playfair Display', Georgia, serif;
                font-size: 3rem; font-weight: 700; color: %s; line-height: 1; }
    .lead-lbl { color: %s; font-size: 0.95rem; margin-top: 4px; }
    .pill { display: inline-block; padding: 2px 10px; border-radius: 2px;
            font-size: 0.78rem; font-weight: 600; color: white; }
    .interp { background: %s; padding: 14px 18px; border-radius: 2px;
              border-left: 4px solid %s; line-height: 1.55; }
    .footer-link { color: %s; font-weight: 600; }
    .footer-link:hover { color: %s; }
    .sr-only-focusable:focus { outline: 2px solid %s; outline-offset: 2px; }
    label.control-label { font-weight: 600; color: %s; }
    .form-text { color: %s; font-size: 0.78rem; }
  ",
  PAL$surface, PAL$chicago, PAL$red, PAL$text_sec, PAL$text_sec,
  PAL$red, PAL$text_sec,
  PAL$gridline, PAL$chicago,
  PAL$chicago, PAL$red,
  PAL$ink, PAL$text, PAL$text_sec))

ui <- page_navbar(
  title = "Data Debt Calculator",
  theme = theme_bs,
  lang = "en",
  navbar_options = navbar_options(bg = PAL$chicago, underline = TRUE),
  header = tags$header(
    tags$style(HTML("
      .navbar-brand { font-weight: 700; letter-spacing: -0.01em; }
      .navbar { padding-top: 0.4rem; padding-bottom: 0.4rem; }
    ")),
    # Skip-link for keyboard users.
    tags$a(href = "#main-content", class = "sr-only-focusable",
           tabindex = "0",
           style = "position:absolute; left:-9999px; top:auto;",
           "Skip to main content")
  ),
  nav_panel(
    title = "Calculator",
    div(id = "main-content", role = "main",
      layout_sidebar(
        sidebar = sidebar(
          width = 320,
          title = tags$h2("Your inputs", style = "font-size:1.05rem; margin: 0 0 4px 0;"),
          p(class = "small text-muted",
            style = "margin-top:0;",
            "Defaults match a reference catalog. Change them to match your own."),
          numericInput("n_skus", "SKU count",
                       value = 50, min = 20, max = 500, step = 10,
                       width = "100%"),
          tags$div(class = "form-text",
                   "How many SKUs are in your active catalog. Range: 20 to 500."),
          numericInput("n_retailers", "Retailer count",
                       value = 4, min = 1, max = 12, step = 1,
                       width = "100%"),
          tags$div(class = "form-text",
                   "Distinct retailer accounts you ship to. Range: 1 to 12."),
          numericInput("annual_cb", "Annual chargebacks ($)",
                       value = 112000, min = 0, max = 5e6, step = 1000,
                       width = "100%"),
          tags$div(class = "form-text",
                   "What retailers deduct from your settlement statements each year."),
          sliderInput("pass_rate", "Data quality pass rate",
                      value = 0.60, min = 0, max = 1, step = 0.01,
                      ticks = FALSE, width = "100%"),
          tags$div(class = "form-text",
                   "Share of SKUs that pass retailer required-field checks."),
          numericInput("rev_per_sku", "Avg annual revenue per SKU ($)",
                       value = 559000, min = 1000, max = 5e6, step = 1000,
                       width = "100%"),
          tags$div(class = "form-text",
                   "Trailing-twelve-month sales divided by active SKU count."),
          tags$hr(),
          tags$p(class = "small text-muted",
                 "Numbers update live as you change any input.")
        ),

        div(role = "region", `aria-labelledby` = "lead-heading",
          tags$h2(id = "lead-heading", class = "visually-hidden",
                  "Annual cost of data debt"),
          div(class = "lead-num", textOutput("lead_total", inline = TRUE)),
          div(class = "lead-lbl", "estimated annual cost of data debt at your current inputs"),

          tags$hr(),

          # Three-card row: 2x scale, 3x scale, density
          layout_columns(col_widths = c(4, 4, 4),
            div(class = "stat-card", role = "region",
              `aria-label` = "Cost at 2x scale",
              div(class = "stat-num", textOutput("scale_2x", inline = TRUE)),
              div(class = "stat-lbl", "Cost at 2× SKU count"),
              div(class = "stat-sub", textOutput("scale_2x_pct", inline = TRUE))
            ),
            div(class = "stat-card", role = "region",
              `aria-label` = "Cost at 3x scale",
              div(class = "stat-num", textOutput("scale_3x", inline = TRUE)),
              div(class = "stat-lbl", "Cost at 3× SKU count"),
              div(class = "stat-sub", textOutput("scale_3x_pct", inline = TRUE))
            ),
            div(class = "stat-card", role = "region",
              `aria-label` = "Data debt density",
              div(class = "stat-num", textOutput("density_val", inline = TRUE)),
              div(class = "stat-lbl", "Chargebacks per $1M of revenue"),
              div(class = "stat-sub", uiOutput("density_pill"))
            )
          ),

          tags$hr(),

          # Cost composition + sensitivity
          layout_columns(col_widths = c(6, 6),
            div(role = "region", `aria-label` = "Cost composition",
              tags$h3("How that total breaks down", style = "font-size:1.05rem;"),
              plotOutput("composition_plot", height = "230px")
            ),
            div(role = "region", `aria-label` = "Sensitivity analysis",
              tags$h3("Which input moves the number most",
                      style = "font-size:1.05rem;"),
              plotOutput("sensitivity_plot", height = "230px"),
              tags$div(class = "form-text",
                       "Effect on annual cost from a +10% change in each input.")
            )
          ),

          tags$hr(),

          # Compliance timeline
          div(role = "region", `aria-label` = "Compliance timeline",
            tags$h3("Compliance timeline", style = "font-size:1.05rem;"),
            uiOutput("compliance_block"),
            plotOutput("timeline_plot", height = "150px")
          ),

          tags$hr(),

          # Interpretation paragraph
          div(role = "region", `aria-label` = "Interpretation",
            tags$h3("Reading your inputs", style = "font-size:1.05rem;"),
            div(class = "interp", uiOutput("interpretation"))
          )
        )
      )
    )
  ),
  nav_panel(
    title = "Cost of Delay",
    div(role = "main",
      layout_sidebar(
        sidebar = sidebar(
          width = 320,
          title = tags$h2("Your inputs", style = "font-size:1.05rem; margin: 0 0 4px 0;"),
          p(class = "small text-muted",
            "Same inputs as the Calculator tab. Cost-of-Delay shows what changes when you wait."),
          numericInput("n_skus2", "SKU count",
                       value = 50, min = 20, max = 500, step = 10),
          numericInput("n_retailers2", "Retailer count",
                       value = 4, min = 1, max = 12, step = 1),
          numericInput("annual_cb2", "Annual chargebacks ($)",
                       value = 112000, min = 0, max = 5e6, step = 1000),
          sliderInput("pass_rate2", "Data quality pass rate",
                      value = 0.60, min = 0, max = 1, step = 0.01,
                      ticks = FALSE),
          numericInput("rev_per_sku2", "Avg annual revenue per SKU ($)",
                       value = 559000, min = 1000, max = 5e6, step = 1000)
        ),

        div(role = "region", `aria-label` = "Cost of delay",
          tags$h2("Every month of delay costs more than the last",
                  style = paste0("font-size:1.4rem; color:", PAL$chicago)),
          tags$p(style = paste0("color:", PAL$text_muted, "; max-width:60ch;"),
                 "Three things compound while a data defect sits unfixed: ",
                 "chargebacks accrue every month, shelf is lost as retailers ",
                 "deauthorize SKUs that fail their checks, and the per-SKU ",
                 "remediation cost rises as the GS1 Sunrise 2027 deadline ",
                 "approaches and emergency-rate fixes become the only option."),
          tags$p(style = paste0("color:", PAL$text_muted, "; max-width:60ch;"),
                 "Major retailers aren't waiting for federal deadlines. ",
                 "Walmart and Kroger began enforcing traceability requirements ",
                 "in 2025. Over 70 retailers have announced compliance ",
                 "programs with timelines ahead of the FDA's."),

          tags$hr(),

          layout_columns(col_widths = c(4, 4, 4),
            div(class = "stat-card",
              div(class = "stat-num", textOutput("cod_m1", inline = TRUE)),
              div(class = "stat-lbl", "Fix in Month 1"),
              div(class = "stat-sub", "Base remediation cost only.")),
            div(class = "stat-card",
              div(class = "stat-num", textOutput("cod_m12", inline = TRUE)),
              div(class = "stat-lbl", "Wait 12 months"),
              div(class = "stat-sub", textOutput("cod_m12_mult", inline = TRUE))),
            div(class = "stat-card",
              div(class = "stat-num", textOutput("cod_m18", inline = TRUE)),
              div(class = "stat-lbl", "Wait 18 months"),
              div(class = "stat-sub", textOutput("cod_m18_mult", inline = TRUE)))
          ),

          tags$hr(),
          tags$h3("Cumulative cost by month waited",
                  style = "font-size:1.05rem;"),
          plotOutput("cod_curve", height = "320px"),
          tags$div(class = "form-text",
                   "The dashed marker shows the GS1 Sunrise 2027 deadline. ",
                   "After the deadline, fixes are still possible, but cost ",
                   "an emergency-rate premium and don't recover lost shelf.")
        )
      )
    )
  ),
  nav_spacer(),
  nav_item(
    tags$a(href = CASE_STUDY_URL,
           class = "footer-link",
           target = "_blank", rel = "noopener",
           style = sprintf("color:%s; font-weight:600;", PAL$white),
           "See what a complete product data audit looks like →")
  )
)

# =========================================================================
# Server
# =========================================================================

server <- function(input, output, session) {

  # Validate a numericInput value: must be a finite scalar within [lo, hi].
  # numericInput returns NA when the user clears the field; that NA must
  # NOT propagate into reactives — we want the prior valid value to hold
  # so the UI stays calm during typing.
  ok_num <- function(x, lo, hi = Inf) {
    v <- suppressWarnings(as.numeric(x))
    length(v) == 1 && !is.na(v) && is.finite(v) && v >= lo && v <= hi
  }

  # Last-known-good values for the 5 inputs. Seeded with the reference
  # defaults; updated by the per-input observers below ONLY when the
  # incoming value passes ok_num().
  last <- reactiveValues(N = 50, R = 4, C = 112000, P = 0.60, A = 559000)

  observe({ if (ok_num(input$n_skus,      1, 500))  last$N <- as.numeric(input$n_skus) })
  observe({ if (ok_num(input$n_retailers, 1, 12))   last$R <- as.numeric(input$n_retailers) })
  observe({ if (ok_num(input$annual_cb,   0))       last$C <- as.numeric(input$annual_cb) })
  observe({ if (ok_num(input$pass_rate,   0, 1))    last$P <- as.numeric(input$pass_rate) })
  observe({ if (ok_num(input$rev_per_sku, 1000))    last$A <- as.numeric(input$rev_per_sku) })

  observe({ if (ok_num(input$n_skus2,      1, 500)) last$N <- as.numeric(input$n_skus2) })
  observe({ if (ok_num(input$n_retailers2, 1, 12))  last$R <- as.numeric(input$n_retailers2) })
  observe({ if (ok_num(input$annual_cb2,   0))      last$C <- as.numeric(input$annual_cb2) })
  observe({ if (ok_num(input$pass_rate2,   0, 1))   last$P <- as.numeric(input$pass_rate2) })
  observe({ if (ok_num(input$rev_per_sku2, 1000))   last$A <- as.numeric(input$rev_per_sku2) })

  # Mirror Calculator → Cost-of-Delay (and back) so users only fill the
  # inputs once. The naive bidirectional setup creates a feedback loop:
  # changing input$X mirrors to input$X2, whose round-trip echo re-fires
  # the X2 → X mirror, which echoes back, etc.
  #
  # Loop-break: per-input "mirror_lock" flags. When mirror_A_to_B fires,
  # it pre-sets B's lock to TRUE. When B's mirror observer fires from the
  # echo, it sees its own lock TRUE, resets it to FALSE, and returns
  # without re-mirroring back to A. Each mirror_lock entry is single-use
  # — one consumed lock per programmatic update, so subsequent legitimate
  # user edits to either input still propagate normally.
  mirror_lock <- reactiveValues(
    n_skus       = FALSE, n_skus2       = FALSE,
    n_retailers  = FALSE, n_retailers2  = FALSE,
    annual_cb    = FALSE, annual_cb2    = FALSE,
    pass_rate    = FALSE, pass_rate2    = FALSE,
    rev_per_sku  = FALSE, rev_per_sku2  = FALSE)

  mirror_input <- function(src_id, dst_id, lo, hi = Inf,
                           kind = c("numeric", "slider")) {
    kind <- match.arg(kind)
    observeEvent(input[[src_id]], ignoreInit = TRUE, {
      # If this fire is the echo of a previous mirror write, swallow it
      # and reset the lock so the next legitimate change goes through.
      if (isTRUE(mirror_lock[[src_id]])) {
        mirror_lock[[src_id]] <- FALSE
        return()
      }
      if (!ok_num(input[[src_id]], lo, hi)) return()
      v <- as.numeric(input[[src_id]])
      # Pre-arm the destination's lock so its observer recognizes the
      # incoming change as our programmatic update, not user input.
      mirror_lock[[dst_id]] <- TRUE
      if (kind == "slider") updateSliderInput(session, dst_id, value = v)
      else                  updateNumericInput(session, dst_id, value = v)
    })
  }

  # Calculator-tab → Cost-of-Delay tab
  mirror_input("n_skus",       "n_skus2",       lo = 1,    hi = 500)
  mirror_input("n_retailers",  "n_retailers2",  lo = 1,    hi = 12)
  mirror_input("annual_cb",    "annual_cb2",    lo = 0)
  mirror_input("pass_rate",    "pass_rate2",    lo = 0,    hi = 1, kind = "slider")
  mirror_input("rev_per_sku",  "rev_per_sku2",  lo = 1000)
  # Cost-of-Delay tab → Calculator tab
  mirror_input("n_skus2",      "n_skus",        lo = 1,    hi = 500)
  mirror_input("n_retailers2", "n_retailers",   lo = 1,    hi = 12)
  mirror_input("annual_cb2",   "annual_cb",     lo = 0)
  mirror_input("pass_rate2",   "pass_rate",     lo = 0,    hi = 1, kind = "slider")
  mirror_input("rev_per_sku2", "rev_per_sku",   lo = 1000)

  # Reactive: always returns the last-known-good values, never NA.
  # Downstream reactives (cost_components, scale_projection, cost_of_delay,
  # interpretation paragraph, all charts) read from this and stay stable
  # even while the user is mid-edit on any input.
  inp <- reactive({
    list(N = last$N, R = last$R, C = last$C, P = last$P, A = last$A)
  })

  cc <- reactive({
    cost_components(inp()$N, inp()$R, inp()$C, inp()$P, inp()$A)
  })

  # ---- Lead number + scale projections + density ----
  output$lead_total <- renderText(dollar_short(cc()$total))

  output$scale_2x <- renderText({
    dollar_short(scale_projection(inp()$N, inp()$R, inp()$C, inp()$P, inp()$A, 2))
  })
  output$scale_2x_pct <- renderText({
    tot <- cc()$total
    if (is.null(tot) || tot == 0) return("—")
    sprintf("%.1fx today's total", scale_projection(inp()$N, inp()$R, inp()$C, inp()$P, inp()$A, 2) / tot)
  })
  output$scale_3x <- renderText({
    dollar_short(scale_projection(inp()$N, inp()$R, inp()$C, inp()$P, inp()$A, 3))
  })
  output$scale_3x_pct <- renderText({
    tot <- cc()$total
    if (is.null(tot) || tot == 0) return("—")
    sprintf("%.1fx today's total", scale_projection(inp()$N, inp()$R, inp()$C, inp()$P, inp()$A, 3) / tot)
  })

  output$density_val <- renderText({
    d <- debt_density(inp()$N, inp()$C, inp()$A)
    if (is.na(d)) "—" else paste0("$", formatC(round(d), big.mark = ",", format = "d"))
  })
  output$density_pill <- renderUI({
    d <- debt_density(inp()$N, inp()$C, inp()$A)
    band <- density_band(d)
    span(class = "pill",
         style = sprintf("background:%s;", band$color),
         band$label)
  })

  # ---- Composition stacked bar ----
  output$composition_plot <- renderPlot({
    c <- cc()
    df <- data.frame(
      component = factor(c("Chargebacks", "Stalled launches", "Shelf loss"),
                          levels = c("Shelf loss", "Stalled launches", "Chargebacks")),
      value = c(c$chargebacks, c$stalled, c$shelf)
    )
    df$label <- dollar_short(df$value)

    ggplot(df, aes(x = "", y = value, fill = component)) +
      geom_col(width = 0.55) +
      geom_text(aes(label = label),
                position = position_stack(vjust = 0.5),
                color = "white", fontface = "bold", size = 4) +
      scale_fill_manual(values = c(
        "Chargebacks"      = PAL$red,
        "Stalled launches" = PAL$coral,
        "Shelf loss"       = PAL$blue_muted)) +
      scale_y_continuous(labels = dollar_short,
                         expand = expansion(mult = c(0, 0.02))) +
      coord_flip() +
      labs(x = NULL, y = NULL,
           caption = paste0(
             "Chargebacks: what retailers deduct now.  ",
             "Stalled launches: revenue lost while failing SKUs sit in queue.  ",
             "Shelf loss: deauthorizations driven by quality.")) +
      theme_calc() +
      theme(legend.position = "top",
            legend.title = element_blank(),
            axis.text.x = element_text(),
            axis.text.y = element_blank(),
            axis.ticks = element_blank(),
            panel.grid.major.y = element_blank(),
            panel.grid.major.x = element_line(color = PAL$bg_pale, linewidth = 0.4))
  }, res = 90)

  # ---- Sensitivity bar ----
  output$sensitivity_plot <- renderPlot({
    base <- cc()$total
    # Apply a +10% relative change to a single input and return the new
    # total annual cost. Pass rate uses the same +10% relative bump as
    # every other input — but it's capped at 1.0, since a probability
    # can't exceed certainty.
    bump <- function(field) {
      v <- inp()
      v[[field]] <- v[[field]] * 1.10
      if (field == "P") v$P <- min(1, v$P)
      cost_components(v$N, v$R, v$C, v$P, v$A)$total
    }

    df <- tibble::tribble(
      ~lever,                 ~new,
      "SKU count (+10%)",      bump("N"),
      "Chargebacks (+10%)",    bump("C"),
      "Pass rate (+10%)",      bump("P"),
      "Revenue per SKU (+10%)",bump("A")
    )
    df$delta_pct <- (df$new - base) / base
    df$lever     <- factor(df$lever, levels = df$lever[order(df$delta_pct)])
    df$label     <- sprintf("%+0.1f%%", df$delta_pct * 100)

    ggplot(df, aes(x = delta_pct, y = lever, fill = delta_pct)) +
      geom_col(width = 0.65) +
      geom_text(aes(label = label),
                hjust = ifelse(df$delta_pct >= 0, -0.05, 1.05),
                size = 3.6, color = PAL$text) +
      scale_x_continuous(labels = percent_format(accuracy = 1),
                         expand = expansion(mult = c(0.15, 0.20))) +
      scale_fill_gradient2(low = PAL$teal, mid = PAL$bg_pale,
                            high = PAL$red, midpoint = 0) +
      labs(x = "Change in annual cost", y = NULL) +
      theme_calc() +
      theme(panel.grid.major.x = element_line(color = PAL$bg_pale, linewidth = 0.4),
            panel.grid.major.y = element_blank())
  }, res = 90)

  # ---- Compliance block + timeline ----
  output$compliance_block <- renderUI({
    days_gs1  <- as.numeric(GS1_SUNRISE - TODAY)
    days_fsma <- as.numeric(FSMA_204    - TODAY)
    rb <- readiness_band(inp()$P)
    div(
      div(style = "display:flex; gap:24px; flex-wrap: wrap; margin-bottom: 8px;",
        div(
          tags$strong("GS1 Sunrise 2027:"),
          " ",
          if (days_gs1 > 0) sprintf("%d days from today (%s)", days_gs1, format(GS1_SUNRISE, "%b %Y"))
          else              "deadline has passed"
        ),
        div(
          tags$strong("FSMA Rule 204:"),
          " ",
          if (days_fsma > 0) sprintf("%d days from today (%s)", days_fsma, format(FSMA_204, "%b %Y"))
          else               "deadline has passed"
        )
      ),
      div(span(class = "pill",
               style = sprintf("background:%s; margin-right:8px;", rb$color),
               rb$label),
          span(style = sprintf("color:%s;", PAL$text), rb$body))
    )
  })

  output$timeline_plot <- renderPlot({
    deadlines <- data.frame(
      x   = c(TODAY, GS1_SUNRISE, FSMA_204),
      lbl = c(paste0("Today (", format(TODAY, "%b %Y"), ")"),
              paste0("GS1 Sunrise 2027 (", format(GS1_SUNRISE, "%b %Y"), ")"),
              paste0("FSMA Rule 204 (", format(FSMA_204, "%b %Y"), ")")),
      col = c(PAL$teal, PAL$red, PAL$coral)
    )
    xmin <- TODAY - 60
    xmax <- max(FSMA_204, TODAY) + 90

    ggplot(deadlines) +
      annotate("rect", xmin = xmin, xmax = xmax,
               ymin = 0.45, ymax = 0.55,
               fill = PAL$bg_pale) +
      geom_point(aes(x = x, y = 0.5, color = col), size = 6) +
      geom_text(aes(x = x, y = 0.78, label = lbl, color = col),
                size = 3.6, fontface = "bold") +
      scale_color_identity() +
      scale_x_date(limits = c(xmin, xmax),
                   date_breaks = "6 months",
                   date_labels = "%b %Y",
                   expand = expansion(mult = c(0.02, 0.02))) +
      coord_cartesian(ylim = c(0, 1)) +
      theme_void() +
      theme(axis.text.x = element_text(color = PAL$text_muted, size = 9,
                                        margin = margin(t = 6)),
            axis.line.x = element_line(color = PAL$text_muted, linewidth = 0.3),
            axis.ticks.x = element_line(color = PAL$text_muted, linewidth = 0.3),
            axis.ticks.length.x = unit(3, "pt"))
  }, res = 90)

  # ---- Interpretation paragraph ----
  output$interpretation <- renderUI({
    v <- inp()
    cc <- cc()
    failing  <- round(v$N * (1 - v$P))
    density  <- debt_density(v$N, v$C, v$A)
    band     <- density_band(density)
    days_gs1 <- as.numeric(GS1_SUNRISE - TODAY)
    rb       <- readiness_band(v$P)

    density_fmt <- paste0("$", formatC(round(density), big.mark = ",", format = "d"))
    tags$p(
      "Your catalog of ", tags$b(v$N, " SKUs"), " across ",
      tags$b(v$R, " retailers"), " generates an estimated ",
      tags$b(style = paste0("color:", PAL$red), dollar_short(cc$total)),
      " in annual data-debt cost. That breaks into ",
      dollar_short(cc$chargebacks), " in chargebacks, ",
      dollar_short(cc$stalled), " in stalled-launch revenue loss, and ",
      dollar_short(cc$shelf), " in shelf loss from deauthorizations. ",
      "The chargeback density of ", tags$b(density_fmt, " per $1M"),
      " sits in the ", tags$b(style = paste0("color:", band$color), band$label),
      " band. A pass rate of ", tags$b(sprintf("%.0f%%", v$P * 100)),
      " means ", tags$b(failing, " SKUs"),
      " currently fail retailer readiness — and the GS1 Sunrise 2027 ",
      "deadline arrives in ", tags$b(max(0, days_gs1), " days"), ". ",
      rb$body, " ",
      "Doubling SKU count without addressing the underlying defect rate ",
      "lifts the annual cost to ",
      tags$b(dollar_short(scale_projection(v$N, v$R, v$C, v$P, v$A, 2))),
      "."
    )
  })

  # ---- Cost of Delay ----
  cod <- reactive({
    cost_of_delay(inp()$N, inp()$R, inp()$C, inp()$P, inp()$A)
  })

  output$cod_m1  <- renderText(dollar_short(cod()$total_cost[1]))
  output$cod_m12 <- renderText(dollar_short(cod()$total_cost[12]))
  output$cod_m18 <- renderText(dollar_short(cod()$total_cost[18]))
  output$cod_m12_mult <- renderText({
    m <- cod()$total_cost[12] / cod()$total_cost[1]
    sprintf("%.1f× the Month-1 cost", m)
  })
  output$cod_m18_mult <- renderText({
    m <- cod()$total_cost[18] / cod()$total_cost[1]
    sprintf("%.1f× the Month-1 cost", m)
  })

  output$cod_curve <- renderPlot({
    df <- cod()
    months_to_dl <- as.numeric(GS1_SUNRISE - TODAY) / 30

    ggplot(df, aes(x = month, y = total_cost)) +
      geom_area(fill = PAL$red, alpha = 0.15) +
      geom_line(color = PAL$red, linewidth = 1.1) +
      geom_point(color = PAL$red, size = 2) +
      annotate("segment",
               x = months_to_dl, xend = months_to_dl,
               y = 0, yend = max(df$total_cost) * 1.02,
               linetype = "dashed", color = PAL$navy, linewidth = 0.6) +
      annotate("text", x = months_to_dl, y = max(df$total_cost) * 1.02,
               label = "GS1 Sunrise 2027",
               hjust = ifelse(months_to_dl > 18, 1.05, -0.05),
               vjust = 1, color = PAL$navy, size = 3.6, fontface = "bold") +
      scale_x_continuous(breaks = seq(0, 24, 3),
                         labels = function(x) ifelse(x == 0, "Now",
                                              ifelse(x == 1, "1 mo",
                                                     paste0(x, " mo")))) +
      scale_y_continuous(labels = function(x) dollar_short(x),
                         expand = expansion(mult = c(0, 0.06))) +
      labs(x = "Months waited before fixing", y = "Cumulative cost") +
      theme_calc()
  }, res = 90)

  # End of server
}

shinyApp(ui = ui, server = server)
