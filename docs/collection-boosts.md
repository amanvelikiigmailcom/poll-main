# Collection — stars and promotion

Prepared client/backend source, not a production rollout.

- Profile card + clickable Stars + reward-screen Collection action all open
  existing `/collection`. Bottom navigation and Friends/Likes/Requests unchanged.
- Replaces the old local cosmetic catalog; no cosmetic entitlement backend exists.
- English UI, navy gradient, white header, fresh server balance, two server-priced
  cards, confirmation, pending retry, active queued rights and earning explanation.
- 1,000 stars per completed 12-question round, or 2,000 for an online round with
  server-confirmed Premium; never per individual vote.
- 5,000: 4 random questions in a single other player's round, at most1sympathy.
  20,000:1sympathy question. Only future eligible school rounds; never self/blocked/
  other campus; placements are not guaranteed votes or verified views.
- The shop cannot spend guest stars or the profile's offline cached balance.
- Pending purchase IDs persist per server account before POST. Uncertain replies
  retry the same operation; another boost stays disabled until resolved.
- Profile balance invalidates after success. The existing online finish path
  awaits backend submission before navigating to star-received.
- Backend feature/schema flags, migrations and rollback:
  `/Users/amanyessen/projects/flyprox_backend/docs/collection-boosts.md`.
- No migration/deploy/native build/upload is authorized by this document.
