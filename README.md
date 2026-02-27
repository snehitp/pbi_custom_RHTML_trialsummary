# Power BI Custom Visual: Swimlane Timeline (RHTML)

An interactive Power BI custom visual that renders a **swimlane / Gantt-style timeline chart** using R and plotly. Each row is a horizontal bar spanning a date range, colored by a grouping category, with rich hover tooltips. Built on top of the [RHTML custom visual template](https://github.com/snehitp/pbi_custom_RHTML_template).

![Timeline screenshot](sample_data/stanford_iit_timeline.png)

## Features

- **Swimlane bars** from Start Date to End Date on a date-scaled X-axis
- **Y-axis labels** formatted as `CAR Target (Cancer Type)` from two input fields
- **Auto-colored by category** — unique values of the first field are assigned distinct colors from a 20-color palette
- **Solid / projected split** — bars are solid up to today's date and semi-transparent (40% opacity) for the projected future portion
- **"Today" reference line** — red dashed vertical line with date annotation
- **Hover tooltips** — show start/end dates plus any additional fields dragged into the Mouse Over well
- **Fully interactive** — zoom, pan, and hover via plotly.js
- **General-purpose** — no hardcoded data; works with any dataset

## Data Roles (Field Wells)

| Well | Required | Max Fields | Description |
|------|----------|------------|-------------|
| **CAR Target** | Yes | 1 | Category for color grouping and label prefix |
| **Cancer Type** | Yes | 1 | Sub-category for label suffix (shown in parentheses) |
| **Start Date** | Yes | 1 | Date field — where the bar begins on the X-axis |
| **End Date** | No | 1 | Date field — where the bar ends. Defaults to Start Date + 4 years if not provided |
| **Mouse Over** | No | Unlimited | Any additional fields shown in the hover tooltip |

The visual renders nothing until CAR Target, Cancer Type, and Start Date are all populated.

## Quick Start

### Prerequisites

1. **Node.js** (v18+) — [nodejs.org](https://nodejs.org/)
2. **R** (v4.0+) — [cran.r-project.org](https://cran.r-project.org/bin/windows/base/)
3. **Power BI Desktop** — [powerbi.microsoft.com](https://powerbi.microsoft.com/desktop/)
4. **pbiviz CLI**:
   ```bash
   npm install -g powerbi-visuals-tools
   ```

### Build and Import

```bash
npm install
npm run package
```

Then in Power BI Desktop: Visualizations pane > `...` > **Import a visual from a file** > select the `.pbiviz` from `dist/`.

Drag the visual onto your canvas and populate the field wells from your data model.

## Development History

This visual was built iteratively from an RHTML template through several rounds of refinement.

### Starting Point: RHTML Template

The project began as a fork of a generic RHTML custom visual template. The template provided:
- The TypeScript scaffolding (`visual.ts`, `htmlInjectionUtility.ts`, `settings.ts`) that receives base64-encoded HTML from the R engine and injects it into the Power BI DOM
- The `flatten_HTML.r` utility that embeds external JS/CSS inline and swaps local plotly.js for a CDN reference
- A single "Values" data role with a sample bar chart in `script.r`

The reference screenshot (`sample_data/stanford_iit_timeline.png`) of a Stanford CAR-T trial timeline was used as the design target for the swimlane chart layout.

### v1: Initial Implementation

**`capabilities.json`** was rewritten with 5 data roles (CAR Target, Cancer Type, Start Date, End Date, Mouse Over) mapped to a single `scriptResult` table input. **`script.r`** was rewritten to build a plotly Gantt chart using `type = "scatter", mode = "lines"` with thick line widths to form horizontal bars.

**Bug: Fields could not be dragged into the visual.** The data roles used `"kind": "Grouping"` which rejected fields typed as measures in the data model, and `"min": 1` conditions on all 4 required roles created a validation deadlock — Power BI couldn't satisfy all minimums simultaneously during incremental field adds.

**Fix:** Changed all roles to `"kind": "GroupingOrMeasure"`, removed `min` constraints (kept only `max: 1`), and explicitly added `mouseover` to the conditions block (Power BI defaults unmentioned roles to `max: 0`).

### v2: Removing Hardcoded Data

**Bug: The visual rendered a full chart even with only one field populated.** The R script contained a large hardcoded sample dataset that it fell back to whenever not all data roles were detected. With only CAR Target populated, the other roles weren't found, so the sample data rendered.

**Fix:** Removed all hardcoded sample data. The script now outputs a blank placeholder with an instructional message when required fields are missing, and exits early with `quit()`.

### v3: Making It General-Purpose

**Bug: The color palette was hardcoded to specific CAR target names** (CD19, CD22, GD2, etc.) using string-matching regex. The chart title was also hardcoded to "Stanford Investigator-Initiated CAR-T Trials".

**Fix:** Replaced the string-matching color function with a generic auto-assignment palette (plotly's D3 category20 colors). Colors are assigned in order of first appearance to each unique value of the first field. Removed the hardcoded title.

### v4: Fixing Hover and Broken Bars

**Bug 1: Hover tooltips only triggered near the "Today" line**, not on the actual bars. Each bar was drawn as a scatter line trace with only 2 data points (start and end). With `hovermode = "closest"`, plotly snapped to whichever of the few data points was nearest — usually the Today line.

**Bug 2: Projected (future) bars rendered as jagged/broken rectangles.** Using `dash = "dot"` on a `line.width = 20` trace caused the dot pattern to render as disconnected blocks.

**Fix for hover:** Each bar segment is now interpolated with ~1 point per month (via `make_date_seq()`), creating a dense sequence of hover targets along the full length of the bar.

**Fix for broken bars:** Replaced `dash = "dot"` with `opacity = 0.4` for the projected portion. This renders a clean, lighter bar that clearly distinguishes past from future without visual artifacts.

## Project Structure

```
├── script.r                    # R visualization code (swimlane timeline)
├── r_files/
│   └── flatten_HTML.r          # Utility: embeds JS/CSS inline (do not modify)
├── src/
│   ├── visual.ts               # TypeScript: receives HTML from R, injects into DOM
│   ├── htmlInjectionUtility.ts  # TypeScript: HTML parsing/injection helpers
│   └── settings.ts             # TypeScript: formatting pane settings model
├── style/
│   └── visual.less             # CSS styles for the visual container
├── capabilities.json           # Data roles, field constraints, script output config
├── dependencies.json           # R package (CRAN) dependencies
├── pbiviz.json                 # Visual metadata (name, GUID, version, author)
├── package.json                # npm dependencies and build scripts
├── sample_data/
│   ├── Trials.xlsx             # Sample dataset of Stanford CAR-T trials
│   └── stanford_iit_timeline.png  # Reference screenshot used during development
├── examples/                   # Example R scripts from the original template
│   ├── bar_chart.r
│   ├── scatter_plot.r
│   └── line_chart.r
└── assets/
    └── icon.png                # 20x20 icon in the Visualizations pane
```

## How It Works

```
Power BI Data Model
    ↓  (fields dragged into data role wells)
R Engine (script.r)
    ↓  builds plotly chart from car_target, cancer_type, start_date, end_date, mouseover
    ↓  saves as out.html
flatten_HTML.r
    ↓  embeds JS/CSS inline, swaps plotly.js for CDN reference
Power BI
    ↓  base64-encodes the HTML
visual.ts + htmlInjectionUtility.ts
    ↓  decodes payload, injects <head> and <body> into DOM
    ↓  calls HTMLWidgets.staticRender()
Browser
    → Interactive plotly chart with hover, zoom, pan
```

## R Dependencies

Declared in `dependencies.json` and auto-installed by Power BI:

| Package | Purpose |
|---------|---------|
| `plotly` | Interactive chart rendering |
| `ggplot2` | Dependency of plotly |
| `htmlwidgets` | Widget serialization to HTML |
| `xml2` | HTML parsing for the flatten utility |

All packages are approved for use in Power BI Service.

## Tips

- **Output file must be `out.html`** — Power BI looks for exactly this filename
- **Power BI deduplicates rows** — it applies `unique()` to input data. Add an index column if you need duplicate rows preserved
- **CDN for plotly.js** — `flatten_HTML.r` replaces local plotly.js with `https://cdn.plot.ly/` (whitelisted in `capabilities.json` under `privileges`)
- **End Date defaults** — if the End Date well is empty or contains NAs, bars default to Start Date + 4 years
- **R version** — Power BI Desktop uses the R installation configured in Options > R scripting

## Development Commands

| Command | Description |
|---------|-------------|
| `npm install` | Install npm dependencies |
| `npm run package` | Build the `.pbiviz` file into `dist/` |
| `npm run start` | Start dev server for live reload |
| `npm run lint` | Lint TypeScript files |

## Further Reading

- [Create an R-powered Power BI visual](https://learn.microsoft.com/en-us/power-bi/developer/visuals/create-r-based-power-bi-desktop)
- [Power BI custom visuals documentation](https://learn.microsoft.com/en-us/power-bi/developer/visuals/)
- [Plotly R reference](https://plotly.com/r/)
- [htmlwidgets for R](https://www.htmlwidgets.org/)
