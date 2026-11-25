> Current source update: [campus waiting, reviewer sessions and storefront country](rewards-campus-policy.md).
> New clients use exact-country discovery and the backend campus policy. The historical
> US/CA shared search below remains only for compatible older requests. Closed campus
> requests now persist as waiting; the fixed client launch-region list has been removed.

# Profile and campus onboarding — deployed backend, 2026-11-24

## Current client behavior

The phone screen opens configured Privacy Policy and Terms of Use URLs directly.
Selecting a campus collapses search results and brings the graduation-year control
into view. The setup menu offers 2026–2041 in ascending order, without a default.
Previously saved years outside this menu require a new selection during setup;
server validation and existing profile data are unchanged. The missing-campus form
labels its location field by country: state/territory for US, province/territory for
CA, county/region for GB, district for SG/HK, and region for NZ.


Flow: phone/guest → age → About you (first name, last name, Female/Male/Non-binary) → Choose your campus (catalog + graduation year) → contacts/examples → username → optional notifications → Home. Existing blue/white form styling is retained. Names were removed from the username step. Full names never prefill @username or appear in voting cards.

School lookup uses the country selected with the phone number. US and CA share one directory; there is no extra country picker. School cards include city, state/region and source country. GB covers England, Scotland, Wales and Northern Ireland. CA, NZ, SG and HK catalogs are imported; the missing-school flow remains for schools absent from the catalogs. Guest defaults to US if no country was selected. An international phone does not prove the country of study; the requested-school form records the current directory country and location typed by the user.

`I can’t find my campus` opens a form for school/campus, country (from the phone step), city, state/region and graduation year. Prepare email first persists the signed-in user's request, then opens a `mailto:` draft to the existing server-configured `support_email`. The user sends it. Opening/returning from Mail is not proof of sending or approval. A failed Mail launch displays the support address and keeps the fields. The account stays blocked from voting until a real directory entry is selected; adding an entry never enrolls a user automatically.

`school_skip_enabled=false` in content_items hides Skip for now and the server rejects a forged skip request. Missing/deleted config falls back to true, matching other flags; use explicit false to disable. Skip completes onboarding without a school, but does NOT unlock voting. Home then shows Choose your campus to play. Direct /vote and server current-round/submit-round/individual-vote endpoints also reject unresolved enrollment. Existing accounts without a new enrollment row retain their old access. New accounts from clients declaring schoolOnboardingVersion=1 receive a pending marker before profile/session issuance. Older clients without that version retain their former behavior; new enrollment saves still create their own marker.

## Authoritative data and identity

- Existing `profiles` row `$id = accountId`: firstName, lastName, gender (`female`, `male`, `nonbinary`; legacy `other` remains readable), canonical schoolId/schoolName. No new columns are added to this already-full table.
- New private `onboarding_details` row `$id = accountId`: country, status (`pending`, `selected`, `skipped`, `requested`), schoolId, graduationYear, requestedSchool, requestedCity, requestedRegion. Cohort index: schoolId + graduationYear; request-management index: country + status. Graduation year is a calendar year, separate from grade/class and legacy university year 1–4.
- New private `school_directory` row `$id = country-source-externalId`: country, name, city, region, searchText. Full-text search index and country/region filters, stable cursor pagination (25 results). API returns only id/name/city/region/country.
- Authenticated ID always comes from the bearer session. Body userId, schoolName and arbitrary school/country combinations are not trusted. Profile/school mutations and deletion use the existing per-account one-writer lock. Multiple Node writers are not supported by that lock.
- The new enrollment row, including school requests, is removed during account erasure. A late queued save rechecks the account inside the deletion lock before any write.
- Guest progress stays local until an authenticated flow explicitly saves it. Session-scoped local keys are hashed; raw session tokens/phone numbers are not placed in key names or logs. Drafts survive restart, and saved account fields can be restored from GET /api/onboarding after a new login. A different session never silently inherits the previous session's local draft. Reset game preserves enrollment status so it cannot unlock a skipped school; account erasure clears storage.

## Catalog sources and reproducibility

US: existing `data/schools_ccd.json` (CCD 2024–25) and `data/schools_pss.json` (PSS 2023–24), 124,688 records in the actual checked-in files. Stable IDs use NCES external IDs, not array positions.

England: [Department for Education, Get Information about Schools](https://www.get-information-schools.service.gov.uk/Downloads), Open Government Licence v3.0. Official extract retrieved from `https://ea-edubase-api-prod.azurewebsites.net/edubase/downloads/public/edubasealldata20261123.csv`. `python3 scripts/build-gb-schools.py /path/to/edubasealldata.csv` in backend filters open establishments with a recorded English GOR, preserves URN, and exports minimal public location fields. Result: 27,195 entries in `data/schools_gb.json`. This is not a complete UK/university directory. Canada shares the search group with its own imported source file (see below).

Canada: [Statistics Canada, Open Database of Educational Facilities v2.1](https://open.canada.ca/data/en/dataset/4dd64c98-b12a-49c7-be29-21c77d22b675), Open Government Licence - Canada. `python3 scripts/build-ca-schools.py /path/to/ODEF_v2_1.csv` keeps K-12 rows (drops post-secondary ISCED4Plus, preschools, career colleges and care/corrections/admin facility types) and exports 16,540 entries in `data/schools_ca.json` with stable `CA-ODEF-<Index>` IDs and full UPPER province regions matching the client list.

Scotland: [Scottish Government School Contact Details](https://www.gov.scot/publications/school-contact-details/) via the School Roll and Locations table, 2,483 entries in `data/schools_scot.json` with stable `GB-SEED-<schuid>` IDs and council-area regions.

Wales: [Welsh Government address list of schools](https://gov.wales/address-list-schools), 1,539 entries in `data/schools_wales.json` with stable `GB-WALEDU-<7-digit number>` IDs and principal-area regions; nursery-only rows excluded.

Northern Ireland: Department of Education open data `locate-a-school` snapshot of February 2016 (no fresher bulk source exists), 1,058 schools in `data/schools_ni.json` with stable `GB-DENI-<Reference>` IDs and county regions. Re-export and rebuild to refresh; closed schools are not pruned automatically.

New Zealand: Ministry of Education Schools Directory (via its ArcGIS mirror; the official CSV is bot-walled for scripts), 2,533 entries in `data/schools_nz.json` with stable `NZ-MOE-<School_ID>` IDs and MoE education regions.

Singapore: MOE "General information of schools" (data.gov.sg datastore API), 337 entries in `data/schools_sg.json` with slug `SG-MOE-<name>` IDs (no official numeric ID; renames orphan old rows), MOE zone regions and planning-area cities.

Hong Kong: EDB "School Location and Information" open CSV, 1,331 primary/secondary entries in `data/schools_hk.json` with stable `HK-EDB-<school no.>` IDs and district regions; kindergartens excluded.

Client `gbRegions` grew 223 → 262 (32 Scottish councils + The Vale of Glamorgan + 6 NI counties; other Welsh LAs were already present from GIAS).

Validated total: 177,704 distinct stable IDs (151,883 on 2026-11-24 plus 25,821 added 2026-11-25: CA 16,540, Scotland 2,483, Wales 1,539, NI 1,058, NZ 2,533, SG 337, HK 1,331). `node scripts/import-school-directory.js` validates input without provider access. `--apply` performs idempotent create/update using those IDs; `--limit N` supports an initial small trial. Full ingestion should run on the server, not across the public tunnel from a laptop. No source phones, street addresses or student totals are imported into this directory.

Search uses Appwrite's full-text index and starts at 3 characters, per [TablesDB query documentation](https://appwrite.io/docs/products/databases/tablesdb/queries). Unit/fake HTTP tests do not prove actual PostgreSQL-backed index behavior; a confirmed migration must include real-database search and cursor checks before enabling the feature.

## Catalog expansion — 2026-11-25

25,821 new rows imported (CA 16,540, Scotland 2,483, Wales 1,539, NI 1,058, NZ 2,533, SG 337, HK 1,331); no existing rows modified. `node scripts/verify-school-rollout.js` confirmed exactly 177,704 live IDs matching the source files, plus US/CA/GB search smoke tests with pagination. NI data is pinned to February 2016; refresh via a fresh DENI export when available.

## Release boundary

The owner confirmed production schema/import/backend deployment. Both private tables and indexes are ready,151883 catalog entries imported and independently verified through complete cursor pagination. Runtime code7661485 is active with SCHOOL_ONBOARDING_ENABLED=1 in a separate systemd user drop-in. school_skip_enabled=true was added without overwriting other configuration. Client codef2365de was pushed with [ci skip]. No new cloud build/TestFlight upload has been performed. Public privacy/parents/App Privacy forms have not been published or changed. Before a public client release, disclose gender, education details and campus-request retention in the public privacy forms; school/year/gender are not currently exposed through social search or used to recommend classmates.

The following rollout was explicitly confirmed and completed; retain these commands for future controlled maintenance:

1. Review/commit the intended changes in both repositories, preserving concurrent round-submission changes. Latest pushed client commit must include `[ci skip]`.
2. Run `node scripts/setup-onboarding.js --apply` to create only the two private tables, columns and indexes. Read-only verification is the default without --apply. Wait for columns/indexes to become available; readiness rejects incompatible definitions or public permissions.
3. Trial a small source batch, verify stable IDs, then import the full validated directory with `node scripts/import-school-directory.js --apply`. Verify at least US/GB lookup, region visibility, pagination, canonical school validation, request storage and deletion. Real Canadian data is a separate missing source.
4. Deploy backend and enable `SCHOOL_ONBOARDING_ENABLED=1` only when both tables/indexes and the catalog are ready. This does not enable invitations or create any invite tables.
5. Configure `school_skip_enabled` as desired. Test two real accounts and native Mail on iPhone after an explicitly authorized build. The existing cloud-build prohibition remains.

Permanent checks: new Flutter service/widget tests cover names/gender, full two-form flow, year/location persistence, stale search/save, session switch, remote skip flag, small screens/large text/keyboard, and waiting-state route protection. Backend pure and real-localhost HTTP tests cover auth/ownership, countries, validation, private request storage, gates, pagination, source IDs, schema readiness and deletion races. Run `python3 scripts/checks.py` in poll-main and `npm run check:summary` in backend. Device checks remain separate; no real SMS/APNs are sent by those suites.

## Verified local result — 2026-11-24

Isolated release snapshot:236 Flutter passed,0 failed,0 skipped; analyzer0 errors/0 warnings/22 existing info. Isolated backend release:92 passed,0 failed,0 skipped; server syntax passed. Concurrent unrelated working-tree changes were preserved and excluded from these commits/deployment. Catalog validation:151883 distinct stable IDs. Flutter-rendered previews of both forms inspected at390×844 (test font substituted; not device screenshots); 320px/x1/x2/keyboard interactions covered by permanent tests. No native Mail or real-database index acceptance is claimed.


## Production acceptance — 2026-11-24

Full ingestion completed with stable-ID100-row bulk upserts. A separate exhaustive read verified exactly151883 IDs:124688 US and27195 GB, with no duplicates or unexpected IDs. The Appwrite list response total is capped at5000; it was not used as an exact catalog count. Real fulltext search and cursor pages passed for US/CA (shared group) and GB. --exercise checked a single isolated enrollment through pending/skip/request/select and graduation year/cohort/country/disabled-skip validation, injecting profile identity in memory so no Auth/profile/session row was created or modified. The isolated enrollment was deleted and absence verified. Runtime health/content/questions and both US/GB school searches returned200; unauthenticated onboarding401. Social flags remained1 and invitations remained unconfigured.

UI wording is campus throughout the enrollment flow. Graduation year offers96 calendar choices (current year minus80 through current year plus15), with no preselected value; on2026-11-24 this is1946–2041. The dropdown is exercised in widget tests. Native Mail and a new client build still require a separately authorized device/release step.

The new owner search standard is recorded in both AGENTS.md: Meilisearch,300ms debounce, minima users2/cities2/campuses3, configurable typo thresholds. This standard is recorded for the next migration; production search currently remains Appwrite fulltext. Meilisearch has NOT been installed or enabled by this rollout.

## Restored enrollment compatibility

Authenticated server restore confirms the existing campus and graduation year for the current session. Unchanged existing enrollments remain available outside launch regions, and an existing valid older year stays selectable. Local drafts never receive this exception; session changes invalidate it. New enrollments still use launch gates and the offered year range. Region filters include both full US state names and postal codes in the backend without rewriting the catalog.

## Onboarding recovery and form layout

- Username Back returns to campus in the school-ready branch, or to contacts in
  the contacts branch. Contacts also exposes Back to campus. These routes retain
  the existing age/enrollment guards.
- Back remains available while saving a username, cancels that handle request,
  and preserves the typed nickname in the session-scoped draft. Late responses
  cannot complete onboarding after leaving the screen.
- Handle saving has a 10-second deadline with a visible retryable error.
  Optional invitation completion and push-status lookup have 3/2-second bounds;
  pending invitation recovery remains in the invitation service. A push lookup
  timeout opens the optional prompt rather than blocking setup.
- Campus Back preserves the unsaved selection, year, search and region as drafts,
  not confirmed enrollment. Missing-campus pickers build after draft restoration.
- Selected-campus name, location and Change occupy separate rows. Search uses a
  short label; form error messages wrap and remain readable on the blue surface.
- The optional notification prompt scrolls on small screens/large text, and Skip
  remains available while notification permission/token upload is pending.

Permanent regression coverage is in `username_onboarding_test.dart` and
`school_onboarding_test.dart`, plus `push_prompt_test.dart`. Widget tests do not prove native keyboard/APNs or
the behavior of an already installed TestFlight binary.


## Reviewer-only hidden forms

For the existing Firebase-verified review account, both personal-details and
campus/year onboarding routes redirect before rendering. OTP and automatic phone
verification restore backend onboarding first; age remains mandatory. Contacts
and example names lead to username creation only if the canonical server handle
is absent. Existing handles are restored without another handle write, while
invitation completion and optional push handling still run.

Reviewer data may stay empty. Existing enrollment/profile values are preserved;
no placeholder names, gender or campus are written to the server. Backend permits
this identity to play contacts rounds without enrollment. Other users retain their
existing mandatory forms and campus gate. Edit profile allows the reviewer to fill
an absent gender once and select country before enrollment, in addition to the
existing editable fields; transaction/replay/campus rules still apply.

Companion backend source commit: `e4c1c13` in `flyprox_backend`.
This source requires that matching backend change. Source commits do not imply
production deployment or a new available TestFlight build. Device Firebase,
Contacts and purchase checks remain separate from fake-provider tests.
