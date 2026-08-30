# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

**CMC** — an *unofficial*, read-only iOS companion app for the
Colégio Marista de Carcavelos website (https://marista-carcavelos.globaleduca.com/).

SwiftUI, iOS 17+, no backend. Four features: **Destaques** (home), **Calendário**,
**Ementas**, and a **daily notification** when a new Destaque is published.

**Read `PLAN.md` before doing anything substantive.** It contains the verified structure
of every page we scrape, the exact CSS selectors, and the parsing hazards. Do not
re-derive that research; do re-verify it if something doesn't match.

Current state: **implemented.** M0–M8 from `PLAN.md` §7 are in the repo. `README.md`
covers how to run it, how to refresh fixtures, and the "the site changed, now what?"
procedure.

## The three rules

These come from the project owner and override any default preference:

1. **Strictly follow the iOS Human Interface Guidelines.** Native patterns over
   web-like ones, always. If a design choice would look out of place in a
   first-party Apple app, it is wrong.
2. **Keep the code as simple as possible so it is easy to contribute to.** No VIPER,
   no Clean Architecture, no DI container, no reactive plumbing. Flat structure,
   plain `async`/`await`, small files. If a change adds a layer of indirection,
   justify it or drop it.
3. **The website is out of our control.** Every native feature is built on top of HTML
   and endpoints we do not own. Assume they will change without notice.

## Non-negotiable technical facts

Getting these wrong wastes a lot of time, so they are repeated here from `PLAN.md`:

- **The WordPress REST API does *not* expose a Destaque's target URL.** `acf` is `[]`,
  there is no `content`, and the `link` permalink is a bare template page with no PDF on
  it. **The destination URL exists only in the rendered homepage HTML.** Any feature that
  opens a Destaque must scrape `/`. This is not negotiable — verify with the API before
  proposing otherwise.
- **Two data sources, on purpose** (`PLAN.md` §3.1):
  - foreground Destaques list → **scrape the homepage** (needs URLs)
  - daily new-item check → **`ultima_hora` REST API** with `after=` + `_fields=`
    (~100 bytes vs 579 KB, and stable integer ids)
- **The calendar page contains its accordion twice** (legacy `.elementor-accordion` and
  new `<details class="e-n-accordion-item">`). Parse one or dedupe by month, or every
  event doubles. The 104-event test is what catches a regression here.
- **The calendar page also contains cookie-consent tables.** Never pick the two real
  tables by index — match the first cell's text (`Semestres` / `Pausas`).
- **The Destaques count is not fixed.** It was 9 when `PLAN.md` was researched and 10 a
  few hours later. Assert *"every item has a URL"*, never a count.
- **Do not use `<strong>` to find calendar dates** — at least one entry inverts the
  bolding. Parse by line position within the `<p>`.
- **Calendar dates have no year and come in five formats**, including `8 ou 22 de maio`
  (either/or). Model as a `DateExpression` enum with an `.unparsed(String)` case.
  **Never silently pick a date, and never drop an entry you couldn't parse** — show the
  raw text instead.
- **Ementas filenames are inconsistent and sometimes misspelled** (`CARACAVELOS`), and
  the filename month disagrees with the upload path. Determine the track from the `h4`
  heading, never from the filename. **Never synthesise a PDF URL from a pattern**, even
  though they look predictable.
- **`BGAppRefreshTask` cannot guarantee a daily morning run.** Do not write code or
  docs that claim it does. The foreground diff on `.active` is the real guarantee.

## Conventions

- **`Services/Selectors.swift` holds every CSS selector and regex.** One file to fix when
  the site changes. Never inline a selector in a parser or a view.
- **`Services/SiteClient.swift` is the only place URLs are constructed** and the only
  place `URLSession` is called.
- **Parsers are pure functions**: `String (HTML) -> ([Model], [Warning])`. No network, no
  I/O, no throwing on partial failure — return what parsed and warn about the rest.
- **Every screen caches its last good result** and shows it while refreshing, with a
  visible "last updated". A broken site must degrade to stale data, never an empty screen.
- **Tests parse checked-in HTML fixtures** in `CMCTests/Fixtures/` — offline and
  deterministic. Assert the invariants from `PLAN.md` §2: 9 Destaques all with non-nil
  URLs, 12 calendar months, 104 events, both ementas tracks.
- Keep files under ~200 lines. Reuse `DestaqueOpener` for all PDF presentation — there
  should only ever be one PDF viewer in the app.
- **Language:** the app ships **pt-PT and English**. `pt-PT` is the source language, so
  the Portuguese string written inline *is* the key; add the English side to
  `CMC/Localizable.xcstrings`. Code, comments, types and commit messages stay English.
  Three things that silently break this:
  - `Text(someString)` takes a `String`, not a `LocalizedStringKey`, so it is **not**
    localized. Wrap it: `Text(LocalizedStringKey(x))`.
  - `UNMutableNotificationContent.title`/`.body` are plain `String` — use
    `String(localized:)` or the notification ships untranslated.
  - Never pin `.locale(Locale(identifier: "pt_PT"))` on a date format. Dates must follow
    the user's locale now that English is a supported language.

  **Scraped content stays Portuguese in every language** — month names, event titles and
  ementas headings are data from the site, not app chrome. Only translate UI you wrote.

## iOS specifics worth remembering

- Top-level navigation is a **`TabView` tab bar** (Destaques / Calendário / Ementas).
  The owner said "app menu"; on iOS that means a tab bar, not a drawer. Do not add a
  hamburger menu.
- Web content opens in **`SFSafariViewController`**, not a bare `WKWebView`.
- PDFs open in an in-app **PDFKit** sheet with a `ShareLink`.
- Other file types go through **QuickLook**.
- **EventKit writes must go through `EKEventEditViewController`** so the user confirms.
  Never write to a user's calendar silently.
- Notification permission is requested **in context**, after the user has seen the
  Destaques list — never on cold launch.
- Dynamic Type, semantic colours, full VoiceOver labels, 44×44 pt targets. No fixed
  font sizes, no hardcoded hex colours.

## Working here

- The app targets **iOS 17+**; it also builds and runs on **macOS 14+** so it can be
  built and tested without an iOS simulator installed. iOS is the design target and the
  HIG still governs. Keep every `#if os(...)` in `Views/Common/Platform.swift` and the
  three sheet files (`WebSheet`, `QuickLookSheet`, `EventEditSheet`) — screens must stay
  platform-free.
- **Models and the parsing layer are `nonisolated`**, because the project builds with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and parsers run off the main actor. Stores
  and views keep the MainActor default.
- Run the tests with
  `xcodebuild test -project CMC.xcodeproj -scheme CMC -destination 'platform=macOS'`.
- When the site's markup appears to have changed, verify against the live site with
  `curl` (or `playwright-cli`, though note Chrome may not be installed — pass
  `--browser webkit`), then update **both** `Selectors.swift` and the fixtures, and note
  the change in `PLAN.md` §2.
- Re-fetching a page to check a selector is cheap and always preferable to guessing.
  `robots.txt` allows it; be polite — no tight loops.
- Keep `PLAN.md` §2 accurate. It is dated research (verified 2026-08-25), and its value
  depends entirely on being trustworthy.
