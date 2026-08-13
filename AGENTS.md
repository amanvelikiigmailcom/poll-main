# Hidavo (poll-main) — agent instructions

**Product name:** Hidavo (was OISTER / flyprox_app package name — keep `flyprox_app` in pubspec/imports).  
**Repo:** `https://github.com/amanvelikiigmailcom/poll-main`  
**Goal:** Gas-like anonymous school polls. Local prototype first; full backend later.

---

## Token-saving rules (read this first)

1. **Do NOT** dump the whole repo, PDFs, or all of `lib/screens/**` on session start.
2. **Do NOT** read by default:
   - `Technical_Specification.pdf`, `design.pdf`, `api.pdf` (only if user asks design/API)
   - `screenshots/` (local QA dumps)
   - `app/build/`, `.dart_tool/`, generated l10n dumps unless debugging gen
   - All 500+ poll seeds in full — open `app/lib/data/poll_questions.dart` only when changing questions
3. **Do** start from this file + the 3–6 paths under “Open first”.
4. Prefer `grep` / targeted `read` over recursive list of every screen.
5. After code changes: **commit and push** (see Rules). No secrets in git.

---

## Open first (minimal map)

| What | Path |
|------|------|
| **App entry** | `app/lib/main.dart` → `app/lib/app.dart` (`HidavoApp`) |
| **Routes** | `app/lib/router/app_router.dart` |
| **Local game brain** | `app/lib/services/local_game_service.dart` |
| **Invite / share** | `app/lib/services/invite_share_service.dart` |
| **Onboarding (login → name → friends)** | `app/lib/screens/onboarding/names_entry_screen.dart` |
| **Vote UI** | `app/lib/screens/voting/vote_screen.dart` |
| **Home / start poll** | `app/lib/screens/home/main_tab.dart` |
| **Question seeds** | `app/lib/data/poll_questions.dart` |
| **Constants / brand URLs** | `app/lib/utils/constants.dart` |
| **Flutter package root** | `app/` (`pubspec.yaml`) |

There is **no separate backend package in this repo**. Network stubs live under:

- `app/lib/services/api_service.dart`, `auth_service.dart`, `poll_service.dart`, `user_service.dart`

“Backend” today = **local** `SharedPreferences` via `LocalGameService`, not a server in-tree.

---

## Project layout (high level)

```
poll-main/                 # git root
  AGENTS.md                # YOU ARE HERE — agent map
  CLAUDE.md                # short repo rules (also loaded)
  app/                     # Flutter app (frontend + local logic)
    lib/
      main.dart, app.dart
      data/                # poll question seeds
      services/            # local game, invite share, API stubs
      screens/             # UI (many screens are shell/mock)
      router/
      providers/, models/, theme/, widgets/
    android|ios|web|macos/ # platform shells (label: Hidavo)
  screenshots/             # ignore unless user asks
  *.pdf                    # specs/design — ignore unless asked
```

**Frontend:** entire Flutter UI under `app/lib/screens/`, `widgets/`, `theme/`.  
**“Backend” (real API):** not implemented in-repo; only stubs + local storage.

---

## What we already built (session history)

Working **local Gas-style loop**:

1. Onboarding: **username (login)** → **display name** → **≥3 classmates**
2. Focus stays on name field after each add
3. Round: **12 questions** (4 sympathy + 4 normal + 4 humor)
4. Each question: **4 cards = player + 3 friends** (shuffled)
5. No “school wait / 3 of 5 participants” gate — min **3 friends** is enough
6. After round: stars (+1000), timer 40 min, **invite** (WhatsApp / Telegram / Instagram + system share)
7. Brand rename **OISTER → Hidavo** (UI, l10n, domains `hidavo.app`; package name still `flyprox_app`)

**Still shell / mock (don’t treat as finished product):**

- Profile / friends list / activity / premium / rooms — mostly demo UI
- Profile does not always show local username/name
- Friends tab ≠ onboarding name list (demo data)
- No real server, matching, or live multi-user votes

---

## How to run

```bash
cd app
flutter pub get
flutter run -d chrome    # no Xcode required
# or: flutter run -d macos
```

Package name for imports: `package:flyprox_app/...`

---

## Product rules (local mode)

- `LocalGameService.minFriends = 3`
- Ready to play: username + playerName + ≥3 friends (`hasEnoughNames`)
- Start poll: `MainTab` → `/vote` (not school-wait screen)
- Invite copy + deep links: `InviteShareService` (IG = copy + open app)

---

## Secrets

- Never commit tokens, PAT, `.env`, or `mcp.json` with secrets
- GitHub PAT if needed: `~/.config/github.env` (outside repo) or env — not in chat
- Project MCP secrets may live in `../mcp.json` (parent `NEW/`) — do not commit

---

## Git rules

- After meaningful changes: **commit + push** to `main` on `amanvelikiigmailcom/poll-main`
- No force-push unless user asks
- Keep commits focused; no secrets

---

## When user opens a new chat

1. Read **this file only** for orientation.
2. Ask or infer the task; then open **only** the files above that match.
3. Do not re-read all of `screens/` “to understand the app.”
4. Summarize plan in 3–5 bullets before large edits.
