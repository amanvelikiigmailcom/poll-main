// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get onboarding_skip => 'Пропустить';

  @override
  String get onboarding_next => 'Далее';

  @override
  String get onboarding_start => 'Начать';

  @override
  String get onboarding1_title => 'Голосуй анонимно';

  @override
  String get onboarding1_desc =>
      'Отвечай на веселые вопросы о своих одноклассниках — никто не узнает, что это ты. Полная анонимность гарантирована.';

  @override
  String get onboarding2_title => 'Без негатива';

  @override
  String get onboarding2_desc =>
      'Только позитивные вопросы, которые сближают ваш класс. Безопасная и дружелюбная среда для всех.';

  @override
  String get onboarding3_title => 'Анонимная лента';

  @override
  String get onboarding3_desc =>
      'Смотри, за кого проголосовали в ленте класса — и собирай звёзды, поднимаясь на вершину.';

  @override
  String get onboarding4_title => 'Приглашай своих друзей';

  @override
  String get onboarding4_desc =>
      'Больше друзей — больше веселья! Приглашай одноклассников и открой полный опыт Hidavo.';

  @override
  String get auth_phoneTitle => 'Вход в Hidavo';

  @override
  String get auth_phoneSubtitle => 'Введите номер телефона';

  @override
  String get auth_phoneContinue => 'Продолжить';

  @override
  String get auth_otpTitle => 'Введите код';

  @override
  String get auth_otpSubtitle => 'Код отправлен в';

  @override
  String get auth_otpOpenTelegram => 'Открыть Telegram';

  @override
  String get auth_otpGetWhatsApp => 'Получить код в WhatsApp';

  @override
  String get auth_otpResend => 'Отправить ещё раз';

  @override
  String get auth_otpTimer => 'Повтор через';

  @override
  String get auth_otpWrongCode => 'Неверный код. Попробуйте ещё раз';

  @override
  String get auth_otpExpired => 'Код истёк. Запросите новый';

  @override
  String get auth_otpTooMany =>
      'Слишком много попыток. Попробуйте через 1 минуту';

  @override
  String get reg_header => 'Регистрация';

  @override
  String get reg_firstName => 'Имя';

  @override
  String get reg_lastName => 'Фамилия';

  @override
  String get reg_genderMale => 'Мужской';

  @override
  String get reg_genderFemale => 'Женский';

  @override
  String get reg_ageHint => 'Пожалуйста, укажите ваш настоящий возраст';

  @override
  String get reg_ageModalTitle => 'Возрастное ограничение';

  @override
  String get reg_ageModalMessage =>
      'К сожалению, приложение доступно только пользователям от 14 до 19 лет.';

  @override
  String get location_header => 'Выберите ваш город';

  @override
  String get location_subtitle => 'Мы покажем школы и друзей поблизости';

  @override
  String get location_search => 'Поиск города...';

  @override
  String get location_noCity => 'Нет вашей локации?';

  @override
  String get location_support => 'Написать в поддержку';

  @override
  String get school_header => 'Выберите школу';

  @override
  String get school_search => 'Поиск школы...';

  @override
  String get class_header => 'Выберите класс';

  @override
  String get username_title => 'Придумайте логин';

  @override
  String get username_available => 'Логин доступен';

  @override
  String get username_taken => 'Логин занят';

  @override
  String get contacts_title => 'Найдите друзей';

  @override
  String get contacts_description =>
      'Включите доступ к контактам чтобы найти ваших друзей';

  @override
  String get contacts_button => 'Включить контакты';

  @override
  String get photo_title => 'Добавьте фото';

  @override
  String get photo_subtitle =>
      'Добавьте фото чтобы вас могли видеть ваши знакомые';

  @override
  String get photo_gallery => 'Выбрать из галереи';

  @override
  String get photo_camera => 'Снять на камеру';

  @override
  String get voting_beforeVoteTitle => 'Жди друзей!';

  @override
  String get voting_beforeVoteDesc =>
      'Минимум нужно ввести 3 друзей, чтобы начать голосование.';

  @override
  String get voting_continueWithout => 'Продолжить без друзей';

  @override
  String get voting_question => 'Вопрос';

  @override
  String get voting_of => 'из';

  @override
  String get voting_shuffle => 'Перемешать';

  @override
  String get voting_timerTitle => 'Следующий раунд через...';

  @override
  String get voting_timerInvite => 'Пригласить друга';

  @override
  String get voting_timerDesc => 'Пригласи друга и голосуй прямо сейчас!';

  @override
  String get voting_goHome => 'На главную';

  @override
  String voting_starsReceived(int count) {
    return 'Ты получил $count звёздочек!';
  }

  @override
  String get voting_myCollection => 'Моя коллекция';

  @override
  String get voting_starTakingTitle => 'Кто-то проголосовал за тебя!';

  @override
  String get voting_viewActivity => 'Посмотреть активность';

  @override
  String get invite_title => 'Пригласи друга';

  @override
  String get invite_description =>
      'Друг установил приложение = можешь голосовать прямо сейчас!';

  @override
  String get invite_share => 'Поделиться';

  @override
  String get invite_copy => 'Скопировать ссылку';

  @override
  String get invite_copied => 'Ссылка скопирована!';

  @override
  String get profile_stars => 'Звёздочки';

  @override
  String get profile_friends => 'Друзья';

  @override
  String get profile_votes => 'Голоса';

  @override
  String get profile_collection => 'Моя коллекция';

  @override
  String get profile_editProfile => 'Редактировать профиль';

  @override
  String get profile_addFriend => 'Добавить в друзья';

  @override
  String get profile_requestSent => 'Запрос отправлен';

  @override
  String get profile_alreadyFriends => 'Вы друзья';

  @override
  String get editProfile_title => 'Редактирование профиля';

  @override
  String get editProfile_changeSchool => 'Изменить школу';

  @override
  String get editProfile_deleteAccount => 'Удалить аккаунт';

  @override
  String get editProfile_deleteAccountFinal => 'Удалить безвозвратно';

  @override
  String get editProfile_deleteScheduled =>
      'Аккаунт будет удалён в течение 30 дней';

  @override
  String get activity_title => 'Активность';

  @override
  String get activity_tabSchool => 'В школе';

  @override
  String get activity_tabMyLikes => 'Мои лайки';

  @override
  String get activity_empty => 'Пока нет активности';

  @override
  String get activity_revealWho => 'Узнать кто';

  @override
  String get activity_voted => 'проголосовал за';

  @override
  String get friends_title => 'Мои друзья';

  @override
  String get friends_empty => 'Нет друзей';

  @override
  String get friends_remove => 'Удалить из друзей';

  @override
  String get friendRequests_title => 'Запросы в друзья';

  @override
  String get friendRequests_accept => 'Принять';

  @override
  String get friendRequests_decline => 'Отклонить';

  @override
  String get friendRequests_empty => 'Нет запросов';

  @override
  String get search_placeholder => 'Поиск пользователей...';

  @override
  String get search_empty => 'Ничего не найдено';

  @override
  String get premium_title => 'Premium';

  @override
  String get premium_proTitle => 'Premium Pro';

  @override
  String get premium_proPrice => '\$7.99 / неделю';

  @override
  String get premium_proButton => 'Получить Pro';

  @override
  String get premium_maxTitle => 'Premium Max';

  @override
  String get premium_maxPrice => '\$27.99 / месяц';

  @override
  String get premium_maxButton => 'Получить Max';

  @override
  String get premium_restore => 'Восстановить покупки';

  @override
  String get premium_activated => 'Premium активирован!';

  @override
  String get premium_purchaseError => 'Не удалось завершить покупку';

  @override
  String get premiumResult_remaining => 'У вас осталось:';

  @override
  String get premiumResult_revealFirstLetter => 'Узнать первую букву имени';

  @override
  String get premiumResult_revealFullName => 'Узнать полное имя';

  @override
  String get premiumResult_limitExhausted =>
      'Лимит исчерпан. Оформите Premium Max для безлимита';

  @override
  String get premiumResult_tapToReveal =>
      'Нажмите на карточку кого хотите узнать';

  @override
  String get settings_title => 'Настройки';

  @override
  String get settings_notifications => 'Уведомления';

  @override
  String get settings_newVotes => 'Новые голоса';

  @override
  String get settings_timerExpired => 'Таймер истёк';

  @override
  String get settings_editProfile => 'Изменить профиль';

  @override
  String get settings_changePhone => 'Изменить номер телефона';

  @override
  String get settings_language => 'Язык';

  @override
  String get settings_deleteAccount => 'Удалить аккаунт';

  @override
  String get settings_logout => 'Выйти';

  @override
  String get settings_version => 'Версия приложения';

  @override
  String get settings_terms => 'Условия использования';

  @override
  String get settings_privacy => 'Политика конфиденциальности';

  @override
  String get settings_logoutConfirm => 'Вы уверены что хотите выйти?';

  @override
  String get collection_title => 'Коллекция';

  @override
  String get collection_unlock => 'Открыть';

  @override
  String get collection_locked => 'Заблокировано';

  @override
  String get collection_frames => 'Рамки';

  @override
  String get collection_badges => 'Значки';

  @override
  String get collection_backgrounds => 'Фоны';

  @override
  String get common_loading => 'Загрузка...';

  @override
  String get common_error => 'Ошибка';

  @override
  String get common_retry => 'Повторить';

  @override
  String get common_save => 'Сохранить';

  @override
  String get common_cancel => 'Отмена';

  @override
  String get common_back => 'Назад';

  @override
  String get common_next => 'Далее';

  @override
  String get common_skip => 'Пропустить';

  @override
  String get common_done => 'Готово';

  @override
  String get common_ok => 'ОК';

  @override
  String get common_close => 'Закрыть';

  @override
  String get common_unknownError => 'Что-то пошло не так';

  @override
  String get common_later => 'Позже';

  @override
  String get common_continue => 'Продолжить';

  @override
  String get common_invite => 'Пригласить';
}
