# Website Editing Guide

The `umgr` website is a static GitHub Pages site served directly from `docs/`.

## Files

- `docs/index.html`: single-page site content
- `docs/provider-authoring.html`: provider guide page linked from the site
- `docs/assets/site.css`: site styles

## Local Preview

Use any static web server from the repository root. For example:

```bash
ruby -run -e httpd docs -p 4000
```

Then open:

- `http://localhost:4000/`

## Deployment

Deployment is handled by `.github/workflows/pages.yml`.

- Triggered on pushes to `main` when files under `docs/` change.
- Publishes the `docs/` directory as the GitHub Pages artifact.
