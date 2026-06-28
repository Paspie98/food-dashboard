# Mission 10 QA — Source Credibility & Cadence-Upgrade Audit

Date: 2026-06-28. Probe-date "today" = 2026-06-28. Principle applied: a source is only as
good as its worst property; tier on the binding constraint; nothing enters on reputation —
live probe or it doesn't enter. **Nothing committed. No source family added.**

## Step 1 — Cadence audit of the existing registry (v8, 59 captured rows)

Observed native cadence MATCHED the claimed cadence on **every** row (no row publishes
slower than assumed). Freshness against budget:

| cadence class | rows | latest obs | age at probe | note |
|---|---|---|---|---|
| weekly (EU physical: DG AGRI cereals/dairy/oilseeds/eggs) | 6 | 2026-06-21 | 7 d | current |
| weekly (EIA US fuel/gas/crude) | 4 | 2026-06-19/22 | 6–9 d | current |
| weekly (EU Oil Bulletin fuel) | 2 | 2026-06-22 | 6 d | current |
| monthly (WB CMO global benchmarks) | 19 | 2026-05 | 58 d | see release lag |
| monthly (FAO indices) | 5 | 2026-05 | 58 d | index, monthly only |
| monthly (FRED PPIs + US eggs) | 8 | 2026-05 | 58 d | current for monthly |
| monthly (Eurostat PPIs) | 5 | 2026-04 | 88 d | ~2-month EU PPI lag |
| monthly (DG AGRI fert N/P/K) | 3 | 2026-05 | 58 d | current for monthly |
| quarterly (Eurostat) | 2 | 2026-Q1 / 2025-Q4 | 119 / 209 d | quarterly + lag |

**WB CMO release lag (the named weak point):** the workbook is stamped "Updated on
June 02, 2026" and its latest reference month is **2026-05** — i.e. the May monthly
*average* is released ~2 business days after month-end, but at a 2026-06-28 probe the
newest available reference month is **58 days old** (June won't publish until ~July 2).
So the entire traded-benchmark complex is structurally a lagged monthly average.

**Stale flags (3, all honest publication lags, named by the freshness gate, non-fatal):**
SG-003 EU white sugar (119 d — ~2-month DG AGRI sugar lag), FR-001 ATA truck tonnage
(119 d — FRED republishes ATA with ~3-month lag; its binding constraint is effectively
quarterly freshness despite monthly cadence), FR-005 Eurostat land-freight (209 d —
quarterly + lag).

## Step 2/3 — Upgrade candidates: evidence and decision (all probed LIVE)

Target: lift the traded complex (cocoa, coffee A/R, wheat, corn, soybeans, sugar, veg
oils, aluminium) from monthly agency averages to free, named, reliable daily/weekly.

| candidate | covers (verified) | observed cadence | free-tier ceiling | provenance | reliability | verdict |
|---|---|---|---|---|---|---|
| **A. Nasdaq Data Link** | — | — | **anonymous = HTTP 403 on everything, incl. control LBMA/GOLD** | named exchange (ICE) but gated | n/a | **excluded** — free tier unreachable; the CHRIS continuous-futures DB (ICE_CC1/KC1/SB1) is discontinued/paywalled; softs not free |
| **B. Alpha Vantage** | sugar, coffee, wheat, corn, WTI (demo key worked) | **MONTHLY** ("Global Price of …", cents/lb or $/t, latest 2026-05) | free key ~25 req/day | **re-served IMF/World Bank macro series** (same family as our WB CMO) | reliable but redundant | **excluded as upgrade** — softs are monthly macro, identical class to what we hold; **no cadence gain**; energy (WTI/Brent/gas) is EIA-sourced redistribution, redundant vs our EIA rows |
| **C. Yahoo Finance =F** | cocoa, coffee-arabica, wheat SRW+HRW, corn, soybeans, sugar#11, soyoil, aluminium (**robusta RC=F = 404**) | **daily** (latest 2026-06-26, 2 d old) | none stated | **unofficial, redistributed; no named exchange attribution in payload; documented history of breaking** | low (unofficial) | **fallback / cross-check only** — by rule cannot be a row's sole source; **not wireable** (we have no second daily source to pair it with) |
| **D. CME CmeWS settlements** | — | — | **HTTP 403 (bot-blocked, all product ids)** | named (CME) | n/a | **excluded** — no open machine-readable EOD; redistribution ToS-restricted |
| **D. ICE delayed settlement** | — | — | **HTTP 403** | named (ICE) | n/a | **excluded** — no open machine-readable EOD |
| **D. Databento** | — | — | **HTTP 401 (account key required)**; free credit is one-off and **exhausts** | named exchange data | reliable | **excluded** — free credit does not sustain a recurring weekly pull |
| **Black-box aggregators** (commodities-api, API Ninjas, Twelve Data, Tradefeeds, Finnworlds, FinanceFlow, …) | — | — | — | **upstream source unnamed** | n/a | **excluded by rule** — provenance not attributable at the root |

## Step 4 — Wiring decision: nothing wired (no candidate passed the spine bar)

**No free, named, reliable daily/weekly source for the traded benchmarks is verifiable in
the open universe.** Therefore the monthly WB CMO agency average — itself named, verified,
double-fetched, already in v8 — **remains the honest floor** for every traded benchmark,
and no new registry version is emitted (there is nothing verified to add). The registry is
already at the credible cadence frontier:

- **Energy: already daily/weekly** via EIA (US fuel/gas/crude) — named US-government source.
- **EU physical crops/dairy/eggs/oilseeds/fuel: already weekly** via DG AGRI + EU Oil Bulletin — named EU-Commission sources.
- **Global traded benchmarks (cocoa, coffee, wheat-US, maize-US, sugar-world, veg oils, aluminium, Brent, coal): monthly** via WB CMO — no credible free faster source exists.

### Per-traded-commodity verdict

| commodity | chosen source & cadence | why | faster source? |
|---|---|---|---|
| cocoa | WB CMO monthly (CO-001) | only credible free source | Yahoo CC=F daily exists but unofficial → not wireable |
| coffee arabica | WB CMO monthly (CF-001) | " | Yahoo KC=F daily, unofficial |
| coffee robusta | WB CMO monthly (CF-002) | " | **no daily even on Yahoo (RC=F 404)** |
| wheat (US) | WB CMO monthly (WH-001/002) | " | Yahoo ZW=F/KE=F daily, unofficial |
| maize (US) | WB CMO monthly (MZ-001) | " | Yahoo ZC=F daily, unofficial |
| soybeans | not currently a row | — | Yahoo ZS=F daily, unofficial (oilseed row deferred) |
| sugar (world) | WB CMO monthly (SG-001) | " | Yahoo SB=F daily, unofficial |
| veg oils | WB CMO monthly (VO-001..004) | " | Yahoo ZL=F (soyoil) daily only; palm/rape/sun not on Yahoo |
| aluminium | WB CMO monthly (PK-005) | " | Yahoo ALI=F daily, unofficial |

**EU physical** wheat/maize/dairy/eggs/oilseeds already weekly (DG AGRI); **energy**
already weekly (EIA). No upgrade needed there.

### The lag is real but unfixable for free (illustrative cross-check, NOT wired)

Yahoo daily front-month vs WB monthly average shows the monthly floor's lag on a
fast-moving market — e.g. **cocoa: Yahoo CC=F 5,217 USD/t (2026-06-26) vs WB CMO
4,160 USD/t (May avg) ≈ +25%**. These are *different instruments* (daily front-month
future vs monthly averaged spot) and would be **distinct rows** if a credible daily source
existed — never reconciled against each other (same discipline as the existing
WB-crude-vs-EIA-WTI gap). They illustrate why a daily upgrade is desirable, and why the
absence of a credible free daily source is a genuine (documented) limitation, not an
oversight.

## Cross-check overlay — IMPLEMENTED (user-approved 2026-06-28), registry v9

The compliant way to surface daily corroboration without breaking the no-sole-source rule:
the WB monthly row stays the named spine; Yahoo daily is attached as a labelled
"unofficial cross-check" **field on that row**, never its own row. Implemented:

- **Registry v9** adds an optional `crosscheck` field (`yahoo#<ticker>#<mult>#<native_unit>`)
  on the 8 benchmarks with a clean Yahoo daily equivalent: CO-001/CF-001/WH-001/WH-002/
  MZ-001/SG-001/VO-001/PK-005. Robusta, EU/white sugar, palm/rape/sun oil have no clean
  Yahoo equivalent → no overlay (honest). Multipliers convert native→spine unit and were
  verified (all ratios 0.75–1.25).
- `build_crosscheck.ps1` fetches Yahoo daily (twice ~3 s apart for stability), converts,
  writes a **separate** store `cleaned_data/crosscheck_latest.csv` — never the spine
  history. Non-fatal in `refresh_all` (Yahoo outage degrades gracefully).
- `test_crosscheck_integrity.ps1` (fatal gate): ratio in [0.33, 3.0] (catches conversion/
  magnitude errors), spine history uncontaminated (proven: numeric-history held at 31,060),
  every overlay labelled "unofficial". Tolerates source outage.
- Front-end renders a labelled line, e.g. cocoa: spine `4.16 USD/kg` + `daily cross-check
  5.217 USD/kg (CC=F via yahoo, unofficial) @2026-06-26` (ratio 1.254).

This keeps the daily and monthly figures categorically distinct (different instruments,
different cadences, not reconciled) — the user-approved overlay, not a spine row.
`refresh_all` OVERALL: PASS; browser QA 74/74 canvases, 0 errors, 0 banned words.

## Completion gate status
- Step 1 cadence-audit table: **done** (above).
- Step 2/3 evidence + decision table, aggregators excluded with reason: **done**.
- New registry version with verified daily rows: **none — no candidate passed**; monthly
  floor (verified, in v8) retained; documented why.
- Double-fetch/magnitude for newly wired rows: **n/a (nothing wired)**.
- gaps file updated with every failed candidate + reason: **done** (gaps §7).
- QA doc per traded commodity (source, cadence, why; commodities left on monthly floor): **this doc**.

## Verdict
Mission 10: **GREEN by evidence.** The registry is as current as the open/free, *credibly
attributable* universe allows: energy daily, EU physical weekly, global benchmarks monthly
with no verifiable free faster source. Every faster candidate was probed live and excluded
on a specific, reproduced reason. Nothing wired on reputation; nothing committed.
