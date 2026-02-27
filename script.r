# =============================================================================
# Power BI RHTML Custom Visual — Swimlane Timeline
# =============================================================================
#
# DATA ROLES (defined in capabilities.json):
#   car_target  (required, 1 field)  — Category for color grouping + label prefix
#   cancer_type (required, 1 field)  — Sub-category for label suffix
#   start_date  (required, 1 field)  — Bar start date
#   end_date    (optional, 1 field)  — Bar end date (defaults to start + 4 years)
#   mouseover   (optional, 0+ fields) — Extra attributes for hover tooltip
#
# Y-AXIS LABELS:  [car_target] ([cancer_type])
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
# Required: car_target, cancer_type, start_date
# Optional: end_date (defaults to start_date + 4 years), mouseover

has_data <- (exists("car_target")  && is.data.frame(car_target)  && ncol(car_target)  >= 1 &&
             exists("cancer_type") && is.data.frame(cancer_type) && ncol(cancer_type) >= 1 &&
             exists("start_date")  && is.data.frame(start_date)  && ncol(start_date)  >= 1)

if (!has_data) {
  # Not enough fields populated — output a blank placeholder
  p <- plotly_empty() %>%
    layout(
      title = list(
        text = "Drag CAR Target, Cancer Type, and Start Date into the field wells",
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
  car_target  = as.character(car_target[[1]]),
  cancer_type = as.character(cancer_type[[1]]),
  start_date  = sdate,
  end_date    = edate,
  stringsAsFactors = FALSE
)

# Mouseover: optional extra tooltip fields
mouseover_df <- NULL
if (exists("mouseover") && is.data.frame(mouseover) && ncol(mouseover) > 0) {
  mouseover_df <- mouseover
}

# --- Remove rows with NA start dates ---
valid <- !is.na(df$start_date)
df <- df[valid, ]
if (!is.null(mouseover_df)) mouseover_df <- mouseover_df[valid, , drop = FALSE]

# Swap dates if end < start
swap <- df$end_date < df$start_date
if (any(swap)) {
  tmp <- df$start_date[swap]
  df$start_date[swap] <- df$end_date[swap]
  df$end_date[swap] <- tmp
}

# --- Y-axis labels: "car_target (cancer_type)" ---
df$label <- paste0(df$car_target, " (", df$cancer_type, ")")

# De-duplicate identical labels
if (anyDuplicated(df$label)) {
  df$label <- make.unique(df$label, sep = " #")
}

# --- Hover text ---
hover_lines <- paste0(
  "<b>", df$car_target, "</b> (", df$cancer_type, ")",
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

# --- Auto-assign colors to unique car_target values ---
palette <- c(
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
  "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
  "#aec7e8", "#ffbb78", "#98df8a", "#ff9896", "#c5b0d5",
  "#c49c94", "#f7b6d2", "#c7c7c7", "#dbdb8d", "#9edae5"
)
unique_targets <- unique(df$car_target)
color_map <- setNames(rep_len(palette, length(unique_targets)), unique_targets)
df$color <- color_map[df$car_target]

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
  tgt   <- df$car_target[i]
  lbl   <- df$label[i]
  clr   <- df$color[i]
  htxt  <- df$hover_text[i]

  show_leg <- !(tgt %in% legend_shown)
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
      name = tgt, legendgroup = tgt,
      showlegend = show_leg,
      hoverinfo = "text", text = rep(htxt, length(xs))
    )
    if (show_leg) {
      legend_shown <- c(legend_shown, tgt)
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
      name = tgt, legendgroup = tgt,
      showlegend = show_leg,
      hoverinfo = "text", text = rep(htxt, length(xs))
    )
    if (show_leg) legend_shown <- c(legend_shown, tgt)
  }
}

# --- X-axis range: pad 6 months on each side of the data ---
x_min <- min(df$start_date) - 180
x_max <- max(df$end_date)   + 180

# --- Layout ---
p <- layout(p,
  title = list(
    text = "Swimlane Timeline",
    font = list(size = 16, family = "Arial, sans-serif"),
    x = 0.5
  ),
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
  annotations = list(
    list(
      x = format(today, "%Y-%m-%d"), y = 1.04, yref = "paper",
      text = paste0("Today (", format(today, "%b %Y"), ")"),
      showarrow = FALSE,
      font = list(color = "red", size = 10)
    )
  ),
  margin = list(l = 300, r = 40, t = 80, b = 60),
  legend = list(
    orientation = "h", y = -0.12, x = 0.5, xanchor = "center",
    font = list(size = 10)
  ),
  hovermode = "closest",
  plot_bgcolor  = "#ffffff",
  paper_bgcolor = "#ffffff"
)

p <- config(p, displayModeBar = TRUE, displaylogo = FALSE)

####################################################

############# Create and save widget ###############
internalSaveWidget(p, 'out.html')
####################################################

################ Reduce paddings ###################
ReadFullFileReplaceString('out.html', 'out.html', ',"padding":[0-9]*,', ',"padding":0,')
####################################################
