# Flyprox — план работ (обновлено 2026-11-23)

## Пуши и Activity — локальная реализация 24.11.2026

Согласованный scope: надёжная backend очередь/APNs, реальные preferences, vote/timer60/invite hooks/friends/verified Premium/inactivity/sign-in/moderation, один native review. Исключения владельца: suspicious/Terms/admin/repeat/removeFirebase/Meili. Settings → Activity получает реальные campus events20→скролл→20, максимум200, graduationYear, English/наш дизайн. Региональный allowlist управляется backend CLI без панели; по умолчанию все регионы открыты.

Новые тесты и детали: docs/notifications-and-activity.md. Пока НЕ live: требуются7private tables+school_location index, signed Superwall webhook credentials и production activation. School-mode/whole-round source развивается параллельно; Activity также читает completed contact rounds только с доказательством campus на timestamp голоса (обе enrollment $updatedAt<=vote). Без этого исторические события пропускаются. Никакого cloud build. Shuffle/skip2 и weekly received-voter disclosures — отдельный игровой этап (нынешний Full Reveal только свои ответы); не считать выполненными.




## Новые формы профиля и школы — 24.11.2026

- [x] About you: имя/фамилия/Female·Male·Non-binary после возраста; прежний дизайн; отдельный ник после контактов без повторного имени.
- [x] Your school: поиск по телефонной стране, единая выдача US/CA, город/регион, отдельный календарный год выпуска; реальные английские GIAS данные.
- [x] Missing-school форма → запись заявки signed-in аккаунта + подготовленное письмо в поддержку; отправку выполняет пользователь.
- [x] Skip for now под server flag school_skip_enabled; без школы Home показывает ожидание, прямое голосование/API закрыты.
- [x] Частные записи по account ID и стабильным school ID, проверки/индексы и explicit scripts для двух таблиц; исправлено использование full name как дефолтного ника.
- [x] Permanent Flutter/Node tests добавлены и просмотрены; полный прогон:237 Flutter/91 backend,0 failed; analyze0 errors/0 warnings/22 прежних info. Обе формы визуально осмотрены в widget previews; native Mail/реальная БД отдельно. Результаты см.docs/onboarding-schools.md.
- [ ] Отдельное подтверждение production schema/import/deploy, реальная проверка индексов/поиска, последующий iPhone Mail QA. Облачные сборки не запускать. Публичные privacy/App Privacy изменения не опубликованы.

Подробности:docs/onboarding-schools.md. Canada пока только общий search group, отдельного канадского источника нет; GB каталог покрывает England.




## Новая задача: друзья, поиск, нижняя навигация и родители — 23.11.2026

- [x] Меню Home·Search·Likes·Profile·Settings; игра/результат/таймер под домиком, сохраняемые ветки. Friends в Settings, ссылка из профиля, настоящие серверные счётчики.
- [x] Поиск exact username и реальные заявки/дружба/блокировки/жалобы через Node/Appwrite; старые mock data не подключены к новым entrypoints. Пустые Friends of friends / From school.
- [x] Пять private social_* tables, уникальный канонический ник, пара аккаунтов, индексы фильтров, quota slots/cleanup, schema verifier и explicit additive migration. Однопроцессный deployment contract; не заявлять distributed safety.
- [x] Серверные блоки в contacts/candidates/votes; очистка аккаунта синхронизирована с social mutations. Смена ника не меняет friendship ID; background invitation sync ник не переписывает.
- [x] For parents обновлён и доступен из Settings, без недоказанного обещания аудита всех вопросов. Likes — отдельное честное coming-soon состояние до отдельной задачи.
- [x] Новые важные HTTP/Flutter tests; локальное визуальное превью поиска осмотрено. Финальный полный прогон:224/224 Flutter,78/78 backend; анализатор0 errors/0 warnings/22 прежних info. Облачных сборок и production writes не было.
- [x] Владелец отдельно подтвердил push обоих репозиториев,5таблиц/индексов и deploy/configuration. Выполнено:app d01b81c,backend68b3b32; systemd service active, runtime flags1; публичные health/content/questions200, social без auth401. Cloud build/public submit не запускались; школы/6invite tables/HMAC не включались.
- [x] Реальная Appwrite schema/unique/query проверка:7групп на изолированных QA IDs,24attempted rows очищены без ошибок; итог5social tables=0. Поправлен mismatch varchar vs ошибочно ожидаемый string; regression сначала упал, после исправления78/78 backend tests.
- [ ] Два реальных аккаунта и iPhone QA после отдельной сборки; публичные privacy изменения и расписание quota cleanup отдельно. Без новой сборки установленный TestFlight13 не содержит новые экраны.

Подробности: docs/social-release.md. Это новая задача, не автоматическое снятие ограничений других rollout.

## Текущая задача: архитектура и важные тесты без iPhone — 23.11.2026

Владелец уточнил:кабеля нет до вечера, сейчас добавлять только важные проверки без телефона; device-проверки описать отдельно рядом с тестами. Также явно описать архитектуру и правило использования Appwrite Redis в обоих AGENTS.md.

- [x] Read-only серверная проверка:отдельный systemd user-сервис flyprox-backend; Docker Appwrite2.7.4; appwrite-postgresql; appwrite-redis7.4.7. В Appwrite подтверждены DB_ADAPTER=postgresql, DB_HOST=postgresql, REDIS_HOST=redis. Приложение/Node не используют прямой SQL.
- [x] Оба AGENTS.md описывают Flutter→Node.js→Appwrite→PostgreSQL и предписание владельца использовать именно существующий appwrite-redis. Прямого Redis-клиента Node пока нет. Внутренние ключи Appwrite/FLUSHDB/FLUSHALL запрещены; новая Redis-интеграция отдельно, собственный namespace/TTL, без публикации сервиса в интернет.
- [x] app/test/README.md и backend/tests/README.md содержат отдельные команды быстрых проверок без телефона. app/test/device/README.md — отдельный ручной чек-лист6device-сценариев. Это не реализованный и не пройденный автоматический device-suite.
- [x] Добавлены5 критических Node-проверок:APNs outage не блокирует grants; восстановление после первой из двух наград; code collision/retry; bounded collision failure без потери старых данных; отсутствие ключа блокирует операции до обращения к провайдеру.
- [x] Добавлены4 Flutter-проверки:Messages unavailable/failed без снятия ожидания; смена аккаунта во время redeem; чужой cooldownKey в success response с восстановлением по подтверждённому ledger без повторного списания.
- [x] Финальный полный прогон:213/213 Flutter tests,64/64 node tests; analyze22 прежних info без errors/warnings. Локальные коммиты [ci skip]. Production migration/deploy/нагрузочный тест/новая база/реальные SMS/APNs и облачные сборки не выполнялись.

Отдельная реальная QA-база Appwrite пока не настроена и тест уникальных индексов на ней не выполнен. Локально нет доступного iPhone/симулятора; Docker daemon не запущен. Не запускать новую тяжёлую среду или нагрузку на production под видом unit tests. Нагрузочную способность всей цепочки нельзя обещать по названию PostgreSQL или текущему snapshot CPU/RAM.

## Текущая задача: критические тесты и регрессии — 23.11.2026

Владелец утвердил аудит:удалить только пустую заглушку, сохранить важные тесты, улучшить хрупкие проверки и добавить критические сценарии. Облачные сборки запрещены. Ранее разрешённый push/migration/deploy пока не возобновлялся после переключения на тесты.

- [x] Удалена единственная пустая заглушка app/test/widget_test.dart (expect(true,isTrue)). Полезные сценарии не удалялись.
- [x] Убраны точное число настроек, точное число внутренних запросов страниц и устаревшее утверждение об отсутствии40:00. Остались обязательные ключи/форматы, полная пагинация без повторов/зависания, фактический остаток/переход таймера.
- [x] Усилена проверка анонимности push; новый HTTP-тест проверяет реальную отправку из /api/votes без имени/номера/скрытого data payload голосовавшего.
- [x] Добавлены9 HTTP-тестов backend (tests/invite_api.test.js):все защищённые endpoints без/с неверной/истёкшей сессией, владение чужими pass/invite, подмена userId/phone, HMAC/minimal public response, forged funnel events, AASA, баланс251 grants/150 redemptions,25+1 invite pagination, anonymous vote push, pass только для соответствующего server cooldown. Провайдеры изолированы, сервер localhost; production/SMS/APNs не вызываются.
- [x] Добавлены5 Flutter-тестов:смена аккаунта в процессе claim,410 против503, новый код во время старого запроса, offline compose queue/restart/account ownership, request-ID retry без сохранения сырого выбранного номера.
- [x] Новый regression-тест сначала воспроизвёл баг:запоздалый claim после смены аккаунта очищал код и мог продолжить refresh/redemption уже другого пользователя. Исправлено проверкой исходной сессии до/после сетевых ожиданий; код сохраняется и требует явного подтверждения.
- [x] В AGENTS.md обоих репозиториев закреплены постоянные пути тестов, команды, критические сценарии и ограничения проверок. /tmp содержит только логи, не исходники тестов.
- [x] Финальный полный прогон:209/209 Flutter tests (flutter test --no-pub),59/59 node tests; flutter analyze lib test:22 прежних info,0 errors/warnings. Новая regression-проверка сначала падала, после исправления проходит. Локальные коммиты с [ci skip]; push/деплой/облачные сборки не выполнялись в рамках текущей задачи тестов.

## Активно: приглашения, 60 минут и пропуски — 23.11.2026

Последнее указание владельца: **облачный билд НЕ запускать**. Xcode Cloud/новые TestFlight upload не выполнялись. Уже проверена локальная iOS release-сборка без подписи.

Прямая команда владельца: реализовать систему SMS/iMessage приглашений и критические тесты. Это заменяет прежние правила WhatsApp/Instagram, 40 минут и Premium без ожидания.

Утверждено:
- Ожидание после раунда — 60 минут; Premium НЕ снимает таймер.
- Приглашения с наградой только после входа по подтверждённому номеру. Гостевая офлайн-игра остаётся.
- Один новый зарегистрировавшийся друг = один пропуск пригласившему и один приглашённому. Установка отдельно не наблюдаема; зачёт по подтверждённой регистрации.
- При наличии активного таймера доступный пропуск автоматически применяется; иначе сохраняется. Баланс виден в профиле и приглашениях.
- Только системное окно SMS/iMessage, ссылка + видимый код; WhatsApp/Instagram удаляются из этого сценария. Отмена/отправка/клик не дают бонус.
- Имя и фамилия добавляются в существующий экран профиля онбординга, сохраняется ник. Firebase/SMS не сообщает имя.
- APNs пригласившему: друг <имя> активировал приглашение, начислен пропуск. Проверка и resume работают без push.
- Кнопка «Проверить приглашения» обновляет серверные данные; не утверждает, что iOS проверяет установку.
- Предлагаемый серверный лимит:100 созданий/сутки и20/час; напоминания отдельно ограничены. Один код на приглашение, один зачёт на нового пользователя, self запрещён.
- Поздний ввод до7 дней с создания аккаунта; срок приглашения30 дней. Код приоритетнее совпадения номера; при неверном коде не выбирать другого пригласившего молча.
- HMAC выбранного E.164 на сервере с отдельным ключом; номера не хранить/логировать. Существующий contact-matching SHA256 не менять.
- Использовать существующий HTTPS api.flyprox.com для /i/CODE и AASA, без нового платного хостинга.

Этапы:
- [x] Backend: отдельные таблицы/уникальные индексы, создание/claim/баланс/погашение/лимиты/события, очистка аккаунта; startup проверяет private schema/index readiness. Production миграция не запускалась.
- [x] Страница /i/CODE и AASA; atomic claim/redemption через уникальные ограничения, без предположения о транзакциях Appwrite2.7.4.
- [x] Flutter:системный Messages-мост, deep links, отдельный экран кода до телефона, локальное pending-состояние. Associated Domains на Apple App ID/подписанном профиле ещё проверить после разрешения.
- [x] Имя/фамилия и серверная синхронизация, claim после допустимого онбординга; offline phone-match retry переживает restart.
- [x] Баланс/проверка/напоминание, синхронизация таймера60мин, Premium copy/поведение. Cached old paywall_features не возвращает снятое преимущество (новый key paywall_features_v2).
- [x] Критические тесты:concurrency/retry/self/double-spend/cancel/network/restart/age gate; **205/205 Flutter tests**, **50/50 backend tests**. flutter analyze lib test:22 прежних info,0 errors/warnings. Локальная unsigned iOS release-сборка успешна (46.3MB), включая новый Swift-мост. Облачный билд/новый upload НЕ запускались.
- [x] Черновик политики/metadata/review notes и точный rollout: docs/invitations-privacy-draft.md, docs/invitations-release.md. Публичные тексты/App Privacy ещё не изменены.
- [ ] Push обоих репозиториев/шесть таблиц/деплой backend уже разрешены владельцем, но работа затем переключена на тесты и rollout пока не возобновлён. Публичная политика остаётся draft. Облачный билд не запускать по последней команде. Публичный submit не разрешён.

### Объяснения для пользователя (раздел9 ТЗ)
SMS содержит ссылку и код. Страница:«Скопировать код и установить»→установка→«Вставить код приглашения», крупный код и обычная ссылка на магазин при отказе clipboard. Экран до регистрации:«Тебя пригласили?»/вставка по нажатию/ручной ввод/пропустить; никаких автоматических чтений буфера. Не писать, что бонус уже начислен до server claim. Перед отправкой объяснить:новый друг подтверждает номер и применяет приглашение, оба получают один пропуск. Settings даёт поздний ввод до7 дней. «Напомнить» открывает тот же код по действию владельца. Метрики событий отдельные от сводного статуса; запрос landing может быть предпросмотром, установка не измеряется.

## Активно: Казахстан в App Store → TestFlight1.0.2(13)

Владелец явно попросил добавить Казахстан в разрешённые страны App Store, затем собрать билд после готовности. Уточнение: **только TestFlight**, публичный App Store review не запускать. После успешной доступности13 сделать итоговый коммит с точным заголовком «ОСНОВНОЙ КОТОРЫЙ УШЕЛ НА ПРОВЕРКУ». Это пользовательское название коммита, не утверждение о публичном submit. PATCH KAZ выполнен, повторный GET всех175 территорий подтвердил ровно7: CAN,GBR,HKG,KAZ,NZL,SGP,USA. Это storefront, не SMS policy: Firebase/PhoneRegions остаются US,GB,CA,NZ,SG,HK. Подписка не менялась. Future territories flag у приложения остаётся true.

- [x] KAZ добавлен, API read-back всех175:7 enabled,168 disabled.
- [x] Номер1.0.2+13. Код тот же, что в build12 (196 tests/analyze22info); новых функций не добавлять.
- [x] pub get / pod install успешны, Podfile.lock==Pods/Manifest.lock; владелец подтвердил, что казахстанский SMS-код не нужен, будет тестовый вход.
- [x] Archive13 (202.3с), source4885745. Flutter export No Accounts/No Distribution; xcodebuild export с ASC API auth успешен. Экспортированный IPA: bundle/version/build13, codesign deep/strict, production APNs, debug=false, encryption=false; billing key/Firebase callback/username screen подтверждены, photo permission отсутствует.
- [x] Upload13: altool exit0 / UPLOAD SUCCEEDED, delivery8c073399-9d38-43db-ab4e-f036331f0234, завершён23.11.2026 01:26:42 Asia/Bangkok. Перед успешным завершением были сетевые retransmits/разрывы; повторный независимый upload не запускался.
- [x] Build8c073399-9d38-43db-ab4e-f036331f0234 = VALID / IN_BETA_TESTING. Внутренняя группа060e4223-2034-457e-aa16-859c63c582f4 содержит13, en-US What to Test записан и перечитан.
- [x] После доступности13 — итоговый snapshot-коммит с точным заголовком владельца «ОСНОВНОЙ КОТОРЫЙ УШЕЛ НА ПРОВЕРКУ». Только TestFlight; публичный App Store submit не выполнялся.

## Активно: TestFlight 1.0.2(12)

Команда владельца: «делай билд». Включить contact-only voting, userNNNNNN и редактируемый ник после контактов, изоляцию тестов. Пол не добавлялся. Исходные исправления: 54214ff. ASC проверен: последний номер11, следующий12 свободен.

- [x] Исходный код проверен:196 Flutter tests, analyze22 info без errors/warnings.
- [x] Номер повышен до1.0.2+12; Flutter3.44.4, Dart3.12.2.
- [x] pub get / pod install успешны, Podfile.lock==Pods/Manifest.lock; локальный billing key отличается от Git placeholder, значение не выводилось.
- [x] Archive12 (221.2с), source b988c32. Стандартный Flutter export: No Accounts/No Distribution; xcodebuild export с ASC API auth успешен. IPA: codesign deep/strict, production APNs, get-task-allow=false, encryption=false, billing key/Firebase callback/username screen подтверждены boolean-проверкой, photo permission отсутствует.
- [x] Upload12 успешен (altool exit0/UPLOAD SUCCEEDED), delivery39956a67-21fd-445f-981d-ad44659db223.
- [x] Apple VALID / IN_BETA_TESTING; build39956a67-21fd-445f-981d-ad44659db223. Внутренняя группа060e4223-2034-457e-aa16-859c63c582f4 содержит12, en-US What to Test записан и перечитан. Upload завершился23.11.2026 00:24:11 Asia/Bangkok; VALID подтверждён~00:26:50. Новый бинарник готов для внутренних тестировщиков. Публичный submit не выполнялся.

## Активно: проверка пуша, только чужие контакты и изоляция тестов (23.11.2026)

Последняя команда владельца: выполнить этот план, самым первым действием отправить тестовое push-уведомление для проверки на iPhone. Профиль по умолчанию — user + случайные цифры; сам игрок не должен добавляться в варианты голосования. Это заменяет прежнее правило self + 3 friends и автоматическое имя Michael, включая деморежим.

- [x] Первым: тестовый APNs push 6b032046000d3fd67306 → sent, deliveredTotal=1, errors=0. Владелец подтвердил получение на iPhone 23.11.2026. Выбрана новейшая из трёх iOS-регистраций одного аккаунта.
- [x] Голосование: четыре выбранных контакта, без автоматически добавленного игрока, во всех путях (server session / cached server bank / offline reserve / resume). Ник профиля userNNNNNN сохраняется; старые автоматические Michael/You мигрируют, выбранный настоящий контакт Michael не удаляется.
- [x] Добавить ник после контактов и перед push prompt: редактируемый userNNNNNN, сохранение в локальном профиле, валидация, возобновление незавершённого шага после перезапуска. Ник не является SMS-аутентификацией и не добавляется в карточки.
- [x] Убрать общий изменяемый router из тестовых запусков: отдельный router на каждый тест с корректным dispose.
- [x] Собрать общие тестовые подмены secure storage и auth persistence, чтобы настройки saveToken/savePhone не забывались.
- [x] Проверить ввод OTP через controller + Verify, возврат назад и повторный вход; проверять видимые экраны, включая сохранение состояния на том же маршруте.
- [x] Полный Flutter test run и analyze; записать реальные результаты и оставшиеся ограничения.

Результат: 196/196 Flutter tests passed; analyze — 22 прежних info, без errors/warnings. Новые проверки: ник/валидация/профиль, resume после нового router, порядок username→push, 320px и keyboard/x2, OTP back/reopen, отсутствие игрока в intro/main/resume/server cards. Изменения пока локальные; новый Archive/TestFlight не собирался. Вопросы по-прежнему приходят с сервера, cache и встроенный первый offline fallback сохранены.

## Активно: исправления после тестирования build 10 → build 11

Последняя команда: закончить исправления, сразу собрать и загрузить; записать контекст для нового агента. Предыдущая пауза отменена. User wants deadline before25th; не добавлять несогласованные фичи.

- [x] Legacy Premium result больше не пропускает общий age gate; миграционные тесты.
- [x] Full contacts list сразу + search, limited subset + Choose more; max10 убран, total50, minimum4.
- [x] Foreground APNs presentation options включены; provider/token/payload проверены. Видимость на iPhone ещё требует подтверждения.
- [x] Фото UI/SDK/permission удалены, 🙂; legacy app-owned image cleaned, gallery untouched.
- [x] guest_enabled и example_names_enabled позволяют скрыть оба guest exits и examples с сервера; tests.
- [x] Home redesign blue/white завершён;320px/large text tests, cooldown preserved.
- [x] ASC1.0.2 draft texts/App Information/review/demo fields записаны и перечитаны. Build пока unattached,9 screenshots требуют сверки, App Privacy UI не подтверждён.
- [x] Account erasure pagination/provider cleanup и client false-success исправлены;33 backend tests. Реальных prod DELETE не делали.
- [x] Final188 tests/analyze22info/Swift; source6ff59d3 pushed. Backendc102de6 deployed, active, health200.
- [x] Archive/export/upload11 успешны; codesign/production APNs/billing/Firebase callback проверены, photo permission/image_picker отсутствуют в IPA. Deliveryd8bbdc46-b2a1-45d2-8b41-083f192839ac.
- [x] Apple VALID/IN_BETA_TESTING; IDd8bbdc46-b2a1-45d2-8b41-083f192839ac, группа/notes проверены, draft1.0.2 build11 attach read-back.
- [x] Notion Privacy/Terms/Support/marketing и local policy обновлены после доступности11; final IDs/checks записаны.
- [ ] До публичного submit: App Privacy UI, актуальные screenshots, native iPhone contacts/SMS/StoreKit/push проверки. Публичный submit не выполнен.

## Текущий выпуск: новый onboarding → build 10

Последняя команда владельца: продолжать по плану, **в конце собрать билд**. Прежняя пауза отменена. Публичный App Store submit не входит в задачу.

- [x] Intro → телефон → SMS-код → возраст → контакты. Гостевой выход явно пропускает авторизацию, но не возраст. Автоматическое подтверждение номера тоже ведёт на возраст. Back/Done/skip не должны открывать игру до допуска.
- [x] Возраст без preselection: 12 or younger, 13…18+. Точный возраст не сохраняется и не отправляется; локально хранится outcome. Under 13 блокирует этот run; cold launch повторяет intro и phone/age. Это declared age, не гарантия COPPA.
- [x] Firebase для входа до возраста, Superwall/вопросы после 13+. Публичные тексты intro могут обновляться без auth/SDK; cache доступен сразу.
- [x] Убраны ручной ник, ручные имена и Choose your friends. Контакты: минимум 4, счётчик, выбранные labels; до 10 за один picker, до 50 всего. Никакой автоматической клавиатуры на контактах. OTP прокручивается и подстраивает ширину кода под маленький экран.
- [x] Michael вместо wish в примерах; остальные sample names сохранены. Live content_items содержит example_names_enabled/button/description, всего 22 ключа; false скрывает кнопку и пояснение. Обновление без нового iOS-бинарника после установки build 10.
- [x] Push prompt после контактов для signed-in users; оба действия ведут Home. Два явно запрошенных теста APNs sent, deliveredTotal=1, errors=[]; показ на устройстве пользователь ещё не подтвердил.
- [x] IMG_1320: свежая проверка подписки/понятный status; временная ошибка не стирает известную подписку. Версия из Bundle, hardcoded build3 удалён.
- [x] Firebase/phone picker/App Store только US,GB,CA,NZ,SG,HK; US default. Флаг future new territories у Apple пока true, см. docs/phone-regions-and-storefront-plan.md.
- [x] Flutter 174/174; analyze 22 прежних info, без errors/warnings. Backend 22/22. Native typecheck прошлых изменений пройден; Archive проверит итоговую компиляцию.
- [x] Source eceda21 запушен. Archive 1.0.2(10), export через ASC signing auth после штатного No Accounts, codesign/production APNs/Firebase callback/billing key проверены. В IPA подтверждены новые ключи/экран/Michael. Upload успешен; build f45c9353-4fa3-4c1b-867c-b0ec22addc8d = VALID/IN_BETA_TESTING, внутренняя группа и What to Test проверены, beta review notes записаны.
- [x] После доступности build 10 обновлены Notion Privacy/Terms/Support/marketing и локальная политика. Нативные Contacts UI, реальный SMS/StoreKit и фактическое появление push на iPhone требуют проверки владельцем; не выдавать SDK/widget/серверные статусы за физический QA.

## Новая задача: контакты iOS 18+, build 9

- [x] Пользователь попросил новый picker вместо старого без поиска. Официальная документация и SDK проверены: contactAccessPicker работает только при .limited, значит нужен Contacts permission flow.
- [x] Native bridge: permission/limited/full/denied, настоящий contactAccessPicker и ContactAccessButton, постоянный поиск, name-only browsing, phone reads только по подтверждённым IDs, legacy fallback 15–17. Plugin cache и backend не менялись.
- [x] Swift typecheck native bridge + AppDelegate; 156/156 Flutter tests, analyze 22 info без errors/warnings; Info.plist и Xcode project lint проходят.
- [x] Source commit e8cc97b запушен. Privacy/Support в Notion и local review/privacy notes обновлены под новое разрешение.
- [x] Archive 1.0.2(9), export, IPA checks, upload, VALID/IN_BETA_TESTING подтверждены до запрета новых сборок. Notes отдельно при следующей подготовке выпуска.
- [ ] Зафиксировать финальный статус и docs. Нативный UI на реальном iPhone требует проверки владельцем после установки.

## Текущий выпуск: TestFlight 1.0.2 (обновлено 22.11.2026)

Пользователь разрешил исправления, коммиты/push без force, деплой backend, Archive и загрузку в TestFlight. Публичный App Store submit отдельно не выполняем. Язык пока English, автопереключение по клавиатуре отменено пользователем.

- [x] API App Store Connect работает; ключи в игнорируемом `.env`, p8 вне репозитория. Реальный Superwall key только локально, skip-worktree.
- [x] Билд 6 загружен, VALID/IN_BETA_TESTING. Билд 5 expired из-за исправленного Firebase callback crash.
- [x] Билд 7 (commit 90a02b1): исправлены клавиатура/переполнение friends, ввод телефона, выход из зависшего входа. 146 тестов. Archive/IPA подписан, проверен и загружен. Delivery/build `ec5f9730-e806-4596-9a13-2d2499c8d66f`, VALID и IN_BETA_TESTING подтверждены.
- [x] Firebase: тестовый номер +16505551234 / 123456 реально настроен. Актуальный SMS allowlist — US,GB,CA,NZ,SG,HK по последнему выбору пользователя. Гостевой режим доступен без SMS.
- [x] Backend на `s-prod`: questions API с cursor pages, нет first-500 cutoff; candidates ограничены self/выбранными matched contacts, чужой winner запрещён. Skip не создаёт ложный голос/пуш. Тест на 10000 вопросов, JSON import с валидацией/dry-run. Коммиты до 3d8603a включительно задеплоены; /health и /api/questions — 200. Полный живой банк: 536 вопросов (512 main + 24 intro), 3 cursor pages; проверен Dart User-Agent.
- [x] Приложение build 8: выбранные локальные имена на карточках, сопоставление account ID отдельно; backend bank для гостя с полным offline cache; встроенный резерв только для первого offline запуска. Добавлен single-contact fallback Find one contact, ранее выбранные контакты не затираются при добавлении следующих.
- [x] Финальный build 8 (source e748467): 152/152 Flutter tests, анализ 22 info без errors/warnings; backend 22/22. Archive 200.5с, API-auth export успешен, IPA codesign/APNs/billing/Firebase callback/encryption flag проверены. Delivery/build c9636727-9c80-4eb0-a762-e24292fc799c: VALID и IN_BETA_TESTING, 22.11.2026. Билд 8 доступен для установки.
- [x] В Notion обновлены Privacy, Terms, Support, marketing. Доступ уже авторизован: дополнительный MCP/SSE/OAuth не требовался. Политика явно разделяет предыдущие local-only версии и online 1.0.2/TestFlight; child pages и Tally embed сохранены.
- [x] Созданы `docs/app-review-notes-1.0.2.md`, `docs/app-privacy-checklist-1.0.2.md`, `docs/server-controlled-features.md`; обновлён `docs/privacy-policy-update.md`. Backend AGENTS.md создан, с env/deploy/Firebase/правилами данных.
- [x] Финальный статус, инструкции и документы сохранены; commit/push завершает этот этап. Билды 6/7 оставлены для сравнения, 5 expired. App Privacy публично не публиковалась, App Store submit не выполнялся.

Проверка push infrastructure: device_tokens=1, выбранных contact_hashes=4, APNs target соответствует provider/token (1/1). Это подтверждает регистрацию и связь, не фактическую доставку на экран iPhone. Beta What to Test для 7 и 8 обновлено по API.

### Что нельзя выдавать за завершённое

- App Privacy checkbox questionnaire в Connect не прочитана/не изменена: публичного поддерживаемого API нет. Подготовлен точный чеклист, нужен веб-интерфейс. Не менять live 1.0.1 labels на новую версию преждевременно.
- Реальные SMS, доставка push между двумя разными аккаунтами, нативный поиск в picker и StoreKit purchase требуют проверки на iPhone. Find one contact открывает отдельный single picker; собственная поисковая строка внутри системного multi-picker не внедрялась.
- Перед публичным review: надёжное account deletion требует доработки (best-effort client, ограниченные выборки server, Firebase/Superwall erasure). Не обещать полное удаление или гарантированное одобрение Apple. Это не блокирует выдачу внутреннего TestFlight для проверки.

## История прежних этапов

Сведения ниже исторические; при расхождениях приоритет у текущего статуса выше.

Очередь задач после сессии 21.11. Контекст сессии — в `AGENTS.md`, раздел «Сессия 2026-11-21».

## Готово (кратко)

- Бэкенд на проде: вход Firebase, хэши контактов + матчинг, удаление аккаунта, девайсы, триггер пушей при голосе. `https://api.flyprox.com` отвечает.
- Приложение: вход по SMS + гость, синк контактов, гейт 13+, пуш-промпт/токены/слушатель, capabilities, plist. Всё запушено.
- П.1 APNs (22.11): пользователь создал провайдер `Flyprox Production` (`6b01db0200007977bfd1`, apns, enabled) и расширил скопы ключа. Тестовый пуш через API ушёл, но упал с `No valid recipients`: пуш-таргетов пока ноль (есть только 2 авто-SMS-таргета). Нужны `APNS_PROVIDER_ID` в прод-`.env`, деплой, запуск на девайсе и повторный тест.
- П.2 Тексты с сервера (22.11): таблица `content_items` создана и засидирована (19 ключей), `GET /api/content` отдаёт карту (проверено локально: 19 ключей). Приложение: `ContentService` (дефолты в коде, кэш 12ч, never-throws) + переведены инвайт, пейволл (кроме legal-блока — он остался в коде ради ревью), апселлы, blocked-экран, URL поддержки, флаги `guest_enabled`/`contacts_enabled`. Тесты: бэкенд 14/14, приложение 141/141. Playwright: серверные тексты и 5 страниц онбординга отрендерились в браузере; без сервера — дефолты, без падений.
- П.3 Онбординг данными (22.11): страницы из ключа `onboarding_pages` (emoji/заголовок/подзаголовок, иллюстрации циклятся), fallback — 3 зашитые страницы, счётчик починен (`N / total`). Widget-тест с подменой на 5 страниц зелёный.
- П.4 Вопросы с сервера (22.11): `ServerRoundSource` (онлайн + вход → сессия и голоса на сервер; офлайн/гость/ошибка — локально). Экран голосования маппит серверные вопросы, голоса дублируются в `POST /api/votes` (пуши фаерятся сервером). Бэкенд стал отдавать `emoji` вопроса. Обе ветки покрыты тестами (юнит + виджет).

## Очередь

### 5. Деплой бэкенда на прод — выполнен агентом

- Рабочий доступ: `ssh s-prod` (настроен ключ id_ed25519_github). Прод `/home/myuser/projects/flyprox_backend` обновлён до f9547f3, setup/seed выполнены, APNS_PROVIDER_ID настроен, сервис перезапущен. Зависимости не менялись.
- Проверка: `GET https://api.flyprox.com/api/content` отдаёт 19 ключей; `/health` — 200. Возраст 13–19 согласован с гейтом приложения; тесты бэкенда 15/15.

### 6. E2E на TestFlight (два живых айфона)

- Вход по SMS тестовым номером, контакты → совпадение, голос → пуш на втором устройстве, удаление аккаунта чистит сервер.
- Пуши не тестируются на симуляторе; TestFlight идёт через продакшн APNs.
- После регистрации девайсов: повторный тестовый пуш через API (сказать агенту).

### 7. Сабмит серверной версии

- Декларации: добавить Contacts, Phone Number, User ID, Name (все App Functionality / Yes / No) + Device ID; Superwall-строки не трогать. Только под сборку с сервером, не раньше.
- Review Notes: тестовый номер, проход гейта (13+), объяснение контактов (пикер → хэши → матчинг → удаление).
- Черновик `docs/privacy-policy-update.md` УСТАРЕЛ (описывает локальную игру без загрузок) — переписать с учётом сервера (хэши, телефон, токены) и абзац в Notion-политику; ограничить iOS-ключ Firebase по Bundle ID в Cloud Console.

## Оставшиеся действия владельца и живые проверки

1. Установить готовую сборку TestFlight на два iPhone и проверить SMS-вход, контакты, голос, реальное получение push и удаление аккаунта. Эти действия требуют живых устройств.
2. При отдельном сабмите в публичный App Store согласовать декларации/политику и выполнить ограничения Firebase-ключа (п.7). Загрузка в TestFlight сама по себе не обновляет эти публичные сведения.
3. Если Apple запросит 2FA, принятие соглашения или системное разрешение Xcode — подтвердить в аккаунте/на Mac. ASC API-ключ уже настроен, сборки/логи/загрузка выполняются агентом.

Версия 1.0.1 уже READY_FOR_SALE по ASC API; старое ожидание ревью от 20.11 неактуально.
