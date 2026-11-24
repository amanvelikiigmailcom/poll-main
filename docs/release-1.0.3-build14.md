# Unified release: 1.0.3 (14)

## Source and worktrees

- Client source commit: `7b079ae18e1be4438a9b3474f22fdfed4cb1ad7f`.
  Subsequent client commits update only release documentation.
- Backend running source: `4a0b889`, immutable `unified-4a0b889` release.
  Subsequent backend commits add the isolated QA runner and runtime documentation;
  all deployed src modules match canonical main byte for byte.
- Both canonical main branches are committed and published. All15 existing
  worktrees are clean; every worktree HEAD is contained in its canonical main.
  No worktree or branch was deleted. Old Premium/Collection worktrees can be
  removed without losing their work; server runtime releases are separate.
- Inventory, decisions and regression plan: [integration](integration-20261125.md).
- The additional100-question dataset is validated and committed in backend source;
  its production import was not part of this rollout.

## Validation

- Full Flutter suite:398 passed,0 failed/skipped.
- Analyzer:0 errors,0 warnings,20 infos in files outside the integration changes.
- Full backend suite:251 passed,0 failed/skipped, plus syntax; repeated on
  production's Node24 before release switching.
- Generated database dictionary matches the schema registry. Read-only live
  checker:36 tables,0 differences.
- Added coverage: combined client capabilities/notice payload, session-bound
  confirmed reward, Collection navigation after reward, updated FAQ, combined
  preference/boost/reveal snapshots, question-level eligibility, reward replay,
  old-client notice enforcement, schema flag independence and int64 backup safety.
- Real TablesDB Collection QA verified transactional debit rollback, concurrent
  replay, bounded balance, four-question/sympathy placement and frozen replay.
- Real TablesDB Premium QA verified ownership, hidden identity,2 full/5 initial
  quotas, replay, both UNIQUE indexes, refund denial and account-erasure behavior.
  All fixtures were removed and absence verified; private QA state is cleaned.

## Production

Actual backend flags, migration application, immutable release, health, source
hashes, backups and rollback are recorded only in
[backend runtime-status](/Users/amanyessen/projects/flyprox_backend/docs/runtime-status.md).
The rollout preserves invitations, notification workers, school access and Redis.
Published Notion Terms/Privacy were updated with the owner's approval using
[the reviewed corrections](release-policy-updates-20261125.md).

## Archive and upload

- Flutter3.44.4, Xcode27.2, existing dependency locks. Runner.xcworkspace, Release,
  arm64 archive. No dependency or CocoaPods/SPM migration was performed.
- Exported IPA: `com.flyprox.flyproxApp`, version1.0.3, build14,33,531,209 bytes.
- SHA256: `0841b6e319fcf447902a9a6bbb26dc04a1ded43e437345e00db76bed61eccbb3`.
- Deep/strict signature verified; production APNs; debug false; Associated Domains
  `applinks:api.flyprox.com`; production API URL and actual billing key compiled.
- The initial1.0.2(14) upload was rejected because that approved version's train
  is closed. ASC already had1.0.3 prepared; the same code was rebuilt for it.
- Corrected upload succeeded with exit0. Delivery/build ID:
  `c8946f41-c004-49c2-8fce-880a85bf46bb`.
- ASC read-back:1.0.3(14), processingState `VALID`, expired false,
  internalBuildState `READY_FOR_BETA_TESTING`, external `READY_FOR_BETA_SUBMISSION`.
- App: [App Store Connect / TestFlight](https://appstoreconnect.apple.com/apps/6828862522/testflight/ios).
  No App Review/public submit or tester email notification was requested or sent.

## Remaining device acceptance

Firebase SMS, native Contacts, actual APNs delivery and Apple Sandbox
purchase/restore/expiry need device testing. Automated suites, fake provider
fixtures and a VALID upload do not prove those paths.

Private backups, exact IPA/archive and logs are outside Git under
`~/backups/flyprox-integration-20261125-015951`. The release procedure now checks
approved App Store versions before Archive to avoid a closed pre-release train.
