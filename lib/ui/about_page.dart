import 'package:material_ui/material_ui.dart';

import '../app_info.dart';
import '../app_state.dart';
import '../models/content.dart';
import 'bilingual.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/look_table.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';
import 'widgets.dart';

/// Ouvre la page « À propos », sur la rubrique [section].
void openAbout(
  BuildContext context, {
  AboutSection section = AboutSection.app,
}) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => AboutPage(initialSection: section)));

/// Les rubriques de la page « À propos », choisies dans son menu.
enum AboutSection {
  app('L\'application', Icons.shield_outlined),
  exam('L\'examen', Icons.school_outlined),
  news('Nouveautés', Icons.new_releases_outlined);

  const AboutSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// À propos : un menu en haut de la page mène à trois rubriques.
/// - L'application : auteur, version, contenu, fonctionnement, nature non
///   officielle.
/// - L'examen : format, domaines et poids, sources vérifiées.
/// - Nouveautés : les changements, du plus récent au plus ancien.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.initialSection = AboutSection.app});

  final AboutSection initialSection;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late AboutSection _section = widget.initialSection;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 480;
    final menu = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SegmentedButton<AboutSection>(
        key: const Key('about-menu'),
        segments: [
          for (final s in AboutSection.values)
            ButtonSegment(
              value: s,
              // Sur téléphone, sans icône, pour que les libellés tiennent.
              icon: narrow ? null : Icon(s.icon),
              label: Text(s.label),
            ),
        ],
        selected: {_section},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _section = s.first),
      ),
    );
    return NotebookPage(
      key: ValueKey(_section),
      title: 'À propos',
      showSearch: false,
      children: [
        menu,
        ...switch (_section) {
          AboutSection.app => _appSection(context),
          AboutSection.exam => _examSection(context),
          AboutSection.news => _newsSection(context),
        },
      ],
    );
  }
}

/// Une ligne « émoji + texte » des panneaux de la page.
Widget _line(BuildContext context, String emoji, String text) => Padding(
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
          ).copyWith(color: Paper.of(context).ink),
        ),
      ),
    ],
  ),
);

List<Widget> _appSection(BuildContext context) {
  final library = AppScope.of(context).library;
  final paper = Paper.of(context);
  final chapters = library.chapters.toList();
  final sections = library.mile2Outline.modules.fold<int>(
    0,
    (n, m) => n + m.sections.length,
  );
  final stats = <(String, String)>[
    ('📘', '${library.modules.length} modules, ${chapters.length} chapitres'),
    ('📖', '${library.lessons.length} leçons'),
    if (library.chapters.any((c) => c.lessonsEn.isNotEmpty))
      (
        '🇬🇧',
        '${library.chapters.fold<int>(0, (n, c) => n + c.lessonsEn.length)} '
            'leçons aussi en anglais (bouton EN), mots-clés suivis du français',
      ),
    ('❓', '${library.examQuestions.length} questions de QCM originales'),
    ('🃏', '${library.flashcards.length} flashcards'),
    (
      '🔤',
      '${library.glossary.length} termes du glossaire, en français et en '
          'anglais, avec une infobulle dans les leçons',
    ),
    ('📋', '${chapters.length} fiches de révision et cartes mentales'),
    if (library.examPrep.questions.isNotEmpty)
      (
        '🎯',
        '${library.examPrep.questions.length} questions de ta formation, '
            'ajoutées au QCM de leur chapitre',
      ),
    (
      '🗂️',
      '3 vues du programme : Livre MILE2'
          '${sections > 0 ? ' ($sections sections)' : ''}, ORSYS et ORSYS enrichi',
    ),
  ];

  Widget line(String emoji, String text) => _line(context, emoji, text);

  return [
    const SizedBox(height: 8),
    GradientBanner(
      tone: Tone.violet,
      toTone: Tone.pink,
      seed: 811,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🛡️ $appName',
            style: TextStyle(
              fontFamily: Hand.title,
              fontSize: Hand.tsize(34),
              height: 1.1,
              fontWeight: Hand.titleWeight,
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
            style: TextStyle(
              fontFamily: Hand.body,
              fontSize: Hand.bsize(24),
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
            'Le chatbot répond à tes questions en cherchant dans le cours, sur '
                'l\'appareil, sans IA en ligne.',
          ),
          line(
            '💬',
            'Chaque mot-clé d\'une leçon ouvre une infobulle : définition '
                'en français et en anglais, et lien vers la leçon qui le '
                'définit.',
          ),
          line(
            '🎨',
            '5 thèmes (cahier, classique, moderne, terminal, lecture), en '
                'clair ou en sombre, dans les réglages.',
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
          line(
            '🆕',
            'Le détail des changements est dans la rubrique Nouveautés.',
          ),
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
          applicationLegalese: '© 2026 $appAuthor. Application non officielle.',
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
  ];
}

List<Widget> _examSection(BuildContext context) {
  final library = AppScope.of(context).library;
  final info = library.examInfo;
  final paper = Paper.of(context);
  final look = LookTable(context);
  final domains = [...library.domains]
    ..sort((a, b) => b.weight.compareTo(a.weight));
  final total = domains.fold<int>(0, (n, d) => n + d.weight);
  Widget line(String emoji, String text) => _line(context, emoji, text);
  Widget cell(String text, {bool bold = false, bool right = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: Hand.sansText(
        context,
        size: 14,
      ).copyWith(color: paper.ink, fontWeight: bold ? FontWeight.w700 : null),
    ),
  );
  Widget head(String text, {bool right = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: look.headerStyle,
    ),
  );
  return [
    const SizedBox(height: 8),
    NotePanel(
      key: const Key('about-exam'),
      title: 'L\'examen CISSO',
      emoji: '🎓',
      tone: Tone.violet,
      seed: 821,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SourceBadge(SourceKind.official),
          line(
            '📝',
            '${info.questionCount} questions à choix multiples, en '
                '${info.durationMinutes} minutes (2 heures).',
          ),
          line('✅', 'Seuil de réussite : ${info.passingScore}/100.'),
          line('🇬🇧', 'Examen en anglais, surveillé en ligne (ProctorU).'),
          line(
            '📚',
            '${domains.length} domaines, chacun avec un poids : voir le '
                'tableau ci-dessous.',
          ),
          line('🧭', 'Aucune expérience professionnelle exigée.'),
          line('🔁', 'Certification à renouveler tous les 3 ans.'),
        ],
      ),
    ),
    NoteBox(
      tone: Tone.yellow,
      emoji: '⚖️',
      label: 'Seuil : 62 ou 70 ?',
      sticky: true,
      child: Text(
        'La fiche de la formation ORSYS indique un seuil de 70 %. La grille '
        'officielle de MILE2 (exam blueprint) fixe ${info.passingScore}/100 : '
        'c\'est elle qui fait foi. Viser 70 % aux examens blancs garde une '
        'marge de sécurité.',
        style: Hand.noteText(context),
      ),
    ),
    NotePanel(
      title: 'Les ${domains.length} domaines et leur poids',
      emoji: '🗂️',
      tone: Tone.blue,
      seed: 822,
      child: Table(
        key: const Key('about-domains'),
        border: look.border,
        columnWidths: const {0: FlexColumnWidth(), 1: IntrinsicColumnWidth()},
        children: [
          TableRow(
            decoration: look.headerDecoration,
            children: [head('Domaine'), head('Poids', right: true)],
          ),
          for (final (i, d) in domains.indexed)
            TableRow(
              decoration: look.row(i),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.nameFr,
                        style: Hand.sansText(context, size: 14).copyWith(
                          color: paper.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        d.nameEn,
                        style: Hand.sansText(context, size: 12.5).copyWith(
                          color: englishColor(context),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                cell('${d.weight} %', bold: true, right: true),
              ],
            ),
          if (total != 100)
            TableRow(children: [cell('Total'), cell('$total %', right: true)]),
        ],
      ),
    ),
    NotePanel(
      title: 'Dans l\'application',
      emoji: '🧰',
      tone: Tone.green,
      seed: 823,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(
            '⏱️',
            'L\'examen blanc (onglet QCM) suit ces poids et le temps '
                'officiel par question.',
          ),
          line(
            '📖',
            'Les QCM par chapitre entraînent chaque domaine, avec tes '
                'questions de formation.',
          ),
          line(
            '🎯',
            'La préparation examen regroupe tes séances, en anglais et en '
                'français.',
          ),
          line(
            'ℹ️',
            'Les questions de l\'application sont originales : elles ne '
                'reproduisent pas celles de l\'examen.',
          ),
        ],
      ),
    ),
    const SizedBox(height: 8),
    Text(
      'Source : ${info.source}, vérifiée le ${frenchDate(info.verifiedOn)}. '
      'Vérifie toujours ces règles sur le site de MILE2 avant de '
      't\'inscrire.',
      key: const Key('about-exam-source'),
      style: Hand.sansText(context, size: 13).copyWith(color: paper.inkSoft),
    ),
  ];
}

/// « 2026-11-16 » → « 16/11/2026 ».
String frenchDate(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

/// Les changements de l'application, du plus récent au plus ancien :
/// (version, date, nouveautés). Chaque lot de nouveautés demandé fait monter
/// la version ; la première entrée porte toujours [appVersion].
const appNews = <(String, String, List<String>)>[
  (
    '1.8.0',
    '20/11/2026',
    [
      'Modules 9, 10 et 11 enrichis à partir de tes cartes mentales, en '
          'français et en anglais : méthodes de développement, vérification '
          'et validation, développement externalisé, retrait, CWE, failles de '
          'logique métier, référentiels de codage sécurisé, code des '
          'assistants d\'IA, renseignement sur les menaces, outils du SOC '
          '(SIEM, IDS/IPS, EDR, NDR, SOAR), centre de crise, copies '
          'contrôlées, criminalité informatique, CVE et CVSS, encadrement '
          'des fournisseurs, règlement ou référentiel, maturité des '
          'contrôles et préparation à l\'audit.',
      'Cartes mentales des modules 9, 10 et 11 complétées avec tes cartes '
          'de révision (traduites, anglais en dessous).',
      'Glossaire : NDR, renseignement sur les menaces, entiercement du '
          'code source, vérification et validation, centre des opérations '
          'd\'urgence (EOC).',
    ],
  ),
  (
    '1.7.0',
    '20/11/2026',
    [
      'Préparation examen : 30 nouvelles questions de ta formation, '
          'module 9 (sécurité du développement logiciel : SAST, DAST, SCA, '
          'DevSecOps, vérification et validation) et module 10 (SOC, PCA, '
          'PRA, BIA, MTD, RTO, RPO, WRT, sites de secours, confinement), '
          'avec corrigés expliqués en anglais et en français.',
      'Ces questions complètent aussi le QCM de leur chapitre '
          '(développement, SOC, continuité, incidents).',
    ],
  ),
  (
    '1.6.0',
    '20/11/2026',
    [
      'Textes et normes : 15 fiches courtes (ISO/IEC 27017, 27018, 27701, '
          'IEC 62443, DMA, DSA, DGA, RGPD, NIS 2, DORA, Cybersecurity Act, '
          'CRA, II 901, IGI 1300, IGI 2102) avec définition, essentiel, '
          'à retenir, liens officiels et renvoi vers les leçons ; en '
          'français et en anglais. Accès depuis Cours et les chapitres '
          'Lois et Conformité européenne.',
    ],
  ),
  (
    '1.4.0',
    '19/11/2026',
    [
      'Cartes mentales en HTML : arbre centré sur le thème, branches à '
          'gauche et à droite comme dans le PDF et dans le cours (replier, '
          'zoom et recherche conservés).',
      'Numéro de version devant chaque entrée des Nouveautés ; la dernière '
          'version s\'affiche partout (À propos, pied de page).',
    ],
  ),
  (
    '1.3.0',
    '19/11/2026',
    [
      'Cartes mentales du livre MILE2 enrichies avec tes cartes de révision '
          '(modules 1, 2, 3, 4, 5 et 8) : leurs branches sous chaque section, '
          'en français avec l\'anglais dessous, plus guides de décision et '
          'glossaires des sigles.',
      'Gestion des changements : le processus en 5 phases (soumettre, '
          'vérifier, coordonner, mettre en œuvre, mesurer) et leurs tâches, '
          'avec schéma, tableau, mémo, flashcard et fiche de révision.',
    ],
  ),
  (
    '1.2.0',
    '18/11/2026',
    [
      'Flashcards bilingues : le recto et le verso de chaque carte en '
          'anglais, avec le français juste en dessous (aussi dans le PDF).',
      'Fiches de révision bilingues : chaque point en anglais, avec le '
          'français juste en dessous (aussi dans le PDF et la copie).',
      'QCM bilingues : chaque question des modules 1 à 5, ses réponses et '
          'sa correction s\'affichent en anglais, avec le français juste en '
          'dessous.',
      'Version anglaise de toutes les leçons (modules 1 à 5) : bouton EN dans la '
          'leçon, chaque mot-clé suivi de sa traduction française.',
      'L\'assistant s\'appelle maintenant « Chatbot ».',
      'Page À propos : menu avec L\'application, L\'examen (format, '
          'seuil, 11 domaines et leur poids) et Nouveautés.',
      'Menu de gauche : Recherche et Chatbot ajoutés ; boutons '
          'étendre et masquer déplacés sur une poignée au bord du menu.',
      'Infobulles sur tous les mots-clés des leçons, y compris dans les '
          'tableaux, listes et étapes ; 111 termes ajoutés au glossaire.',
      'Tes questions de formation ajoutées au QCM de leur chapitre (hors '
          'examen blanc).',
      'Cartes mentales du livre : mots-clés essentiels de chaque section, '
          'sans répétition.',
      'Préparation examen : séance du 18/11 (référentiels et cryptographie).',
      'QCM cryptographie : 15 questions du quiz crypto de ta formation, '
          'avec corrigé en anglais et en français.',
      '5 thèmes au choix et mode clair ou sombre.',
      'Menu de gauche toujours visible, avec un bouton Masquer tout en bas.',
      'Menu de gauche : l\'entrée Examen est retirée, la rubrique L\'examen '
          'se trouve dans À propos.',
      'QCM du module 5 (sécurité des données) : 20 questions de ta formation '
          'ajoutées, avec corrigé en anglais et en français.',
    ],
  ),
  (
    '1.1.0',
    '17/11/2026',
    [
      'Page À propos, mention de l\'auteur et pied de page.',
      'Mots-clés cliquables dans les leçons.',
      'Chatbot hors ligne (questions sur le cours), avec historique.',
      'Historique des recherches.',
      'Mascottes sur le thème de la cybersécurité.',
      'Trois vues du cours : Livre MILE2, ORSYS et ORSYS enrichi.',
      'Module 11 : NIS 2, DORA, règlement sur la cyberrésilience.',
      'Relecture complète des leçons et des questions.',
      'Recherche dans toute la formation.',
      'Fin du module 5 (incidents, lois, sécurité physique) et leçons '
          'manquantes ajoutées : 5 modules et 21 chapitres.',
    ],
  ),
  (
    '1.0.0',
    '16/11/2026',
    [
      'Socle de l\'application et modules 1 à 4, puis début du module 5 : '
          'leçons, QCM, flashcards, fiches de révision et cartes mentales.',
      'Préparation examen : première séance de tes questions de formation.',
      'Style « cahier » et versions Android et Windows.',
    ],
  ),
];

/// Titre d'une entrée des Nouveautés : « v1.4.0 · 19/11/2026 ».
String newsTitle(String version, String date) => 'v$version · $date';

List<Widget> _newsSection(BuildContext context) => [
  const SizedBox(height: 8),
  for (final (i, (version, date, items)) in appNews.indexed)
    NotePanel(
      title: newsTitle(version, date),
      emoji: i == 0 ? '🆕' : '🗓️',
      tone: i == 0 ? Tone.pink : Tone.orange,
      seed: 830 + i,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final t in items) _line(context, '•', t)],
      ),
    ),
];
