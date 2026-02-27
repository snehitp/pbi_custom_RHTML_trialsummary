# =============================================================================
# Example: Interactive Bar Chart
# =============================================================================
# Replace the contents of script.r with this file to use it.
#
# DATA REQUIREMENTS:
#   - Column 1: Category (text) - e.g., product names, regions
#   - Column 2: Value (numeric) - e.g., sales, counts
# =============================================================================

source('./r_files/flatten_HTML.r')

libraryRequireInstall("ggplot2")
libraryRequireInstall("plotly")

# Fallback sample data
if (!exists("Values") || ncol(Values) < 2) {
  Values <- data.frame(
    Product = c("Widget A", "Widget B", "Widget C", "Widget D", "Widget E"),
    Sales = c(150, 230, 180, 310, 95)
  )
}

col_names <- names(Values)

g <- ggplot(Values, aes_string(x = col_names[1], y = col_names[2])) +
  geom_bar(stat = "identity", fill = "steelblue", width = 0.7) +
  geom_text(aes_string(label = col_names[2]), vjust = -0.3, size = 3.5) +
  labs(
    title = "Sales by Product",
    x = col_names[1],
    y = col_names[2]
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

p <- ggplotly(g)
internalSaveWidget(p, 'out.html')
ReadFullFileReplaceString('out.html', 'out.html', ',"padding":[0-9]*,', ',"padding":0,')
