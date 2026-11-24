# Тесты Flyprox

Premium: `premium_service_test.dart` checks pinned credentials/stale 401 and
server-only counters; `premium_reveal_test.dart` checks paywall, two independent
quotas, first initial/full name with backend graduation year, account clearing and
badge expiry. `premium_screen_test.dart` checks the single weekly offer.
`round_completion_test.dart` replaces retired round_reveal tests and proves Full
Reveal is absent and acknowledged server rewards can display 2000.
These fakes do not prove real purchase/restore, webhooks or production DB uniqueness.

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
# Other-person profile

`person_profile_screen_test.dart` covers the English other-person screen,
relationship actions/confirmations, guarded names, paginated nomination groups,
stale responses, self redirect and narrow-screen text scaling.
`cooldown_navigation_test.dart` verifies both profile routes preserve search and
the unfinished round in the real router. See `docs/person-profile.md`.
