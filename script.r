# =============================================================================
# Power BI RHTML Custom Visual - Hello World
# =============================================================================
#
# HOW THIS WORKS:
# 1. Power BI sends data to R as a dataframe called "Values"
#    (the name matches the dataRole in capabilities.json)
# 2. This script processes the data and creates an interactive HTML widget
# 3. The widget is saved as 'out.html' using internalSaveWidget()
# 4. Power BI reads out.html and renders it in the visual container
#
# IMPORTANT NOTES:
# - The output file MUST be named 'out.html'
# - Power BI applies unique() to input data by default
#   (add an index column to your data if you need duplicate rows)
# - All R packages must be declared in dependencies.json
# =============================================================================

# Load HTML flattening utilities (required for all RHTML visuals)
source('./r_files/flatten_HTML.r')

############### Library Declarations ###############
libraryRequireInstall("ggplot2");
libraryRequireInstall("plotly")
####################################################

################### Actual code ####################

# --- Data Handling ---
# When connected to Power BI, data arrives as a dataframe called "Values".
# The columns correspond to the fields the user dragged into the visual.
#
# For local testing or when no data is connected, we use sample data:
if (!exists("Values") || ncol(Values) < 1) {
  # Sample data for testing outside Power BI
  Values <- data.frame(
    Category = c("Alpha", "Beta", "Gamma", "Delta", "Epsilon"),
    Amount = c(42, 87, 53, 71, 36)
  )
}

# Determine column names from whatever the user dragged in
col_names <- names(Values)
x_col <- col_names[1]

# If there's a second column, use it as the Y axis; otherwise count occurrences
if (length(col_names) >= 2) {
  y_col <- col_names[2]
  g <- ggplot(Values, aes_string(x = x_col, y = y_col)) +
    geom_bar(stat = "identity", fill = "steelblue") +
    labs(title = "Hello World RHTML Visual", x = x_col, y = y_col) +
    theme_minimal()
} else {
  g <- ggplot(Values, aes_string(x = x_col)) +
    geom_bar(fill = "steelblue") +
    labs(title = "Hello World RHTML Visual", x = x_col, y = "Count") +
    theme_minimal()
}

####################################################

############# Create and save widget ###############
# Convert ggplot to an interactive plotly widget (adds hover, zoom, pan)
p <- ggplotly(g)

# Save as self-contained HTML (this is REQUIRED - must output to 'out.html')
internalSaveWidget(p, 'out.html')
####################################################

################ Reduce paddings ###################
ReadFullFileReplaceString('out.html', 'out.html', ',"padding":[0-9]*,', ',"padding":0,')
####################################################
