# Push destinations and email support

Paired backend commit: `70b4efc1152dde6d0daf7ce158f7b3af13f05c94`
(`feature/push-support-context-20261125` in flyprox_backend).

## Current client behavior

Support, feedback, app problems, parent/guardian questions, account reports and
question reports use **support@flyprox.com**. Settings exposes Contact support,
Report a problem and Send feedback. Safety and For parents use the same draft
flow. The support address is fixed in client content rather than replaced by
remote content overrides.

Account reports from public profiles and social lists ask for a reason and an
optional description. The draft contains the target username/account reference,
user-entered text and app version when available. It does not automatically
include the reporter's phone, auth credentials, contacts, votes or game draft.
Opening or copying a draft is not submission: the user must send the email.
No email SDK, helpdesk, background service or new database table is introduced.
The client no longer calls the social report action; older clients can still
use the existing server endpoint. Existing server reports are not deleted.
Blocking remains a separate server action, independently available from the
account menu. A question report keeps its existing question ID/text-only flow.

Mail launch errors retain the text and expose Copy message (Copy report for a
question). The full address and message remain selectable if clipboard access
fails. All support UI is English. Safety uses the current 13+ gate and explains
both guest and online play. No reply-time promise is made.

## Push destinations

| Backend type | Client destination |
| --- | --- |
| vote_received | Likes |
| friend_request | Friends → Received, with Accept / Decline |
| friend_accepted | Friends |
| round_ready, inactive_1, inactive_3, inactive_7 | Voting, subject to existing gates |
| invitation_activated | Invitations |
| premium_renewed, premium_expiring | Premium |
| new_device | New sign-in notice and email support |
| moderation | Account update notice and email support |

Known cold-start taps skip the launch video. Existing onboarding/age/school
requirements still apply. Unknown push types do not navigate.
Each live tap refreshes the data destination, including repeated taps on an
already mounted Likes or Received screen. The vote route stays stable so a tap
cannot recreate an in-progress round. Normal tab changes still preserve state.

The paired backend change adds `recipientId` and an opaque `eventId`, plus
`actorId` for friend events only. The native bridge accepts top-level, nested
map or JSON-string data and projects those fields to Flutter. Malformed metadata
is discarded. Addressed taps navigate only when the signed-in user matches the
recipient. Legacy type-only pushes remain compatible and show current-session
data. The server still authorizes every request.

Friend events place the matching account first if it is present in the loaded,
authorized list. Missing/removed requests are not injected from the push.
The opaque event ID is a support reference, not a vote identifier; no voter ID
is included. Account notices do not invent unavailable moderation/device details;
their support email includes the notification reference when available.
Backend copy names Likes and describes invitation rewards as extra rounds.
Backend and client deployment are required to activate the complete contract.

## Acceptance

Run `python3 scripts/checks.py` from both repository roots and
`python3 scripts/test_push_payload.py` from the client root. Automated tests cover
email encoding, unavailable email app, copy fallback, account reason selection,
no false sent status, no server report action, narrow screens/large type,
repeated push refresh, incoming requests and cold-start notice routing.

Before release, test on a real iPhone with signed-in accounts:

- Open each real APNs notification with the app foregrounded, backgrounded and
  terminated. Confirm the destination, current data, and absence of launch video.
- Receive a new vote while Likes is already mounted; tap twice and verify fresh
  data without duplicate rows. Verify the same for friend requests.
- Cancel/accept a request on another device before tapping its old push. Confirm
  current server state and no actionable stale request.
- Sign out or switch accounts before tapping an old push. Only current-session
  data may appear. Never expose a previous account's data.
- Confirm an in-progress round survives tab switching and repeated round pushes.
- Open all email entry points, inspect recipient/subject/body, send a test email
  manually and verify actual mailbox receipt and ability to reply.
- Test no configured email app, clipboard failure, large text and keyboard.
- Verify account-report email and server-side Block work independently.

Automated tests do not prove APNs delivery, email receipt, production deployment
or availability in TestFlight. This change does not trigger a build or upload.
