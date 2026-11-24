# Other-person profile

`app/lib/screens/profile/person_profile_screen.dart` is the sole other-person
screen. `/people/:id` and `/p/:handle` both use it in the existing stateful shell.
Search, recommendations, requests, accepted friends and own-profile friend preview
link to `/people/:id`. Own ID/handle redirects to `/home/profile`.
The unused demo `profile_for_people_screen.dart` has been removed; SocialScreen
retains lists/search only, not a duplicate person mode.

English UI: blue AppColors gradient, rounded white card, fixed 🙂, canonical
@username, friend-only server-projected full name, selected campus and graduation
year. Existing five bottom tabs and in-progress round remain unchanged.
No photos, initials, public balance/Collection, invented users, voter reveal,
public friends graph or mutual-friend names.

## Interaction

- None: Add friend. Outgoing: disabled Request sent; Cancel request in account menu.
- Incoming: Accept request / Decline. Friends: Remove friend with confirmation.
- Block and Report require confirmation. Existing server endpoints are reused.
- Block success immediately removes all profile/statistics content. Unblock remains
  in Settings → Blocked accounts and does not restore friendship.
- Every action is disabled while confirming/saving. Toasts require server success.
  Errors retain confirmed relationship. Mutations refresh social summary, previews
  and mounted lists via the shared visibility revision.
- Authoritative statistics load separately. A failed section does not hide the
  loaded profile and missing counts display a dash, never a made-up zero.
- One scrollable lazy ListView; grouped nominations are informational, with
  decorative stars unrelated to spendable stars. Subsequent pages load near scroll
  end (also an explicit accessible Load more action).
- Invalidated aggregate cursor: clear all grouped pages/counts and retry from start.
  404: generic Profile unavailable, never disclose block reason.
- Account/campus/route changes clear old data; generation checks reject stale
  profile/statistics/actions. Resume and pull-to-refresh reconcile server changes.
- Old backend without the new endpoint keeps the profile/actions functional and
  shows a retryable statistics error, not fake counters or an empty success state.

Backend contract: `flyprox_backend/docs/profile-social-contract.md`.
The aggregate visible total is intentionally separate from the owner's historical
Likes counter; it equals the sum over all available groups, including later pages.
No schema migration or production data change is required for this implementation.

## Verification

- `app/test/person_profile_screen_test.dart`: English UI, names, states/actions,
  confirmations, errors, stale replies, scrolling, own redirect, small screens.
- `app/test/social_service_test.dart`: actual HTTP/session/cursor behavior.
- Backend `tests/person-profile.test.js` and `tests/social_api.test.js`: guarded
  aggregate eligibility, full-history grouping, cursors, blocked/deleted actors,
  oversized histories and campus changes.
- Run full `python3 scripts/checks.py` in both repositories.
- Device QA remains separate: enter via search/friends/requests/profile link,
  return with Back, switch tabs with an unfinished round, change campus/account,
  verify safe areas and larger text. Native/cloud build/deploy are not authorized
  merely by this document.
