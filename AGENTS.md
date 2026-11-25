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

## Несколько ИИ-терминалов и Git worktrees

- Канонический source приложения — опубликованный `main` этого репозитория;
  backend имеет собственный `main`. Связанные изменения связывать ссылками на commits.
  Рабочая ветка, серверный checkout и установленный binary могут иметь разные версии.
- Перед работой проверить `pwd`, `git status --short --branch`, текущую ветку и
  `git worktree list`. Для сравнения с GitHub обновить refs через `git fetch origin`.
- Каждой параллельной задаче — отдельные branch и worktree от актуального main.
  Несколько терминалов не должны одновременно менять одну рабочую папку.
  Заранее определить владельца общих файлов: router, providers, quiz/API services.
- `main` объединяет один назначенный терминал. При параллельном редактировании
  согласовать паузу затронутых worktrees перед интеграцией; не останавливать чужие процессы самостоятельно.
- У worktrees раздельные рабочие файлы/index/HEAD, но общие branch refs и stash.
  Не считать чужой stash своим и не выполнять pop/drop без проверки и разрешения.
- Коммитить небольшие законченные изменения с относящимися к ним тестами и docs.
  Перед staging просматривать список файлов; локальный Superwall key, credentials
  и generated build artifacts сохранять отдельно от source commits.
- Перед объединением проверить все worktrees, staged/unstaged/untracked файлы,
  stash и уникальные commits. До массового переноса сохранить приватный backup;
  чистая branch history сама по себе не доказывает отсутствие незакоммиченной работы.
- Сливать из чистой рабочей папки. Сначала проверить diff; текстовые конфликты
  разрешать по действующему контракту функций, сохраняя полезные изменения обеих сторон.
  Не заменять общие файлы целиком по принципу «наша/их версия».
- Ноль commits в `main..branch` подтверждает ancestry, но не поведение функций.
  После squash/cherry-pick дополнительно сравнивать patches и итоговый source.
  `merge -s ours` допустим только после доказанной эквивалентности перенесённых
  изменений, с записанным обоснованием; он не заменяет разрешение конфликтов.
- После объединения проверять пересечения функций: capabilities запроса, смену
  аккаунта, сохранённый draft, награду/replay и навигацию. Общий API/game contract
  требует полных проверок обоих репозиториев, описанных ниже.
- Перед разрешённым push обновить remote refs и учесть чужие commits. При расхождении
  повторно проверить объединённый результат. Canonical main обновлять fast-forward
  от проверенной integration branch; опубликованную историю не переписывать.
- Завершение подтверждать отдельно: чистый status, отсутствие unmerged paths,
  включение нужных feature commits и совпадение main с актуальным origin/main.
  Отставание старого worktree нормально, если вся его работа уже перенесена.
- Удалять worktree только по явной команде: проверить tracked/untracked/ignored
  файлы, включая локальную конфигурацию, сохранить нужное и подтвердить перенос.
  Использовать `git worktree remove` без force; ветки и backup не удалять неявно.
  Серверные `releases/` — отдельные runtime/rollback snapshots; очистка worktree
  не разрешает их удаление, остановку сервиса или новый deploy.
- Процедуры Git: [worktree](https://git-scm.com/docs/git-worktree),
  [тематические ветки](https://git-scm.com/docs/gitworkflows),
  [слияние](https://git-scm.com/docs/git-merge). Это правила работы, не разрешение на выпуск.

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
- Новая выдача кампусов разделяет страны; старые запросы US/CA сохраняют общий каталог. Полнота каталога каждой страны проверяется отдельно; импортированы CA (StatCan ODEF), NZ, SG, HK; GB-каталог покрывает England, Scotland, Wales и Northern Ireland.
- Missing campus request сохраняется перед mailto; письмо отправляет сам пользователь.
- Skip/requested campus не открывает игру новым enrollment; server gate обязателен.
- Reviewer skips, guest exit и examples доступны только текущей подтверждённой reviewer-сессии; старый install-wide reviewer flag не даёт прав.
- Remote skip/guest/example flags — UI controls, не серверная авторизация.
- Доступность кампуса определяется backend policy; waiting восстанавливается с сервера и не обходится сменой страны, Reset game или Edit profile.
- StoreKit storefront — подсказка страны; страна учёбы подтверждается отдельно. Новая выдача кампусов разделяет US/CA; старые запросы совместимы.
- Collect stars показывает уже начисленную сервером награду; анимация не меняет баланс.
- Возрастной gate, ожидание и school gate не обходятся Reset game/deep link.
- Подробный контракт форм: [onboarding](docs/onboarding-schools.md); release sections там исторические.

## Раунд и баланс

- Ожидание после раунда —60минут (один час), включая Premium.
- За себя голосовать нельзя; self не является кандидатом.
- Backend-константы — src/rules.js; клиентская реализация — LocalGameService.
- Изменение общего game contract требует согласованной правки и проверок обеих реализаций.
- Приглашения v2: один засчитанный получатель — один раунд из12 вопросов; только сервер подтверждает grant/redemption.
- Messages .sent или первые5 WhatsApp-возвратов в UTC-день после >4сек дают раунд; с6-го требуется POST подтверждения получателя. GET/share сами по себе не награждают.
- Максимум50 завершённых online раундов в UTC-день; приглашения не обходят лимит, неиспользованные раунды сохраняются.
- Состояние invitation rollout читать в backend runtime-status; server-confirmed redemption нельзя заменять UI-фактом.
- Online draft хранит точные IDs, owner/session identity и sealed answers для replay.
- До/после submit проверять аккаунт; ошибка отправки не завершает подтверждённый online round.
- Повтор batch не начисляет награду снова; абсолютный баланс брать с сервера.
- Guest stars не загружать числом для серверного начисления; online reward не добавлять гостю.
- При offline signed-in показывать последний подтверждённый баланс своей сессии либо ожидание.
- Старые counters/balances не пересчитывать без подтверждённой истории начислений.
- Не обещать полную анонимность или несуществующее раскрытие имён входящих голосов.
- Full Reveal своих ответов удалён целиком. Premium: серверные 2 полных имени + 5 первых букв за неделю, ×2 онлайн-звёзды и защита имени/первой буквы при активной подписке; публичной галочки нет; контракт docs/premium.md. Legacy голоса не раскрывать.

## Контакты, поиск и кампус

- Контакты выбирает пользователь; полную книгу и сырые номера контактов не загружать.
- Соль/нормализация hash должны совпадать с backend rules.js; hash не гарантирует анонимность.
- Новый клиент отправляет hashes и хранит labels локально; mapping — по owned contactHash.
- Неоднозначный/unmatched контакт не даёт права голосовать за произвольный профиль.
- Privacy cutover старого клиента и school voting activation определяются backend runtime-status.
- Рекомендации кампуса сделаны: Friends of friends и From your campus.
- Сначала5карточек и See more; server limit кампуса50; общего каталога пользователей нет.
- Карточки поиска/рекомендаций и профиль показывают имя/фамилию только из разрешённой серверной same-campus projection, затем @username/relationship. Телефоны и имена общих друзей не показывать.
- Профиль: Friends, Likes, Requests; Collection — отдельная карточка звёзд и бустов, также доступна после раунда. Таб-бар не менять.
- Collection:1000звёзд за полный раунд,2000за online раунд с серверно подтверждённым Premium; покупки только серверные. 5000 —4случайных вопроса одного чужого раунда, максимум1sympathy;20000 —1sympathy. Назначение не гарантирует просмотр/голос; self/campus/blocks не обходить.
- Порог5учеников относится к школьным раундам, а не к рекомендациям.
- Search/cards/friends/accept проверяют текущий selected campus и блокировки в обе стороны.
- Смена campus/account очищает видимые старые результаты; stale responses игнорируются.
- Search от2символов: prefix username либо токены имени/фамилии только в выбранном кампусе; @ ограничивает запрос username. Debounce300мс; регистрация ника3–32 ASCII.
- Hide suggestion сохраняется сервером и не меняет дружбу/заявку/блокировку; Undo и Settings → Hidden suggestions восстанавливают рекомендацию.
- School batch choicePolicyVersion1 отправляет точные показанные choiceIds для каждого вопроса, включая Shuffle; снимок выбора и reward сохраняются атомарно.
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


## Reviewer onboarding exception

- Only the current backend-confirmed session for Firebase reviewer `+16505551234` must never show either About you or campus/graduation onboarding form, including Back/deep links.
- Contacts/examples remain available. Other users retain all mandatory registration/enrollment rules; age gate applies to everyone.
- Preserve actual profile/campus values; never seed fake names, gender or enrollment. Reviewer can fill omitted data in Edit profile; first absent gender/country capabilities come from backend limits.
- Existing server username must be restored before showing creation; a failed identity request is Retry, not permission to generate a replacement.
