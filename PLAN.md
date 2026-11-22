# Flyprox — план работ (обновлено 2026-11-22)

## Новая задача: контакты iOS 18+, build 9

- [x] Пользователь попросил новый picker вместо старого без поиска. Официальная документация и SDK проверены: contactAccessPicker работает только при .limited, значит нужен Contacts permission flow.
- [x] Native bridge: permission/limited/full/denied, настоящий contactAccessPicker и ContactAccessButton, постоянный поиск, name-only browsing, phone reads только по подтверждённым IDs, legacy fallback 15–17. Plugin cache и backend не менялись.
- [x] Swift typecheck native bridge + AppDelegate; 156/156 Flutter tests, analyze 22 info без errors/warnings; Info.plist и Xcode project lint проходят.
- [x] Source commit e8cc97b запушен. Privacy/Support в Notion и local review/privacy notes обновлены под новое разрешение.
- [ ] Archive 1.0.2(9), export, IPA checks, upload, VALID/IN_BETA_TESTING и notes.
- [ ] Зафиксировать финальный статус и docs. Нативный UI на реальном iPhone требует проверки владельцем после установки.

## Текущий выпуск: TestFlight 1.0.2 (обновлено 22.11.2026)

Пользователь разрешил исправления, коммиты/push без force, деплой backend, Archive и загрузку в TestFlight. Публичный App Store submit отдельно не выполняем. Язык пока English, автопереключение по клавиатуре отменено пользователем.

- [x] API App Store Connect работает; ключи в игнорируемом `.env`, p8 вне репозитория. Реальный Superwall key только локально, skip-worktree.
- [x] Билд 6 загружен, VALID/IN_BETA_TESTING. Билд 5 expired из-за исправленного Firebase callback crash.
- [x] Билд 7 (commit 90a02b1): исправлены клавиатура/переполнение friends, ввод телефона, выход из зависшего входа. 146 тестов. Archive/IPA подписан, проверен и загружен. Delivery/build `ec5f9730-e806-4596-9a13-2d2499c8d66f`, VALID и IN_BETA_TESTING подтверждены.
- [x] Firebase: тестовый номер +16505551234 / 123456 реально настроен. SMS allowlist — только US по явному выбору пользователя. Гостевой режим доступен без SMS.
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
