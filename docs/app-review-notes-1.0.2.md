# Flyprox 1.0.2 — Review Notes и проверка перед отправкой

Подготовлено 22.11.2026. Это отдельный файл для новой серверной версии. Старые примечания 1.0.1, где всё называлось локальным, для неё не подходят. Загрузка в TestFlight не является отправкой версии на публичное ревью.

## English text for App Review

Flyprox is a name-based entertainment game with 12-question rounds. Phone sign-in is optional. Users first see phone entry and SMS verification (or may continue without login), then an unselected declared-age question, then contact selection. There is no manual nickname or participant-name entry in this onboarding. At least four selected contacts are needed to continue, or users can try the built-in example names without Contacts access. Each question shows the player label and three participant labels. Shuffle reorders the same cards; Skip advances without selecting a person.

Review phone: +1 650-555-1234
Verification code: 123456

This is a configured Firebase test number; it does not send a real SMS. Normal SMS sign-in is enabled for the United States, United Kingdom, Canada, New Zealand, Singapore and Hong Kong. Select the matching country code; US/+1 is the default. Firebase may use standard app verification/reCAPTCHA. Do not try the fixed review code with arbitrary numbers.

Suggested review path:
1. Complete or skip the introduction. Enter the review number and code, or choose “Continue without login”.
2. Answer the age question. Options are 12 or younger, 13, 14, 15, 16, 17 and 18+. No answer is preselected. An under-13 response blocks contacts, gameplay and purchases for the current run. The exact selected age is neither retained nor sent to the backend; a local eligibility outcome is kept. Phone verification precedes this question, so Firebase authentication is not gated by the age answer. Subscription initialization is deferred until an eligible answer.
3. Tap “Choose from contacts” and confirm at least four entries, or tap “Try with example names”. Contacts are requested only after the user taps a contacts action. On iOS 18+, selected/limited access is supported with native access controls and a searchable selection screen. Full access requires a name search and loads at most 50 matching names, not the entire address book. Only confirmed entries become participants. “Find one contact” selects one entry. Refusal/cancellation is supported; the example path does not require Contacts access. On iOS 15–17, the one-time system picker remains available.
4. After setup, signed-in users may see an optional notification explanation. The iOS notification prompt appears only after “Enable notifications”; Skip is supported. Open Quiz to play a round. Reveal displays this device's saved answers and does not identify other voters.
5. Premium is optional. The paywall shows the weekly subscription, price, auto-renewal terms, Restore purchases, Terms and Privacy. Use Apple sandbox purchasing in TestFlight.

Version 1.0.2 includes real optional online features: Firebase phone verification, backend account sessions, selected-contact matching, online votes and APNs notifications through Appwrite Messaging. Signed-in contact matching uploads only confirmed labels and phone-number hashes, not the full address book or raw selected-contact numbers. Selecting someone sends no invitation. A vote notification requires a matched different registered account, registered device and notification permission. Reusing one review number on two devices is one account, not two players. Unmatched labels remain local choices and do not notify another person. Guest answers stay on the device.

Question reporting prepares an email with the question and ID, without participant names or answers; the user chooses whether to send it. There is no public chat or public user-content feed in this flow. Privacy/support links and Reset game are available in Settings. Verify the deletion limitations below before public submission.

## Проверки до публичного сабмита

- Не копировать этот файл целиком в Connect: английский блок — основа notes, внутренние ограничения ниже — рабочая проверка.
- Убедиться, что выбран именно финальный билд с исправлениями, а не 1.0.2(5), который отозван. Проверить фактические build number, VALID и внутреннюю группу.
- На живом iPhone: реальный US SMS-вход, тестовый номер, отмена входа, повторная отправка, восстановление после сети, контакты, отказ от пушей, покупка/Restore. Для доставки пуша нужны два разных аккаунта, а не один номер на двух устройствах.
- Подготовить App Privacy под фактическую новую версию; таблица в `app-privacy-checklist-1.0.2.md`. Нельзя скрывать сбор SDK или называть хэши анонимными.
- Удаление аккаунта требует дополнительной доработки/проверки перед публичным выпуском: клиент сейчас продолжает локальный reset при неудаче серверного запроса, сервер удаляет ограниченные выборки, а удаление Firebase/Superwall отдельно не подтверждено. Политика честно указывает путь через поддержку; это не заменяет надёжное удаление в приложении для ревью.
- Если социальные функции расширятся: аудит требований к пользовательскому контенту, жалобам/блокировке и модерации. Не писать, что эти механизмы уже существуют, если фактически есть только email-report вопроса.
- Не менять публичные notes уже выпущенной 1.0.1 на описание новой версии. Добавить новые notes в редактируемую новую версию при отдельном сабмите.
- Firebase API key: отдельно проверить ограничения по официальной инструкции Phone Auth и оба пути — silent APNs и reCAPTCHA. Не ограничивать ключ только Bundle ID вслепую: Firebase указывает требования к web handler firebaseapp.com. Это отдельная настройка от уже включённого SMS allowlist US,GB,CA,NZ,SG,HK.
- Не гарантировать одобрение Apple. Показывать функцию и объяснять использование данных, не маскировать онлайн-логику под локальную.

## Разрешения и момент запроса

Контакты с build 9: на iOS 18+ после нажатия кнопки используется новый limited-access flow (`ContactAccessBridge.swift`, `contactAccessPicker` и `ContactAccessButton`). При первом открытии iOS показывает системное разрешение с возможностью выбранного/полного доступа или отказа. В limited режиме в список загружаются только разрешённые имена, а телефоны — только для подтверждённых в игру записей. В full режиме без поисковой строки нет чтения книги; выполняется только поиск по имени с максимумом 50 результатов. Поиск видим постоянно. После отказа можно открыть Settings или отменить и использовать примеры (если кнопка включена сервером). Предоставленные через iOS контакты предварительно отмечаются, но их добавление в игру подтверждается Add; лимит 10 (Find one — 1). На iOS 15–17 сохранён разовый `CNContactPickerViewController`. Отмена/отказ не открывают старое окно автоматически. Изменение доступа в Settings проверяется при возврате; отзыв разрешения сам по себе не удаляет уже скопированные игровые labels/серверные hash — это отдельный reset/deletion.

Проверка на устройстве: первый limited grant → выбранные имена → Add → карточки; повторный доступ → Choose more → поиск; Cancel и swipe-dismiss; Deny → примеры; Settings → limited/full/revoke → возврат; full access → пустая строка ничего не загружает → поиск → подтверждение; ограничение 10/1; предыдущий iOS fallback. Эти нативные действия не считать подтверждёнными одним Flutter widget-тестом.

Пуши: системное окно появляется после явного “Enable notifications”, только если статус ещё позволяет запрос. Повторного системного окна после отказа iOS обычно не показывает — включение через Settings. С build 10 объясняющий экран стоит после выбора контактов или примеров у вошедшего пользователя и имеет Skip. До возраста и контактов игровые push permissions не запрашиваются.

Телефон: отдельного системного запроса “разрешить номер телефона” нет. Пользователь сам вводит номер; Firebase может использовать тихую APNs-проверку или reCAPTCHA. Это не равно согласию на игровые уведомления.

ATT, геолокация, микрофон и камера для текущего игрового сценария не нужны. Выбор локального фото идёт через системный picker. Новое разрешение нельзя добавлять только ради пункта в анкете App Privacy: анкета описывает сбор данных, а системные окна управляют доступом устройства.

## Источники

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: in-app account deletion](https://developer.apple.com/news/?id=12m75xbj)
- [Apple: limited contact access](https://developer.apple.com/documentation/contacts/accessing-the-contact-store)
- [Apple: contact picker](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)
- [Apple: privacy design](https://developer.apple.com/design/human-interface-guidelines/privacy/)
- [Apple: notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Firebase iOS phone auth](https://firebase.google.com/docs/auth/ios/phone-auth)


## Build 10: internal age and release limits

The new order is phone → code → declared age → contacts. Under-13 answers block this run. At the owner's request, a full new launch replays intro and allows a new answer; this is self-declaration, not independent age verification or a guarantee of COPPA compliance. Phone/Firebase/backend account processing occurs before the age response; do not claim otherwise. Superwall starts after eligibility. Public intro copy may refresh without authenticated API interceptors. Privacy/parents pages remain accessible without game tabs.

The example button and explanation can be hidden with content_items.example_names_enabled=false. Labels are example_names_button and example_names_description. Do not delete a key to hide it: a missing key falls back to the baked-in default. This controls availability of an example path, not arbitrary executable code.

App Store future-new-territory automatic availability remains enabled and requires UI attention; current availability was verified for exactly six requested territories. Account deletion still needs the separate audit described above before public submission.
