# Social and voting polish

Source-only changes; not proof of a deployed backend or available TestFlight.
The already-fixed onboarding flow is intentionally unchanged.

## Client contract

- Search sends `q`, supports names and @username, and displays the server's
  authorized first/last names above the canonical handle. Explicit @ queries
  accept only handle characters. No phone search or global name directory.
- One card layout for none/incoming/outgoing/friends. Actions remain below the
  identity at narrow widths and large text scales. Hide is a menu action.
- Hide/Show are server actions, not a local-only blacklist. Undo reverses a
  successful hide; Settings → Hidden suggestions lists currently accessible
  hidden accounts and restores them without accepting/declining a request.
- Empty friends-of-friends does not impersonate a campus recommendation.
  Campus people remain visible, with a short explanation of the missing graph.
- Settings starts with Activity → Friends → Collection, then account/notifications.
  How to play lives in Settings, not duplicated on Profile.
- Share profile uses the system share sheet; the adjacent link button copies.
  Own Likes uses the existing server counter and owned Likes destination.
- Vote details and share capture use the same `VoteResultContent` component.
  Capture contains only the public historical projection, not premium reveals,
  voter IDs, navigation or share controls. Export is 1080×1920; long content scales
  down without cropping. Missing historical participants are not reconstructed.
- School submission sends `choicePolicyVersion:1` and an ordered `choiceIds`
  list for each question from the persisted visible cards. Winner must be in it.
  Shuffle replaces cards from the question's authorized pool and invalidates
  an old answer. With no alternatives it explains why and spends no use.
- Non-school legacy/local rounds retain their existing submission contract.

## Backend release dependency

See backend `docs/social-game-polish.md` and `docs/round-submission.md`.
Matching backend source commit: `bb565f7` in
`fix/social-game-polish-20261125` (285 tests passed; source only, not deployed).
The additive social_hidden table needs an approved migration before deployment.
New q search is not a reason to ship the client against an old server.
School choice pools are opt-in and old clients continue receiving pinned fours.

## Verification

Full suites: `python3 scripts/checks.py` in both repositories.
`app/test/social_game_polish_test.dart` covers names, request-card layout,
report reason, hidden restoration and Settings order. Optional
`POLISH_SCREENSHOTS=1` writes fixture-based UI screenshots to the approved
OpenCode temporary folder; these are not screenshots of a live user session.
Native share targets and real backend round latency still require device QA
after a separately approved release.

An eligibility rejection (HTTP422, confirmed no writes) offers a separately
confirmed refresh of participants for the same server round. Unknown network
outcomes stay sealed and retry the exact payload; they never offer an automatic
discard or pretend that the round finished.
