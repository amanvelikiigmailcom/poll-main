# Тесты Flyprox

Premium: `premium_service_test.dart` checks pinned credentials/stale 401 and
server-only counters; `premium_reveal_test.dart` checks paywall, two independent
quotas, first initial/full name with backend graduation year, account clearing and
protected full/initial responses without spending, explicit author-Premium copy,
and a purchase hiding an old unlock. `premium_service_test.dart` also strips mixed
identity fields from protected GET/POST responses. `premium_screen_test.dart` checks
the single weekly offer, 2/5 limits, protection disclaimer and legal controls, and
ignores old cached badge copy. Activity receives legacy badge fields to verify
that they cannot render membership icons. Backend tests additionally exercise
three/five users and auto-fill five users' full rounds with mixed Premium status.
`round_completion_test.dart` replaces retired round_reveal tests and proves Full
Reveal is absent and acknowledged server rewards can display 2000.
These fakes do not prove real purchase/restore, webhooks or production DB uniqueness.

## Critical session and network regressions

- `api_service_test.dart` uses a fake HTTP adapter with real Dio interceptors:
  all five methods, pinned/missing Bearer, current/stale 401, caller-owned 401,
  connection/timeout/cancellation errors and malformed HTTP error bodies.
- `auth_session_test.dart` uses real services and in-memory platform storage:
  cancelled login after logout, reversed login responses, shared Firebase/legacy
  attempt ordering, offline logout, pinned remote logout and stale UI completions.
- `storage_service_test.dart` covers secure token persistence, serialized writes,
  cancellation during a native write, metadata rollback on secure-write failure,
  and recovery after a failed queued operation.
- `star_balance_provider_test.dart` exercises the actual Riverpod provider/cache
  wiring through guest → A → offline → B → logout, hashed cache keys and late
  responses. The lower-level balance tests remain responsible for invalid values.
- `profile_edit_service_test.dart` also preserves the server's username conflict
  status/message. Retired photo/registration paths are not new coverage targets.
- `invite_code_store_test.dart` checks accepted HTTPS/manual inputs, hostile or
  malformed URLs and preservation of the existing code on invalid input.
- `invitation_links_test.dart` injects a URI stream and fresh router: warm links
  preserve OTP/vote/age-screen input, attribution is not auto-claimed, duplicates
  do not replace the pending code and observation failures do not lose it.
  This tests the Dart handler, not native cold-start Universal Links or the full
  application age gate; the existing age/router suites and device checklist apply.

No backend limits are reimplemented in client fakes. Existing backend
`share-invites.test.js` covers the fifth/sixth WhatsApp return, concurrent grants,
replay and UTC rollover; `round-submission.test.js` covers 49 → 50 and rejection
of the 51st round. Existing Premium/backend subscription tests cover quotas,
expiry and webhook idempotency; they do not replace Apple Sandbox.

Session ordering: both sign-in paths share an attempt generation. New attempts,
logout and direct credential changes invalidate old login completions. Logout
clears local credentials before its best-effort request and pins that request to
the old Bearer. Secure credential writes are serialized; login metadata is rolled
back on failed/cancelled commits. No API payload, database schema or game rule
changes are required.

Эти файлы — постоянная часть Git-репозитория. Они доступны любому агенту/разработчику с доступом к этой версии проекта. Логи `/tmp/flyprox-*.log` временные и не заменяют исходники тестов.


## Reviewer onboarding and returning username

`reviewer_onboarding_flow_test.dart` follows OTP → contacts → examples → username
→ Home → empty profile, proves both skipped forms never render, checks direct
links/back navigation across saved stages, canonical username restore and retry after identity errors.
Additional paths cover typed phone + test OTP, Firebase automatic verification,
Continue without login on both phone/code pages, network failure/retry, duplicate
taps, remembered phone without a session, restart and the reviewer age gate.
An ordinary Firebase test phone still enters personal-details setup.
`edit_profile_screen_test.dart` covers independent first-name/gender/country fill
with other reviewer fields blank, including both dropdowns on a 320px phone at
1×/2× text scale. Backend HTTP tests prove campus-free contacts
round submission/replay for the verified reviewer only, and atomic editor saves.
These tests use fake Firebase/HTTP providers and do not log into a real account.


## Без iPhone, кабеля и Xcode Cloud

Обычный компактный запуск **из корня репозитория**:

```sh
python3 scripts/checks.py
```

Он выполняет полный набор и анализ последовательно. Нужен Python 3; новые пакеты не требуются. Показывает количество passed/failed/skipped, время, exit и путь к полным логам в уникальном временном каталоге. При ошибке выводит короткую диагностику; полный лог сохраняется. Пустой/незавершённый прогон не считается успешным. Анализ запускается с `--no-fatal-infos`: все info видны в счётчике, errors/warnings блокируют успех; прежняя база — 22 info, новые замечания нужно разбирать.

После изменения самого скрипта дополнительно: `python3 scripts/test_checks.py` — проверки обработки ошибок и отчётов; они не заменяют тесты приложения. Скрипты и эти проверки хранятся в Git. Логи временные; при необходимости сохранить их перед очисткой `/tmp`.

Исходные команды для подробной диагностики из папки `app`:

```sh
flutter test --no-pub
flutter analyze lib test
```

Запускать последовательно. `--no-pub` подходит при уже установленных зависимостях; после изменения pubspec сначала отдельно выполнить `flutter pub get`. Не запускать параллельно несколько Flutter-команд, регенерирующих платформенные файлы.

Отдельный критический набор:

```sh
flutter test --no-pub test/invitation_service_test.dart test/invitation_code_screen_test.dart test/cooldown_navigation_test.dart test/phone_login_test.dart test/reset_game_test.dart
```

Unit-тесты проверяют правила и восстановление, widget-тесты создают экраны, нажимают кнопки, вводят текст и проверяют навигацию. Внешние службы/платформенные каналы там изолированы: тест результата `sent` не доказывает реальную доставку сообщения. Backend-проверки находятся в соседнем репозитории `flyprox_backend/tests/` и запускаются через `npm test`.

## Отдельно на iPhone

См. [device/README.md](device/README.md). Это отдельный ручной чек-лист, не автоматически исполняемый device-suite. Обычный `flutter test` его не запускает. Безопасность начислений/списаний/авторизации проверяем постоянно без телефона; настоящие Messages, APNs, Universal Links и Apple Sandbox проверяем отдельным этапом перед релизом соответствующих функций. Xcode Cloud для этих локальных проверок не требуется и сейчас запрещён владельцем.
# Collection / boosts

`collection_service_test.dart`: server-only spendable balance, persisted purchase
ID, lost replies/restart/retry, double tap and stale account responses.
`collection_screen_test.dart`: confirmation/cancel, skeleton/error/retry, insufficient
stars, guest sign-in, profile and reward navigation, small display/large text.
No network or native build required. These tests are not production DB/device QA.
# Other-person profile

`person_profile_screen_test.dart` covers the English other-person screen,
relationship actions/confirmations, guarded names, paginated nomination groups,
stale responses, self redirect and narrow-screen text scaling.
Backend API/privacy checks live in `flyprox_backend/tests/person-profile.test.js`
and `tests/social_api.test.js`; see `docs/person-profile.md`.
# Quiz preferences coverage

`quiz_preferences_screen_test.dart` covers server values, dropdown selection,
cancel/swipe, save/reopen, retries, lost-reply reconciliation, session changes
and small-phone large-text layout. `quiz_preferences_service_test.dart` verifies
the backend contract and stale-session isolation. `server_round_source_test.dart`
also prevents authenticated load failures from bypassing filters via local play.
These fake tests do not prove device UI or production rollout.

## Onboarding and UI polish

- `phone_login_test.dart`: Privacy/Terms launch their configured URLs while the
  phone route stays open.
- `school_onboarding_test.dart`: selection from 30 results reveals the year field,
  setup offers exactly 2026–2041, country-specific location labels, and both campus
  branches still continue through their required onboarding steps.
- `sharing_timer_test.dart` and `vote_screen_test.dart`: Skip and Shuffle each
  allow two actions per 12-question round, persist their usage in the draft, keep
  server candidates scoped to each question, and preserve exact submission retry.
  Shuffle displays at most four candidates, prioritizing replacements when the
  current question has other eligible candidates. A fixed four-candidate server
  question only permits reordering; no candidates are borrowed from other questions.
  These are client interaction limits, not new server authorization rules.
- `settings_profile_layout_test.dart`: home/profile/settings at 320px and 1×/2×
  text scale, local-data access, single profile edit entry, and no People counter.
- `reset_game_test.dart`: less frequent destructive actions remain reachable at
  the bottom of Settings; cancellation and failed erasure preserve account data.

Settings order: account → circle → game/feedback → Premium → help → privacy/data →
account actions. The local JSON viewer remains under privacy/data and exports only
on-device data. It is not a complete server-data access/export workflow.
# Performance scheduling

`invitation_poller_test.dart` verifies adaptive intervals, hidden/background
suppression, pause/dispose, slow in-flight checks and failure backoff.
`invitation_service_test.dart` verifies one rewards read without delivery work,
coalesced callers, owner isolation and mandatory re-read after a lost delivery
acknowledgement. See `docs/performance-capacity.md` in the repository root.
