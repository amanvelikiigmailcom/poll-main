# Integrated source for TestFlight 18

- Baseline published client main: `9c0f003`.
- Merged `195f274` (server-confirmed contacts decision before ordinary onboarding
  contacts) and `bfa2229` (onboarding/voting copy cleanup). Earlier feature worktrees
  are already ancestors of baseline main; their source is retained.
- Reviewer-only secondary phone/OTP button now reads `Continue without login`.
  `Send code`, action behavior, verified-session entitlement, age and campus gates
  are unchanged. Ordinary users do not receive that secondary button.
- Preserve concise Premium disclosure before voting and before submission: the
  copy-cleanup branch removed it but QuizService still acknowledges policy version 1.
  Removed fallback banner stays removed; frozen draft fallback state is preserved.
- Source version: `1.0.3+18`; ASC preflight found build 17 latest and marketing
  version 1.0.3 open. Recheck actual uploaded/processed build separately.
- Backend pair: `flyprox_backend` source `e2e8b17`, including readiness `3d43ace`.
  Schema modules do not change. Migration necessity is determined by live preflight,
  not by the presence of historical migration files.

Private backups include branch bundles, all worktree status/ignored inventories,
dirty patches/local files and the skip-worktree billing configuration. No old
worktrees, branches, stash entries, releases or user files were removed.
Native SMS/Contacts/APNs/StoreKit/device acceptance is separate from source tests.
No App Store public submission is implied by internal TestFlight distribution.

Integrated checks: 650 Flutter passed, no failed/skipped; analyzer has zero errors
and warnings, with the same ten notices in unchanged files. Backend full suite:
436 passed, syntax and generated-schema checks passed.
