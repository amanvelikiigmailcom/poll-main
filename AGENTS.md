# Flyprox — действующие правила приложения

## Область действия и источники

- Этот файл содержит правила репозитория, а не журнал задач и старых разрешений.
- Учитывать родительские инструкции и актуальные явные команды владельца.
- Сначала `git status`; сохранять чужие незавершённые правки.
- Flutter-приложение находится в `app/`, пакет flyprox_app.
- История сборок/команд: [архив](docs/history/agents-before-cleanup-2026-11-24.md).
- Архив и прошлые команды не разрешают новые deploy/build/upload.
- Backend — отдельный flyprox_backend: [расположение и ссылки](docs/backend-reference.md).
- [Единственный production-статус](/Users/amanyessen/projects/flyprox_backend/docs/runtime-status.md) — в backend.
- Не копировать сюда live commit, флаги, номера тестов и статусы прошлых релизов.
- Версию source-клиента читать в [app/pubspec.yaml](app/pubspec.yaml).
- Наличие номера в source не доказывает доступность соответствующего TestFlight.

## Архитектура и авторитетные данные

- Flutter → Node.js/Express → Appwrite TablesDB → PostgreSQL.
- Правила доступа/наград исполняет Node; Appwrite Functions не используются.
- Firebase — SMS-вход; push transport — Appwrite Messaging/APNs без FCM.
- Существующий Firebase Messaging SDK для клиентского APNs пока сохраняется.
- Superwall — покупки; профильный debug/local Premium flag не даёт серверных прав.
- Авторитетные campus/year — onboarding_details; username — social_handles.
- Signed-in balance — profiles.stars; гостевой баланс остаётся локальным.
- Серверные подписки — notify_subscriptions с проверенными owner/state/expiry.
- Legacy fields profiles не использовать как второй источник прав.
- Auth userId определяется серверной сессией; клиентские body IDs не являются полномочиями.
- Сессию фиксировать на запрос; stale success/401 не меняет данные другого аккаунта.
- Не превращать сетевую ошибку в подтверждённое отсутствие подписки/данных.
- Redis-клиент/кэш рекомендаций в backend реализованы; состояние подключения — в runtime-status.
- Использовать только существующий Appwrite Redis; отдельный сервис не добавлять.

## Схема и документация в одном коммите

- Единственный машинный контракт БД — backend src/database-schema.js.
- Справочник backend docs/database-schema.md генерируется из чистых schema modules.
- История схемы — backend schema/migrations; применённые миграции неизменяемы.
- Поля таблиц в AGENTS.md и отдельную ручную схему в приложении не копировать.
- Backend/API/table change обновляет затронутые contracts, миграцию при изменении БД,
  генерируемый справочник/API docs и необходимые тесты в commit соответствующего репозитория.
- Если схема не менялась, пустая миграция не нужна.
- Проверять совместимость установленного клиента; новые profiles columns не добавлять.
- [Контракт интеграции клиента](docs/database-hardening-client.md) дополняет backend contracts.

## Продуктовые правила и дизайн

- Интерфейс приложения — English; сохранять существующий blue/white AppColors-дизайн.
- Навигация: Home · Search · Likes · Profile · Settings, единый Phosphor regular/fill.
- StatefulShellRoute сохраняет поиск и незавершённый раунд между вкладками.
- Friends и Blocked users — в Settings; Activity — отдельный экран в Settings.
- Likes не заменять старыми mock voter screens; текущие route implementations — в app_router.dart.
- Фото профиля не возвращать: используется фиксированный 🙂; gallery originals не менять.
- Возрастной gate —13+; сохранять outcome/time, не точный выбранный возраст/DOB.
- Legacy Premium age key не засчитывает общий gate; это не независимая age verification.
- Поток: phone/guest → age → About you → Choose your campus + graduation year →
  contacts/examples → username → optional push → Home.
- School-ready branch может пропустить contacts только по подтверждённому server mode.
- Имя/фамилия и @username независимы; full name не подставлять в username.
- Female/Male/Non-binary и формы кампуса сохраняют существующий дизайн.
- US/CA — одна выдача; Canada dataset отсутствует, GB-каталог покрывает England.
- Missing campus request сохраняется перед mailto; письмо отправляет сам пользователь.
- Skip/requested campus не открывает игру новым enrollment; server gate обязателен.
- Remote skip/guest/example flags — UI controls, не серверная авторизация.
- Возрастной gate, ожидание и school gate не обходятся Reset game/deep link.
- Подробный контракт форм: [onboarding](docs/onboarding-schools.md); release sections там исторические.

## Раунд и баланс

- Ожидание после раунда —60минут (один час), включая Premium.
- За себя голосовать нельзя; self не является кандидатом.
- Backend-константы — src/rules.js; клиентская реализация — LocalGameService.
- Изменение общего game contract требует согласованной правки и проверок обеих реализаций.
- Открытие share/compose и клики сами по себе не снимают ожидание и не дают награды.
- Invitation rollout остаётся на паузе; server-confirmed redemption нельзя заменять UI-фактом.
- Online draft хранит точные IDs, owner/session identity и sealed answers для replay.
- До/после submit проверять аккаунт; ошибка отправки не завершает подтверждённый online round.
- Повтор batch не начисляет награду снова; абсолютный баланс брать с сервера.
- Guest stars не загружать числом для серверного начисления; online reward не добавлять гостю.
- При offline signed-in показывать последний подтверждённый баланс своей сессии либо ожидание.
- Старые counters/balances не пересчитывать без подтверждённой истории начислений.
- Не обещать полную анонимность или несуществующее раскрытие имён входящих голосов.
- Текущий Full Reveal показывает собственные ответы; новые quotas требуют отдельного контракта.

## Контакты, поиск и кампус

- Контакты выбирает пользователь; полную книгу и сырые номера контактов не загружать.
- Соль/нормализация hash должны совпадать с backend rules.js; hash не гарантирует анонимность.
- Новый клиент отправляет hashes и хранит labels локально; mapping — по owned contactHash.
- Неоднозначный/unmatched контакт не даёт права голосовать за произвольный профиль.
- Privacy cutover старого клиента и school voting activation определяются backend runtime-status.
- Рекомендации кампуса сделаны: Friends of friends и From your campus.
- Сначала5карточек и See more; server limit кампуса50; общего каталога пользователей нет.
- Карточки показывают @username/relationship; не показывать ФИО, телефоны и имена общих друзей.
- Порог5учеников относится к школьным раундам, а не к рекомендациям.
- Search/cards/friends/accept проверяют текущий selected campus и блокировки в обе стороны.
- Смена campus/account очищает видимые старые результаты; stale responses игнорируются.
- Search сейчас prefix @username от2символов, debounce300мс; регистрация ника3–32 ASCII.
- Кампусы ищутся от3символов; города от2 либо локально по уже загруженному списку.
- Meilisearch — согласованный отложенный переход; не включать его этой задачей неявно.
- Для Meili: oneTypo=5, twoTypos=9; master keys в приложение не передавать.
- Activity: English,20сначала, следующие20только при scroll, максимум200в выдаче.
- Показывать выбранного человека, вопрос, graduation year и время; имя/ID голосовавшего не выдавать.

## Проверки и основные пути

- Основная проверка из корня poll-main: `python3 scripts/checks.py`.
- Она последовательно запускает полный Flutter suite и analyzer; устройство/cloud build не нужны.
- Диагностика из app/: `flutter test --no-pub`, затем `flutter analyze lib test`.
- Errors/warnings блокируют успех; новые info разбирать, не объявлять автоматически прежними.
- До изменения читать относящиеся тесты; новые/изменённые тесты просматривать после green.
- Общий API/game contract: также полный `python3 scripts/checks.py` из backend root.
- Runner change: `python3 scripts/test_checks.py`, затем настоящий полный прогон.
- Ноль тестов/incomplete report/ненулевой exit не являются успехом; не маскировать failures.
- Тесты постоянны в app/test; временные логи не заменяют их и не коммитятся.
- Widget tests используют fake secure storage и fresh router с dispose.
- Fake tests не доказывают SMS/APNs, native Contacts, Sandbox purchase/restore или device delivery.
- [Проверки](app/test/README.md) и [device checklist](app/test/device/README.md) разделены.
- Маршруты: app/lib/router/app_router.dart; игра: app/lib/services/local_game_service.dart.
- Баланс: app/lib/services/account_balance_service.dart; API: app/lib/services/api_service.dart.
- Версии/зависимости: app/pubspec.yaml и app/pubspec.lock; обновления только по необходимости, по одной.

## Разрешения и завершение

- Безопасные чтение, правки, тесты и commits выполнять в согласованном scope.
- Опасный пакет заранее описать: конкретные изменения, backup, QA и rollback.
- Уже полученное подтверждение этого пакета не спрашивать повторно; новые действия оценивать отдельно.
- Прошлые разрешения другой задачи не действуют как постоянное разрешение.
- Push/deploy/внешние записи — по действующим разрешениям; force-push запрещён.
- Cloud/native build, TestFlight upload и публичный submit — только по явной актуальной команде.
- При разрешённом push последний commit содержит `[ci skip]` для защиты от случайного cloud build.
- [iOS release runbook](docs/ios-release-runbook.md) — процедура, а не разрешение на запуск.
- Credentials читать только внутри авторизованного процесса; не выводить .env/JWT/.p8/tokens.
- Не коммитить credentials; публичный Firebase config — ранее согласованное исключение.
- Server erasure подтверждать deleted:true; при ошибке сохранять credential/progress для retry.
- Не обещать удаление Apple records или подтверждённое соответствие законам по одному age gate.
- В отчёте различать: код готов / committed / pushed / deployed / build available / device tested.
