import '../data/progress_store.dart';
import 'stats.dart';

/// Objectif quotidien de révision : nombre de réponses à donner par jour.
const dailyAnswerGoal = 20;

/// Un badge de progression, obtenu ou non.
class Achievement {
  const Achievement(this.emoji, this.title, this.rule, {required this.earned});

  final String emoji;
  final String title;

  /// Condition d'obtention, affichée à l'apprenant.
  final String rule;
  final bool earned;
}

/// Badges calculés uniquement à partir de la progression locale.
List<Achievement> computeAchievements(ProgressStats s) {
  final lessonsRead = s.chapters.fold<int>(0, (n, c) => n + c.lessonsRead);
  return [
    Achievement(
      '🎯',
      'Premier pas',
      'Répondre à une première question',
      earned: s.totalAnswers > 0,
    ),
    Achievement(
      '📖',
      'Lecteur assidu',
      'Terminer 3 leçons',
      earned: lessonsRead >= 3,
    ),
    Achievement(
      '🌟',
      'Objectif du jour',
      'Donner $dailyAnswerGoal réponses dans la journée',
      earned: s.answersToday >= dailyAnswerGoal,
    ),
    Achievement(
      '🔥',
      'Régularité',
      'Réviser 3 jours de suite',
      earned: s.streakDays >= 3,
    ),
    Achievement(
      '🧠',
      'Bonne mémoire',
      'Maîtriser 10 flashcards',
      earned: s.masteredCardCount >= 10,
    ),
    Achievement(
      '🏆',
      'Chapitre maîtrisé',
      'Atteindre 80 % sur un chapitre',
      earned: s.availableChapters.any(
        (c) => c.status == ChapterStatus.mastered,
      ),
    ),
    Achievement(
      '📝',
      'Examen blanc',
      'Terminer un examen blanc',
      earned: s.sessions.any((r) => r.mode == SessionMode.exam),
    ),
    Achievement(
      '💯',
      'Sans faute',
      'Obtenir 100/100 sur une série d\'au moins 10 questions',
      earned: s.sessions.any((r) => r.total >= 10 && r.correctCount == r.total),
    ),
  ];
}

/// Message d'encouragement adapté à la progression.
String encouragement(ProgressStats s) {
  final today = s.answersToday;
  if (s.totalAnswers == 0) {
    return 'Premier pas aujourd\'hui : une leçon de 20 minutes suffit pour démarrer !';
  }
  if (today >= dailyAnswerGoal) {
    return 'Objectif du jour atteint, bravo ! Chaque réponse vous rapproche du CISSO.';
  }
  if (s.streakDays >= 3) {
    return '${s.streakDays} jours d\'affilée : votre régularité fait la différence, continuez !';
  }
  if (today > 0) {
    return 'Encore ${dailyAnswerGoal - today} réponses pour l\'objectif du jour, vous y êtes presque !';
  }
  return 'Bon retour ! Quelques questions aujourd\'hui et votre série repart.';
}

/// Petites phrases de motivation (rédigées pour l'application), une par jour.
const motivationQuotes = [
  'Un petit pas chaque jour vaut mieux qu\'un marathon la veille.',
  'Comprendre le risque, c\'est déjà le réduire.',
  'Chaque erreur corrigée aujourd\'hui est un point gagné à l\'examen.',
  'La sécurité est un processus, votre préparation aussi.',
  'Révisez malin : un peu, souvent, et à voix haute.',
  'Vous apprenez déjà ce qu\'un RSSI applique tous les jours.',
  'Le doute d\'aujourd\'hui devient le réflexe de demain.',
];

String quoteOfTheDay(DateTime now) {
  final day = now.difference(DateTime(now.year)).inDays;
  return motivationQuotes[day % motivationQuotes.length];
}
