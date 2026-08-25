# CMC — Unofficial Colégio Marista de Carcavelos iOS App

**Status:** implemented. M0–M8 are in the repo; see `README.md` to run and test.
**Source site:** https://marista-carcavelos.globaleduca.com/ (WordPress 6.x + Elementor 4.1.3 + "AnyWhere Elementor" post-block widgets)

This document is the design record. It is written to be read by a new contributor
(or by Claude) with no prior context.

---

## 1. Scope

An unofficial, read-only companion app for the school website. Four features:

| # | Feature | Source page |
|---|---------|-------------|
| 1 | **Destaques** — app's home screen; tap opens the linked page/file natively | `/` (homepage) |
| 2 | **Calendário** — the school year calendar, rendered natively | `/calendario-geral/` |
| 3 | **Ementas** — monthly canteen menus (PDFs) | `/oferecemos/refeitorio-ementas/` |
| 4 | **Notifications** — local notification when a new Destaque appears | daily poll |

### Non-goals
- No login / "Área Reservada" (private-area) support.
- No write operations of any kind. The app never posts to the site.
- No account system, no analytics, no server component (see §6.4 for the one optional exception).

### Ground rules (from the project owner)
1. **Strictly follow the iOS Human Interface Guidelines.** Native patterns win over
   web-like ones every time.
2. **Keep the code as simple as possible** so it is easy to contribute to. No
   architectural ceremony (no VIPER, no Clean Architecture layering, no DI container).
3. **The website is out of our control.** Every native feature is built *on top of*
   HTML and endpoints we do not own, and must degrade gracefully when they change.

---

## 2. Research findings (verified 2026-08-25, re-verified 2026-08-25 during implementation)

This section is the empirical basis for the design. It was established by fetching and
parsing the live pages. **Re-verify before trusting it** — the site can change at any time.

**Two corrections found while implementing** (both now reflected below and in the code):

1. The Destaques widget served **10** items, not 9. The cap is not fixed, so nothing may
   assume a count. The parser and its test assert *"every item has a URL"* and a lower
   bound, never an exact number.
2. The second calendar table is headed **"Pausas letivas"**, not *"Interrupções letivas"*.
   `Selectors.breaksTableMarkers` accepts both. The page also contains several unrelated
   **cookie-consent tables**, so tables must be identified by their first cell's text and
   never by index — a hazard the original research missed.

### 2.1 There is a WordPress REST API, and it is open

`https://marista-carcavelos.globaleduca.com/wp-json/wp/v2/` responds without auth.
Relevant custom post types:

| Post type | Label | REST base | Used for |
|-----------|-------|-----------|----------|
| `ultima_hora` | Última Hora | `/wp-json/wp/v2/ultima_hora` | **the "Destaques" list** |
| `destacados_home` | Destacados | `/wp-json/wp/v2/destacados_home` | the image-banner carousel (see §2.3) |

Supported query params (all verified working): `per_page`, `orderby=date`, `order=desc`,
`after=<ISO8601>`, `_fields=id,date,modified,title,slug`.

A trimmed request is tiny — this returned a **single ~100-byte object**:

```
/wp-json/wp/v2/ultima_hora?after=2026-08-01T00:00:00&orderby=date&order=desc&_fields=id,date,title
→ [{"id":224727,"date":"2026-08-18T12:00:41","title":{"rendered":"Circular"}}]
```

Response headers include `x-wp-total` (13) and `x-wp-totalpages`. There is **no `ETag`
and no `Last-Modified`**, and `cache-control: max-age=0`, so conditional requests are
not available; use `after=` to keep payloads small instead.

`robots.txt` disallows only `/wp-admin/` and sets no `Crawl-delay`. A once-daily poll is
well within courtesy limits.

### 2.2 CRITICAL: the API does *not* expose the Destaque's target URL

This is the single most important constraint in the whole project.

An `ultima_hora` item from the API looks like this — note what is missing:

```json
{
  "id": 224727, "date": "2026-08-18T12:00:41", "modified": "2026-08-24T13:15:06",
  "slug": "circular", "status": "publish", "type": "ultima_hora",
  "link": "https://marista-carcavelos.globaleduca.com/ultima_hora/circular/",
  "title": { "rendered": "Circular" },
  "acf": []
}
```

- There is **no `content`, no `excerpt`, and `acf` is an empty array.** The custom field
  holding the destination URL is not registered for REST output.
- `link` is a permalink to a **bare template page** — fetching
  `/ultima_hora/circular/` returns a 428 KB page containing **zero PDF links**. It is
  useless to us.

**Therefore: the destination URL exists only in the rendered homepage HTML.** Any design
that needs to open a Destaque must scrape the homepage. This is not optional.

### 2.3 Disambiguation: which section is "Destaques"?

The homepage has **two** candidate sections. This must be settled explicitly:

- **`<h3>Destaques</h3>` → backed by `ultima_hora`.** A text list of 9 items, each a
  title plus a call-to-action link. **This is the section literally labelled
  "Destaques", and this plan targets it.**
- A lower image-banner **carousel** backed by `destacados_home` (6 tiles: Calendário,
  Bom Dia Maristas, LEMA, Proteção à Infância, Trabalha Connosco, Fotos). Linked
  targets include off-site destinations (`bomdiamaristas.pt`, `view.genially.com`,
  `mqmilpalavras.com`).

See §10, open question **Q1**.

### 2.4 Destaques — exact DOM shape

Widget container: `div[data-source="ultima_hora"]` (Elementor element id `aa95852`,
class `ae-post-widget-wrapper`). One `article.ae-post-list-item` per Destaque. Inside
each article:

| Field | Selector | Example |
|-------|----------|---------|
| Title | `span.elementor-icon-list-text` | `Circular` |
| CTA label | `span.elementor-heading-title a` (text) | `Agosto 2026` |
| Target URL | `span.elementor-heading-title a[href]` | `.../uploads/2026/08/Circular-de-agosto-2026-1.pdf` |

The anchor carries `target="_blank"`.

The items rendered on the homepage are **exactly the first N of the 13 items the API
returns in `date desc` order**, same order. So homepage order == API order, and the
widget caps at some N — **9 when first researched, 10 a few hours later.** Treat the
count as unstable and never assert it. Live snapshot (10 items):

| # | Title | CTA | Target kind |
|---|-------|-----|-------------|
| 1 | Circular | Agosto 2026 | PDF |
| 2 | Manuais Escolares 26-27 | Consultar | internal page |
| 3 | Alteração do calendário de exames | Consultar | PDF |
| 4 | Material escolar 1º, 2º e 3º ciclos | — | internal page |
| 5 | Calendário Geral 2026-2027 | — | PDF |
| 6 | Banco de Resumos | — | **external** (`bancoderesumos.marista-carcavelos.org`) |
| 7 | Avaliação Externa | — | internal page |
| 8 | Preçário | — | PDF |
| 9 | Certificação Cambridge 2025-2026 | Consultar | PDF |
| 10 | Regulamento Interno 2025-2027 | Consultar | PDF |

**Design consequence:** a Destaque's target may be a PDF, an internal page, or an
off-site URL. The app must classify at open time (§5.2).

### 2.5 Calendário — exact structure

`/calendario-geral/` contains **no PDF, no iframe, no calendar plugin** — it is plain
Elementor HTML. Three parts:

1. **`Semestres letivos`** — a `<table>`: semester → Início / Fim. Cells can hold
   multiple year-group-specific dates, e.g. *"4 de junho 2027 – 9º, 11º e 12º anos"*.
2. **`Pausas letivas`** — a `<table>`: break name → Início / Fim
   (Intercalares, Natal, Carnaval, Verão, …). The site has also called this
   *"Interrupções letivas"*; both spellings are accepted.
   **The page also contains unrelated cookie-consent tables**, so the two real tables are
   found by matching the first cell of the first row, never by index.
3. **A 12-month accordion**, `Setembro` → `Agosto`, **104 event entries** (106 `<p>`
   elements, two of which are empty and are skipped silently).

Each `<p>` entry is: a **first line = the date**, then `<br />`, then one or more
**event lines** (also `<br />`-separated). Example:

```html
<p><strong>25 de setembro </strong><br /> Dia de Turma – 2º ano<br /> Dia de Turma – 5 anos (Pré-escolar)</p>
```

#### Parsing hazards — all confirmed present

- **The page contains the accordion TWICE.** Elementor renders both a legacy
  `.elementor-accordion` (with `a.elementor-accordion-title`) and a newer
  `<details class="e-n-accordion-item">` version — responsive variants. Both list all
  12 months. **Parse one and ignore the other, or dedupe by month name**, otherwise
  every event appears twice.
- **Do not rely on `<strong>` to find the date.** At least one entry inverts the
  bolding — `<p>10 de setembro<br /><strong>Receção aos novos alunos…</strong></p>`.
  Parse by **line position** (first `<br/>`-separated line is the date), not by tag.
- **Dates carry no year.** Infer it from the academic year: months Setembro–Dezembro →
  first year, Janeiro–Agosto → second year. Derive the academic year from the
  `Semestres letivos` table (currently 2026 → 2027), and fall back to the page title
  (*"Calendário Geral"*) / current date if that fails.
- **Five distinct date formats** occur (8 of 104 entries are non-simple):

  | Format | Example | Meaning |
  |--------|---------|---------|
  | `D de MONTH` | `2 de setembro` | single day |
  | `D a D de MONTH` | `7 a 10 de setembro` | inclusive range |
  | `D e D de MONTH` | `27 e 28 de janeiro` | two discrete days |
  | `D de MONTH a D de MONTH` | `30 de março a 2 de abril` | cross-month range |
  | `D ou D de MONTH` | `8 ou 22 de maio` | **either/or — genuinely ambiguous** |

  Trailing whitespace inside the date element is common (`"22 de setembro "`).
  `&#8211;` (en dash) appears throughout and must be HTML-unescaped.
  Month names are lowercase in dates, Title Case in accordion headers.

**Design consequence:** the parser must return a *date expression*, not a single
`Date`. Model it as an enum (§4.3) and let the UI decide how to show `ou` cases —
never silently pick one.

### 2.6 Ementas — exact structure

`/oferecemos/refeitorio-ementas/` is a flat, simple page:

```
<h2>Ementas</h2>
  <h4>Pré-Escolar</h4>   → <a>junho</a>, <a>julho</a>
  <h4>Geral</h4>         → <a>junho</a>, <a>julho</a>
```

Two **tracks** (`Pré-Escolar`, `Geral`), each with month links to PDFs under
`/wp-content/uploads/<YYYY>/<MM>/`:

```
Ementa-pre-Carcavelos-JUNHO-2026.pdf
Ementa-Pre-escolar-Carcavelos-JULHO-2026.pdf
Ementa-geral-CARACAVELOS-JUNHO-2026.pdf     ← note the typo in the filename
Ementa-geral-Carcavelos-JULHO-2026.pdf
```

Notes and hazards:
- **Link text is only the month name** (lowercase, no year). The year must come from
  the **URL path** (`/2026/05/` = upload month) or the filename. These disagree:
  `JUNHO-2026.pdf` sits under `/2026/05/`. **Trust the filename's month/year when it
  parses; fall back to the link text plus the upload path's year.**
- Filenames are **inconsistently cased and even misspelled** (`CARACAVELOS`).
  Never pattern-match on the filename to determine the track — use the `h4` grouping.
- **Only 2 months were live** at snapshot time, and they are already in the past
  (June/July 2026, snapshot 2026-08-25). The page is maintained irregularly.
  The UI must handle 0, 1, or many months, and must not imply freshness it can't verify.

---

## 3. Architecture

### 3.1 Guiding decision: use each source for what it is good at

| Need | Source | Why |
|------|--------|-----|
| Destaques list **with links** (foreground) | homepage HTML scrape | only place the target URL exists (§2.2) |
| "Is there a new Destaque?" (background) | `ultima_hora` REST API + `after=` | ~100 bytes vs a 579 KB homepage download; stable integer ids |
| Calendário | `/calendario-geral/` HTML scrape | no API for it |
| Ementas | `/oferecemos/refeitorio-ementas/` HTML scrape | no API for it |

The background poll deliberately does **not** need the URL: the notification's job is to
say *"«Circular» foi publicado"* and open the app, which then loads the real list.
This keeps the daily background task cheap and reliable.

### 3.2 Stack

- **SwiftUI**, **iOS 17+**, Swift 5.9+. Xcode project, no workspace.
- **`async`/`await` + `URLSession`.** No Combine, no reactive plumbing.
- **One third-party dependency: [SwiftSoup](https://github.com/scinfu/SwiftSoup)** (SPM,
  pure Swift, MIT). *Justification:* this app is fundamentally an HTML-scraping app
  against markup we do not control. Regex-based HTML parsing is the classic
  unmaintainable trap and directly conflicts with "easy to contribute". SwiftSoup gives
  contributors CSS selectors (`article.ae-post-list-item`), which are readable and match
  the selectors documented in §2. This is a deliberate, single, well-scoped exception to
  a no-dependencies preference.
- **No backend.** Persistence is JSON files in Application Support + `UserDefaults` for
  small state.

### 3.3 Shape of the code

Deliberately flat. Three folders, no abstraction layer for its own sake:

```
CMC/
  CMCApp.swift              app entry, TabView, background-task registration
  Models/
    Destaque.swift
    CalendarYear.swift      semesters, breaks, months, events, DateExpression
    Ementa.swift            track + month + URL
  Services/
    SiteClient.swift        all URLSession calls; the ONLY place URLs are built
    Selectors.swift         ★ every CSS selector / regex, in ONE file
    DestaquesParser.swift
    CalendarParser.swift
    EmentasParser.swift
    Cache.swift             generic Codable JSON load/save
    NotificationService.swift
    BackgroundRefresh.swift
  Views/
    DestaquesView.swift
    DestaqueOpener.swift    URL → PDF / Safari / QuickLook routing
    CalendarView.swift
    EmentasView.swift
    Common/                 LoadingView, ErrorView, EmptyStateView
CMCTests/
  Fixtures/                 saved copies of the 3 real HTML pages
  *ParserTests.swift        parse fixtures offline, assert exact counts
```

**`Selectors.swift` is the load-bearing convention.** When the site changes — and it
will — a contributor should need to edit exactly one file. Every selector from §2 lives
there as a named constant with a comment recording what it matched and when.

### 3.4 Resilience contract (rule 3 made concrete)

Because the site is not ours:

1. **Parsers never throw on partial failure.** A parser returns what it understood and
   a list of non-fatal warnings. One malformed calendar entry must not blank the screen.
2. **Every screen caches its last good result** and renders it while refreshing, with a
   "last updated" timestamp. A broken site becomes stale data, not an empty app.
3. **Parser tests run against checked-in HTML fixtures**, so they are offline,
   deterministic, and fast. Assert the §2 invariants: 9 Destaques with non-nil URLs,
   12 calendar months, 104 events, both ementas tracks present.
4. **A `refresh-fixtures` script** re-downloads the three pages into `Fixtures/`.
   When tests then fail, the site changed — that diff *is* the alert, and the failing
   test tells the contributor exactly which selector died.
5. **Never fabricate.** If the ementas page lists no current month, show
   *"Sem ementas publicadas"* — never guess a URL by pattern, even though the filenames
   look predictable.

---

## 4. Data layer

### 4.1 `Destaque`

```
id: Int?          // from API when joined, nil when scrape-only
title: String     // "Circular"
ctaLabel: String? // "Agosto 2026" / "Consultar"
url: URL
publishedAt: Date? // from API, joined by title
kind: Kind        // .pdf | .webPage | .externalWebPage | .otherFile
```

Fetch: GET `/`, select `div[data-source="ultima_hora"] article.ae-post-list-item`, map
per §2.4. Optionally then GET the trimmed `ultima_hora` API and **join by title** (order
also matches) to fill `publishedAt` and `id`. If the join fails, keep the scraped list —
dates are a nice-to-have, links are not.

`kind` is derived from the URL: `.pdf` if path ends `.pdf`; `.webPage` if host is
`marista-carcavelos.globaleduca.com`; `.otherFile` for other known document extensions;
`.externalWebPage` otherwise.

### 4.2 `Ementa`

```
track: String   // "Pré-Escolar" | "Geral"  (verbatim from the h4)
monthLabel: String   // "junho"
month: Int?; year: Int?   // parsed from filename, fallback upload path
url: URL
```

Group by `track` in `h4` document order — do **not** hardcode the two track names, so a
third track appearing does not require a code change.

### 4.3 `CalendarYear`

```
academicYear: (start: Int, end: Int)
semesters: [Semester]      // from the first table
breaks: [Break]            // from the second table
months: [MonthSection]     // 12, in site order Setembro → Agosto
  MonthSection: name, monthNumber, year, events: [CalendarEvent]
  CalendarEvent: dates: DateExpression, titles: [String]
```

```
enum DateExpression {
  case single(Date)
  case range(Date, Date)       // "7 a 10 de setembro", "30 de março a 2 de abril"
  case discrete([Date])        // "27 e 28 de janeiro"
  case eitherOr([Date])        // "8 ou 22 de maio" — surface BOTH, never pick one
  case unparsed(String)        // keep the raw text and still show it
}
```

`.unparsed` is essential: an unrecognised format must still be **displayed verbatim**,
never dropped. A parent missing an event because our regex was too strict is a worse
failure than an ugly row.

---

## 5. UI — HIG-aligned

### 5.1 Navigation: a tab bar, not a "menu"

The owner described an "app menu" with Calendar and Ementas entries. The HIG-correct
realisation of that on iOS is a **`TabView` tab bar**, because these are three
**peer, top-level destinations**. A hamburger/side menu is an Android/web pattern that
the HIG steers away from, and rule 1 is "strictly follow the HIG".

```
Tab 1  Destaques   star / sparkles      ← launch tab, per requirement 1
Tab 2  Calendário  calendar
Tab 3  Ementas     fork.knife
```

If a 4th+ section is ever added, add a `Mais` tab rather than reverting to a drawer.

Throughout: system fonts with **Dynamic Type** (no fixed sizes), semantic colours
(`.label`, `.secondaryLabel`, `systemGroupedBackground`) so dark mode is automatic,
full VoiceOver labels, 44×44 pt minimum touch targets, and Portuguese (pt-PT) as the
base localization — the content is Portuguese, so the chrome should be too.

### 5.2 Destaques (home)

- `NavigationStack` + `List` (`.insetGrouped`), title "Destaques" (large title).
- Row: title as primary text, `ctaLabel` as secondary, plus an **SF Symbol denoting the
  target kind** (`doc.richtext` PDF, `safari` external, `chevron.right` internal) so the
  user knows what a tap will do before tapping. Publish date as a relative footnote when
  known.
- `.refreshable` pull-to-refresh. Cached content shows immediately on launch.
- **Tap routing — "some kind of iOS native modal", per requirement 1:**

  | Target | Presentation |
  |--------|--------------|
  | PDF | in-app **PDFKit** viewer in a sheet, with a nav bar and a **`ShareLink`** (so it can be saved to Files / printed / AirDropped) |
  | Internal or external web page | **`SFSafariViewController`** — sheet presentation, Reader-mode available, cookies/reading list shared with Safari, and the user cannot get lost outside our app |
  | Other file type | download to a temp URL, present via **QuickLook** (`QLPreviewController`) |

  `SFSafariViewController` is the HIG-sanctioned way to show third-party web content;
  a bare `WKWebView` with no chrome would be a worse, less trustworthy experience.
  Never render the school's site inside a chrome-less webview and pass it off as native.
- Long-press context menu: *Copiar link*, *Partilhar*, *Abrir no Safari*.

### 5.3 Calendário

The most valuable native win, since the source is a 12-month accordion of plain text.

- **Segmented control** at the top: **`Ano letivo`** / **`Próximos`**.
  - *Próximos* (default): a single chronological `List` of events from today forward,
    grouped by month with sticky section headers — the "what's next?" question a parent
    actually has. Today's events pinned at top.
  - *Ano letivo*: all 12 months, `Setembro`→`Agosto`, in `DisclosureGroup`s mirroring
    the site's own accordion so it feels familiar.
- Above the list, a compact **summary card** rendering the two tables: semester start/end
  and the next upcoming break. These are high-value facts currently buried in a table.
- Event row: formatted date badge on the leading edge, event title(s) as the body.
  `.eitherOr` renders as e.g. *"8 ou 22 de maio"* with both dates visible.
  `.unparsed` renders its raw string.
- **`Adicionar ao Calendário`** per event via **EventKit** (`EKEventEditViewController`,
  so the user reviews and confirms — no silent calendar writes), plus an
  **export-the-year-as-`.ics`** `ShareLink`. This is the flagship "native feature built
  on top of a site that has none".
  - `.eitherOr` and `.unparsed` events are **not** exportable to EventKit; disable the
    action with an explanatory footnote rather than guessing a date.
- Searchable via `.searchable` over event titles.

### 5.4 Ementas

- `List`, one **`Section` per track** (`Pré-Escolar`, `Geral`), header from the `h4`.
- Row per month: month name Title-Cased for display plus its year
  (*"Junho 2026"*), `doc.richtext` icon.
- **Tap → the same in-app PDFKit sheet** as Destaques, with `ShareLink`. Reuse
  `DestaqueOpener`; do not write a second PDF viewer.
- The current month, when present, is highlighted and sorted first.
- Empty state: *"Sem ementas publicadas"* with a "Abrir a página no Safari" button, so
  a stale source page still leaves the user a path forward.

---

## 6. Notifications

**Requirement:** notify when a new Destaque is published, by polling once per day in the
morning.

### 6.1 Honest statement of the platform limit

**iOS cannot guarantee a daily morning fetch for an app with no server.**
`BGAppRefreshTask` lets us set an *earliest* begin date; the actual execution time is
chosen by iOS based on how much the user uses the app, battery, and network, and it may
be **skipped entirely** for days if the app is rarely opened. The scheduled-time
guarantee the requirement implies is not something the OS offers.

This does not block the feature — it shapes it. The design below is best-effort daily
and, importantly, **can never miss a new Destaque permanently**, because it also checks
on every foreground. §6.4 records the only way to get true reliability, as an optional
later phase.

### 6.2 Design

- **State:** a `Set<Int>` of already-seen `ultima_hora` ids, plus the newest seen `date`,
  in `UserDefaults`.
- **`BGAppRefreshTask`** registered at launch; after each run, reschedule with
  `earliestBeginDate` = **tomorrow ~07:00 local**. The task:
  1. GETs `/wp-json/wp/v2/ultima_hora?orderby=date&order=desc&per_page=20&_fields=id,date,title`
     (a few hundred bytes).
  2. Diffs ids against the seen set.
  3. For each new item, posts a **local notification**: title *"Novo destaque"*, body =
     the Destaque title. Two or more new items collapse into one summary notification
     (*"3 novos destaques"*) rather than a burst.
  4. Saves state. Always calls `setTaskCompleted`, and reschedules even on failure.
- **Foreground safety net:** run the exact same diff on every `.active` transition. This
  is what makes the feature dependable in practice — an opportunistic background miss
  costs latency, never a lost notification.
- **First run seeds the seen-set silently** — never notify 13 times on install.
- **Permission is requested in context**, not at first launch: after the user has seen
  the Destaques list, with a short explanation of what they'll get. A cold
  `UNUserNotificationCenter` prompt on launch is a HIG anti-pattern and gets denied.
- **Tapping the notification** deep-links to the Destaques tab. If the id can be matched
  to a scraped row, open that Destaque's target directly; otherwise just show the list.
  (The background poll has no URL by design — §3.1.)
- A **`Notificações` toggle** in a small settings surface, defaulting on once granted.

### 6.3 Why the API and not the homepage for polling

579 KB of HTML per day per user, parsed with SwiftSoup in a background task with a tight
time budget, versus a few hundred bytes of JSON and integer id comparison. The API is
also far more stable than Elementor's generated class names. Use the cheap, stable path
for the unattended job and the scrape for the attended one.

### 6.4 Optional later phase — real push (explicitly out of scope for v1)

True guaranteed morning delivery needs a sender. A minimal, serverless-ish option: a
**GitHub Action** on a cron that polls the same public API and sends APNs pushes for new
ids. It adds an APNs key, a device-token registry, and a privacy surface — real cost
against rule 2. **Not in v1.** Recorded so the tradeoff is not rediscovered later.

---

## 7. Milestones

| M | Deliverable | Done when |
|---|-------------|-----------|
| **M0** | Xcode project, SwiftSoup, `SiteClient`, `Selectors.swift`, 3 HTML fixtures, `Cache` | `swift test` runs green on fixtures |
| **M1** | Destaques tab: parse, list, cache, pull-to-refresh | 9 items, every one with a non-nil URL |
| **M2** | `DestaqueOpener`: PDFKit sheet / `SFSafariViewController` / QuickLook | all 9 live items open correctly; PDF, internal and external cases each verified |
| **M3** | Ementas tab, reusing the PDF viewer | both tracks + all months; empty state verified |
| **M4** | Calendar parser + models | 12 months, 104 events, dedupe proven, all 5 date formats covered by tests |
| **M5** | Calendar UI: Próximos / Ano letivo, summary card, search | — |
| **M6** | EventKit add-to-calendar + `.ics` export | ambiguous events correctly non-exportable |
| **M7** | Notifications: background task, foreground diff, in-context permission | new-item diff unit-tested against two fixture snapshots |
| **M8** | Polish: Dynamic Type, VoiceOver, dark mode, pt-PT strings, app icon, README | HIG pass on every screen |

M1+M2 alone are a genuinely useful app. Ship early, iterate.

---

## 8. Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Elementor class names change and the Destaques scrape breaks | **high** — generated markup | all selectors in `Selectors.swift`; fixture tests; cached last-good list; visible "last updated" |
| The `ultima_hora` REST endpoint is closed off | medium | fall back to the homepage scrape for notification diffing (by title) |
| Calendar HTML restructured next school year | **high** — hand-authored annually | `.unparsed` fallback keeps text visible; tolerant parser; per-month independence |
| Ementas page left stale by the school | **confirmed already** | honest empty/stale states; never synthesise URLs |
| Background refresh rarely fires | **certain for light users** | foreground diff is the real guarantee (§6.2) |
| App Store review: unofficial app using school name/branding | medium | name it clearly unofficial, no school logo in the icon, "não oficial" in the description; be ready to seek the school's written consent |
| Private-area ("área privada") Destaques surfacing | low | the categorised private items live in `destacados_home`, not `ultima_hora`; if such an item ever appears, opening it just lands on the site's own login page — acceptable |

---

## 9. Contributor experience

Rule 2 concretely means:
- A new contributor can add a screen by copying an existing `Service` + `View` pair.
- No file over ~200 lines. No generics beyond `Cache<T: Codable>`.
- Parser functions are pure: `String (HTML) -> ([Model], [Warning])`. Trivially testable,
  no network in tests.
- `README.md` must include: how to run, how to refresh fixtures, and **"the site changed,
  now what?"** — the single most likely maintenance task, pointing straight at
  `Selectors.swift` and the failing fixture test.

---

## 10. Open questions

- **Q1 — Which "Destaques"?** *Built as planned:* the `<h3>Destaques</h3>` text list
  (`ultima_hora`, §2.3), being the section actually labelled that. A test asserts the
  `destacados_home` carousel's targets never leak in. **Still open:** whether to also
  show the carousel as a header above the list.
- **Q2 — Calendar default view:** *Built as planned:* *Próximos* is the default, with
  *Ano letivo* one tap away in a segmented control. **Confirm.**
- **Q3 — Notification time:** *Built as planned:* 07:00 local `earliestBeginDate`,
  not user-configurable. **Still open** — the settings screen has room for it, but
  since iOS ignores the requested time anyway (§6.1), exposing it would promise more
  than the OS delivers.
- **Q4 — Distribution:** personal/TestFlight/AdHoc, or public App Store? This decides how
  much the §8 naming-and-branding risk actually matters.
- **Q5 — Has the school been asked?** Even for an unofficial app, a heads-up to the
  Colégio is worth it — and it is the one path to eventually getting real data access
  instead of scraping.
