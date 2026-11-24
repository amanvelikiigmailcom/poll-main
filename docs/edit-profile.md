# Edit profile

Only the existing Edit profile is redesigned. Own/other profile screens and
bottom navigation visuals are unchanged. The shell only consults a scoped
editor leave callback before switching tabs; normal navigation is untouched.

- English UI, blue AppColors header, white form, fixed 🙂. No photos/reset game.
- Server-first first name, surname, username, locked gender, campus and
  **graduation year** (included after the owner's clarification).
- Independent90-day wait on each real saved change. This implements the
  owner's day90 example, not three calendar months.
- Username remains3–32; uppercase input normalized lowercase.
- Edited names2–50 Unicode code points, letters/marks/spaces/hyphens/apostrophes.
- Only changed fields are sent, with explicit restriction confirmation.
- Save failure retains draft/requestId; repeated request is idempotent.
- Server policy/revision are authoritative; no local-only success or timers.
- Campus picker reuses the existing directory service, is draft-only and has
  search pagination. It does not save during selection or spend an edit.
- Close/Back/tab switch asks Save / Discard / Keep editing when dirty.
- Guest sees sign-in guidance. Missing/disabled API is a load error with Retry.
- Session changes clear the form; stale success/failure cannot update another
  account. After save invalidate canonical profile identity and restore
  session-scoped onboarding cache. No rewrite of other profile layouts.

Backend contract: `flyprox_backend/docs/profile-edit-contract.md`.
Requires the prepared backend migration and explicit feature rollout; local
source is not a deployed API or available TestFlight build. No migration,
push, deploy, native/cloud build or upload is authorized by this document.
