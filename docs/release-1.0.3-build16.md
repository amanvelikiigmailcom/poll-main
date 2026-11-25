# Release1.0.3(16)

Source client: [2fe5d74](https://github.com/amanvelikiigmailcom/poll-main/commit/2fe5d74914b8551cd7a8f427e9bbc40a9f491092).
Running backend source: [e86eaac](https://github.com/amanvelikiigmailcom/flyprox_backend/commit/e86eaac294773eb53672607673908825c48091b1).
Integration decisions: [client](integration-all-agents-20261126.md).
Actual backend schema, Redis and rollout evidence remain in its
[runtime status](/Users/amanyessen/projects/flyprox_backend/docs/runtime-status.md).

All completed client feature heads are integrated in published main. Backend
includes all intended feature heads and the preserved paused performance patch;
the historical degraded rollback branch and stash remain retained separately.
No worktrees, releases or backups were deleted. Source pushes use[ci skip].

## Validation

Application integration:629 Flutter tests passed,0 failed/skipped; analyzer0
errors,0 warnings and10 reviewed infos. Native APNs decoder regression passed.
Backend correction:427 tests passed locally and on server Node24.22.3, syntax and
schema dictionary passed. The final client follow-up changes only app icon PNGs:
all19 catalog slots validate dimensions/RGB/no alpha, and native archive/export
and compiled icon read-back passed. SDK/dependency lockfiles unchanged by icon work.

## Owner app icon

Prepared from owner-provided PNG. Main icon1024x1024 RGB PNG with no transparency;
black square backing replaces the original baked white/rounded backing because
iOS applies its own mask. Red artwork preserved before high-quality downsampling.
Lossless PNG encoding verified by pixel read-back, without palette quantization.
Source765599bytes -> icon150518bytes (80.3% smaller).
App icon only; fallback logo and the startup video were not replaced.
The720x1280 startup video remains3.029002s; source/archive/exported IPA SHA256:
`4a01fa6292b98a3597aa03573c759765eacf4c21e762239c31a02f77888c225f`.

Native archive uses Flutter3.44.4, Xcode27.2, Runner.xcworkspace. The existing
ASC-authenticated export procedure signed the archive without changing team or
recreating certificates/profiles. Exported IPA verification:

- Bundle com.flyprox.flyproxApp; version1.0.3,build16.
- Deep/strict signature verified; get-task-allow false; production APNs;
  Associated Domains applinks:api.flyprox.com; existing App Store profile.
- Production API and local billing key verified in AOT without printing the key.
- Compiled120px iPhone icon matches prepared icon exactly (RGB mean difference0).
- Bytes:32436208; SHA256:`6ce3ab089fab18ff7f2af920342ad875d4e0471af4f034ef1997cbfe3d7dc7d3`.
- Private artifact/evidence directory:
  ~/.local/state/flyprox-integration-20261125T183317Z.

## TestFlight

Upload exit0, delivery UUIDfe44cc06-4436-47f2-aca2-01af6fd1df67.
ASC read-back at2026-11-25 19:24:04 UTC confirms build IDfe44cc06-4436-47f2-aca2-01af6fd1df67,
processingState VALID,expired false,internalBuildStateIN_BETA_TESTING,
externalBuildStateREADY_FOR_BETA_SUBMISSION.
The existing internal group explicitly lists build16; availability verified without
sending invitations or changing group configuration.
[TestFlight](https://appstoreconnect.apple.com/apps/6828862522/testflight/ios).
No public App Review submit was requested or performed.

Real-device acceptance remains separate:Firebase SMS, Contacts, APNs delivery,
Sandbox purchase/restore/expiry and native message/share handoff. Automated checks,
code signing and Apple processing do not establish these device results.
