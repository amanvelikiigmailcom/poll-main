# Premium Weekly integration

One weekly product, `premium_pro_weekly`, store price (fallback $6.99/week).
Backend contract: `flyprox_backend/docs/premium-contract.md`.
Companion backend commit: [f80b53e](https://github.com/amanvelikiigmailcom/flyprox_backend/commit/f80b53e).

- 2 full-name voter reveals + 5 first-initial reveals per subscription week.
- 2000 stars per completed online round, awarded only by backend.
- Active Premium protects the voter from both full-name and first-initial reveals.
- No membership badge on any screen or in public API projections.
- No Max, no timer bypass. Full Reveal of own answers is removed entirely.

Likes details and participant pages carry the received vote ID to the same reveal
component. No subscription → paywall; confirmed active subscription → independent
full/initial actions and server counters/reset date. Errors do not grant access or
locally spend a reveal. No hidden name/ID is included in ordinary Likes data.
Participant names come only from backend snapshots, never local answers/friends.
Voter labels use backend gender and `Class of YEAR`, not Grade, when unprotected.
Protected GET/POST replies contain no voter name, initial, ID or cohort metadata.
The card says “This user also has Premium” and explains that their votes are
protected and the attempt was not used. Both independent 2/5 counters stay intact.
Previously unlocked names are hidden on recheck while the author has active
Premium; expiry restores ordinary access without charging an old unlock again.
Already seen names or screenshots cannot be withdrawn.

Paywall uses `paywall_features_v4` so cached badge promises cannot reappear. It
keeps the 2/5 paid-week limits, 2× online stars and active protection. A readable
pre-purchase disclaimer explains other Premium voters are also protected and
attempts are not spent. Store pricing, autorenewal, restore and legal links remain.
No product, API route or schema migration is added by this update.

Purchase/restore first binds the backend-owned billing alias. SDK success is not
server confirmation: refresh benefits after the verified webhook arrives. Account
changes clear the current private response; requests pin credentials and reject
stale success/failure. Benefits are not persisted on the device.

New online round requests send revealPolicyVersion=1. The voting UI warns before
answers and before submitting about limited Premium identity disclosure. Backend
only opts in newly created rounds with the feature enabled. Resume requires the
new capability and batch submission sends the notice version; old votes are not
retroactively exposed. Update published Terms/Privacy before activation.

This branch does not apply a migration, change dashboard/ASC pricing, deploy or
build/upload TestFlight. Device purchase/restore and real DB acceptance remain
separate release gates. Other unfinished features from main worktrees are excluded.
