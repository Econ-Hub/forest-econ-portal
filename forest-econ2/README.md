# forest-econ2

Blank-slate starting point for the next iteration of the Forest Economics portal,
kept separate from the current pilot dashboard (which currently occupies the
`forest-econ` domain). This project will eventually be promoted to the main
"forest econ" site.

## Stack

- [Quarto](https://quarto.org/) static website (`type: website`)
- HTML output rendered to `_site/`
- Deployed via Netlify (see `netlify.toml`)

## Develop locally

```bash
# from the forest-econ2/ directory
quarto preview   # live-reload preview
quarto render    # build the static site into _site/
```

## Structure

- `_quarto.yml` — site/project configuration and navbar
- `index.qmd` — home page
- `about.qmd` — about page
- `netlify.toml` — Netlify build config (base = `forest-econ2`, publish = `_site`)
