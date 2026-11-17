import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../app_state.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Ouvre la page « À propos ».
void openAbout(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AboutPage()));

/// À propos : auteur, version, contenu et nature non officielle de
/// l'application.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final paper = Paper.of(context);
    final chapters = library.chapters.toList();
    final terms = {for (final t in library.glossary) t.termEn.toLowerCase()};
    final sections = library.mile2Outline.modules.fold<int>(
      0,
      (n, m) => n + m.sections.length,
    );
    final stats = <(String, String)>[
      ('📘', '${library.modules.length} modules, ${chapters.length} chapitres'),
      ('📖', '${library.lessons.length} leçons'),
      ('❓', '${library.questions.length} questions de QCM'),
      ('🃏', '${library.flashcards.length} flashcards'),
      ('🔤', '${terms.length} termes du glossaire, en français et en anglais'),
      ('📋', '${chapters.length} fiches de révision et cartes mentales'),
      if (library.examPrep.questions.isNotEmpty)
        ('🎯', '${library.examPrep.questions.length} questions de préparation'),
      (
        '🗂️',
        '3 vues du programme : Livre MILE2'
            '${sections > 0 ? ' ($sections sections)' : ''}, ORSYS et ORSYS enrichi',
      ),
    ];

    Widget line(String emoji, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          Expanded(
            child: Text(
              text,
              style: Hand.sansText(
                context,
                size: 15,
              ).copyWith(color: paper.ink),
            ),
          ),
        ],
      ),
    );

    return NotebookPage(
      title: 'À propos',
      showSearch: false,
      children: [
        const SizedBox(height: 8),
        GradientBanner(
          tone: Tone.violet,
          toTone: Tone.pink,
          seed: 811,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🛡️ $appName',
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Préparation à la certification CISSO',
                style: Hand.sansText(
                  context,
                  size: 15,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Créée par $appAuthor',
                key: const Key('about-author'),
                style: const TextStyle(
                  fontFamily: Hand.body,
                  fontSize: 24,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              Text(
                appAuthorTitle,
                style: Hand.sansText(
                  context,
                  size: 15,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: const [
                  Sticker(text: 'Version $appVersion', tone: Tone.yellow),
                  Sticker(text: 'Créée en novembre 2026', tone: Tone.green),
                  Sticker(text: '100 % hors ligne', tone: Tone.blue),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NoteBox(
          tone: Tone.pink,
          emoji: '⚠️',
          label: 'Application non officielle',
          child: Text(
            'Cette application est un travail personnel de $appAuthor pour '
            'préparer la certification CISSO. Elle n\'est ni officielle, ni '
            'approuvée, ni affiliée à MILE2 ou à ORSYS. CISSO et MILE2 sont '
            'des marques de leurs propriétaires ; ORSYS est une marque de son '
            'propriétaire.\n\n'
            'Le cours est rédigé et reformulé pour l\'application : il ne '
            'recopie ni le livre officiel MILE2 ni le programme ORSYS, dont '
            'seuls l\'ordre et les intitulés des parties servent de repère. '
            'Les questions sont originales et ne proviennent pas de '
            'l\'examen. Vérifiez toujours les règles de l\'examen auprès de '
            'MILE2.',
            style: Hand.noteText(context),
          ),
        ),
        NotePanel(
          title: 'Contenu',
          emoji: '📚',
          tone: Tone.turquoise,
          seed: 812,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final (e, t) in stats) line(e, t)],
          ),
        ),
        NotePanel(
          title: 'Fonctionnement',
          emoji: '🔒',
          tone: Tone.green,
          seed: 813,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(
                '📶',
                'Tout fonctionne sans internet, sans compte ni abonnement.',
              ),
              line(
                '💾',
                'La progression reste sur cet appareil ; rien n\'est envoyé.',
              ),
              line(
                '🤖',
                'L\'assistant de questions cherche dans le cours, sur '
                    'l\'appareil, sans IA en ligne.',
              ),
              line(
                '🔗',
                'Références : normes et publications citées dans les leçons '
                    '(NIST, ISO/IEC, textes européens).',
              ),
            ],
          ),
        ),
        NotePanel(
          title: 'Historique',
          emoji: '🗓️',
          tone: Tone.orange,
          seed: 814,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line('🚀', 'Projet commencé le $appCreated.'),
              line('🏷️', 'Version $appVersion · Android et Windows.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: appName,
              applicationVersion: appVersion,
              applicationLegalese:
                  '© 2026 $appAuthor. Application non officielle.',
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Licences des composants'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '© 2026 $appAuthor',
            style: Hand.sansText(
              context,
              size: 12.5,
            ).copyWith(color: paper.inkSoft),
          ),
        ),
      ],
    );
  }
}
