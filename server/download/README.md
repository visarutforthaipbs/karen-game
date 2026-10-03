# Beta download website

The download page is part of the Under Two Skies website identity. The promotion
site at `/Users/lighthouse-control/Desktop/satellite-shadow-site` is the design
source: `src/styles/global.css` and `src/layouts/BaseLayout.astro`.

Keep these shared brand values aligned when changing either site:

- Background `#101b21`, panels `#16252b`, text `#f4efdf`, secondary text `#b8c3c3`.
- Gold links, actions and focus indicators `#e8bf76`; action text `#18252b`.
- Kanit for Thai/body text; Chakra Petch for Latin platform headings and labels.
- Approved `header-logo.png`, 144px wide on desktop and 128px on mobile.
- Straight-edged gold buttons, thin panel borders, restrained spacing.

`public/` contains exact copies of the promotion website's approved logo, icon,
fonts and font licences, served by Workers Static Assets on the download origin.
When those source assets change, copy the corresponding files from the promotion
site's `public/` and verify their hashes match. Do not independently restyle this
page or introduce another logo. Download clarity still takes priority: keep each
platform's action, ZIP size and installation instructions together.

Deploy with `wrangler deploy --config server/download/wrangler.toml --profile undertwoskies-game` from the game
repository after verifying the intended account. Check the page on desktop and
390px mobile, loaded logo/fonts, ZIP HEAD/range requests and SHA256SUMS.txt.
Installer archives remain in the R2 bucket, separate from `public/`.

English downloads: `/en/`; Thai downloads: `/` (also `/th/`). Language switches
change website instructions; the same beta3 installer is served in both languages.
The game itself has a saved Thai/English switch for UI, subtitles and speech in Settings.
Both languages default to Thai on an existing/new profile until the player changes it.
`website-ux.js` is shared with the promotion site's `public/website-ux.js`:
advisory OS suggestions, phone/tablet guidance and explicit-click clipboard copy.
Keep these copies aligned. No analytics or device information is transmitted.
Requirements must remain labelled as being measured until hardware testing
provides evidence. Linux/Steam Deck stays labelled untested until native testing.
