# Flyprox — инструкции агенту

Корень: `/Users/amanyessen/NEW/poll-main`. Flutter-приложение — `app/`, пакет `flyprox_app`. Локальная игра без бэкенда, аккаунтов, Firebase и платных функций. `AGENTS.md` — единственный источник инструкций; `CLAUDE.md` ссылается на него. Поведение сверять с кодом, устаревшие инструкции исправлять вместе с изменениями.

## Основные пути

| Что | Путь от корня |
|---|---|
| Запуск и маршруты | `app/lib/main.dart`, `app/lib/app.dart`, `app/lib/router/app_router.dart` |
| Игра и профиль | `app/lib/services/local_game_service.dart`, `app/lib/providers/user_provider.dart` |
| Экраны / тесты | `app/lib/screens/`, `app/test/` |
| iOS workspace / scheme | `app/ios/Runner.xcworkspace` / `Runner` |
| Xcode Cloud: установка Flutter и Pods | `app/ios/ci_scripts/ci_post_clone.sh` |
| Логотип / заставка с музыкой | `app/assets/images/flyprox-logo.png`, `app/assets/animations/flyprox-intro.mp4` |
| Дизайн вне сборки | `design-reference/ppm/` — не включать в assets |
| Ссылки поддержки и политик | `app/lib/utils/constants.dart`; страницы в Notion, публичный доступ проверять без входа |

## Запуск и проверки

Команды из `app/`:

```bash
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080
flutter analyze lib test --no-pub
flutter test --no-pub
```

Локальный интерфейс проверять в Chrome. Xcode, iOS Simulator и macOS-сборку запускать только по прямому запросу. Проверки выполнять по задаче; результат подтверждать выводом команд. После изменения assets полностью перезапускать Flutter; веб-путь ресурса начинается с `/assets/assets/`.

## iOS и TestFlight

- Проверенная среда: Flutter **3.44.4** локально и в CI, Dart **3.12+**, Xcode/iOS SDK **27.2**. Минимальная iOS **15.0** означает поддержку 15 и новее.
- Bundle ID: `com.flyprox.flyproxApp`. Версия: `app/pubspec.yaml`; номера облачных сборок проверять отдельно.
- Трейн 1.0.0 закрыт (версия была одобрена раньше): новые сборки только с повышением версии, сейчас 1.0.1+3. Подписка `premium_pro_weekly` ($6.99/нед) создана в Connect и подаётся вместе с версией.
- Оплата: Superwall SDK (`superwallkit_flutter`), свой пейвол + прямые покупки; entitlement `pro`, dashboard app 60567. Ключ: в репо плейсхолдер (чистые сборки компилируются, биллинг выключен); реальный только локально + skip-worktree, в чат и git не тащить. TestFlight — только локальный Archive.
- Ревью (статус на 2026-11-20): версия 1.0.1 + группа + `premium_pro_weekly` поданы одним пакетом, ждём решения. Первая подписка подаётся только вместе с версией; в черновике должны лежать версия + группа + подписка (иначе ошибка «New subscription groups must be submitted with...»).
- Best practices подписки: пейвол показывает название/срок/цену/автопродление/Restore/Terms/Privacy; название товара в Connect = названию на пейволе; скрин пейвола + пошаговые примечания + Sandbox-аккаунт в Review Information; App Privacy отражает сбор SDK (Purchases, Identifiers, Usage Data); договор Paid Apps активен.
- Пути Superwall: приложение → Settings → General (Bundle ID, Team ID); Settings → Keys (публичный iOS-ключ); Settings → Revenue Tracking (ключи Apple, уведомления); Products (товар + привязка к `pro`, дефолтный entitlement создавать не надо). TestFlight = песочница: работает со статусом Ready to Submit; недельная подписка продлевается ~3 минуты.
- Перед локальным Archive: из `app/` выполнить `flutter pub get`, затем `cd ios` и `pod install`. Открывать **Runner.xcworkspace**. `Pods/Manifest.lock` должен совпадать с `Podfile.lock`; не удалять lock-файлы для устранения ошибки.
- Проверка компиляции из `app/`: `flutter build ios --release --no-codesign`. Результат: `app/build/ios/iphoneos/Runner.app`; эта сборка не подписана для установки.
- Подписанная отправка: Xcode → **Product → Archive → Distribute App → App Store Connect → Upload**. **Validate App** только проверяет. Стандартный путь архива Flutter: `app/build/ios/archive/Runner.xcarchive`; архивы Xcode — Organizer, обычно `~/Library/Developer/Xcode/Archives/`.
- Xcode Cloud: первичное подключение через Xcode, затем управление через App Store Connect. Для TestFlight нужен **Archive**, подготовка **TestFlight and App Store** и post-action для раздачи группе. Успешный **Build** сам по себе загрузку не подтверждает.

## Правила работы

- Сначала `git status`; сохранять чужие правки. Читать файлы точечно: без общего сканирования проекта, PDF, скриншотов, `app/build/`, `.dart_tool/` и сгенерированных локализаций, если задача этого не требует. `app/lib/data/quiz_questions.dart` — только для задач с вопросами.
- Зависимости обновлять **по одной**, изучая официальную миграцию; после каждого шага — анализ, тесты и запуск. Небольшие отставания не обновлять без необходимости. Версии брать из `pubspec.lock`, ограничения — из `pubspec.yaml`.
- GoRouter 18 / Pinput 7 требуют миграции Material; текущие провайдеры используют `flutter_riverpod/legacy.dart`. Secure Storage 11 требует предварительной миграции данных через 10; одного локального запуска 10 недостаточно. Permission Handler 13 требует Android API 37 и нового AGP; Android SDK на этом Mac отсутствует.
- Делать узкие изменения без лишних зависимостей и документов. Секреты, `.env`, токены и `.p8` не просматривать, не выводить и не коммитить; ключи не просить присылать в чат.
- Значимые изменения коммитить отдельно в `main`, репозиторий `amanvelikiigmailcom/poll-main`. Push и внешние публикации — с явным разрешением пользователя; уже полученное разрешение не спрашивать повторно. Force-push запрещён.

## Поведение, которое нужно сохранить

- Играть можно с ником и минимум четырьмя именами участников либо с примерами; реальные имена и фото необязательны. Онбординг показывается один раз, повтор — Settings → Replay intro. Навигация: Home · Quiz · Profile · Settings. Иконки таб-бара — единый набор Phosphor (4 пары regular/fill, `app/lib/theme/navigation_icons.dart`), локальные поднаборы шрифтов и MIT-лицензия — `app/assets/fonts/phosphor/`; выбранная вкладка синяя, без отдельного круга у Quiz.
- Раунд — 12 вопросов. Reveal доступен в конце и показывает только собственные локальные ответы; входящих голосов других людей нет. После раунда — сохранённый таймер на 40 минут; переходы в игру не обходят его. Нажатие WhatsApp/Instagram снимает таймер независимо от отправки сообщения; отправка добровольная. Instagram открывает `instagram://sharesheet?text=Hi%21` с выбором получателей и текстом `Hi!`, без сайта и копирования в буфер; маршрут недокументированный, проверен пользователем на iPhone.
- Аватар, текущий и последний завершённый раунд хранятся локально; Reset game удаляет их и остальные игровые данные, очищает кэши профиля, сохраняя настройки эффектов и завершение онбординга. Оригинал фото в галерее не изменять. Report a question готовит письмо с вопросом и ID без имён и ответов; отправляет его сам пользователь.
- Не обещать анонимную соцсеть, шифрование SharedPreferences или подтверждённое соответствие GDPR/COPPA. Для политики есть неопубликованный проект `docs/privacy-policy-update.md`; параметры видео — `docs/intro-video.md`.

## Сессия 2026-11-21: сервер, вход, пуши (статус работ)

Очередь оставшихся задач — в [PLAN.md](PLAN.md), смотреть его первым делом.

**Бэкенд `flyprox_backend` (запушен в `main`, работает на проде):** `POST /api/auth/firebase` (проверка ID-токена через Firebase Admin, своя сессия), `POST/DELETE /api/contacts` (хэши `sha256("flyprox-contacts-v1:<E.164>")`, кап 50/запрос, матчинг отдаёт только displayName), `DELETE /api/users/me`, `POST/DELETE /api/devices`, пуш при первом голосе voter→winner в раунде (анонимный текст). Таблицы: `contact_hashes`, `phone_index`, `device_tokens`. Тесты `node --test` 8/8. `scripts/setup.js` идемпотентен и сначала сверяет существующие колонки (Appwrite на повторное создание отвечает 400 `column_limit_exceeded`, а не 409). Таблица `profiles` упёрлась в лимит колонок — новые персонифицированные поля класть только в отдельные таблицы. Сырые номера сервер не хранит.

**Приложение (запушено, тесты 119/119, сборки web + iOS зелёные):** вход по SMS через Firebase + гостевой режим (`phone_auth_*`, экраны `auth/`, `pushReplacement` на промпт); синк контактов (`contact_sync_service`, E.164 через `phone_numbers_parser`, регион из локали); гейт 13+ перед `/premium` (`age_gate_service` в keychain, крутилка 10–18+ без дефолта-прохода, blocked-экран без пути назад); пуши (`push_service` + `FirebasePushDriver` только для APNs-токена, `push_prompt_screen`, `push_listener` в shell); удаление стирает и сервер (best-effort, таймаут 5с). Зависимости ставились по одной: `flutter_native_contact_picker` 0.0.13 (пин без `^`), `firebase_core`, `firebase_auth`, `phone_numbers_parser`, `firebase_messaging` (резолвнулся 15.2.10), `flutter_secure_storage_platform_interface` (dev, для тестов). Capabilities: `Runner.entitlements` (production) + `Runner-Debug.entitlements` (development), `CODE_SIGN_ENTITLEMENTS` в трёх конфигах таргета Runner, `UIBackgroundModes` remote-notification. `GoogleService-Info.plist` закоммичен (исключение с одобрения владельца: ключ публичный по докам Firebase, иначе Xcode Cloud файл не получит); ограничить ключ по Bundle ID в Cloud Console.

**Инфра:** прод `myuser@2.135.146.185:2222` (команды SSH — в профилях iTerm2). Бэкенд — systemd user-сервис `flyprox-backend` (`Linger=yes`), публичный URL `https://api.flyprox.com` через Cloudflare Tunnel (`flyprox-tunnel.service`, DNS CNAME в зоне `flyprox.com`). Appwrite 2.7.4 self-hosted, проект `flyprox`, консоль `http://2.135.146.185/`. Firebase-проект `flyprox-2d01b`, тестовый номер `+1 650-555-1234` / код `123456`. Несекретные ID: APNs Key ID `4UK954WJMA`, Team ID `5QG4KFTZNJ`. Секреты живут только так: прод-`.env` и ключи (`flyprox-service-account.json`, `AuthKey_*.p8`) в `~/.config/` с правами 600, в git/чат/вывод команд не попадают никогда; использовать только внутри команд.

**Решения (не менять без пользователя):** пуши — отправка через Appwrite Messaging + APNs (таргетинг/условия позже), никаких кастомных APN-библиотек (`apn` через npm не ставится — git-зависимость заблокирована); Firebase — только SMS-вход (FCM бесплатен, но лишний след не нужен); тексты/контент — свой бэкенд, не Firebase Remote Config (платный сверх 100K запросов/день); гостевой офлайн-режим сохраняется всегда; на сервер — только хэши выбранных контактов, никогда вся книга и никогда сырые номера; возрастной порог ≤12 — COPPA, колесо гранулярное; push утверждён для `poll-main` и `flyprox_backend`, спрашивать повторно не надо.

**Ловушки тестов (проверено, не наступать):** чтение `flutter_secure_storage` без мока в widget-тестах виснет навсегда — ставить `test/fakes/fake_secure_storage.dart` в `setUp`; `go_router.push()` на top-level роутах возвращает значение провайдера к базовому — после push ассертить виджеты, не путь; `go()` на тот же location переиспользует стейт страницы — возвраты из флоу входа делать через `pop`, шаг выставлять до `push`; центр `Pinput` не хит-тестится — код вводить через `controller.text` + кнопка Verify; незастабанные mocktail-методы бросают — стабать `saveToken`/`savePhone`; `flutter test` гонять целиком, focused-прогоны лгут про shared-состояние (`appRouter` глобален).
