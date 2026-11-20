import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models/content.dart';
import 'lesson_page.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/note_box.dart';
import 'notebook/page_kit.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

/// Ouvre la page des fiches « Textes et normes », éventuellement sur une fiche.
void openRegulations(BuildContext context, {String? sheetId}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegulationsPage(initialSheet: sheetId),
      ),
    );

/// Fiches courtes sur les normes et règlements : définition, essentiel,
/// liens officiels, et renvoi vers les leçons qui approfondissent le sujet.
class RegulationsPage extends StatefulWidget {
  const RegulationsPage({super.key, this.initialSheet});

  /// Fiche dépliée à l'ouverture.
  final String? initialSheet;

  @override
  State<RegulationsPage> createState() => _RegulationsPageState();
}

class _RegulationsPageState extends State<RegulationsPage> {
  late final Set<String> _open = {?widget.initialSheet};
  final _keys = <String, GlobalKey>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    final id = widget.initialSheet;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(id, 12));
    }
  }

  /// Amène la fiche [id] à l'écran. La liste ne construit que ce qui est
  /// proche de l'écran : tant que la fiche n'existe pas, on descend.
  void _reveal(String id, int tries) {
    if (!mounted || tries == 0) return;
    final target = _keys[id]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
      );
      return;
    }
    final built = _keys.values
        .map((k) => k.currentContext)
        .whereType<BuildContext>()
        .firstOrNull;
    final position = built == null ? null : Scrollable.maybeOf(built)?.position;
    if (position == null || position.pixels >= position.maxScrollExtent) {
      return;
    }
    position.jumpTo(
      (position.pixels + position.viewportDimension)
          .clamp(0, position.maxScrollExtent)
          .toDouble(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(id, tries - 1));
  }

  bool _matches(RegulationSheet s) {
    if (_query.isEmpty) return true;
    final q = normalize(_query);
    return [
      s.name,
      s.title.fr,
      s.title.en,
      s.reference.fr,
      s.definition.fr,
      s.definition.en,
    ].any((t) => normalize(t).contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final regs = state.library.regulations;
    final en = state.lessonsInEnglish;
    String t(Bi b) => en ? b.en : b.fr;
    final white = Hand.sansText(
      context,
      size: 14,
    ).copyWith(color: Colors.white, fontWeight: FontWeight.w600);
    return NotebookPage(
      title: en ? 'Laws and standards' : 'Textes et normes',
      actions: [
        Tooltip(
          message: en ? 'Lire en français' : 'Read in English',
          child: TextButton(
            key: const Key('regulations-language'),
            onPressed: () => state.setLessonsInEnglish(!en),
            child: Text(
              en ? 'FR' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
      children: [
        GradientBanner(
          tone: Tone.violet,
          toTone: Tone.blue,
          seed: 81,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                en ? '📜 Laws and standards' : '📜 Textes et normes',
                style: TextStyle(
                  fontFamily: Hand.title,
                  fontSize: Hand.tsize(34),
                  fontWeight: Hand.titleWeight,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(t(regs.intro), style: white),
              const SizedBox(height: 6),
              Text(
                '${regs.sheets.length} ${en ? 'sheets' : 'fiches'} · '
                '${t(regs.notice)}',
                style: white.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('regulations-filter'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: en
                ? 'Filter: GDPR, cloud, ICS…'
                : 'Filtrer : RGPD, cloud, industriel…',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        for (final (gi, g) in regs.groups.indexed)
          if (g.items.any(_matches))
            NotePanel(
              title: t(g.title),
              emoji: g.emoji,
              tone: const [
                Tone.blue,
                Tone.turquoise,
                Tone.violet,
                Tone.orange,
              ][gi % 4],
              seed: 82 + gi,
              child: Column(
                children: [
                  for (final s in g.items.where(_matches))
                    _SheetCard(
                      key: _keys.putIfAbsent(s.id, GlobalKey.new),
                      sheet: s,
                      english: en,
                      open: _open.contains(s.id) || _query.isNotEmpty,
                      onToggle: () => setState(() {
                        if (!_open.remove(s.id)) _open.add(s.id);
                      }),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({
    super.key,
    required this.sheet,
    required this.english,
    required this.open,
    required this.onToggle,
  });

  final RegulationSheet sheet;
  final bool english;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    final brightness = Theme.of(context).brightness;
    String t(Bi b) => english ? b.en : b.fr;
    final body = Hand.sansText(context, size: 15);
    final small = Hand.sansText(
      context,
      size: 13,
    ).copyWith(color: paper.inkSoft);
    final library = AppScope.of(context).library;
    final lessons = [for (final id in sheet.lessons) library.lesson(id)];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: HandBox(
        fill: paper.page,
        stroke: paper.rule,
        strokeWidth: 1.6,
        seed: sheet.id.hashCode % 50,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: Key('sheet-${sheet.id}'),
              onTap: onToggle,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheet.name,
                          style: Hand.subtitle(
                            context,
                            Tone.blue,
                          ).copyWith(fontSize: Hand.tsize(26)),
                        ),
                        Text(
                          t(sheet.title),
                          style: body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${t(sheet.nature)} · ${t(sheet.reference)}',
                          style: small,
                        ),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (open) ...[
              const SizedBox(height: 8),
              Text('🗓️ ${t(sheet.status)}', style: small),
              const SizedBox(height: 10),
              NoteBox(
                tone: Tone.blue,
                label: english ? 'Definition' : 'Définition',
                emoji: '📘',
                seed: 3,
                child: Text(t(sheet.definition), style: body),
              ),
              const SizedBox(height: 10),
              Text(
                english ? '🔑 Key points' : '🔑 L\'essentiel à savoir',
                style: body.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              HandBullets([
                for (final e in sheet.essentials) t(e),
              ], style: body),
              const SizedBox(height: 6),
              NoteBox(
                tone: Tone.orange,
                label: english ? 'Remember' : 'À retenir',
                emoji: '💡',
                seed: 5,
                child: Text(t(sheet.remember), style: body),
              ),
              if (lessons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  english ? '📚 In this course' : '📚 Dans la formation',
                  style: body.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in lessons)
                      ActionChip(
                        avatar: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(
                          english
                              ? (library.englishLesson(l.id)?.title ?? l.title)
                              : l.title,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LessonPage(lesson: l),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                english
                    ? '🔗 Learn more (official sources, online)'
                    : '🔗 Pour en savoir plus (sources officielles, en ligne)',
                style: body.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              for (final link in sheet.links)
                _LinkTile(
                  link: link,
                  english: english,
                  color: toneColors(Tone.blue, brightness).ink,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lien externe : ouvre le navigateur ; à défaut, copie l'adresse.
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.link,
    required this.english,
    required this.color,
  });

  final RegulationLink link;
  final bool english;
  final Color color;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(link.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: link.url));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          english
              ? 'Could not open the browser: link copied.'
              : 'Impossible d\'ouvrir le navigateur : lien copié.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return InkWell(
      onTap: () => _open(context),
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: link.url));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(english ? 'Link copied.' : 'Lien copié.')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.open_in_new, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english ? link.label.en : link.label.fr,
                    style: Hand.sansText(context, size: 14.5).copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  Text(
                    link.url,
                    style: Hand.sansText(
                      context,
                      size: 12,
                    ).copyWith(color: paper.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
