# All-agent integration — 26 November 2026

Integrates all pending completed client feature heads from the frozen manifest,
including reviewer commits def53ce/abecc54, auth/session regressions, social/game
polish, Premium protection, contextual push/email support, native invitation
picker, invitation backoff, quiz terminology and both cleanup branches.

## Conflict decisions

- Retain verified-session reviewer bypass, age gate, ordinary-user onboarding,
  existing identity restoration/retry, and Edit profile capabilities.
- Preserve campus waiting/resume behavior instead of restoring an old screen
  while applying terminology-only changes.
- Keep shared historical result rendering for screen/image export, consistent
  quiz wording and Class of labels, with Premium protection and no public badges.
- Account reporting uses an explicit email draft per the support branch. Opening
  a draft is not a submitted server report or proof that mail was sent. Backend
  report APIs remain available for compatible callers. Hidden suggestions retain
  their server-backed hide/show/Undo behavior.
- Remove duplicate fake actions introduced by automatic test merges. Keep both
  invitation picker and polling checks. Ensure support controls are scrolled into
  view before test taps; do not suppress missed taps.
- Remove only retired screens with no remaining references. Retain asset originals,
  active editor/router regressions and necessary native startup assets.
- Preserve the local billing key outside commits using the established local
  override. App source version is 1.0.3+16; availability is checked separately.

Final release verification and TestFlight evidence are recorded separately after
checks/archive/upload. No device acceptance is implied by fake-provider tests.

## Included source commits

abecc54 Verify reviewer login paths and handle guest retry and narrow layouts [ci skip]
def53ce Hide profile and campus onboarding for verified reviewer only [ci skip]
b02ef28 test: cover invitation routing and profile conflicts [ci skip]
7b3a82c fix(auth): isolate cancelled sign-ins and delayed logout [ci skip]
fdf906c test(api): cover auth interceptors and malformed errors [ci skip]
004de8d Clarify Messages invitations and streamline recipient selection [ci skip]
916685d Bound runtime assets and resize logo with original and regression guards preserved [ci skip]
4eccc1a Remove unused cached image package and orphaned cache dependencies [ci skip]
a3a605f Remove unreferenced Cupertino icon font package [ci skip]
7079da4 Remove unused flutter animate and its orphaned shader dependency [ci skip]
ebd3596 Remove unused smooth page indicator dependency [ci skip]
3f33323 Remove unused shimmer dependency without upgrading retained packages [ci skip]
4378559 Remove unconsumed localization JSON and regenerate retired result keys [ci skip]
0ce4209 Unbundle retired university picker while preserving source and profile regression [ci skip]
6b72786 Remove unused menus and their orphaned client models and providers [ci skip]
846c3e7 Remove unregistered legacy onboarding and voting screens [ci skip]
3f209bd Remove isolated unused client helpers and record cleanup boundaries [ci skip]
fcc018f Use quiz and pick wording throughout the frontend [ci skip]
408b709 Back off visible invitation polling and avoid redundant reward reads [ci skip]
a53f184 Polish campus search, recoverable suggestions, profile sharing and exact vote batches [ci skip]
3c9d2e8 Route push taps to fresh screens and add email support [ci skip]
02a45b5 Explain Premium reveal protection and remove membership badges [ci skip]
3a53233 Remove unreachable legacy screens and unused localization keys [ci skip]
