# Flyprox 1.0.2 — Review Notes и проверка перед отправкой

Подготовлено 22.11.2026. Это отдельный файл для новой серверной версии. Старые примечания 1.0.1, где всё называлось локальным, для неё не подходят. Загрузка в TestFlight не является отправкой версии на публичное ревью.

## English text for App Review

Flyprox is a name-based entertainment game. Core guest play is available without registration, contacts, notifications or a purchase. Users can choose a nickname and at least four participant labels, or tap “Try with example names”. Each question displays the player's nickname and three selected participants. A round has 12 questions; Shuffle reorders the same cards and Skip advances without choosing a person.

Version 1.0.2 adds optional phone sign-in, selected-contact matching, online votes and push notifications. These are real online features; the previous version's local-only description no longer describes every flow. Guest answers stay on the device. Signed-in online votes are processed by our backend. Names without a matched registered account are local choices and do not produce a vote notification for another user.

Review phone: +1 650-555-1234
Verification code: 123456

This number is configured as a Firebase test phone number; no real SMS is sent. For normal users, real SMS sign-in is currently available for US numbers only. Guest play is available without SMS. If shown, complete the standard verification/reCAPTCHA flow. Please do not use an arbitrary phone number to test the fixed code.

Suggested path:
1. Complete or skip the introduction, enter a nickname, then choose phone sign-in or “Continue without login”.
2. For phone sign-in use the test number and code above. Notification permission is optional; decline/skip is supported.
3. Add at least four participant nicknames, choose contacts, or use the built-in examples. Contact selection is initiated by the user through Apple's system picker. “Find one contact” is an alternative single-contact selection flow. Only selected labels and phone-number hashes are uploaded for matching when signed in; the full address book and raw selected-contact phone numbers are not uploaded.
4. Open the Quiz tab and play 12 questions. Selected local labels remain the quiz options, including labels without an account. The end-of-round Reveal displays this device's saved answers; it does not identify other voters.
5. A notification requires a selected contact matching a different registered account with a device registered for push and notifications enabled. Reusing the same test phone on two devices represents one account, not two players. Merely selecting a contact sends no invitation.
6. Premium is optional. Open the Premium screen, pass the age check with an eligible age of 13+, and review the weekly subscription, Restore purchases, Terms and Privacy links. Use Apple sandbox purchasing in TestFlight; Premium does not promise other voters' identities.

The app includes a question-report action that prepares an email containing the question and its ID, without participant names or answers. The user decides whether to send it. There is no public chat or public user-content feed in this flow.

Privacy and support information is available from the app's links. Settings includes Reset game. See the release checks below before using deletion claims in a public submission.

## Проверки до публичного сабмита

- Не копировать этот файл целиком в Connect: английский блок — основа notes, внутренние ограничения ниже — рабочая проверка.
- Убедиться, что выбран именно финальный билд с исправлениями, а не 1.0.2(5), который отозван. Проверить фактические build number, VALID и внутреннюю группу.
- На живом iPhone: реальный US SMS-вход, тестовый номер, отмена входа, повторная отправка, восстановление после сети, контакты, отказ от пушей, покупка/Restore. Для доставки пуша нужны два разных аккаунта, а не один номер на двух устройствах.
- Подготовить App Privacy под фактическую новую версию; таблица в `app-privacy-checklist-1.0.2.md`. Нельзя скрывать сбор SDK или называть хэши анонимными.
- Удаление аккаунта требует дополнительной доработки/проверки перед публичным выпуском: клиент сейчас продолжает локальный reset при неудаче серверного запроса, сервер удаляет ограниченные выборки, а удаление Firebase/Superwall отдельно не подтверждено. Политика честно указывает путь через поддержку; это не заменяет надёжное удаление в приложении для ревью.
- Если социальные функции расширятся: аудит требований к пользовательскому контенту, жалобам/блокировке и модерации. Не писать, что эти механизмы уже существуют, если фактически есть только email-report вопроса.
- Не менять публичные notes уже выпущенной 1.0.1 на описание новой версии. Добавить новые notes в редактируемую новую версию при отдельном сабмите.
- Firebase API key: отдельно проверить ограничения по официальной инструкции Phone Auth и оба пути — silent APNs и reCAPTCHA. Не ограничивать ключ только Bundle ID вслепую: Firebase указывает требования к web handler firebaseapp.com. Это отдельная настройка от уже включённого SMS allowlist US.
- Не гарантировать одобрение Apple. Показывать функцию и объяснять использование данных, не маскировать онлайн-логику под локальную.

## Разрешения и момент запроса

Контакты: системный `CNContactPickerViewController` открывается только после “Choose from contacts”. Это разовый выбор контактов; широкое разрешение на чтение всей книги не нужно. Перед кнопкой поясняется передача выбранных labels/hash при входе. Не заменять пикер массовым чтением адресной книги ради поиска.

Пуши: системное окно появляется после явного “Enable notifications”, только если статус ещё позволяет запрос. Повторного системного окна после отказа iOS обычно не показывает — включение через Settings. Сейчас объясняющий экран стоит после входа и имеет Skip. Возможное улучшение: предложить уведомления после первого значимого действия/матчинга, когда понятна их польза.

Телефон: отдельного системного запроса “разрешить номер телефона” нет. Пользователь сам вводит номер; Firebase может использовать тихую APNs-проверку или reCAPTCHA. Это не равно согласию на игровые уведомления.

ATT, геолокация, микрофон и камера для текущего игрового сценария не нужны. Выбор локального фото идёт через системный picker. Новое разрешение нельзя добавлять только ради пункта в анкете App Privacy: анкета описывает сбор данных, а системные окна управляют доступом устройства.

## Источники

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: in-app account deletion](https://developer.apple.com/news/?id=12m75xbj)
- [Apple: contact picker](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)
- [Apple: privacy design](https://developer.apple.com/design/human-interface-guidelines/privacy/)
- [Apple: notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Firebase iOS phone auth](https://firebase.google.com/docs/auth/ios/phone-auth)
