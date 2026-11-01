# Website hosting

The public website at https://capsomnia.com is served by the
`capsomnia-language-router` Cloudflare Worker and its `ASSETS` binding.
The HTML, CSS, images, sitemap, and verification file are uploaded from `docs/`.
GitHub Pages is no longer the production origin. App downloads still use GitHub Releases.

The Worker runs before static assets to apply the language cookie, browser-language
preference, and legacy English URL redirects. Missing assets return 404; requests
and Worker errors do not fall back to an external origin. `docs/.assetsignore`
excludes GitHub Pages configuration, Markdown documentation, and CSS source files.

## Develop and deploy

Run `npm ci`, `npm run build:site`, and `npm test`. `npm run dev:site` starts
Wrangler with the same static-asset and language-routing behavior as production.
With Cloudflare authentication configured, `npm run deploy:worker` publishes both
Worker code and static assets.

The `Deploy Cloudflare site` workflow publishes main when website files, Worker
code, dependencies, or deployment configuration change. It also supports manual
runs from main. It uses the `CLOUDFLARE_ACCOUNT_ID` repository variable and the
`CLOUDFLARE_API_TOKEN` repository secret. The token must be limited to deploying
this Worker. Creating or changing domain routes requires separate zone permissions. Unrelated app-only changes do not
trigger website deployment.

## Domain and TLS

`wrangler.jsonc` declares the production Worker route. Cloudflare DNS proxying
must stay enabled. A proxied placeholder address keeps this route active without
an external origin. The zone redirects HTTP to HTTPS and `www.capsomnia.com` to
`capsomnia.com`, preserving paths and query parameters. SSL/TLS mode is Full
(strict). Website content is served inside Cloudflare, so it does not depend on
the former GitHub Pages origin certificate.

Do not restore an older Worker version that forwards requests to GitHub Pages:
its origin certificate was expired at migration. For rollback, deploy a previous
known-good static-asset version together with its matching Worker code.
