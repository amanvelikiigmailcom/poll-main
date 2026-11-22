# Flyprox 1.0.2 — Review Notes и проверка перед отправкой

Подготовлено 22.11.2026. Это отдельный файл для новой серверной версии. Старые примечания 1.0.1, где всё называлось локальным, для неё не подходят. Загрузка в TestFlight не является отправкой версии на публичное ревью.

## English text for App Review

Этот блок уже сохранён и перечитан через API в App Store Connect → Flyprox → iOS 1.0.2 → App Review Information. Версия остаётся PREPARE_FOR_SUBMISSION, выпуск MANUAL. Финальная сборка не прикреплена: по последней команде владельца новые Archive/upload приостановлены до завершения исправлений. Тексты ниже описывают подготовленный исходный код следующего build 11, не старую сборку 10.

REVIEW ACCESS
Phone: +1 650-555-1234
SMS verification code: 123456
This is a configured Firebase test number; it sends no real SMS and needs no access to a personal phone. US/+1 is the default country code. Core guest play is also available without sign-in.

APP AND UPDATE
Flyprox is a 13+ entertainment quiz, not a chat or photo-sharing app. It has no in-app messaging, public posting feed or photo upload. The profile uses a built-in smiley. Version 1.0.2 adds real optional Firebase phone authentication, backend accounts, selected-contact matching, online votes and APNs notifications; it is not a local-only app. Apple handles optional Premium Weekly purchases; Superwall manages subscription access.

REVIEW PATH
1. Complete or skip the intro. Enter the test phone and code above, or tap Continue without login.
2. Answer the unselected age question (12 or younger, 13, 14, 15, 16, 17, 18+). An under-13 answer blocks contacts, gameplay and subscriptions for that run. Exact selected age is not retained or uploaded; a local eligibility outcome/check time is stored. Phone/account verification precedes this question; subscription initialization follows an eligible answer.
3. Choose at least four contacts, or tap Try with example names. There is no manual nickname/participant-name entry in onboarding. In the contact selection screen, tap Add to confirm the selection, then Continue.
4. Signed-in users may see the optional notification explanation after setup. Enable notifications opens the iOS prompt; Skip/denial is supported. Play a 12-question round from Quiz. Shuffle and Skip are available. Reveal shows this device’s saved answers, not the identity of other voters.
5. Open Premium or Settings > Premium to inspect the weekly auto-renewing subscription, localized price, terms, Restore purchases, Terms and Privacy links. Use Apple sandbox purchasing during review.

PERMISSIONS AND DATA
Contacts: requested only after tapping a contacts action, to choose quiz participants and match selected friends. iOS 18+ supports limited or full access. Full access displays authorized names with search; limited access displays permitted names with an option to choose more. Only confirmed entries become participants (up to 50 total). Browsing reads names locally; phone fields are fetched for confirmed selections. On iOS 15–17 the one-time picker remains available. The example path needs no Contacts access.

When signed in, only confirmed labels and hashes of selected phone numbers are sent for friend matching; the full address book and raw selected-contact numbers are not uploaded. Selecting a contact sends no invitation. A vote push needs a matched different registered account, registered device and notification permission. The same test number on two devices is one account, so it cannot simulate two players. Phone/Firebase processing occurs before the age response. Phone sign-in regions: US, UK, Canada, New Zealand, Singapore and Hong Kong.

Notifications: optional alerts when matched friends vote; the app asks only after Enable notifications. No camera, photo-library, microphone, location or tracking permission is requested by this quiz flow. External WhatsApp/Instagram sharing opens an external app and is user-controlled.

Question reporting prepares an email with the question/ID, excluding participant names and answers. The user decides whether to send it. Settings contains privacy/support links and Delete account.

## Проверки до публичного сабмита

- Не копировать этот файл целиком в Connect: английский блок — основа notes, внутренние ограничения ниже — рабочая проверка.
- Убедиться, что выбран именно финальный билд с исправлениями, а не 1.0.2(5), который отозван. Проверить фактические build number, VALID и внутреннюю группу.
- На живом iPhone: реальный US SMS-вход, тестовый номер, отмена входа, повторная отправка, восстановление после сети, контакты, отказ от пушей, покупка/Restore. Для доставки пуша нужны два разных аккаунта, а не один номер на двух устройствах.
- Подготовить App Privacy под фактическую новую версию; таблица в `app-privacy-checklist-1.0.2.md`. Нельзя скрывать сбор SDK или называть хэши анонимными.
- Исправления удаления аккаунта pending build11: клиент требует deleted:true перед local wipe и сохраняет credential/progress при ошибке. Сервер дренирует страницы до конца, удаляет owned/incoming votes, rounds, contact hashes/index, APNs targets/avatar, Firebase identity по авторитетному номеру, Appwrite identity/profile/sessions. Current session удаляется последней.33 fake-adapter tests пройдены; реальные prod-аккаунты ради теста не удалялись. Отдельную очистку Superwall analytics/Apple purchase records не выдавать за выполненную: subscription управляется Apple, provider-data requests — через поддержку.
- Если социальные функции расширятся: аудит требований к пользовательскому контенту, жалобам/блокировке и модерации. Не писать, что эти механизмы уже существуют, если фактически есть только email-report вопроса.
- Не менять публичные notes уже выпущенной 1.0.1 на описание новой версии. Добавить новые notes в редактируемую новую версию при отдельном сабмите.
- Firebase API key: отдельно проверить ограничения по официальной инструкции Phone Auth и оба пути — silent APNs и reCAPTCHA. Не ограничивать ключ только Bundle ID вслепую: Firebase указывает требования к web handler firebaseapp.com. Это отдельная настройка от уже включённого SMS allowlist US,GB,CA,NZ,SG,HK.
- Не гарантировать одобрение Apple. Показывать функцию и объяснять использование данных, не маскировать онлайн-логику под локальную.

## Разрешения и момент запроса

| Доступ | Зачем и когда | Ограничение |
|---|---|---|
| Contacts / NSContactsUsageDescription | После Choose from contacts / Find one contact: участники квиза и optional friend matching | iOS 18+ limited или full; отказ допустим, примерный режим работает без Contacts |
| Notifications | После настройки контактов/примеров у signed-in игрока и нажатия Enable notifications | Необязательный системный запрос; Skip/отказ не блокирует игру |
| Телефон/Firebase | Пользователь вводит номер и подтверждает код до вопроса возраста | Отдельного iOS-разрешения «читать телефон/SMS» нет; Firebase может использовать silent APNs/reCAPTCHA, это не разрешение игровых уведомлений |
| Camera / Photo Library | Не используются в новой версии | Photo picker и его purpose string удалены; вместо фото фиксированный 🙂 |
| Location / Microphone / ATT | Не запрашиваются в этом сценарии | Не путать отсутствие окна ATT с отсутствием сбора данных SDK: App Privacy заполняется по фактическому SDK-сбору |

Контакты pending build 11: при full доступе сразу показываются все доступные **имена**, поиск фильтрует список локально. При limited доступе показывается разрешённое подмножество и кнопка Choose more contacts… для управления доступом. Это исправляет пустой экран старых сборок 9/10, где при full требовался поисковый запрос. Телефонные поля запрашиваются только для подтверждённых записей; вся книга/сырые номера не отправляются. Минимум игры — 4 выбранных контакта; общий максимум — 50. Прежний лимит 10 за одно открытие удалён, оставшаяся ёмкость передаётся в нативный picker. Find one выбирает одну запись. На iOS 15–17 используется одноразовый системный picker. Отмена не переключает молча на другой механизм доступа. Отзыв доступа в iPhone Settings не равен удалению уже сохранённых labels/hash — это отдельное действие удаления.

Нативный QA до публичного submit: full grant → список без ввода → поиск → Add; limited grant → выбранные имена → Add; повторное открытие limited → разрешённый список → Choose more; Cancel/swipe-dismiss; Deny → примеры; Settings → limited/full/revoke → возврат; 17 выбранных контактов не должны обрезаться до 10; старый iOS fallback. Widget-тесты и проверку компилятора не выдавать за проверку реального Contacts UI.

Пуши pending build 11: код включает native foreground presentation, потому что прямые Appwrite/APNs payload без gcm.message_id не поступают в FlutterFire onMessage. Старые sent/deliveredTotal подтверждают ответ провайдера, не показ баннера. Проверить отдельно открытое приложение, фон и заблокированный экран, разрешённые/отклонённые уведомления. Фактическое получение на устройстве до подтверждения владельца не считать доказанным.

## Источники

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: in-app account deletion](https://developer.apple.com/news/?id=12m75xbj)
- [Apple: limited contact access](https://developer.apple.com/documentation/contacts/accessing-the-contact-store)
- [Apple: contact picker](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)
- [Apple: privacy design](https://developer.apple.com/design/human-interface-guidelines/privacy/)
- [Apple: notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Firebase iOS phone auth](https://firebase.google.com/docs/auth/ios/phone-auth)


## Pending build 11: internal age and release limits

The order is phone → code → declared age → contacts. Pending build 11 uses a versioned onboarding eligibility key: an old Premium-only pass is not imported, so it cannot skip the new age question. Under-13 answers block this run. At the owner's request, a full new launch replays intro and allows a new answer; this is self-declaration, not independent age verification or a guarantee of COPPA compliance. Phone/Firebase/backend account processing occurs before the age response; do not claim otherwise. Superwall starts after eligibility. Public intro copy may refresh without authenticated API interceptors. Privacy/parents pages remain accessible without game tabs.

The example button and explanation can be hidden with content_items.example_names_enabled=false. Labels are example_names_button and example_names_description. Do not delete a key to hide it: a missing key falls back to the baked-in default. This controls availability of an example path, not arbitrary executable code.

App Store future-new-territory automatic availability remains enabled and requires UI attention; current availability was verified for exactly six requested territories. Account deletion still needs the separate audit described above before public submission.


## Сохранённые тексты App Store Connect

Точная копия публичных полей и review notes: `app-store-metadata-1.0.2.json`. Через API сохранены и read-back проверены Description, Promotional Text, Keywords, What’s New, Support URL, Marketing URL, copyright и App Review notes. В отдельном draft App Information сохранены Flyprox, subtitle «Quick quizzes with your people» и Privacy Policy URL. Данные постоянного Firebase demo-входа внесены в demo-поля и notes; sign-in отмечен как нужный для проверки всех optional online-функций, при этом гостевой сценарий явно описан. Контакты App Review сохранены из уже существующих полей, их личные значения в репозиторий не копировались.

Это подготовка черновика, а не submit. Финальный build, актуальные screenshots, App Privacy и физическая проверка остаются отдельными условиями. В черновик унаследованы 9 старых screenshots в 3 наборах; это не доказательство их соответствия новому Home/contacts/профилю. Финальный build пока не прикреплён. Не прикреплять build 10 к этим текстам: в нём ещё есть старое поведение contacts/photo/age migration.

## Основание для структуры notes

[Apple: complete review information](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/) просит объяснить обновления, внешние сервисы, региональные отличия и дать постоянный код входа. [Справочник полей Connect](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) ограничивает Notes 4000 байтами; сохранённый блок проверен по UTF-8 и содержит 3458 байт. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) требуют точных данных и рабочего доступа, а не обещания одобрения.

В [обсуждении разработчика на форуме Apple](https://developer.apple.com/forums/thread/857680) автор описал отказ, когда demo-аккаунт не открывал покупку. Это частный опыт, не правило и не гарантия; перед submit отдельно проверить Premium/Restore с чистым sandbox-пользователем, а не ограничиваться входом в аккаунт.


## Age rating: read-only проверка

У draft App Information уже были `messagingAndChat=false`, `userGeneratedContent=false`, `socialMedia=false`, `ageAssurance=false`, override `THIRTEEN_PLUS` (также V2). Сами AppInfo resources пока возвращают вычисленное `appStoreAgeRating=TWELVE_PLUS`; не выдавать override за подтверждённое отображение магазина 13+. Эти declarations не менялись этой задачей. Существующие frequency-ответы NONE не проверены по полному банку вопросов; не считать их аудитом контента. Privacy Policy URL у draft populated и перечитан после записи.
