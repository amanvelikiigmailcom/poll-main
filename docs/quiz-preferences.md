# Quiz preferences

Settings → GAME → Quiz preferences opens the server-backed settings sheet.
All UI is English, using existing blue/white colors.

- GET/PUT `/api/quiz-preferences`; options/current value come from backend.
- Default Everyone. Girls, Boys, Non-binary are single-select alternatives.
- Same-campus graduation year is prioritized by backend, then other eligible people.
- Dropdown stays open after selection. Select saves; Back/swipe handle discards.
- Closing is blocked while saving; repeated taps cannot send duplicate writes.
- Failed load shows Retry, never a fabricated Everyone value.
- Failed save preserves draft; a read reconciles a possibly lost successful reply.
- Guests must sign in. No local settings persistence or offline success.
- A changed session clears the visible value and invalidates pending responses.
- Changes apply to the next new round; active draft and timer remain intact.

Preference-aware sessions use only server candidates, including matched contacts.
Contact labels stay local. Signed-in production load failures do not create an
unfiltered local round. Existing legacy drafts retain their prior behavior.

Backend source of truth and rollout:
`/Users/amanyessen/projects/flyprox_backend/docs/quiz-preferences.md`.
Backend migration/deploy/flag activation and device testing are not implied by
source completion.
