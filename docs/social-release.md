# Friends and navigation — local implementation, 2026-11-23

This release is not deployed. Cloud builds/TestFlight uploads remain prohibited. Production changes require the owner's confirmation. The previously paused invitation rollout is separate.

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

## Release procedure (not executed)

1. Review diff and run both full check commands. Review new tests, not just their result.
2. Confirm five additive private tables/indexes, backend push/deploy and production configuration changes with owner. Public privacy updates are a separate publication; prepare matching text before external release. Keep SOCIAL_ENABLED unset until ready. No cloud build.
3. After authorized push (last commit contains [ci skip]), update backend checkout using fast-forward only. Preserve production secrets and invitation configuration. No full npm setup, no schools import and no invitation migration implicitly.
4. Run `node scripts/setup-social.js --apply` in the server repo; wait for every column/index and read-back verification. Default `node scripts/setup-social.js` is read-only and fails if absent or mismatched. Never drop/recreate tables or indexes to bypass mismatch.
5. Verify one Node writer, configure SOCIAL_SINGLE_WRITER=1 and SOCIAL_ENABLED=1 privately, restart only flyprox-backend. Check health and authenticated APIs with explicitly authorized test accounts, never real SMS/APNs or destructive real-account tests by default.
6. Verify DB unique-index behavior against the actual self-hosted version using dedicated test accounts/data. Unit/provider fakes do not prove real Appwrite uniqueness or query index compatibility. If this fails, leave the feature disabled.
7. Arrange daily expired quota cleanup after separate scheduler authorization: `node scripts/prune-social-limits.js --apply`. Default run is read-only. Only social_limits rows expired more than 24h ago are eligible. Never FLUSHDB or touch Appwrite internal Redis keys.
8. Process reports in the private Appwrite console; each includes owner/target IDs, reason and creation time. No automatic sanctions, moderation SLA or live alerts are promised. Establish review frequency before public launch.
9. Publish accurate privacy text/App Privacy metadata as separately authorized. App release/device QA remains separate; do not claim installed TestFlight contains this feature.

Rollback: disable social feature and deploy prior backend code after authorization. Retain the new tables. Disabling does not erase data and must not be presented as permanent account deletion.

## Verification

Backend tests/social_api.test.js uses actual Express routes/auth/store adapter with isolated provider fixtures. Covers authorization, concurrent unique nicknames, rename, ownership, duplicate/crossed actions, block/accept race, blocked votes, pagination/counts, quota, deletion over 100 rows, deletion/request race, disabled feature and private schema mismatches. Single-process concurrency only.

Flutter tests/social_service_test.dart and social_screen_test.dart cover guest no-network, account change, stale search ordering, late 401, handle conflict, list filtering and 320px/x2 layout. cooldown_navigation_test.dart covers real round/question and query preservation across tabs, unchanged cooldown and no Quiz tab. Existing tests remain required.

Full commands: `python3 scripts/checks.py` in poll-main, `npm run check:summary` in backend. No new dependencies, production data writes or cloud builds are needed for these checks.

Final local validation: 224/224 Flutter tests, analyzer 0 errors / 0 warnings / 22 baseline infos; 78/78 backend tests and server syntax check passed. Last Flutter logs: /var/folders/n4/fwvw8mbx4554wtn5kn6dyg300000gn/T/flyprox-checks-069geiau/. Backend logs: /var/folders/n4/fwvw8mbx4554wtn5kn6dyg300000gn/T/flyprox-checks-lxukp852/. Local visual preview: /tmp/flyprox-social-search.png (widget render, not device proof).

Editorial finding: existing bundled questions include classic11 ("most playfully toxic") and classic12 ("most epic fail"). The bank was not rewritten in this task. Do not publish an exclusively-positive-content promise before a separate editorial pass and synchronized server/fallback update.
