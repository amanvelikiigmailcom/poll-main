# Premium Weekly integration

One weekly product, `premium_pro_weekly`, store price (fallback $6.99/week).
Backend contract: `flyprox_backend/docs/premium-contract.md`.

- 2 full-name voter reveals + 5 first-initial reveals per subscription week.
- 2000 stars per completed online round, awarded only by backend.
- Blue membership badge from backend in own profile, friends, Activity chosen
  person and question options. Not identity verification. Expiry removes it.
- No Max, no timer bypass. Full Reveal of own answers is removed entirely.

Likes details and participant pages carry the received vote ID to the same reveal
component. No subscription → paywall; confirmed active subscription → independent
full/initial actions and server counters/reset date. Errors do not grant access or
locally spend a reveal. No hidden name/ID is included in ordinary Likes data.
Participant names come only from backend snapshots, never local answers/friends.
Voter labels use backend gender and `Class of YEAR`, not Grade.

Purchase/restore first binds the backend-owned billing alias. SDK success is not
server confirmation: refresh benefits after the verified webhook arrives. Account
changes clear the current private response; requests pin credentials and reject
stale success/failure. Benefits are not persisted on the device.

New online round requests send revealPolicyVersion=1. The voting UI warns before
answers and before submitting about limited Premium identity disclosure. Backend
only opts in newly created rounds with the feature enabled; old votes are not
retroactively exposed. Update published Terms/Privacy before activation.

This branch does not apply a migration, change dashboard/ASC pricing, deploy or
build/upload TestFlight. Device purchase/restore and real DB acceptance remain
separate release gates. Other unfinished features from main worktrees are excluded.
