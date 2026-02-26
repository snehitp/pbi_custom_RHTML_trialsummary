# =============================================================================
# Example: Interactive Line Chart (Time Series)
# =============================================================================
# Replace the contents of script.r with this file to use it.
#
# DATA REQUIREMENTS:
#   - Column 1: Date/time or sequential x-axis (date or numeric)
#   - Column 2: Value (numeric) - e.g., revenue, temperature
#   - Column 3 (optional): Series/group (text) - for multiple lines
# =============================================================================

source('./r_files/flatten_HTML.r')

libraryRequireInstall("ggplot2")
libraryRequireInstall("plotly")

# Fallback sample data
if (!exists("Values") || ncol(Values) < 2) {
  Values <- data.frame(
    Month = factor(month.abb[1:12], levels = month.abb),
    Revenue = c(12000, 15000, 13500, 17000, 19500, 22000,
                21000, 24000, 20000, 18000, 23000, 28000)
  )
}

col_names <- names(Values)

if (length(col_names) >= 3) {
  g <- ggplot(Values, aes_string(x = col_names[1], y = col_names[2],
                                  color = col_names[3], group = col_names[3])) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    labs(title = "Trend Over Time", x = col_names[1], y = col_names[2]) +
    theme_minimal()
} else {
  g <- ggplot(Values, aes_string(x = col_names[1], y = col_names[2], group = 1)) +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(color = "steelblue", size = 2) +
    labs(title = "Trend Over Time", x = col_names[1], y = col_names[2]) +
    theme_minimal()
}

p <- ggplotly(g)
internalSaveWidget(p, 'out.html')
ReadFullFileReplaceString('out.html', 'out.html', ',"padding":[0-9]*,', ',"padding":0,')
