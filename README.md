# Power BI Custom Visual: R + HTML (RHTML) Template

A starter template for building **interactive** Power BI custom visuals using **R** and **HTML**. Unlike standard R visuals (which produce static PNG images), RHTML visuals produce interactive HTML output with hover tooltips, zooming, panning, and click events via [plotly](https://plotly.com/r/) and [htmlwidgets](https://www.htmlwidgets.org/).

## Quick Comparison

| Feature | R Visual | RHTML Visual (this template) |
|---|---|---|
| Output | Static PNG | Interactive HTML |
| Hover/zoom/pan | No | Yes |
| Publish to web | No | Yes |
| R engine required | Yes | Yes |

## Prerequisites

Install these before getting started:

1. **Node.js** (v18+) - [nodejs.org](https://nodejs.org/)
2. **R** (v4.0+) - [cran.r-project.org](https://cran.r-project.org/bin/windows/base/)
3. **Power BI Desktop** - [powerbi.microsoft.com](https://powerbi.microsoft.com/desktop/)
4. **Power BI Visuals Tools (pbiviz)** - install globally:
   ```bash
   npm install -g powerbi-visuals-tools
   ```
5. **SSL Certificate** (one-time setup for dev server):
   ```bash
   pbiviz --install-cert
   ```

### R Packages

The following R packages are required (Power BI auto-installs them, but you can pre-install):

```r
install.packages(c("ggplot2", "plotly", "htmlwidgets", "xml2"))
```

## How to Use It

1. **Build**: `npm run package` - creates the `.pbiviz` file in `dist/`
2. **Import**: In Power BI Desktop, go to Visualizations pane > `...` > "Import a visual from a file" > select the `.pbiviz` from `dist/`
3. **Use**: Drag the visual onto your canvas, then drag data fields into the **Values** well

### How to Customize (Quick Reference)

- Edit `script.r` - this is where your R visualization code goes
- The `Values` dataframe arrives from Power BI with whatever columns the user drags in
- The script creates a ggplot2 chart, converts it to interactive plotly, and saves as `out.html`
- Swap in any example from `examples/` to try different chart types (bar, scatter, line)
- Add new R packages via `dependencies.json`

### Key Things to Change for a New Visual

1. **`pbiviz.json`**: Update `name`, `displayName`, `guid` (generate a new one), `author`
2. **`script.r`**: Your visualization logic
3. **`dependencies.json`**: Any additional R packages you need
4. **`capabilities.json`**: Data roles if you want separate Category/Measure wells

## Getting Started

### 1. Install dependencies

```bash
npm install
```

### 2. Build the visual

```bash
npm run package
```

This creates a `.pbiviz` file in the `dist/` folder.

### 3. Import into Power BI

1. Open **Power BI Desktop**
2. In the Visualizations pane, click the **...** (ellipsis) menu
3. Select **Import a visual from a file**
4. Browse to `dist/helloWorldRHTML.pbiviz`
5. The visual appears in the Visualizations pane
6. Drag it onto your report canvas
7. Drag data fields into the **Values** well

## Project Structure

```
├── script.r                    # ← YOUR R CODE GOES HERE
├── r_files/
│   └── flatten_HTML.r          # Utility: embeds JS/CSS inline into HTML (do not modify)
├── src/
│   ├── visual.ts               # TypeScript: receives HTML from R and injects into DOM
│   ├── htmlInjectionUtility.ts  # TypeScript: HTML parsing/injection helpers
│   └── settings.ts             # TypeScript: formatting pane settings model
├── style/
│   └── visual.less             # CSS styles for the visual container
├── capabilities.json           # Data roles, mappings, and script output type
├── dependencies.json           # R package (CRAN) dependencies
├── pbiviz.json                 # Visual metadata (name, GUID, version)
├── package.json                # npm dependencies
├── examples/                   # Example R scripts you can swap into script.r
│   ├── bar_chart.r
│   ├── scatter_plot.r
│   └── line_chart.r
└── assets/
    └── icon.png                # 20x20 icon shown in the Visualizations pane
```

## How It Works

The data pipeline flows like this:

```
Power BI Data → R Engine → HTML Widget → TypeScript → DOM
```

1. **Power BI** sends your data to R as a dataframe called `Values` (the name matches the `dataRoles` in `capabilities.json`)
2. **`script.r`** runs in the R engine, builds a `ggplot2` chart, converts it to an interactive `plotly` widget, and saves it as `out.html`
3. **`flatten_HTML.r`** embeds all external JS/CSS files inline into a single self-contained HTML file
4. **Power BI** base64-encodes the HTML and passes it to the TypeScript layer
5. **`visual.ts`** decodes the payload and injects the `<head>` (scripts/styles) and `<body>` (chart) into the DOM

## Customizing the Visual

### Editing the R Script

The main file you'll edit is **`script.r`**. It follows this pattern:

```r
# 1. Load utilities (required)
source('./r_files/flatten_HTML.r')

# 2. Load R libraries
libraryRequireInstall("ggplot2")
libraryRequireInstall("plotly")

# 3. Process the "Values" dataframe from Power BI
# ... your data manipulation and visualization code ...

# 4. Convert to plotly and save (required)
p <- ggplotly(your_ggplot)
internalSaveWidget(p, 'out.html')

# 5. Optional: reduce padding
ReadFullFileReplaceString('out.html', 'out.html', ',"padding":[0-9]*,', ',"padding":0,')
```

### Using Example Scripts

Copy any example from `examples/` into `script.r`:

```bash
cp examples/scatter_plot.r script.r
```

Then rebuild:

```bash
npm run package
```

### Changing Data Roles

By default, the visual has a single data role called "Values" that accepts any fields. To add specific roles (e.g., separate "Category" and "Measure" wells), edit `capabilities.json`:

```json
{
  "dataRoles": [
    {
      "displayName": "Category",
      "kind": "Grouping",
      "name": "Category"
    },
    {
      "displayName": "Measure",
      "kind": "Measure",
      "name": "Measure"
    }
  ]
}
```

In your R script, you'll then have `Category` and `Measure` as separate dataframes.

### Adding R Packages

1. Add the package to **`dependencies.json`**:
   ```json
   {
     "cranPackages": [
       { "name": "dplyr", "displayName": "dplyr", "url": "https://cran.r-project.org/web/packages/dplyr/index.html" }
     ]
   }
   ```
2. Use it in `script.r`:
   ```r
   libraryRequireInstall("dplyr")
   ```

Power BI will auto-install declared CRAN packages on first use.

### Adding Visual Properties (Formatting Pane)

To let users configure the visual from Power BI's formatting pane:

1. Add an object to `capabilities.json` under `"objects"`:
   ```json
   "settings": {
     "properties": {
       "chartColor": {
         "type": { "fill": { "solid": { "color": true } } }
       }
     }
   }
   ```

2. Read it in `script.r` with a default fallback:
   ```r
   if (!exists("settings_chartColor")) {
     settings_chartColor <- "#4682B4"
   }
   ```
   The naming convention is `<objectName>_<propertyName>`.

3. Update `src/settings.ts` to register the formatting card.

### Changing the Visual Icon

Replace `assets/icon.png` with your own 20x20 pixel PNG image.

### Generating a New GUID

When creating a new visual from this template, generate a unique GUID. In `pbiviz.json`, change the `guid` field. You can generate one at [guidgenerator.com](https://www.guidgenerator.com/) or via PowerShell:

```powershell
[guid]::NewGuid().ToString("N")
```

## Common R + Plotly Patterns

### Direct Plotly (without ggplot2)

```r
p <- plot_ly(Values, x = ~Category, y = ~Amount, type = 'bar',
             marker = list(color = 'steelblue'))
p <- layout(p, title = "My Chart")
internalSaveWidget(p, 'out.html')
```

### Heatmap

```r
p <- plot_ly(z = as.matrix(Values), type = "heatmap")
internalSaveWidget(p, 'out.html')
```

### Multiple Traces

```r
p <- plot_ly(Values) %>%
  add_trace(x = ~X, y = ~Y1, name = "Series 1", type = "scatter", mode = "lines") %>%
  add_trace(x = ~X, y = ~Y2, name = "Series 2", type = "scatter", mode = "lines")
internalSaveWidget(p, 'out.html')
```

## Tips and Gotchas

- **Output file must be `out.html`** - Power BI looks for exactly this filename
- **Power BI deduplicates rows** - it applies `unique()` to input data. Add an index column if you need duplicate rows
- **Reduce HTML size** - aggregate data in R before plotting; large HTML files slow rendering
- **CDN for plotly.js** - the `flatten_HTML.r` utility replaces local plotly.js with a CDN reference to keep file sizes small. The CDN URL (`https://cdn.plot.ly/`) is whitelisted in `capabilities.json` under `privileges`
- **Performance** - `updateHTMLHead` in `visual.ts` is `false` by default, meaning `<head>` scripts load only on first render (not on every data refresh). Set to `true` only if you use multiple widget packages
- **R version** - Power BI Desktop uses the R installation configured in Options > R scripting. Ensure it points to your R installation

## Development Commands

| Command | Description |
|---|---|
| `npm install` | Install npm dependencies |
| `npm run package` | Build the `.pbiviz` file into `dist/` |
| `npm run start` | Start the dev server (for live reload in Power BI) |
| `npm run lint` | Lint TypeScript files |

## Live Development (Optional)

For a faster development loop:

1. Run `npm run start` (starts dev server on port 8080)
2. In Power BI Desktop, enable **Developer Visual** in Options > Preview features
3. The developer visual in the Visualizations pane auto-reloads when you save changes

## Further Reading

- [Create an R-powered Power BI visual](https://learn.microsoft.com/en-us/power-bi/developer/visuals/create-r-based-power-bi-desktop)
- [Power BI custom visuals documentation](https://learn.microsoft.com/en-us/power-bi/developer/visuals/)
- [Plotly R reference](https://plotly.com/r/)
- [htmlwidgets for R](https://www.htmlwidgets.org/)
- [RHTML Tutorial (GitHub)](https://github.com/PowerBi-Projects/PowerBI-visuals/blob/master/RVisualTutorial/CreateRHTML.md)
