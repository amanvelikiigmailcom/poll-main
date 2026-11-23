# Flyprox: invitation release — implementation and activation

Status: source implementation prepared on 2026-11-23; production/TestFlight unchanged. Owner explicitly prohibited cloud builds; do not start Xcode Cloud. Local unsigned iOS release compilation was verified. This document and the active PLAN.md section supersede historical 40-minute / social-button / Premium-no-wait rules for the new source only.

## Product rules

- All players, including Premium, wait 60 minutes after a round.
- One new verified account applying one invitation earns one pass for each participant. Download alone is not observable and is never a reward trigger.
- Account-based invitations only. Guest/offline play remains available.
- An available pass automatically removes one active local wait after online confirmation, otherwise remains in the account. Balance/earned/used are displayed in Profile and Invite friends.
- One code per invitation, one claim per invite and new account. The database unique indexes arbitrate concurrent requests. Profile completeness is not proof of a new account: Appwrite Auth creation time is used.
- Explicit code has priority; an invalid code is not silently replaced with another person's phone match. No-code phone matches choose the earliest unexpired, unused invitation.
- Claim within seven days of Auth account creation; invitation expires after 30 days. Invitation must have existed before the account was created. Old accounts/reinstalls are not new referrals.
- Limits are fixed UTC buckets: 100 creation attempts/day and 20/hour per account, including reservations consumed by failed attempts. Request-ID retries reuse a successfully created invite. Reminders are 20/hour, 100/day, at most three/day per code. Limits concern Flyprox operations, not a guarantee of Messages delivery/capacity.
- Names are user-entered; Firebase phone login does not provide first/last name. Existing local username is retained. Full name is excluded from quiz cards. A first name is disclosed to the inviter on claim with advance explanation.

## Files and implementation

Backend repository: `/Users/amanyessen/projects/flyprox_backend`. `src/invites.js` contains injectable domain logic; invite-store adapts Appwrite; invite-routes exposes HTTP; invite-schema defines six tables and required indexes. No new profile columns or dependencies.

Flutter: InvitationService handles attribution, account-scoped pending signup retry, balances, compose-event retry, and cooldown-specific redemption. Pending codes and compose telemetry contain no bearer token. Native InvitationBridge presents a single contact property picker and MFMessageComposeViewController. A sent/cancelled/failed result is telemetry, never reward evidence. A copy fallback is available when Messages is unsupported.

`app_links` handles only `https://api.flyprox.com/i/CODE`; Flutter's default deep-link handler is disabled to prevent duplicate routing. A code arriving during OTP or voting is saved without replacing that screen. Applying a pending link requires user confirmation. Clipboard reads happen only on Paste. Another pending code is not silently overwritten.

Universal link appID: `5QG4KFTZNJ.com.flyprox.flyproxApp`. Associated Domains in both entitlements: `applinks:api.flyprox.com`. App Store: `https://apps.apple.com/app/id6828862522`.

## Correctness and recovery

- The authoritative claim is one insert with unique inviteId and inviteeUserId indexes. Two deterministic reward IDs are recoverable projections of that claim.
- The authoritative spend is one redemption insert with unique rewardId and unique (userId,cooldownKey). No read-modify-write balance counter.
- Stable notification IDs prevent duplicate Appwrite message enqueue on repair. APNs delivery still depends on valid targets and permission. It cannot be guaranteed by a unit test.
- Reward readiness is recorded only after grants exist and notification enqueue succeeds or is already present. Balance reconciliation repairs partial grants.
- A redemption includes the local cooldown key and snapshot of server lastRoundAt. The server waives only that server wait, never writes lastRoundAt=null over a newer completion. The client clears only the matching local timestamp.
- After a lost redemption response, balance refresh returns recent confirmed cooldown keys so a spent pass can still clear its original local wait without a second spend.
- The existing app supports local fallback; this release does not make offline game storage tamper-proof or provide device-level anti-fraud. One verified phone/account is not proof of one physical person. Account deletion does not retain permanent phone tombstones.
- Account deletion removes associated invitation attribution, first-name notification records, selected phone HMACs, own rewards/redemptions and events. The other participant's already-earned grant is retained without the removed name/claim record. Provider/device copies of already delivered messages cannot be recalled.

## Production activation — not yet performed

Production writes require the owner's confirmation under `/Users/amanyessen/AGENTS.md`. Prepare and review commits first; no force push, no public App Store submission.

1. Push the reviewed application/backend commits after authorization. Use `ssh s-prod`, repo `/home/myuser/projects/flyprox_backend`, `git pull --ff-only origin main`.
2. With backend traffic still on the old process, run `node scripts/setup-invites.js` in the server repository. It creates only invites, invite_claims, invite_rewards, invite_redemptions, invite_events and invite_limits, with private permissions. It waits for all columns/indexes; stop if any unique index is missing or mismatched. Never skip index readiness.
3. Generate a separate >=32-byte cryptographically random `INVITE_HMAC_KEY` inside the server process and append it privately to the existing protected .env. Do not display it or copy it to chat/git. `INVITE_PUBLIC_ORIGIN=https://api.flyprox.com`. Preserve the key for the lifetime of unexpired phone-matched invitations; v1 key rotation needs an explicit migration design.
4. Restart only `systemctl --user restart flyprox-backend`. Check /health, /api/content, /api/questions and the AASA URL (200 JSON, no redirect). Verify new tables have no public permissions.
5. Add a daily user-service timer/cron for `node scripts/cleanup-invite-limits.js --apply`. It removes only quota slots expired more than a day ago. Default invocation is a dry run. Invites/events/claims are retained with the account until deletion in this implementation; the 30-day invitation expiry is not a deletion policy.
6. Enable Associated Domains on the Apple App ID if not enabled, refresh signing profiles, verify the signed archive entitlement matches AASA. This is a required external configuration step, not completed by editing entitlements alone.
7. Publish reviewed Privacy Policy text (draft below) and update App Privacy using App Store Connect UI. Prepare new version metadata/review notes without the old social-tap/no-wait Premium claims.
8. Only after a separate build/upload instruction (cloud builds are currently prohibited), prepare a new incremented TestFlight binary, validate signed entitlements and actual SMS/iMessage/universal links on real devices. Never re-upload build13 as the new feature; the existing public App Store URL still installs the previous public binary until a new version is released.
9. Public App Store submission requires a separate explicit instruction. Existing public clients continue their previous local behavior until updated.

Safe rollback: return backend/app to reviewed previous commits, restart only the Node service; leave additive invite tables intact. Do not delete tables, keys or earned grants as a rollback shortcut. A rollback is itself a production action requiring approval.

## Device acceptance

- Two distinct verified accounts, not the same Firebase test phone on two devices.
- iPhone→iPhone iMessage and iPhone→Android SMS; Android can receive a link but there is no Android Flyprox client.
- Cancel, failed compose, unsupported Messages and changed recipient; no immediate reward.
- Fresh install with Paste/manual code; installed-app cold/warm link; retained pending code after process restart; no clipboard access on launch.
- Invitation during OTP/vote and under-13 flow; no route or age bypass.
- Friend claims once: one pass each, first-name notification, check/resume updates without a push dependency.
- Active wait clears once; no wait preserves the pass; two rewards racing consume only one; lost response recovers; next round starts a fresh 60-minute wait for Premium too.

## Review notes draft

This build replaces optional WhatsApp/Instagram timer shortcuts with user-controlled Messages invitations. Sending/cancelling a message grants nothing. A new phone-verified account applying an invitation earns one wait pass for each participant. All players, including Premium, otherwise wait 60 minutes. Premium offers full local Reveal, double stars and a badge; it does not skip waiting periods. Guest core play remains available. The first/last-name fields are user-entered; first-name disclosure to the inviter is explained before applying. No IDFA, ATT request, third-party attribution SDK or IP fingerprinting is used. Selected contact number matching is optional and server-HMAC based. Universal Links do not provide deferred install attribution; Paste/manual code and selected-number matching cover that path.

## Validation recorded

- Flutter:205/205 tests passed; includes code persistence/clipboard, lost redemption response, account switching, concurrent refresh, cancelled compose and Premium preserving the cooldown.
- Backend:50/50 tests passed; includes concurrency, grant repair, daily/hour quota, reminder ownership/cap, deletion and schema privacy/index readiness.
- `flutter analyze lib test`:22 existing info diagnostics, no errors or warnings. Target project source/tests explicitly; `build/ios/SourcePackages` contains dependency example projects that are not application source.
- Local `flutter build ios --release --no-codesign`:successful, Runner.app46.3MB; native bridge/entitlements compile. This is not a signed distribution archive, device QA, TestFlight upload or cloud build.
- No production schema/config/deploy, remote push, public policy write, Apple capability change or public submission performed for this feature.

## Test hardening follow-up

Owner requested preserving critical coverage and removing only the empty smoke placeholder. Latest validation:209/209 Flutter tests (`flutter test --no-pub`),59/59 Node tests; analysis22 existing info diagnostics, no errors/warnings. Nine new localhost HTTP integration tests exercise real Express/auth/adapter behavior with isolated providers; five new client cases cover account switching during claim,410/503 handling, pending-code replacement, compose-event retry/account isolation and idempotent creation without raw-number persistence. The account-switch regression was reproduced as a failing test, fixed, then verified passing. Required-field/pagination-outcome checks replace brittle configuration/request totals. Only `app/test/widget_test.dart`, containing `expect(true,isTrue)`, was deleted. Test sources and test instructions in both AGENTS.md files are permanent Git artifacts; `/tmp` logs are disposable. No cloud builds or production rollout in this follow-up.
