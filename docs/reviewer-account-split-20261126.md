# Reviewer account separation and regression fixes

The existing ordinary account kept its backend ID, username, campus, balance and
history while its phone login moved to the other configured US Firebase test
number. The reviewer number now resolves to a separate, blank backend account.
Phone values/codes were delivered to the owner; private snapshots/tokens are not
repository artifacts. Backend runtime evidence belongs in its runtime-status.md.

## Client behavior

- Firebase login consumes the verified reviewer capability and stable account ID.
  Local participants, nickname, draft and timer are archived/restored per account.
- Reviewer skips personal details and campus/year; contacts and remotely controlled
  example names remain available. Ordinary registration gates stay mandatory.
- Returning selected enrollment and canonical username restore before navigation,
  including a fresh device/browser profile. A ready campus skips contact setup.
- Server waiting payloads retain their deadline and open the designed timer;
  initial timer refresh cannot bounce through the voting screen before settling.
- Empty reviewer profile/editor use absent values; reviewer gender/country edits
  follow server field limits. Campus-less Search explains how to add a campus.
- Shuffle keeps its text/behavior and loses only its icon. Replay intro is removed.
- Invitations show one current item, with older invitations collapsed in history.
- Likes identify historical answer options accurately. Details use each selected
  vote's own snapshot. Backend timeline ordering is newest first with stable ties.

## Verification

Full client suite:635 passed,0 failed/skipped; analyzer0 errors,0 warnings
and10 existing informational notices. Backend suite:433 passed. Regression tests for the actual
server waiting response, local account isolation, campus-less Search and distinct
received-vote details. Backend tests and positive authenticated checks are recorded
in the backend runtime report. Browser acceptance used real API/Firebase identity
with native-only handoffs replaced; see app/test/browser/README.md.

Two reviewer rounds (examples and six picked contacts) completed, received the
server reward and opened the waiting screen. Name and gender saves succeeded;
ordinary restored login skipped setup. The reviewer test data was reset afterward.
The ordinary account's 200 pre-existing history rows/profile were re-read unchanged.

Likes reconciliation: 64 historical incoming rows, 48 accessible results over four
pages; four self-votes and twelve votes from a blocked actor are excluded. Blocked
candidates are also removed from historical option sets. No vote/balance history
was rewritten to change those counts or to invent missing option names.

Client code readiness, source publication and native/TestFlight availability are
separate stages. No new native build or TestFlight upload is implied by these checks.
