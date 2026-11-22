# App Privacy — Flyprox 1.0.2

Аудит кода и интеграций от 22.11.2026. **Текущие галочки в Connect через API не прочитаны и не изменены:** поддерживаемого публичного endpoint анкеты не найдено. Нужен App Store Connect → Flyprox → App Privacy в веб-интерфейсе. Account Holder, Admin или App Manager могут управлять этими сведениями; повышать роль до Admin только ради этой анкеты не требуется.

Не смешивать анкету с iOS-разрешениями. Контакты в анкете — какие данные собираются сервером; системный пикер — какие записи пользователь передаёт приложению.

## Рабочая таблица для новой версии

| Категория Apple | Основание в этой версии | Purpose | Linked | Tracking |
|---|---|---|---|---|
| Contact Info → Phone Number | Собственный номер аккаунта, Firebase и backend | App Functionality; проверить Anti-fraud как Other Purposes по форме | Yes | No |
| Contacts | Выбранные labels и хэши телефонов для матчинга | App Functionality | Yes | No |
| Identifiers → User ID | Account/session ID, installation/app user ID SDK | App Functionality; Analytics для SDK | Yes | No |
| Identifiers → Device ID | APNs device token и идентификатор устройства/установки SDK | App Functionality; Analytics для SDK | Yes | No |
| Purchases → Purchase History | Apple-покупки и Superwall entitlement/subscription status | App Functionality, Analytics | Yes при используемой привязке идентификаторов | No |
| Usage Data → Product Interaction | События Superwall: запуск, показ пейвола, purchase action | Analytics, App Functionality | Yes при используемой привязке | No |
| User Content → Gameplay Content | Сохраняемые сервером раунды и голоса | App Functionality | Yes | No |
| Contact Info → Name | Если имена профиля передаются онлайн; выбранные contact-labels также учесть в Contacts | App Functionality | Yes | No |

Gameplay Content нужен потому, что новые онлайн-раунды/голоса сохраняются на сервере. Если бы вся игра оставалась только на устройстве, эти данные не считались бы серверным сбором. Нельзя убрать строку, оставив ту же серверную логику.

Product Interaction нужен при текущей конфигурации Superwall (нативный default `eventTrackingBehavior = .all`). Манифест SDK не заменяет аудит всей интеграции. Чтобы убрать эту категорию, сначала действительно отключить соответствующие события, проверить настройки/другие SDK и пересобрать приложение.

С build 9 изменено системное разрешение, но категория серверного сбора Contacts остаётся: передаются только подтверждённые labels/hash. На iOS 18+ появились persistent limited access и нативный поиск; отзыв разрешения не подтверждает удаления ранее сохранённых данных. Публичная Privacy Policy/Support обновлены под этот flow.

## Что проверить отдельно перед окончательным Save/Publish

- Superwall может определять регион по IP. Проверить фактическую конфигурацию и поле location в аккаунте/SDK; при сохраняемой приблизительной геолокации добавить Location → Coarse Location с соответствующей целью. Отсутствие системного запроса геолокации само по себе не доказывает отсутствия IP-derived location.
- Support: адрес email, текст сообщения/вложения, указанные пользователем. Оценить применимость исключения для добровольных редких support submissions по правилам Apple; если исключение не выполняется — добавить Email Address и Customer Support/Other User Content по факту формы.
- Build11 удаляет фото UI/image_picker/NSPhotoLibraryUsageDescription; фиксированный смайлик, legacy app-owned image очищается при startup. Не объявлять Photos or Videos только из-за прежнего локального аватара; серверной загрузки в этом flow нет. При новой загрузке фото пересмотреть.
- Optional university/year, age/gender/profile fields: отмечать соответствующие категории по реальной отправке, а не наличию неиспользуемой формы в исходниках. Не ставить Precise Location, Audio Data, Health Data без фактической обработки.
- Хэш контакта не делает сведения анонимными: сервер сопоставляет их с аккаунтом. Linked = Yes.
- Tracking не равен любой аналитике. Для текущей заявленной цели нет рекламного cross-app tracking, поэтому No; не включать ATT, если не меняется само использование данных.
- Privacy URL должен открываться без логина и соответствовать версии. Политика уже описывает различие local-only версий и 1.0.2 online/TestFlight.
- Публичные сведения должны отражать фактически распространяемую App Store версию. Не публиковать новые labels преждевременно как будто online-возможности уже есть в live 1.0.1; согласовать обновление с новым публичным выпуском.

## Источники и границы проверки

- [Apple: data types, purposes, collection and linkage](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple: управление анкетой и роли](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Superwall: App Privacy](https://superwall.com/docs/ios/guides/app-privacy-nutrition-labels)
- [Firebase: privacy and processing](https://firebase.google.com/support/privacy/)

Это перечень по коду и документации, а не подтверждение сохранённых настроек в Connect. Финальная анкета требует проверки фактических SDK-настроек и редактируемого веб-интерфейса. Загрузка TestFlight сама по себе её не заполняет.
