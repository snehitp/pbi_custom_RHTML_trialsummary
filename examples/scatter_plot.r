# =============================================================================
# Example: Interactive Scatter Plot
# =============================================================================
# Replace the contents of script.r with this file to use it.
#
# DATA REQUIREMENTS:
#   - Column 1: X axis (numeric) - e.g., height, temperature
#   - Column 2: Y axis (numeric) - e.g., weight, sales
#   - Column 3 (optional): Group/color (text) - e.g., category, region
# =============================================================================

source('./r_files/flatten_HTML.r')

libraryRequireInstall("ggplot2")
libraryRequireInstall("plotly")

# Fallback sample data
if (!exists("Values") || ncol(Values) < 2) {
  set.seed(42)
  Values <- data.frame(
    Height = rnorm(50, mean = 170, sd = 10),
    Weight = rnorm(50, mean = 70, sd = 12),
    Group = sample(c("Group A", "Group B"), 50, replace = TRUE)
  )
}

col_names <- names(Values)

if (length(col_names) >= 3) {
  # Color by third column
  g <- ggplot(Values, aes_string(x = col_names[1], y = col_names[2], color = col_names[3])) +
    geom_point(size = 3, alpha = 0.7) +
    labs(title = "Scatter Plot", x = col_names[1], y = col_names[2], color = col_names[3]) +
    theme_minimal()
} else {
  g <- ggplot(Values, aes_string(x = col_names[1], y = col_names[2])) +
    geom_point(size = 3, alpha = 0.7, color = "steelblue") +
    labs(title = "Scatter Plot", x = col_names[1], y = col_names[2]) +
    theme_minimal()
}

p <- ggplotly(g)
internalSaveWidget(p, 'out.html')
ReadFullFileReplaceString('out.html', 'out.html', ',"padding":[0-9]*,', ',"padding":0,')
