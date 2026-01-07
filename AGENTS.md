# Instructions for AI Agents

This repository contains the "Forest Economics Portal", a static website built with Quarto and R.

## Project Structure
- `_quarto.yml`: Main configuration file.
- `index.qmd`: Home page.
- `forecasts-na-starts.qmd`: Analysis dashboard using R.
- `about.qmd`: About page.
- `_site/`: Generated static site (do not edit directly).

## Technology Stack
- **Framework**: Quarto
- **Language**: R
- **Key Packages**: `rvest`, `tidyverse`, `lubridate`, `plotly`

## Guidelines
1. **Editing Content**: Modify `.qmd` files, not the output in `_site/`.
2. **Code Execution**: The project is set up to execute R code. Ensure any new R code is valid and uses the specified dependencies.
3. **Paths**: Use relative paths.
4. **Style**: Follow standard R coding conventions (tidyverse style).
