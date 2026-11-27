# Aman campus discovery and four-card round diagnostics

Date: 2026-11-27. School: New Horizon Alternative School, Bessemer, Alabama
(`US-CCD-010033001264`). This is investigation and prepared-source evidence,
not a deployment, installed-build or native-device acceptance report.

## Prepared source

- Client branch: `fix/aman-campus-actions-20261127`.
- Backend branch: `fix/four-candidate-fallback-20261127`, based on the existing
  school-ranking-V2 branch. The canonical backend main does not yet contain
  that branch's previously deployed work; integration must preserve it.
- At initial source preparation, no push/deployment had occurred. The owner
  subsequently authorized backend release and source pushes without app builds;
  see the publication follow-up below.
- Canonical client's pre-existing `.gitignore` modification was not touched.

## Confirmed causes

1. Search used one global busy flag and a shared visibility invalidation after
   sending a friend request. Its own listener cleared and reloaded all cards.
   Outgoing requests stayed in suggestions but were ranked lower, producing
   flicker/reordering without reducing the section count.
2. Aman's last saved round was created on November 26 under ranking V1.
   Its 12 pinned questions all contained the same four 2030 classmates despite
   an 11-person frozen pool. New QA accounts were not in that old snapshot.
3. Actual runtime is the existing ranking-V2 release, with V2 globally enabled;
   it differs from the old canonical-main runtime-status snapshot.
4. V2's strict gender filtering could leave fewer than four peers. On reload,
   the HTTP route rejected empty questions, but permitted partially depleted
   questions containing one to three current candidates.

## Prepared client fix

Search request/cancel actions patch the authoritative server relationship
in place. They retain card ordering and counts, avoid self-triggered reload,
and disable only the affected card. Other mounted screens still receive the
visibility revision. Duplicate callbacks during async credential reads are
guarded. Failures leave the original card available for retry.

Eight new widget tests cover stable cards/counts, independent concurrent cards,
duplicate taps/callbacks, error/retry, cancellation, sign-out, authoritative
relationship changes and stale completion after changing the query.

## Prepared backend fix

The existing V2 weights, role selection, history and attention behavior remain
the primary algorithm. A too-small gender cohort expands to other legal
classmates without changing the saved account preference.

Depleted questions refill first from the existing frozen organic pool, then
from the existing V2 school sampler. A final seeded random refill preserves
valid pinned candidates and only completes short questions. Expanded snapshot
and question pins commit together. Complete questions and existing paid-boost
question assignments are preserved. Reload, submission and replay agree.

The HTTP response does not issue a one-to-three-person V2 grid. No fallback
overrides blocks, self exclusion, current-campus membership or profile
existence. If fewer than four permitted real classmates exist in total,
four distinct people cannot be manufactured: existing participant-change
recovery remains. No new explanation screen was introduced.

## Read-only live-data diagnostics

The school had 39 selected participants: Aman, 15 earlier seeded classmates and
23 current QA accounts. Aman had four friends, eight outgoing requests, one
incoming request, five blocking peers and one hidden suggestion.

The deployed suggestions function returned 28 campus cards and no mutuals:
39 minus self, four friends, five blocks and one hidden recommendation.
Outgoing requests remain part of that count.

Using live rows and the deployed pure V2 functions, without creating rounds:

- Aman: 33 eligible candidates, including 19 QA accounts; the deterministic
  diagnostic run showed 24 unique people and 12 distinct fours across 12
  simulated questions, with eight total candidates/reserves per question.
- All 23 QA accounts: no self/campus/block violations in the checked outputs.
- QA07 had three eligible peers; QA08, QA21 and QA22 each had one because
  of intentional fixture blocks. Restricted gender settings explain other
  smaller QA pools. These facts are not evidence of missing school accounts.
- This calculation is not a new persisted Aman round or a device test.

## Authenticated production HTTP acceptance

Owner explicitly approved one Aman round request without votes and a QA-only
request/cancellation. Private evidence and before/after snapshots:

`/home/myuser/.local/state/flyprox-aman-campus-acceptance-1795769806915`

- A real Firebase-verified Aman login returned his existing ordinary account,
  not reviewer capability. The temporary API session was logged out afterward.
- At 08:56:51 UTC, `/api/quizzes/current` returned `409 round_cooldown` with
  1596 seconds remaining, approximately until 09:23:27 UTC. No timer bypass,
  round reset, vote submission or reward was performed.
- Aman's full profile, enrollment, rounds and relations were unchanged.
- QA12 sent a request to QA13. Outgoing/incoming states were confirmed through
  both authenticated API identities. Repeating the request produced one
  relation, not a duplicate. Cancellation cleared both sides; the relation
  remained idle with its normal retry cooldown.
- QA12/QA13 profiles and balances were unchanged. The test can leave a
  notification event in QA history, as approved; notification delivery was
  not asserted.
- All 23 selected QA accounts passed 161 authenticated GET checks in total:
  me, suggestions, summary, friends, likes, voting mode and search for Aman.
  All returned 200. The four QA accounts blocking Aman did not find him.

## Automated checks

- Client full suite: 658 passed, zero failed/skipped.
- Analyzer: zero errors, zero warnings, 10 reviewed infos outside the edited
  social screen/tests (constructor lint and existing deprecated APIs).
- Backend original ranking-V2 branch: 458 passed, syntax passed.
- Prepared backend after four-card fixes: 471 passed, zero failed/skipped,
  syntax passed.
- Deployed source's targeted ranking/API fake-provider suite: 20 passed.
  Local/runtime hashes matched for ranking, voting-mode, server and suggestions
  before the prepared changes.
- Regression tests failed before the fixes and passed afterward.

## Remaining acceptance

Native iPhone UI behavior, APNs delivery and purchase flows are not proven by
this task. The client card fix is not in the installed binary. No native build
or upload was authorized or started.

## Publication follow-up

The owner subsequently authorized backend publication/deployment and source-only
frontend push, explicitly without an application build or app-store upload.

- Backend source was published to canonical GitHub main. The actual release,
  verification timestamp, preserved runtime settings, private backups and
  rollback are recorded only in the backend's
  [runtime-status](/Users/amanyessen/projects/flyprox_backend/docs/runtime-status.md).
- Post-switch authenticated Aman acceptance returned a new V2 round with12
  questions and four displayed candidates plus four reserves per question.
  The shown fours covered23 different people including15 QA participants.
  Reload was identical. No votes were submitted; balance, timer, received-vote
  counter and enrollment stayed unchanged. No reviewer reset was performed.
- The server full suite passed471 tests; live metadata before/after showed
  39 tables and0 differences. A first test-only attempt that inherited Redis
  settings was stopped before switching; isolated tests passed afterward.
- Client code and this report are published in branch
  `fix/aman-campus-actions-20261127`, with `[ci skip]`; no main integration or
  installed-client release is implied. GitHub Actions listed no runs on that
  branch at publication. The repeated full client suite passed658 tests, with
  zero analyzer errors/warnings and the same10 reviewed infos.
- A cached device-local draft does not automatically become a fresh server
  round. New server behavior applies when the client loads a round online.
