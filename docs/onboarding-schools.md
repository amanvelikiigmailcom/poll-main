# Profile and school onboarding — local implementation, 2026-11-24

Flow: phone/guest → age → About you (first name, last name, Female/Male/Non-binary) → Your school (catalog + graduation year) → contacts/examples → username → optional notifications → Home. Existing blue/white form styling is retained. Names were removed from the username step. Full names never prefill @username or appear in voting cards.

School lookup uses the country selected with the phone number. US and CA share one directory; there is no extra country picker. School cards include city, state/region and source country. GB currently has England coverage only. NZ/SG/HK use the missing-school flow until actual catalogs are added. Guest defaults to US if no country was selected. An international phone does not prove the country of study; the requested-school form records the current directory country and location typed by the user.

`I can’t find my school` opens a form for school/campus, country (from the phone step), city, state/region and graduation year. Prepare email first persists the signed-in user's request, then opens a `mailto:` draft to the existing server-configured `support_email`. The user sends it. Opening/returning from Mail is not proof of sending or approval. A failed Mail launch displays the support address and keeps the fields. The account stays blocked from voting until a real directory entry is selected; adding an entry never enrolls a user automatically.

`school_skip_enabled=false` in content_items hides Skip for now and the server rejects a forged skip request. Missing/deleted config falls back to true, matching other flags; use explicit false to disable. Skip completes onboarding without a school, but does NOT unlock voting. Home then shows Choose your school to play. Direct /vote and server current-round/submit-round/individual-vote endpoints also reject unresolved enrollment. Existing accounts without a new enrollment row retain their old access. New accounts receive a pending marker before profile/session issuance when the feature is enabled.

## Authoritative data and identity

- Existing `profiles` row `$id = accountId`: firstName, lastName, gender (`female`, `male`, `nonbinary`; legacy `other` remains readable), canonical schoolId/schoolName. No new columns are added to this already-full table.
- New private `onboarding_details` row `$id = accountId`: country, status (`pending`, `selected`, `skipped`, `requested`), schoolId, graduationYear, requestedSchool, requestedCity, requestedRegion. Cohort index: schoolId + graduationYear; request-management index: country + status. Graduation year is a calendar year, separate from grade/class and legacy university year 1–4.
- New private `school_directory` row `$id = country-source-externalId`: country, name, city, region, searchText. Full-text search index and country/region filters, stable cursor pagination (25 results). API returns only id/name/city/region/country.
- Authenticated ID always comes from the bearer session. Body userId, schoolName and arbitrary school/country combinations are not trusted. Profile/school mutations and deletion use the existing per-account one-writer lock. Multiple Node writers are not supported by that lock.
- The new enrollment row, including school requests, is removed during account erasure. A late queued save rechecks the account inside the deletion lock before any write.
- Guest progress stays local until an authenticated flow explicitly saves it. Session-scoped local keys are hashed; raw session tokens/phone numbers are not placed in key names or logs. Drafts survive restart, and saved account fields can be restored from GET /api/onboarding after a new login. A different session never silently inherits the previous session's local draft. Reset game preserves enrollment status so it cannot unlock a skipped school; account erasure clears storage.

## Catalog sources and reproducibility

US: existing `data/schools_ccd.json` (CCD 2024–25) and `data/schools_pss.json` (PSS 2023–24), 124,688 records in the actual checked-in files. Stable IDs use NCES external IDs, not array positions.

England: [Department for Education, Get Information about Schools](https://www.get-information-schools.service.gov.uk/Downloads), Open Government Licence v3.0. Official extract retrieved from `https://ea-edubase-api-prod.azurewebsites.net/edubase/downloads/public/edubasealldata20261123.csv`. `python3 scripts/build-gb-schools.py /path/to/edubasealldata.csv` in backend filters open establishments with a recorded English GOR, preserves URN, and exports minimal public location fields. Result: 27,195 entries in `data/schools_gb.json`. This is not a complete UK/university directory. Canada shares the search group but a Canadian source file has NOT been imported; do not describe the US files as Canadian data.

Validated total: 151,883 distinct stable IDs. `node scripts/import-school-directory.js` validates input without provider access. `--apply` performs idempotent create/update using those IDs; `--limit N` supports an initial small trial. Full ingestion should run on the server, not across the public tunnel from a laptop. No source phones, street addresses or student totals are imported into this directory.

Search uses Appwrite's full-text index and starts at 3 characters, per [TablesDB query documentation](https://appwrite.io/docs/products/databases/tablesdb/queries). Unit/fake HTTP tests do not prove actual PostgreSQL-backed index behavior; a confirmed migration must include real-database search and cursor checks before enabling the feature.

## Release boundary

This change is LOCAL ONLY. No table creation, school import, production writes, push, restart, cloud build or TestFlight upload has been performed for this task. `SCHOOL_ONBOARDING_ENABLED` defaults off. Public privacy/parents/App Privacy forms have not been published or changed. Before release, disclose gender, education details and school-request retention in the public privacy forms; school/year/gender are not currently exposed through social search or used to recommend classmates.

Production actions require the owner's separate confirmation under /Users/amanyessen/AGENTS.md:

1. Review/commit the intended changes in both repositories, preserving concurrent round-submission changes. Latest pushed client commit must include `[ci skip]`.
2. Run `node scripts/setup-onboarding.js --apply` to create only the two private tables, columns and indexes. Read-only verification is the default without --apply. Wait for columns/indexes to become available; readiness rejects incompatible definitions or public permissions.
3. Trial a small source batch, verify stable IDs, then import the full validated directory with `node scripts/import-school-directory.js --apply`. Verify at least US/GB lookup, region visibility, pagination, canonical school validation, request storage and deletion. Real Canadian data is a separate missing source.
4. Deploy backend and enable `SCHOOL_ONBOARDING_ENABLED=1` only when both tables/indexes and the catalog are ready. This does not enable invitations or create any invite tables.
5. Configure `school_skip_enabled` as desired. Test two real accounts and native Mail on iPhone after an explicitly authorized build. The existing cloud-build prohibition remains.

Permanent checks: new Flutter service/widget tests cover names/gender, full two-form flow, year/location persistence, stale search/save, session switch, remote skip flag, small screens/large text/keyboard, and waiting-state route protection. Backend pure and real-localhost HTTP tests cover auth/ownership, countries, validation, private request storage, gates, pagination, source IDs, schema readiness and deletion races. Run `python3 scripts/checks.py` in poll-main and `npm run check:summary` in backend. Device checks remain separate; no real SMS/APNs are sent by those suites.

## Verified local result — 2026-11-24

Full app run:237 passed,0 failed,0 skipped; analyzer0 errors/0 warnings/22 existing info. Backend:91 passed,0 failed,0 skipped; server syntax passed. Catalog validation:151883 distinct stable IDs. Flutter-rendered previews of both forms inspected at390×844 (test font substituted; not device screenshots); 320px/x1/x2/keyboard interactions covered by permanent tests. No native Mail or real-database index acceptance is claimed.
