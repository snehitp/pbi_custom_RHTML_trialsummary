# =============================================================================
# Power BI RHTML Custom Visual — Swimlane Timeline
# =============================================================================
#
# DATA ROLES (defined in capabilities.json):
#   program_id       (required, 1 field)  — Y-axis label
#   program_category (required, 1 field)  — Color grouping + legend
#   start_date       (required, 1 field)  — Bar start date
#   end_date         (optional, 1 field)  — Bar end date (defaults to start + 4 years)
#   mouseover        (optional, 0+ fields) — Extra attributes for hover tooltip
#   milestone        (optional, 1 field)  — Milestone label (paired with milestone_time)
#   milestone_time   (optional, 1 field)  — Milestone date (paired with milestone)
#   milestone_tooltip (optional, 0+ fields) — Extra attributes for milestone hover tooltip
#
# Y-AXIS LABELS:  [program_id]
# X-AXIS:         Timeline, auto-ranged from data
#
# Each data role arrives in R as a data.frame named after the role.
# Output MUST be saved to 'out.html'.
# =============================================================================

source('./r_files/flatten_HTML.r')

############### Library Declarations ###############
libraryRequireInstall("plotly")
####################################################

################### Actual code ####################

# --- Data Handling ---
# All data comes from PBI data roles. No hardcoded sample data.
# Required: program_id, program_category, start_date
# Optional: end_date (defaults to start_date + 4 years), mouseover,
#           milestone + milestone_time (both needed for callout annotations)

has_data <- (exists("program_id")       && is.data.frame(program_id)       && ncol(program_id)       >= 1 &&
             exists("program_category") && is.data.frame(program_category) && ncol(program_category) >= 1 &&
             exists("start_date")       && is.data.frame(start_date)       && ncol(start_date)       >= 1)

if (!has_data) {
  # Not enough fields populated — output a blank placeholder
  p <- plotly_empty() %>%
    layout(
      title = list(
        text = "Drag Program Identifier, Program Category, and Start Date into the field wells",
        font = list(size = 14, color = "#888888")
      )
    )
  internalSaveWidget(p, 'out.html')
  ReadFullFileReplaceString('out.html', 'out.html', ',"padding":[0-9]*,', ',"padding":0,')
  quit()
}

# ---- Build dataframe from PBI data roles ----
sdate <- as.Date(start_date[[1]])

# Use end_date if provided, otherwise default to start_date + 4 years
if (exists("end_date") && is.data.frame(end_date) && ncol(end_date) >= 1) {
  edate <- as.Date(end_date[[1]])
  edate[is.na(edate)] <- sdate[is.na(edate)] + (365.25 * 4)
} else {
  edate <- sdate + (365.25 * 4)
}

df <- data.frame(
  program_id       = as.character(program_id[[1]]),
  program_category = as.character(program_category[[1]]),
  start_date       = sdate,
  end_date         = edate,
  stringsAsFactors = FALSE
)

# Mouseover: optional extra tooltip fields
mouseover_df <- NULL
if (exists("mouseover") && is.data.frame(mouseover) && ncol(mouseover) > 0) {
  mouseover_df <- mouseover
}

# Milestones: optional paired fields (both must be present to render)
has_milestones <- (exists("milestone")      && is.data.frame(milestone)      && ncol(milestone)      >= 1 &&
                   exists("milestone_time") && is.data.frame(milestone_time) && ncol(milestone_time) >= 1)

milestone_df <- NULL
milestone_tooltip_df <- NULL
if (has_milestones) {
  milestone_df <- data.frame(
    label = as.character(milestone[[1]]),
    date  = as.Date(milestone_time[[1]]),
    program_id = df$program_id,
    stringsAsFactors = FALSE
  )
  # Milestone tooltip: optional extra fields shown on milestone hover
  if (exists("milestone_tooltip") && is.data.frame(milestone_tooltip) && ncol(milestone_tooltip) > 0) {
    milestone_tooltip_df <- milestone_tooltip
  }
}

# --- Remove rows with NA start dates ---
valid <- !is.na(df$start_date)
df <- df[valid, ]
if (!is.null(mouseover_df)) mouseover_df <- mouseover_df[valid, , drop = FALSE]
if (!is.null(milestone_df)) milestone_df <- milestone_df[valid, ]
if (!is.null(milestone_tooltip_df)) milestone_tooltip_df <- milestone_tooltip_df[valid, , drop = FALSE]

# Swap dates if end < start
swap <- df$end_date < df$start_date
if (any(swap)) {
  tmp <- df$start_date[swap]
  df$start_date[swap] <- df$end_date[swap]
  df$end_date[swap] <- tmp
}

# --- Deduplicate when milestones cause repeated program rows ---
if (!is.null(milestone_df)) {
  # Remove milestones with NA label or date
  ms_valid <- !is.na(milestone_df$label) & milestone_df$label != "" &
              !is.na(milestone_df$date)
  milestone_df <- milestone_df[ms_valid, ]
  if (!is.null(milestone_tooltip_df)) milestone_tooltip_df <- milestone_tooltip_df[ms_valid, , drop = FALSE]

  # Keep one row per program for bar rendering
  dup_idx <- !duplicated(df$program_id)
  df <- df[dup_idx, ]
  if (!is.null(mouseover_df)) mouseover_df <- mouseover_df[dup_idx, , drop = FALSE]
}

# --- Y-axis labels: program_id only ---
df$label <- df$program_id

# De-duplicate identical labels
if (anyDuplicated(df$label)) {
  df$label <- make.unique(df$label, sep = " #")
}

# Map milestones to (possibly de-duplicated) y-axis labels
if (!is.null(milestone_df) && nrow(milestone_df) > 0) {
  id_to_label <- setNames(df$label, df$program_id)
  milestone_df$y_label <- id_to_label[milestone_df$program_id]
  milestone_df <- milestone_df[!is.na(milestone_df$y_label), ]
}

# --- Hover text ---
hover_lines <- paste0(
  "<b>", df$program_id, "</b>",
  "<br>Category: ", df$program_category,
  "<br>Start: ", format(df$start_date, "%b %Y"),
  "<br>Est. End: ", format(df$end_date, "%b %Y")
)
if (!is.null(mouseover_df)) {
  for (cn in names(mouseover_df)) {
    vals <- as.character(mouseover_df[[cn]])
    vals[is.na(vals) | vals == "NA"] <- "N/A"
    hover_lines <- paste0(hover_lines, "<br><b>", cn, ":</b> ", vals)
  }
}
df$hover_text <- hover_lines

# --- Sort by start date (earliest at top of chart) ---
df <- df[order(df$start_date), ]

# Plotly draws y-categories bottom-to-top; reverse so earliest is at top
y_order <- rev(df$label)

# --- Auto-assign colors to unique program_category values ---
palette <- c(
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
  "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
  "#aec7e8", "#ffbb78", "#98df8a", "#ff9896", "#c5b0d5",
  "#c49c94", "#f7b6d2", "#c7c7c7", "#dbdb8d", "#9edae5"
)
unique_categories <- unique(df$program_category)
color_map <- setNames(rep_len(palette, length(unique_categories)), unique_categories)
df$color <- color_map[df$program_category]

# --- Build Plotly figure ---
today <- Sys.Date()
p <- plot_ly()

legend_shown <- character(0)

# Helper: generate a sequence of dates for hover detection along the bar
make_date_seq <- function(d_start, d_end) {
  span_days <- as.numeric(difftime(d_end, d_start, units = "days"))
  n <- max(2, min(50, ceiling(span_days / 30)))
  seq(d_start, d_end, length.out = n)
}

for (i in seq_len(nrow(df))) {
  catg  <- df$program_category[i]
  lbl   <- df$label[i]
  clr   <- df$color[i]
  htxt  <- df$hover_text[i]

  show_leg <- !(catg %in% legend_shown)
  has_solid  <- df$start_date[i] <= today
  has_future <- df$end_date[i] > today

  # --- Solid portion (actual: start → min(end, today)) ---
  if (has_solid) {
    solid_end <- min(df$end_date[i], today)
    xs <- make_date_seq(df$start_date[i], solid_end)
    p <- add_trace(p,
      x = xs, y = rep(lbl, length(xs)),
      type = "scatter", mode = "lines",
      line = list(width = 20, color = clr),
      name = catg, legendgroup = catg,
      showlegend = show_leg,
      hoverinfo = "text", text = rep(htxt, length(xs))
    )
    if (show_leg) {
      legend_shown <- c(legend_shown, catg)
      show_leg <- FALSE
    }
  }

  # --- Projected portion (future: max(start, today) → end) ---
  # Uses lower opacity instead of dash pattern to avoid broken-bar rendering
  if (has_future) {
    future_start <- max(df$start_date[i], today)
    xs <- make_date_seq(future_start, df$end_date[i])
    p <- add_trace(p,
      x = xs, y = rep(lbl, length(xs)),
      type = "scatter", mode = "lines",
      line = list(width = 20, color = clr),
      opacity = 0.4,
      name = catg, legendgroup = catg,
      showlegend = show_leg,
      hoverinfo = "text", text = rep(htxt, length(xs))
    )
    if (show_leg) legend_shown <- c(legend_shown, catg)
  }
}

# --- Milestone annotations ---
milestone_annotations <- list()

if (!is.null(milestone_df) && nrow(milestone_df) > 0) {
  # Per-program counter for alternating above/below with progressive offset
  ms_counter <- list()

  for (idx in seq_len(nrow(milestone_df))) {
    ms_label <- milestone_df$label[idx]
    ms_date  <- milestone_df$date[idx]
    ms_y     <- milestone_df$y_label[idx]
    ms_pid   <- milestone_df$program_id[idx]

    # Find the corresponding bar
    bar_row <- df[df$program_id == ms_pid, ]
    if (nrow(bar_row) == 0) next

    bar_color <- bar_row$color[1]

    # Clamp milestone date to bar range
    ms_date <- max(ms_date, bar_row$start_date[1])
    ms_date <- min(ms_date, bar_row$end_date[1])

    # Build milestone hover text
    ms_htxt <- paste0("<b>", ms_label, "</b><br>Date: ", format(ms_date, "%b %Y"))
    if (!is.null(milestone_tooltip_df)) {
      for (cn in names(milestone_tooltip_df)) {
        val <- as.character(milestone_tooltip_df[[cn]][idx])
        if (is.na(val) || val == "NA") val <- "N/A"
        ms_htxt <- paste0(ms_htxt, "<br><b>", cn, ":</b> ", val)
      }
    }

    # Progressive alternating offset: -40, +40, -70, +70, -100, +100, ...
    if (is.null(ms_counter[[ms_pid]])) ms_counter[[ms_pid]] <- 0L
    ms_counter[[ms_pid]] <- ms_counter[[ms_pid]] + 1L
    counter <- ms_counter[[ms_pid]]
    tier <- ceiling(counter / 2)
    direction <- if (counter %% 2 == 1) -1 else 1
    ay_offset <- direction * (40 + (tier - 1) * 30)

    milestone_annotations[[length(milestone_annotations) + 1]] <- list(
      x = format(ms_date, "%Y-%m-%d"),
      y = ms_y,
      text = ms_label,
      showarrow = TRUE,
      arrowhead = 0,
      arrowwidth = 1.5,
      arrowcolor = bar_color,
      ax = 0,
      ay = ay_offset,
      bgcolor = bar_color,
      font = list(color = "#ffffff", size = 9),
      bordercolor = bar_color,
      borderwidth = 1,
      borderpad = 3,
      opacity = 0.9,
      captureevents = TRUE,
      hovertext = ms_htxt
    )
  }
}

# --- Build combined annotations list ---
all_annotations <- list(
  list(
    x = format(today, "%Y-%m-%d"), y = 1.02, yref = "paper",
    text = paste0("Today (", format(today, "%b %Y"), ")"),
    showarrow = FALSE,
    font = list(color = "red", size = 10)
  )
)
all_annotations <- c(all_annotations, milestone_annotations)

# --- X-axis range ---
x_min <- min(df$start_date) - 180
# Cap x-axis at 2 years from today; use data range + padding if shorter
x_max_data <- max(df$end_date) + 180
x_max_cap  <- today + (365.25 * 2)
x_max <- min(x_max_data, x_max_cap)

# --- Truncation arrows for bars that extend beyond the x-axis cap ---
truncated_idx <- which(df$end_date > x_max_cap)
truncation_annotations <- list()
for (ti in truncated_idx) {
  # Arrow stalk starts 60 days left of cap, arrowhead points at cap minus small inset
  arrow_tip  <- x_max_cap - 15
  arrow_tail <- x_max_cap - 75
  truncation_annotations[[length(truncation_annotations) + 1]] <- list(
    x = format(arrow_tip, "%Y-%m-%d"),
    y = df$label[ti],
    ax = format(arrow_tail, "%Y-%m-%d"),
    ay = df$label[ti],
    axref = "x", ayref = "y",
    showarrow = TRUE,
    arrowhead = 2,
    arrowsize = 1.5,
    arrowwidth = 2,
    arrowcolor = "#000000",
    text = paste0("→ ", format(df$end_date[ti], "%b %Y")),
    font = list(size = 1, color = "rgba(0,0,0,0)"),
    hovertext = paste0("Continues to ", format(df$end_date[ti], "%b %Y"))
  )
}

all_annotations <- c(all_annotations, truncation_annotations)

# --- Dynamic chart height: enough room per bar for milestone callouts ---
px_per_bar <- if (length(milestone_annotations) > 0) 150 else 40
chart_height <- max(300, nrow(df) * px_per_bar + 80)

# --- Layout ---
p <- layout(p,
  height = chart_height,
  title = FALSE,
  xaxis = list(
    title = list(text = "Year", font = list(size = 12)),
    type = "date",
    range = c(format(x_min, "%Y-%m-%d"), format(x_max, "%Y-%m-%d")),
    gridcolor = "#e8e8e8",
    zeroline = FALSE
  ),
  yaxis = list(
    title = "",
    categoryorder = "array",
    categoryarray = y_order,
    tickfont = list(size = 10)
  ),
  shapes = list(
    list(
      type = "line",
      x0 = format(today, "%Y-%m-%d"), x1 = format(today, "%Y-%m-%d"),
      y0 = 0, y1 = 1, yref = "paper",
      line = list(color = "red", width = 1.5, dash = "dash")
    )
  ),
  annotations = all_annotations,
  margin = list(l = 60, r = 10, t = 20, b = 30),
  legend = list(
    orientation = "h", y = -0.08, x = 0.5, xanchor = "center",
    font = list(size = 10)
  ),
  hovermode = "closest",
  hoverlabel = list(align = "left"),
  plot_bgcolor  = "#ffffff",
  paper_bgcolor = "#ffffff"
)

# Custom modebar button: copy SVG to clipboard
# (PBI sandbox blocks file downloads, so we copy to clipboard instead)
copy_svg_btn <- list(
  name = "copySVG",
  title = "Copy SVG to clipboard",
  icon = list(
    path = "M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z",
    transform = "matrix(0.83 0 0 0.83 0 0)"
  ),
  click = htmlwidgets::JS("function(gd) {
    Plotly.toImage(gd, {format:'svg', height:gd._fullLayout.height, width:gd._fullLayout.width})
      .then(function(url) {
        var svg = decodeURIComponent(url.replace('data:image/svg+xml,',''));
        var ta = document.createElement('textarea');
        ta.value = svg;
        ta.style.position = 'fixed';
        ta.style.left = '-9999px';
        document.body.appendChild(ta);
        ta.select();
        var ok = document.execCommand('copy');
        document.body.removeChild(ta);
        var msg = document.createElement('div');
        msg.textContent = ok ? 'SVG copied to clipboard' : 'Copy failed';
        msg.style.cssText = 'position:fixed;top:12px;left:50%;transform:translateX(-50%);background:#333;color:#fff;padding:8px 16px;border-radius:4px;font:13px sans-serif;z-index:99999;opacity:0.95;';
        document.body.appendChild(msg);
        setTimeout(function(){document.body.removeChild(msg);}, 2000);
      });
  }")
)

p <- config(p,
  displayModeBar = TRUE,
  displaylogo = FALSE,
  modeBarButtonsToAdd = list(copy_svg_btn),
  toImageButtonOptions = list(format = "svg")
)

####################################################

############# Create and save widget ###############
internalSaveWidget(p, 'out.html')
####################################################

################ Reduce paddings ###################
ReadFullFileReplaceString('out.html', 'out.html', ',"padding":[0-9]*,', ',"padding":0,')
####################################################

######### Wrap body in scrollable container #########
ReadFullFileReplaceString('out.html', 'out.html',
  '<body>',
  '<body><div style="position:absolute;top:0;left:0;right:0;bottom:0;overflow-y:auto;">')
ReadFullFileReplaceString('out.html', 'out.html',
  '</body>',
  '</div></body>')
####################################################
