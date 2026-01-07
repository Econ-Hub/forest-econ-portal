# Forest Economics Portal

This repository contains the source code for the "Forest Economics Portal", a Quarto-based website for hosting internal forecasts and exploratory analysis.

## Overview

The portal is designed to provide lightweight and transparent economic forecasts. It currently features:

-   **NA Starts Dashboard:** Analyzes Canadian housing starts (SAAR) by dwelling type. It pulls data from CMHC, visualizes historical trends (last 5 years), and projects future starts using a random walk with drift model.

## Repository Structure

-   `index.qmd`: The homepage of the portal.
-   `forecasts-na-starts.qmd`: The Quarto document generating the North American Starts dashboard. It uses R for data scraping (from CMHC), processing, and visualization.
-   `about.qmd`: Information about the site's ownership and deployment.
-   `_quarto.yml`: The Quarto project configuration file.
-   `netlify.toml`: Configuration for Netlify deployment.

## Getting Started

### Prerequisites

To render this project locally, you will need:

-   [Quarto](https://quarto.org/)
-   R
-   The following R packages:
    -   `rvest`
    -   `tidyverse`
    -   `lubridate`
    -   `plotly`

### Rendering the Site

To preview the site locally:

```bash
quarto preview
```

To render the entire site:

```bash
quarto render
```

## Deployment

The site is configured for deployment on Netlify via the `netlify.toml` file.
