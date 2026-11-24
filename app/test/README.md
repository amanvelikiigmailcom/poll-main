# Тесты Flyprox

Эти файлы — постоянная часть Git-репозитория. Они доступны любому агенту/разработчику с доступом к этой версии проекта. Логи `/tmp/flyprox-*.log` временные и не заменяют исходники тестов.

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
