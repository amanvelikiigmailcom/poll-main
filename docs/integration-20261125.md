# Worktree integration and build 14

## Scope and sources

The owner stopped other editing processes and requested consolidation of all
client/backend worktrees, migrations, regression tests and an App Store Connect
upload. Premium behavior comes from the Premium worktrees. Existing Collection,
profile editing, quiz preferences, invitations and current navigation are retained.

Canonical repositories remain `poll-main` and `flyprox_backend`; each has its own
`main`. The backend schema registry is the only database contract. Actual runtime
and migration application evidence belongs exclusively to backend
`docs/runtime-status.md`. Source completion is not deployment or device acceptance.

## Inventory and preservation

- Client baseline: `3083a37`; backend baseline: `e67b47f`.
- Client Premium: `d8d61c6`; backend Premium: `5a257b0`, plus preserved migration
  runner/tests `1cd4728`.
- Collection client checkpoint `603ef32`: feature code already integrated into
  the client baseline. Preserve current profile/preferences additions.
- Collection backend checkpoint `e72e20b`: retain the missing real-storage
  verification script and int64 backup fix, while keeping newer gender eligibility.
- Likes checkpoint `c848e5d`: the empty card and equivalent tests already exist in
  current received_likes_screen_test.dart. Retain the newer list and navigation.
- Invitations, Profile, Person profile and Collection runtime branches contain no
  source commits missing from their respective baseline main branches.
- Backend autostash was compared file by file. Its feature changes and tests are
  already incorporated; subsequent Premium changes intentionally extend them.
  Retain the stash and all old worktrees until release acceptance.
- The additional 100-question dataset passes the existing import validator. Save
  it in source; importing it into production is a separate content operation.
- A private backup outside Git contains both complete Git bundles and the
  working/staged patches and untracked files of 15 existing working copies.
  One missing temporary checkout has only a stale worktree registration.

## Integration decisions

1. Preserve the new FAQ categories/search and update Premium/reward/privacy copy.
2. Remove the old Full Reveal screens/actions. Keep Collection after round reward.
3. Send schoolVoting, quizPreferences and revealPolicyVersion capabilities together.
4. Preserve server-only candidates and each question's frozen boost eligibility.
5. Compute Premium rewards on the backend and display only its acknowledged award;
   idempotent replay never adds stars again. Guest/debug Premium cannot double stars.
6. Save preferences, boost markers and reveal policy in the same round snapshot.
7. Require the updated client and submit notice acknowledgment for reveal-enabled
   rounds. Old rounds remain hidden; completed identical replay remains valid.
8. Include every schema domain in the offline dictionary and read-only live checker.
   Existing applied migrations are immutable. Premium migration is additive and
   has a backup-gated runner with metadata drift and duplicate preflight checks.

## Checks and release sequence

1. Run full backend suite/syntax and schema dictionary check; run full Flutter suite
   and analyzer. Read the added tests after passing.
2. Confirm no conflict markers, unmerged files, missing feature files or secrets
   in staged changes. Commit both integrations, then fast-forward canonical main.
3. Prepare an immutable backend release and private rollback/configuration backup.
   Read-only live schema preview determines which migrations actually remain.
4. Apply only missing additive migrations with the sole API writer stopped; verify
   complete metadata and isolated real-storage behavior, cleaning all fixtures.
5. Deploy only the explicitly approved flags. Premium activation also requires the
   published Terms/Privacy to match the identity disclosure and billing acceptance.
6. Archive version 1.0.2 build 14 from the checked client commit using Flutter 3.44.4,
   existing Pods and Xcode Runner.xcworkspace. Preserve the local billing key.
7. Verify archive/IPA identifier, version, signature, APNs and encryption settings;
   upload to App Store Connect and read back processing and TestFlight availability.

## Regression coverage

Backend tests exercise combined round snapshots, Premium plus gender/per-question
eligibility, reward replay, old-client notice enforcement, independent schema
flags, Premium migration preflight and lossless private Collection backups.
Client tests exercise combined capability/notice payloads, session-bound reward,
Collection navigation after reward, FAQ Premium copy, guest rewards and existing
received-Likes empty/list/guest/modal behavior.

SMS/APNs delivery, native Contacts and real Sandbox purchase/restore require
device acceptance. Automated fake suites and a VALID upload cannot prove them.
