# Power BI Custom Visual: Swimlane Timeline (RHTML)

An interactive Power BI custom visual that renders a **swimlane / Gantt-style timeline chart** using R and plotly. Each row is a horizontal bar spanning a date range, colored by a grouping category, with rich hover tooltips and optional milestone callout annotations. Built on top of the [RHTML custom visual template](https://github.com/snehitp/pbi_custom_RHTML_template).

![Timeline screenshot](sample_data/stanford_iit_timeline.png)

## Features

- **Swimlane bars** from Start Date to End Date on a date-scaled X-axis
- **Y-axis labels** from the Program Identifier field
- **Auto-colored by category** — unique values of the Program Category field are assigned distinct colors from a 20-color palette (D3 category20)
- **Solid / projected split** — bars are solid up to today's date and semi-transparent (40% opacity) for the projected future portion
- **"Today" reference line** — red dashed vertical line with "Today (Mon YYYY)" annotation
- **Milestone callout annotations** — optional date-labeled markers on bars, shown as colored label boxes with arrow stems, alternating above/below to avoid overlap
- **Milestone hover tooltips** — milestone callout boxes show a tooltip on hover (via plotly `captureevents`) with the milestone label, date, and any additional Milestone Tooltip fields
- **Truncation arrows** — when bars extend beyond the X-axis cap (2 years from today), a black right-pointing arrow with stalk indicates continuation, with hover text showing the actual end date
- **Bar hover tooltips** — left-justified tooltips showing program name, category, start/end dates, and any Mouse Over fields
- **Vertical scrolling** — when the chart exceeds the visual frame, the content is scrollable via an absolute-positioned wrapper div
- **Dynamic chart height** — 150px per bar when milestones are present, 40px per bar without, ensuring compact layout without milestones and sufficient spacing with them
- **Fully interactive** — zoom, pan, and hover via plotly.js
- **General-purpose** — no hardcoded data; works with any dataset

## Data Roles (Field Wells)

| Well | Required | Max Fields | Description |
|------|----------|------------|-------------|
| **Program Identifier** | Yes | 1 | Y-axis label for each bar |
| **Program Category** | Yes | 1 | Color grouping and legend |
| **Start Date** | Yes | 1 | Date field — where the bar begins on the X-axis |
| **End Date** | No | 1 | Date field — where the bar ends. Defaults to Start Date + 4 years if not provided |
| **Mouse Over** | No | Unlimited | Any additional fields shown in the bar hover tooltip |
| **Milestone** | No | 1 | Milestone label text (requires Milestone Time) |
| **Milestone Time** | No | 1 | Date when each milestone occurred (requires Milestone) |
| **Milestone Tooltip** | No | Unlimited | Additional fields shown when hovering over a milestone callout box |

The visual renders a blank placeholder until Program Identifier, Program Category, and Start Date are all populated. Milestone and Milestone Time must both be provided for callout annotations to render; if only one is present, it is ignored.

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

## Architecture

### How It Works

```
Power BI Data Model
    |  (fields dragged into data role wells)
    v
R Engine (script.r)
    |  builds plotly chart from data role variables
    |  saves as out.html
    v
flatten_HTML.r
    |  embeds JS/CSS inline, swaps plotly.js for CDN reference
    v
Power BI
    |  base64-encodes the HTML
    v
visual.ts + htmlInjectionUtility.ts
    |  decodes payload, injects <head> and <body> into DOM
    |  calls HTMLWidgets.staticRender()
    v
Browser — Interactive plotly chart with hover, zoom, pan
```

### Key Implementation Details

**Bar rendering:** Each bar is a plotly scatter trace (`type = "scatter", mode = "lines"`) with `line.width = 20`. Bars are split at today's date into a solid portion (past) and a 40% opacity portion (projected future). Each segment is interpolated with ~1 point per month via `make_date_seq()` to ensure hover detection works along the full bar length (not just at endpoints).

**Milestone annotations:** Plotly layout annotations (`layout(annotations = ...)`) with `showarrow = TRUE, arrowhead = 0` for stems. Callout boxes use `bgcolor` matching the bar color, white font, and are positioned with progressive alternating offsets (`-40, +40, -70, +70, -100, +100` pixels) to avoid overlap when a program has multiple milestones. Milestone dates are clamped to the bar's `[start_date, end_date]` range.

**Milestone hover:** Annotation `captureevents = TRUE` with `hovertext` containing the milestone label, date, and any Milestone Tooltip fields. **Known limitation:** plotly annotation hover labels cannot left-align multi-line text — the text appears centered regardless of `hoverlabel.align` settings. Attempted workarounds (CSS `text-anchor` override, JS MutationObserver, custom HTML tooltip div) all failed due to plotly's internal SVG rendering. This remains an open issue.

**Deduplication:** When milestones are provided, Power BI sends one row per program-milestone combination. The script deduplicates with `!duplicated(df$program_id)` to keep one row per program for bar rendering, while preserving the full milestone list separately.

**X-axis cap:** The X-axis extends to `min(max_end_date + 180 days, today + 2 years)`. Bars truncated by this cap get a black right-pointing arrow annotation (stalk + arrowhead) with hover text showing the actual end date.

**Scrolling:** The HTML output body is wrapped in an absolute-positioned div (`position:absolute;top:0;left:0;right:0;bottom:0;overflow-y:auto`) via `ReadFullFileReplaceString` post-processing.

**Layout:** No plot title, tight margins (`l=60, r=10, t=20, b=30`), horizontal legend below the chart. "Today" annotation at `y=1.02, yref="paper"`.

### Files to Modify vs. Files to Leave Alone

| File | Modify? | Purpose |
|------|---------|---------|
| `script.r` | **YES** | All visualization logic — bar rendering, milestones, hover, layout |
| `capabilities.json` | **YES** | Data role definitions, field constraints, script output config |
| `pbiviz.json` | **YES** | Visual metadata (name, GUID, version, description) |
| `r_files/flatten_HTML.r` | **NO** | Template utility — embeds JS/CSS, swaps plotly CDN |
| `src/visual.ts` | **NO** | Template scaffolding — HTML injection from R payload |
| `src/htmlInjectionUtility.ts` | **NO** | Template scaffolding — DOM parsing helpers |
| `src/settings.ts` | **NO** | Template scaffolding — formatting pane model |

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

## R Dependencies

Declared in `dependencies.json` and auto-installed by Power BI:

| Package | Purpose |
|---------|---------|
| `plotly` | Interactive chart rendering |
| `ggplot2` | Dependency of plotly |
| `htmlwidgets` | Widget serialization to HTML |
| `xml2` | HTML parsing for the flatten utility |

All packages are approved for use in Power BI Service.

## Development History

This visual was built iteratively from an RHTML template through several rounds of refinement.

### Starting Point: RHTML Template

The project began as a fork of a generic RHTML custom visual template. The template provided the TypeScript scaffolding, `flatten_HTML.r` utility, and a sample bar chart. The reference screenshot (`sample_data/stanford_iit_timeline.png`) of a Stanford CAR-T trial timeline was used as the design target.

### v1: Initial Swimlane Implementation

`capabilities.json` was rewritten with 5 data roles (Program Identifier, Program Category, Start Date, End Date, Mouse Over). `script.r` was rewritten to build a plotly Gantt chart using scatter traces with thick lines.

**Bug:** Fields could not be dragged into the visual — `"kind": "Grouping"` rejected measures, and `"min": 1` on multiple roles created a validation deadlock.
**Fix:** Changed all roles to `"kind": "GroupingOrMeasure"`, removed `min` constraints, explicitly added `mouseover` to conditions (unmentioned roles default to `max: 0`).

### v2: Removing Hardcoded Data

**Bug:** Hardcoded sample dataset rendered when not all roles were populated.
**Fix:** Removed all sample data; script outputs a blank placeholder with instructional message when required fields are missing.

### v3: General-Purpose Colors

**Bug:** Color palette was hardcoded to specific target names via regex.
**Fix:** Replaced with generic auto-assignment from D3 category20 palette based on unique Program Category values.

### v4: Hover Detection and Bar Rendering

**Bug 1:** Hover only triggered near the "Today" line (only 2 data points per trace).
**Bug 2:** `dash = "dot"` on thick lines rendered as broken blocks.
**Fix:** Interpolated ~1 point per month along each bar for hover detection. Replaced `dash = "dot"` with `opacity = 0.4` for projected portions.

### v5: Milestone Callout Annotations

Added 2 optional data roles (Milestone, Milestone Time). Milestone callout boxes rendered as plotly annotations with alternating above/below positioning. Required deduplication logic since milestones cause repeated program rows.

### v6: Tooltip Fixes and Layout Tuning

**Bug:** Hover tooltips showed raw HTML div tags — plotly's `hoverinfo = "text"` doesn't support `<div>` styling.
**Fix:** Replaced HTML div wrapper with `hoverlabel = list(align = "left")` in layout.

Added vertical scrolling (absolute-positioned wrapper div), X-axis cap (originally 5 years, later reduced to 2 years), dynamic chart height, title removal, and margin tightening.

### v7: Truncation Arrows and Milestone Tooltips

Added black right-pointing arrow annotations for bars truncated by the X-axis cap. Added Milestone Tooltip data role for additional hover fields on milestone callout boxes. Milestone annotations use `captureevents = TRUE` with `hovertext` for hover on the callout box itself.

### Known Issues and Lessons Learned

| Issue | Status | Detail |
|-------|--------|--------|
| Milestone hover text is centered, not left-aligned | **Open** | Plotly annotation `hoverlabel.align` does not work for multi-line text. CSS `text-anchor` overrides, JS MutationObserver, and custom HTML tooltip approaches were all attempted and failed. |
| `"kind": "Grouping"` rejects measures | Resolved | Always use `"kind": "GroupingOrMeasure"` |
| `"min": 1` on multiple roles simultaneously | Resolved | Causes PBI validation deadlock — never use `min` constraints on multiple required roles |
| Unmentioned roles in conditions default to `max: 0` | Resolved | Explicitly include all roles (e.g., `mouseover` with `"min": 0`) |
| `dash = "dot"` on thick lines | Resolved | Renders as broken blocks — use `opacity` instead |
| Only 2 endpoints per trace | Resolved | Hover misses the bar body — interpolate points along bar length |
| HTML div tags in hover text | Resolved | Plotly renders them as literal text — use `hoverlabel.align` instead |
| Scrolling with `height: 100%` | Resolved | Doesn't work in PBI container — use absolute positioning |

## Tips

- **Output file must be `out.html`** — Power BI looks for exactly this filename
- **Power BI deduplicates rows** — it applies `unique()` to input data. Add an index column if you need duplicate rows preserved
- **CDN for plotly.js** — `flatten_HTML.r` replaces local plotly.js with `https://cdn.plot.ly/` (whitelisted in `capabilities.json` under `privileges`)
- **End Date defaults** — if the End Date well is empty or contains NAs, bars default to Start Date + 4 years
- **R version** — Power BI Desktop uses the R installation configured in Options > R scripting
- **Always build after changes** — run `npm run package` after any modification to `script.r`, `capabilities.json`, or `pbiviz.json`
- **GUID change = new visual** — if you change the GUID in `pbiviz.json`, Power BI treats it as a different visual; you must re-import rather than update

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
