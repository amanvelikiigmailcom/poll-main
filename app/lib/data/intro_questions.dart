// Hand-authored neutral intro rounds. Not part of the generated pool in
// quiz_questions.dart: these 24 questions play first (rounds 1-2, fixed
// order) and never recycle into later rounds.
//
// Topics: humor, everyday life, travel, hobbies. No romance,
// attractiveness, or sympathy themes.
import 'quiz_questions.dart';

/// Fixed play order. Round 1 = [0..12), round 2 = [12..24).
const List<QuizQuestionSeed> introQuestionSeeds = [
  // ── Round 1: humor ─────────────────────────────────────────────────
  QuizQuestionSeed(id: 'intro1', textRu: 'Кто рассмешит всю компанию?', textEn: 'Who can make the whole group laugh?', category: 'humor', emoji: '😂'),
  QuizQuestionSeed(id: 'intro2', textRu: 'Кто смеётся громче всех?', textEn: 'Who laughs the loudest?', category: 'humor', emoji: '📢'),
  QuizQuestionSeed(id: 'intro3', textRu: 'Кто придумает смешное прозвище для каждого?', textEn: 'Who will come up with a funny nickname for everyone?', category: 'humor', emoji: '🤣'),
  QuizQuestionSeed(id: 'intro4', textRu: 'Кто рассмешит даже самого строгого учителя?', textEn: 'Who can make even the strictest teacher laugh?', category: 'humor', emoji: '😄'),
  QuizQuestionSeed(id: 'intro5', textRu: 'Кто заснёт на самом интересном месте фильма?', textEn: 'Who will fall asleep at the most exciting part of a movie?', category: 'humor', emoji: '😴'),
  QuizQuestionSeed(id: 'intro6', textRu: 'Кто перепутает, какой сегодня день недели?', textEn: 'Who will mix up what day of the week it is?', category: 'humor', emoji: '😅'),
  // ── Round 1: everyday life ─────────────────────────────────────────
  QuizQuestionSeed(id: 'intro7', textRu: 'Кто встаёт раньше всех без будильника?', textEn: 'Who wakes up earliest without an alarm?', category: 'normal', emoji: '☀️'),
  QuizQuestionSeed(id: 'intro8', textRu: 'Кто никогда не опаздывает?', textEn: 'Who is never late?', category: 'normal', emoji: '⏰'),
  QuizQuestionSeed(id: 'intro9', textRu: 'Кто помнит все дни рождения?', textEn: 'Who remembers all the birthdays?', category: 'normal', emoji: '🎂'),
  QuizQuestionSeed(id: 'intro10', textRu: 'Кто даст лучший совет?', textEn: 'Who gives the best advice?', category: 'normal', emoji: '💡'),
  QuizQuestionSeed(id: 'intro11', textRu: 'Кто организует лучший праздник?', textEn: 'Who throws the best party?', category: 'normal', emoji: '🎉'),
  QuizQuestionSeed(id: 'intro12', textRu: 'Кто чинит всё своими руками?', textEn: 'Who can fix anything with their own hands?', category: 'normal', emoji: '🔧'),
  // ── Round 2: travel ────────────────────────────────────────────────
  QuizQuestionSeed(id: 'intro13', textRu: 'Кто лучше спланирует поездку?', textEn: 'Who plans trips the best?', category: 'normal', emoji: '🗺️'),
  QuizQuestionSeed(id: 'intro14', textRu: 'Кто собирает чемодан за пять минут?', textEn: 'Who packs a suitcase in five minutes?', category: 'normal', emoji: '🧳'),
  QuizQuestionSeed(id: 'intro15', textRu: 'Кто находит самые крутые места в новом городе?', textEn: 'Who finds the coolest spots in a new city?', category: 'normal', emoji: '📍'),
  QuizQuestionSeed(id: 'intro16', textRu: 'Кто попробует любую местную еду?', textEn: 'Who will try any local food?', category: 'normal', emoji: '🍜'),
  QuizQuestionSeed(id: 'intro17', textRu: 'Кто делает лучшие фото из поездок?', textEn: 'Who takes the best travel photos?', category: 'normal', emoji: '📸'),
  QuizQuestionSeed(id: 'intro18', textRu: 'Кто выучит фразы на любом языке за день?', textEn: 'Who can learn phrases in any language in a day?', category: 'normal', emoji: '🗣️'),
  // ── Round 2: hobbies ───────────────────────────────────────────────
  QuizQuestionSeed(id: 'intro19', textRu: 'Кто лучше всех играет в видеоигры?', textEn: 'Who is the best at video games?', category: 'normal', emoji: '🎮'),
  QuizQuestionSeed(id: 'intro20', textRu: 'Кто рисует лучше всех?', textEn: 'Who draws the best?', category: 'normal', emoji: '🎨'),
  QuizQuestionSeed(id: 'intro21', textRu: 'Кто лучший музыкант?', textEn: 'Who is the best musician?', category: 'normal', emoji: '🎵'),
  QuizQuestionSeed(id: 'intro22', textRu: 'Кто самый спортивный?', textEn: 'Who is the sportiest?', category: 'normal', emoji: '⚽'),
  QuizQuestionSeed(id: 'intro23', textRu: 'Кто смотрит больше всех фильмов?', textEn: 'Who watches the most movies?', category: 'normal', emoji: '🎬'),
  QuizQuestionSeed(id: 'intro24', textRu: 'Кто читает больше всех книг?', textEn: 'Who reads the most books?', category: 'normal', emoji: '📚'),
];
