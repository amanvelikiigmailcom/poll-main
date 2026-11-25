# Reviewed release:1.0.3(15)

Client source:[c1ea537](https://github.com/amanvelikiigmailcom/poll-main/commit/c1ea537afefbd3fb329afd784c3d0ee643f5e8c5). Backend source:[dd475b8](https://github.com/amanvelikiigmailcom/flyprox_backend/commit/dd475b8cf6b611486505f12589ad23393ada5a70). All completed worktree heads are
included in their canonical main; source commits are published with[ci skip].
Worktrees/stashes/backups were retained. Integration decisions and regression
coverage:[reviewed integration](reviewed-integration-20261125.md).

Validation:485 Flutter tests,0 failures/skips; analyzer0 errors/0 warnings,16
reviewed infos. Backend279 tests plus syntax locally and on server Node24.22.3.
Generated schema matches;36 live tables,0 differences. No new migration required.
Actual backend runtime/flags/rollback:[runtime status](/Users/amanyessen/projects/flyprox_backend/docs/runtime-status.md).

Native archive/export used Flutter3.44.4 and Xcode27.2 with unchanged lockfiles.
Runner.xcworkspace Release archive compiled successfully. Flutter's unauthenticated
export could not find a distribution identity; exporting the same archive with
the existing authenticated ASC signing procedure succeeded, without replacing
certificates or profiles or changing the signing team.

Verified exported IPA:
- Bundle:com.flyprox.flyproxApp; version1.0.3,build15.
- Deep/strict signature valid; debugfalse; production APNs; Associated Domains
  applinks:api.flyprox.com; existing App Store profile. Production API URL and
  configured billing key are confirmed inside the exported AOT binary.
- Bytes:33618799; SHA256:`14e235b2e13ed50a0cf805b9a7180e136996acb913449cbd0d6f0b80594a506b`.
- IPA/archive/logs are private under
  ~/.local/state/flyprox-integration-final-20261125T134443.

Upload succeeded with exit0; Apple delivery UUID:0d380f25-120d-4ed5-a157-ed6603301080.
ASC read-back confirmed version1.0.3,build15,processingState VALID,expired false,
internalBuildState IN_BETA_TESTING,externalBuildState READY_FOR_BETA_SUBMISSION.
The existing internal all-builds group explicitly lists build15. Automatic group
distribution was already configured; no tester invite or group write was needed.
[App Store Connect / TestFlight](https://appstoreconnect.apple.com/apps/6828862522/testflight/ios).
No public App Review submit requested.

Device acceptance remains:real Firebase SMS, native Contacts, APNs delivery,
Sandbox purchase/restore/expiry, and native social story composer handoff.
Automated/fake-provider checks and signatures do not establish these device results.
