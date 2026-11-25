# Rewards and campus release candidate

The owner authorized source commit/push only. Backend switching, live policy writes,
native/cloud builds and uploads are deferred. This is a reviewed future release plan,
not authorization to execute those deferred stages.

## Reviewed source

- Client behavior source: 59dc3b6, including current main startup changes and removal of
  Share from the reward receipt. Collect animates first; Continue leads to the timer,
  whose invitation button follows backend country policy. Source remains 1.0.3+15 because no build is authorized; 1.0.3+16 is a future build candidate requiring a fresh availability check.
- Backend: abb81ad. Saved waiting state, reviewer identity, country policy, and explicit
  campus-configuration readiness. Missing policy cannot be bypassed by omitting a
  client capability or using ProfileEditor.
- Compatibility rollback source: d5e67bf in backend branch rollback/rewards-campus-20261125.
  It retains waiting guards over the previous runtime source. Its temporary feature
  limitations are documented in that branch's docs/rollback-rewards-campus.md.
- Local full checks: client497 passed; analyzer0 errors/0 warnings/16 unchanged info.
  Backend294 passed plus syntax and generated schema check. Rollback281 passed.
- Read-only live metadata matched all36 private application tables. No schema migration,
  catalog import, queue reset, notification replay or new infrastructure is needed.

## Exact proposed configuration

Apply only these two content_items keys, using the committed backend JSON files:

1. campus_access_policy = config/campus-launch-policy.json. Allow Texas (both source
   labels TEXAS/TX), West Midlands, Ontario, Auckland, Central Singapore and Hong Kong
   Island, plus exact campus US-CCD-010033001264 (New Horizon Alternative School).
   Exact ID exceptions never open neighboring campuses. This replaces the retired
   client launch list with one authoritative server policy.
2. invitation_channel_policy = config/invitation-channel-policy.json. US/CA Messages;
   GB/NZ/SG/HK WhatsApp. Supported messaging fallback is the existing share sheet.

Preflight found both keys absent, with support email configured. Verify again immediately
before apply; do not overwrite a concurrent operator's new policy without reviewing it.
Real catalog rows were found for Texas, West Midlands, Ontario, Auckland and the exact
team campus. No matching Central Singapore/Hong Kong Island rows were found. A matching
row does not prove a complete national catalog; existing missing-campus flow remains.
Existing skip/guest/example flags are preserved; server-issued reviewer access decides
whether those special onboarding actions appear. Optional push permission stays optional.

## Authorized execution order

1. Refresh refs; confirm no unrelated changes or unmerged paths. Fast-forward the two
   canonical main branches from the reviewed candidates and push without force. The
   final source commits carry [ci skip] to prevent an accidental Xcode Cloud run.
2. On the server, privately back up effective unit/drop-ins, environment references,
   current immutable runtime identity, and exact previous values/absence of the two
   content keys. Do not print or copy credentials into Git. Keep all existing releases.
3. Prepare an immutable release from abb81ad with its own npm ci dependencies. Preserve
   WorkingDirectory, all environment/feature flags and the single API writer. Switch
   only ExecStart, restart one writer, verify baseline health and live metadata.
4. Validate/read back the proposed policy JSON, then write the two keys together in an
   Appwrite transaction. New/changed campus enrollment safely returns503 until explicit
   policy exists. Verify both values, matching open/closed country search behavior,
   exact team-campus exception, unchanged metadata and service health afterward.
5. Immediately before building, read App Store Connect again. Latest verified marketing
   version was1.0.3 PREPARE_FOR_SUBMISSION, latest valid build15, last public version1.0.2.
   Target build16 must still be free; otherwise review the number before upload.
6. Use Flutter3.44.4 and existing Pod/Swift dependency locks. Inject the existing local
   Superwall SDK key into build configuration privately; it must remain outside source
   commits. Open app/ios/Runner.xcworkspace, scheme Runner. Archive/export/sign the
   explicitly authorized native build, inspect bundle/version/entitlements, then upload.
7. Wait for processing and read back internal TestFlight availability. Do not submit the
   app publicly or add external testers under this package. Preserve build15 as fallback.
8. On an available iPhone verify reward sound/silent mode/haptics/Reduce Motion, reviewer
   versus ordinary test login, storefront country, campus waiting across login, Mail,
   and Messages/WhatsApp open/cancel. No automatic sends to real recipients. The paired
   physical iPhone was unavailable during preparation, so device QA is still pending.
9. Only after actual verification update backend runtime-status and client release notes
   with observed runtime/build evidence. Source commits are not runtime evidence.

## Rollback

Before any waiting requests exist, restore the privately captured previous runtime and
exact previous two-key configuration. Once waiting requests exist, never restore an
unguarded old backend or erase requests: prepare/switch the d5e67bf compatibility release
with the existing environment and keep the approved campus policy. Waiting users remain
blocked while the main release is repaired. A client issue can use existing build15 while
keeping the secure backend. Database schema is unchanged and is not rolled back.

Private read-only preflight evidence is under ~/.local/state/flyprox-release-prep/;
Firebase test account credentials are stored privately, outside this repository.
