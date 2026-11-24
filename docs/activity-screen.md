# Campus Activity

- Entry: Settings → Activity (`/home/activity`); back returns to Settings.
- The five bottom tabs remain available, with none highlighted on this screen.
- English UI: blue header, light-gray background, white event cards, gold stars
  and compact time badges. Long names and large text wrap rather than truncate.
- Data comes from the authenticated `GET /api/activity` endpoint, not local
  sample entries. Backend enforces campus visibility and blocks.
- Cards show the chosen person's name, question, event time and confirmed
  graduation year when available. Do not infer gender, grade or voter identity.
- Request the first page on entry; request further pages only on downward
  scrolling. Keep the existing 20-per-page / 200-item display limit.
- Pull to refresh restarts pagination. Account/campus changes clear old entries
  and invalidate pending responses.
- Distinct states: loading, empty campus feed, campus selection required,
  authentication required and request failure with retry. An unavailable API
  must not appear as a successfully loaded empty campus.

Tests: `app/test/activity_screen_test.dart` and
`app/test/cooldown_navigation_test.dart`. Run the complete local checks with
`python3 scripts/checks.py` from the repository root. Widget tests do not prove
live backend delivery or rendering on a physical device.
