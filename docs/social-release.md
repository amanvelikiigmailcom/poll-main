# Friends and navigation — production backend, 2026-11-23

The owner explicitly approved both pushes, five additive tables/indexes, backend deployment and social configuration. Backend source68b3b32 is deployed and active; Flutter source d01b81c is pushed. No app build/TestFlight upload was started, so installed beta13 does not contain this UI. Invitation HMAC remains absent; its six tables were not migrated. Schools and recommendations remain dormant.

## Product

Bottom navigation: Home (round/start/result/cooldown), Search, Likes, Profile, Settings. Stateful branches preserve search text, scrolling and the running question. Repeated Home presses do not reset a round. Friends is a Settings entry; Profile links to the same list. Search is exact, authenticated, case-insensitive username lookup. First/last names and phone numbers are not search inputs or response fields. Friends of friends / From school are empty future sections; no school APIs or recommendations are enabled. Likes has an explicit coming-soon state; existing fake-voter screens are not connected to the tab.

Friends has My friends, Received, Sent; both sides must consent. Requesting, accepting, declining, cancelling, removing, blocking and unblocking use real HTTP APIs. Profile cards expose only ID, username and relationship. Reporting creates a private safety-concern record, with no free-text message to the other user. No chat or request push notification has been added.

For parents is reachable in Settings and remains outside the age/auth gate. Copy describes no chat, prepared questions, skip/report, contacts, server data, deletion and separate Apple subscription management. It does not claim every question has been audited or guarantee safety/COPPA compliance. Full editorial review of the bank remains separate.

## Database and authority

Existing Node.js → Appwrite TablesDB → PostgreSQL; no direct SQL, no new Redis instance or dependencies.

| Table | Identity and purpose | Indexes |
|---|---|---|
| social_handles | Row ID = account ID; canonical lowercase username, 3–32 ASCII letters/digits/underscore | Unique username |
| social_relations | One deterministic canonical pair; sender/recipient, pending/friends/idle, retryAfter | Unique pair; left+status, right+status, sender+status, recipient+status |
| social_blocks | Deterministic directional owner/target pair | Unique owner+target, both lookup directions |
| social_reports | One report per reporter/target/UTC day, fixed safety reason | Owner and target |
| social_limits | Unique fixed-window quota slots; expiry, no phone/name/query text | User and expiry |

Tables have no client permissions and rowSecurity=false. Backend API key is the only reader/writer. Schema readiness validates permissions, column types/sizes/required flags and all indexes before enabling the feature. No columns are added to profiles. Friendship refers to account IDs, not usernames. Renaming does not affect friendship. Existing ambiguous local/legacy handles are not mass-imported: a user explicitly reserves a free handle in Edit profile or registration. Background invitation sync never renames an account.

**Single writer requirement:** this implementation targets the existing one-process systemd Node deployment. Ordered account/pair locks serialize requests, block, votes and deletion in that process. DB unique indexes enforce nickname/pair/quota uniqueness. This is NOT a distributed transaction implementation. Set SOCIAL_SINGLE_WRITER=1 only after verifying one API writer; do not enable cluster/PM2 multiple workers/rolling overlapping writers. Multiple writers require database CAS/transactions or a separately reviewed distributed lock first. SOCIAL_ENABLED=1 enables routes and readiness; absent/0 returns 503 for social APIs.

Blocks are checked in search, public profiles, friend listing, contact matching, candidates and votes. Account deletion removes handles, all pair memberships, blocks in both directions, reports in both directions and quota slots. It serializes with new pair mutations. Unblocking clears the prior relation and does not restore friendship. Removing/declining/cancelling imposes a 24h new-request cooldown. Limits: 30 searches/min, 20 request attempts/hour, 10 reports/hour, 15 actual handle changes/hour. Saving an unchanged handle does not consume rename quota.

## HTTP

All /api/social operations require the existing bearer session and return Cache-Control: no-store. Client binds each response to the initiating token; stale success/failure is discarded after account change. A late 401 cannot clear another account's token.

- GET /me — authoritative handle (nullable)
- PUT /handle {username} — explicit unique reservation/rename; 409 for occupied handle
- GET /search?username=… — exact match only, at most one public card
- GET /summary — actual friends/incoming counts
- GET /list?kind=friends|incoming|outgoing|blocked&cursor=… — 50 records/page, nextCursor
- GET /users/:id — minimal card, blocked/unavailable returns 404
- POST /users/:id/request|accept|decline|cancel|remove|block|unblock|report

No caller-supplied owner/userId is trusted. Lists use indexed membership/direction filters before pagination. No directory/full-profile serializer is reused for public cards.

## Executed rollout and remaining release work

- Both main branches pushed without force, last commits carry [ci skip]. Server checkout fast-forwarded from c102de6 to social source68b3b32, preserving production credentials and data. Exactly one existing API writer was verified before enabling the feature.
- `node scripts/setup-social.js --apply` created the five private tables, all required columns and unique/query indexes. Installed Appwrite returns column type `varchar`, not the previously mocked `string`; corrected verifier in68b3b32 after a failing regression test, then78/78 full backend tests passed. Read-only verification passed against the actual schema. Nothing was dropped/recreated.
- Actual database smoke passed seven groups: private readiness; concurrent canonical username uniqueness; indexed incoming/outgoing/ownership/consent; pair uniqueness/OR membership/count; rename/report; block/unblock; decline cooldown. Identity lookup was isolated to synthetic QA IDs, while all social persistence used the real Appwrite adapter. No Auth users, profile/session rows, real phones, SMS, APNs or game data were created or changed.24 attempted temporary rows were cleaned up with zero errors; a second read confirmed all five social tables had zero rows. This is not authenticated real-account/device E2E QA.
- Enabled SOCIAL_ENABLED=1 and SOCIAL_SINGLE_WRITER=1 with dedicated systemd user override `~/.config/systemd/user/flyprox-backend.service.d/social-friends.conf`. Original .env/credentials unchanged. Reloaded systemd user configuration and restarted only flyprox-backend. Runtime process flags verified1; service active/running.
- Public checks: /health200, /api/content200 with22keys, /api/questions?limit=1 returns200 and one question. /api/social/me and search without authentication return401. No real account was impersonated for HTTP testing.

Remaining release work: physical iPhone/two-account QA and a separately authorized app build; accurate public privacy/App Privacy publication; establish private report-review frequency; obtain scheduler authorization for daily `node scripts/prune-social-limits.js --apply`. Cleanup script default is read-only and only targets social quota rows expired over24h ago. No timer/cron was installed by this rollout. No provider erasure or public compliance guarantee is implied.

Rollback: disable the social-specific systemd override and restart backend after authorization. Retain the new tables. Disabling does not erase data or mean account deletion. Multiple API writers still require a separately reviewed distributed CAS/transaction design.

## Verification

Backend tests/social_api.test.js uses actual Express routes/auth/store adapter with isolated provider fixtures. Covers authorization, concurrent unique nicknames, rename, ownership, duplicate/crossed actions, block/accept race, blocked votes, pagination/counts, quota, deletion over 100 rows, deletion/request race, disabled feature and private schema mismatches. Single-process concurrency only.

Flutter tests/social_service_test.dart and social_screen_test.dart cover guest no-network, account change, stale search ordering, late 401, handle conflict, list filtering and 320px/x2 layout. cooldown_navigation_test.dart covers real round/question and query preservation across tabs, unchanged cooldown and no Quiz tab. Existing tests remain required.

Full commands: `python3 scripts/checks.py` in poll-main, `npm run check:summary` in backend. No new dependencies, production data writes or cloud builds are needed for these checks.

Final local validation: 224/224 Flutter tests, analyzer 0 errors / 0 warnings / 22 baseline infos; 78/78 backend tests and server syntax check passed. Last Flutter logs: /var/folders/n4/fwvw8mbx4554wtn5kn6dyg300000gn/T/flyprox-checks-069geiau/. Backend logs: /var/folders/n4/fwvw8mbx4554wtn5kn6dyg300000gn/T/flyprox-checks-lxukp852/. Local visual preview: /tmp/flyprox-social-search.png (widget render, not device proof).

Editorial finding: existing bundled questions include classic11 ("most playfully toxic") and classic12 ("most epic fail"). The bank was not rewritten in this task. Do not publish an exclusively-positive-content promise before a separate editorial pass and synchronized server/fallback update.

Production schema fix validation: backend78/78, syntax passed; log /var/folders/n4/fwvw8mbx4554wtn5kn6dyg300000gn/T/flyprox-checks-12j0844d/. No Flutter source changed during the server rollout; last full Flutter result remains224/224 and22 baseline infos.
