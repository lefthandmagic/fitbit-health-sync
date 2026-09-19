# Custom domain (Google rejected github.io)

Google: homepage and privacy must sit on a domain **you can verify**. `lefthandmagic.github.io` is a shared host. GitHub Pages is fine **after** a custom domain + Search Console ownership.

Do **not** add a `CNAME` file in this repo until the DNS record exists, or Pages will 404.

## Option A — fastest (you already have Search Console on billie.fyi)

Use a **subdomain of billie.fyi**, e.g. `https://fithealth.billie.fyi/`

1. In the billie.fyi DNS (Vercel / registrar), add:

   | Type | Name | Value |
   | --- | --- | --- |
   | CNAME | `fithealth` | `lefthandmagic.github.io` |

2. In the **fitbit-health-sync** repo → Settings → Pages → Custom domain: `fithealth.billie.fyi`. Commit the generated `CNAME`. Enforce HTTPS.
3. Search Console: billie.fyi is already a property. Add a URL-prefix property for `https://fithealth.billie.fyi/` if asked, or rely on **domain** verification of `billie.fyi` (preferred).
4. Cloud Console Authorized domains: `billie.fyi`
5. Homepage / privacy / terms:

   - `https://fithealth.billie.fyi/`
   - `https://fithealth.billie.fyi/privacy`
   - `https://fithealth.billie.fyi/terms`

The homepage copy now names **Fit Health Sync by Praveen Murugesan** so reviewers do not think this is the Billie product.

## Option B — cleaner brand (buy a domain)

Buy something like `fithealthsync.app` or `fithealthsync.com`. **Do not buy until you say yes.** Then same Pages + Search Console **domain** TXT steps, Authorized domain = that registrable domain.

## Search Console (must match Cloud project)

Use `lefthandmagic@gmail.com` as **Owner** on the Search Console property **and** Owner/Editor on the Google Cloud project that owns the iOS OAuth client.

Verify with a **DNS TXT** on the top private domain (not an HTML file on github.io).

## After it is live

Update:

- Cloud Console branding URLs
- `fastlane/metadata/en-US/marketing_url.txt`
- `fastlane/metadata/en-US/support_url.txt`
- `fastlane/metadata/en-US/privacy_url.txt`
- description.txt privacy footer
- README Pages URL
