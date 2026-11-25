# Capacity optimization (source only)

Backend implementation/sequence:
`/Users/amanyessen/projects/flyprox_backend-performance-20261125/docs/performance-capacity-plan.md`.

## Invitation transport scheduling

The invitation screen initially refreshes once, then polls at 15, 30 and 60 seconds,
remaining at 60 seconds while idle. After an invitation it starts with 5 seconds,
then 15/30/60. Background lifecycle states pause the scheduler. On resume the
visible current route checks immediately. Covered routes and a busy composer do
not poll. One slow check cannot overlap another scheduled check, and an obsolete
completion cannot restart a paused/disposed schedule.

Invitation v2 reads rewards once per refresh when its owner's delivery queue is
empty. A delivery attempt (including a lost acknowledgement) still causes a second
rewards read, preserving server-authoritative grants and replay recovery. Another
account's queue is neither submitted nor a reason for the second read. Redemptions
still refresh the balance. No server rights are inferred from UI actions.

Coverage: `invitation_poller_test.dart`, added request-count/lost-ack tests in
`invitation_service_test.dart`, and the existing full widget/service suite.
Local acceptance: 502 tests passed, 0 failed/skipped; analyzer 0 errors, 0 warnings,
16 unchanged infos. Backend companion full suite: 299 passed + syntax.
No build, TestFlight upload, device acceptance, push or production rollout.
