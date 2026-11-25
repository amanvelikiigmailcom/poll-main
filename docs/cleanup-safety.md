# Bounded client cleanup — 2026-11-25

## Scope and evidence

This is local source maintenance, not a release or a backend change.
The cleanup starts at published client commit `5ec43ba` in an isolated worktree.
The existing `3a53233` cleanup was compared before editing; its retired screen
files have not changed since the common ancestor. Its commit is not merged
wholesale: the current router and later campus/reward changes must be preserved.

Candidates are checked against the import/export graph rooted at `lib/main.dart`,
including conditional imports, test imports, registered routes and asset loads.
An unused import count alone is not permission to delete a feature or SDK.

## Small reviewable batches

1. Independent unused providers, utilities and common widgets.
2. Seven retired registration screens, three retired voting screens, and only
   their unregistered route constants.
3. Two unused menu screens, the unused menu sheet/avatar, orphaned models and
   provider barrel; unused AppConstants members only after checking consumers.
4. The test-only local university picker/catalog; move its unchanged JSON to
   `docs/reference/` instead of deleting the source directory data.
   Preserve the active editor's legacy-university non-overwrite regression.
5. Unconsumed JSON localization copies and the five retired `premiumResult_*`
   ARB keys; regenerate localization output with `flutter gen-l10n`.
6. Dependencies with no remaining consumers; retain versions of other packages.
7. Explicit runtime asset entries and a smaller Retina-ready logo. Keep its
   full-resolution original outside the runtime bundle.

Run `python3 scripts/checks.py` after each batch, review the changed tests after
green, and commit each complete batch separately. The runner includes the full
Flutter suite and analysis. Errors/warnings or unexplained new info block success.

## Deliberately preserved

- Current onboarding, campus policy, country catalogs and reviewer/session gates.
- Current navigation, Likes, rewards, Collection and unfinished-round recovery.
- Superwall setup, gateway, subscription identity, purchase/restore and Premium.
- Firebase phone authentication and Firebase Messaging/APNs integration.
- Intro video and video_player, sounds, Phosphor fonts and their license.
- Bundled bilingual question bank, remote refresh/cache and offline fallback.
- Age-gate legacy key, avatar migration, saved local university/profile data.
- Language screen/route, saved language preference and localization delegates.
- Design reference images: the nested design directory is not bundled by the
  non-recursive `assets/images/` entry, so its deletion would not save IPA bytes.

Do not clear user preferences or remove compatibility redirects as a side effect.
Do not run `flutter clean`: existing build archives may be useful.
Do not change native SDK configuration or generated registrants by hand.

## Verification and limits

Baseline at `5ec43ba`: 497 Flutter tests passed, none failed/skipped; analysis
reported 0 errors, 0 warnings and 16 info. The initial cold-cache attempt hit its
120-second process limit and is not counted as a successful run; the complete
rerun used a longer timeout.

Tests must check the retained runtime assets, including the native reward sound.
Only the two tests exercising the retired university picker/catalog may disappear;
the active editor regression must remain.

Asset file-byte reductions are not IPA/download-size measurements. Native/plugin
size inspection must include Swift Package Manager, not just Podfile.lock.
Native/release builds, TestFlight, device QA, push and deploy require separate
authorization. Fake tests do not prove actual billing, APNs or video playback.

## Completed local verification

Every row below is a complete `python3 scripts/checks.py` run, not just targeted
tests. All rows have zero failed/skipped tests and zero analyzer errors/warnings.

| Batch | Passed tests | Analyzer info |
| --- | ---: | ---: |
| Baseline | 497 | 16 |
| Unused independent helpers | 497 | 16 |
| Unregistered screens + route contract tests | 499 | 10 |
| Menus, orphaned models/providers and unused constants | 499 | 10 |
| University directory unbundling + retained editor/asset tests | 499 | 10 |
| Localization JSON and five generated result keys | 499 | 10 |
| Remove shimmer | 499 | 10 |
| Remove smooth_page_indicator | 499 | 10 |
| Remove flutter_animate + orphaned flutter_shaders | 499 | 10 |
| Remove cupertino_icons | 499 | 10 |
| Remove cached_network_image + orphaned cache packages | 499 | 10 |
| Explicit assets + 512×512 logo and decode test | 500 | 10 |

Test accounting: two tests of the retired directory/picker were removed; the
active editor regression was preserved in its own file. Two route contract tests
and three runtime asset tests were added: 497 − 2 + 5 = 500.

Final inspection against the starting commit confirms:

- 32 unreachable Dart files removed; no current service implementation changed.
- All 132 retained package versions are unchanged. Five direct dependencies and
  twelve orphaned transitive packages left the resolved graph.
- The macOS registrant was regenerated by `flutter pub get`, dropping only the
  orphaned sqflite import/registration; no native source was edited manually.
- The university source and original logo match the starting bytes exactly.
- Video, reward sound, fonts/license, design references, question seeds,
  main/app entrypoints, active providers, configuration and native iOS/Android
  source remain unchanged.
- Other ARB keys/values and generated localization code remain unchanged apart
  from removal of the five explicitly retired getters.

The runtime logo is 162,978 bytes instead of 1,053,026 (512×512 instead of
1254×1254). Together with the unbundled directory and localization JSON, app-owned
asset file payload decreases by **1,590,953 bytes** before packaging/compression.
This does not count removed package assets and is **not an IPA size measurement**.
The full-resolution logo and directory remain in `docs/reference/`, outside the
bundle.

## Integration and rollback

The working `main` and other worktrees are not edited. Before integration, fetch
current refs, coordinate ownership of router/pubspec, compare intervening changes,
and rerun checks on the combined result. Do not overwrite concurrent campus edits.
Each cleanup commit can be reverted individually from a clean integration branch;
do not reset, rewrite history, or discard somebody else's work.
