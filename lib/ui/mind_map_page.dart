import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../export/pdf_export.dart';
import '../export/mind_map_html.dart';
import '../export/pdf_save.dart';
import '../logic/study_groups.dart';
import '../logic/terms.dart';
import '../models/content.dart';
import 'course_view_bar.dart';
import 'notebook/hand_drawn.dart';
import 'notebook/page_kit.dart';
import 'notebook/look.dart';
import 'notebook/palette.dart';
import 'notebook/typography.dart';

// ---------------------------------------------------------------------------
// Construction des cartes : chapitre, module, formation entière.
// ---------------------------------------------------------------------------

/// Carte d'un chapitre : celle rédigée dans le contenu, sinon le plan des leçons.
MindNode chapterMindMap(Chapter chapter) =>
    chapter.mindMap ??
    MindNode(
      label: chapter.title,
      en: chapter.titleEn,
      children: [
        for (final l in chapter.lessons)
          MindNode(
            label: l.title,
            children: [
              for (final b in l.blocks)
                if (b.type == BlockType.heading && (b.text ?? '').isNotEmpty)
                  MindNode(label: b.text!),
            ],
          ),
      ],
    );

/// Carte d'un module : ses chapitres, et pour chacun les branches de sa carte.
MindNode moduleMindMap(Module module) {
  final (_, emoji) = moduleStyle(module.number);
  return MindNode(
    label: 'Module ${module.number}\n${module.title}',
    en: module.titleEn,
    emoji: emoji,
    children: [
      for (final (i, c) in module.chapters.indexed)
        c.available
            ? MindNode(
                label: '${module.number}.${i + 1} ${c.title}',
                en: c.titleEn,
                children: chapterMindMap(c).children,
              )
            : MindNode(
                label: '${module.number}.${i + 1} ${c.title}',
                en: c.titleEn,
                children: const [MindNode(label: '🔒 Bientôt disponible')],
              ),
    ],
  );
}

/// Section du livre : ses mots-clés essentiels (français et anglais) ; les
/// leçons qui la traitent sont rappelées dans le détail. Sans mots-clés, les
/// titres des leçons.
MindNode _sectionNode(
  ContentLibrary library,
  OutlineSection s, {
  bool keywords = true,
}) {
  final lessons = [for (final id in s.lessons) library.lesson(id).title];
  return MindNode(
    label: 'Section ${s.number} · ${s.titleFr}',
    en: s.titleEn,
    detail: lessons.isEmpty
        ? null
        : '${lessons.length > 1 ? 'Leçons' : 'Leçon'} : ${lessons.join(' ; ')}',
    children: [
      if (keywords && s.keywords.isNotEmpty)
        for (final k in s.keywords)
          MindNode(label: k.fr, en: k.en == k.fr ? null : k.en)
      else if (keywords)
        for (final t in lessons) MindNode(label: t),
    ],
  );
}

/// Carte d'un module de la vue choisie. Pour le livre MILE2 : ses sections
/// et leurs mots-clés essentiels ; pour ORSYS : la carte
/// du module et de ses chapitres.
MindNode groupMindMap(ContentLibrary library, StudyGroup g) {
  final outline = g.outline;
  if (outline == null) {
    return moduleMindMap(
      library.modules.firstWhere((m) => m.number == g.moduleNumber),
    );
  }
  final (tone, emoji) = groupStyle(g);
  return MindNode(
    label: '${g.label}\n${g.title}',
    en: g.titleEn,
    emoji: emoji,
    tone: tone.name,
    children: [for (final s in outline.sections) _sectionNode(library, s)],
  );
}

/// Carte de toute la formation dans la vue [view] : modules, puis chapitres
/// et grandes idées (ORSYS) ou sections (livre MILE2), et les
/// domaines officiels de l'examen avec leur poids.
MindNode courseMindMap(ContentLibrary library, {CourseView? view}) {
  if (view == CourseView.mile2 && library.mile2Outline.modules.isNotEmpty) {
    return MindNode(
      label: 'CISSO MILE2\nToute la formation',
      emoji: '🎓',
      children: [
        for (final g in studyGroups(library, CourseView.mile2))
          MindNode(
            label: g.fullTitle,
            en: g.titleEn,
            emoji: groupStyle(g).$2,
            tone: groupStyle(g).$1.name,
            children: [
              for (final s in g.outline!.sections)
                _sectionNode(library, s, keywords: false),
            ],
          ),
        _domainsNode(library),
      ],
    );
  }
  return MindNode(
    label: 'CISSO MILE2\nToute la formation',
    emoji: '🎓',
    children: [
      for (final m in library.modules)
        MindNode(
          label: 'Module ${m.number} · ${m.title}',
          en: m.titleEn,
          emoji: moduleStyle(m.number).$2,
          tone: moduleStyle(m.number).$1.name,
          children: [
            for (final (i, c) in m.chapters.indexed)
              MindNode(
                label: '${m.number}.${i + 1} ${c.title}',
                en: c.titleEn,
                children: c.available
                    ? [
                        for (final b in chapterMindMap(c).children)
                          MindNode(label: b.label, en: b.en, emoji: b.emoji),
                      ]
                    : const [MindNode(label: '🔒 Bientôt disponible')],
              ),
          ],
        ),
      _domainsNode(library),
    ],
  );
}

MindNode _domainsNode(ContentLibrary library) => MindNode(
  label: 'Les ${library.domains.length} domaines de l\'examen',
  emoji: '🎯',
  tone: 'red',
  detail: 'Poids officiels du blueprint MILE2 (${library.examInfo.source}).',
  children: [
    for (final d in [
      ...library.domains,
    ]..sort((a, b) => b.weight.compareTo(a.weight)))
      MindNode(label: '${d.nameFr} · ${d.weight}\u00a0%', en: d.nameEn),
  ],
);

/// Complète les nœuds sans terme anglais grâce au glossaire.
MindNode withEnglish(MindNode n, TermIndex terms) => MindNode(
  label: n.label,
  en: n.en ?? terms.englishFor(n.label),
  emoji: n.emoji,
  detail: n.detail,
  tone: n.tone,
  children: [for (final c in n.children) withEnglish(c, terms)],
);

Tone _toneNamed(String? name, Tone fallback) =>
    Tone.values.firstWhere((t) => t.name == name, orElse: () => fallback);

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class MindMapPage extends StatefulWidget {
  const MindMapPage({
    super.key,
    required this.title,
    required this.root,
    this.exportOnOpen = false,
    this.htmlOnOpen = false,
  });

  final String title;
  final MindNode root;

  /// Ouvre la carte puis lance tout de suite l'export PDF.
  final bool exportOnOpen;

  /// Ouvre la carte puis lance tout de suite l'export HTML interactif.
  final bool htmlOnOpen;

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  /// Chemins des nœuds repliés (ex. « 0/2 »).
  late Set<String> _collapsed = _defaultCollapsed();
  bool? _listView;
  final _transform = TransformationController();
  Size? _fittedFor;
  final _canvasKey = GlobalKey();
  MindNode? _enriched;
  bool _exporting = false;

  /// La carte, complétée des termes anglais du glossaire.
  MindNode _root(BuildContext context) => _enriched ??= switch (context
      .getInheritedWidgetOfExactType<AppScope>()
      ?.notifier) {
    final state? => withEnglish(widget.root, state.terms),
    null => widget.root,
  };

  /// Crée le PDF : la carte dessinée en arborescence, puis son plan.
  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final root = _root(context);
    try {
      await exportPdf(
        context,
        title: 'Carte mentale ${widget.title}',
        build: () =>
            mindMapPdf(title: 'Carte mentale · ${widget.title}', root: root),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Crée la page HTML interactive, autonome et utilisable hors ligne.
  Future<void> _exportHtml() async {
    final root = _root(context);
    await exportHtml(
      context,
      title: 'Carte mentale ${widget.title}',
      build: () =>
          mindMapHtml(title: 'Carte mentale · ${widget.title}', root: root),
    );
  }

  Set<String> _defaultCollapsed() {
    final out = <String>{};
    void walk(MindNode n, String path, int depth) {
      if (depth >= 2 && n.children.isNotEmpty) out.add(path);
      for (final (i, c) in n.children.indexed) {
        walk(c, '$path/$i', depth + 1);
      }
    }

    walk(widget.root, '0', 0);
    return out;
  }

  void _toggle(String path) => setState(() {
    _collapsed.contains(path) ? _collapsed.remove(path) : _collapsed.add(path);
  });

  // Sur le web, les polices manuscrites arrivent après le premier affichage :
  // on recalcule alors la taille des bulles.
  void _fontsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    if (widget.exportOnOpen) {
      // Laisse le temps aux polices manuscrites de se charger.
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _exportPdf();
      });
    } else if (widget.htmlOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _exportHtml();
      });
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final list = _listView ?? !wide;
    return Scaffold(
      backgroundColor: Paper.of(context).background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!list) ...[
            IconButton(
              tooltip: 'Tout déplier',
              icon: const Icon(Icons.unfold_more),
              onPressed: () => setState(() => _collapsed = {}),
            ),
            IconButton(
              tooltip: 'Tout replier',
              icon: const Icon(Icons.unfold_less),
              onPressed: () => setState(() => _collapsed = _defaultCollapsed()),
            ),
          ],
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<String>(
                  tooltip: 'Télécharger',
                  icon: const Icon(Icons.download_outlined),
                  onSelected: (choice) =>
                      choice == 'html' ? _exportHtml() : _exportPdf(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined),
                        title: Text('PDF zoomable'),
                        subtitle: Text(
                          'Carte générale cliquable, une page par branche',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'html',
                      child: ListTile(
                        leading: Icon(Icons.web_outlined),
                        title: Text('Page HTML interactive'),
                        subtitle: Text(
                          'Un seul fichier, hors ligne, branches à déplier',
                        ),
                      ),
                    ),
                  ],
                ),
          IconButton(
            tooltip: list ? 'Voir la carte' : 'Voir la liste',
            icon: Icon(list ? Icons.account_tree_outlined : Icons.list_alt),
            onPressed: () => setState(() => _listView = !list),
          ),
        ],
      ),
      body: list
          ? _MindOutline(root: _root(context))
          : LayoutBuilder(
              builder: (context, box) {
                final layout = _MindLayout.compute(
                  context,
                  _root(context),
                  _collapsed,
                );
                // Premier affichage : la carte entière tient dans l'écran.
                if (_fittedFor == null) {
                  _fittedFor = layout.size;
                  final scale = min(
                    1.0,
                    min(
                      box.maxWidth / layout.size.width,
                      box.maxHeight / layout.size.height,
                    ),
                  ).clamp(0.25, 1.0);
                  final dx = (box.maxWidth - layout.size.width * scale) / 2;
                  final dy = max(
                    0.0,
                    (box.maxHeight - layout.size.height * scale) / 2,
                  );
                  _transform.value = Matrix4.identity()
                    ..translateByDouble(max(0.0, dx), dy, 0, 1)
                    ..scaleByDouble(scale, scale, 1, 1);
                }
                return InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(400),
                  minScale: 0.2,
                  maxScale: 2.5,
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: _MindCanvas(
                      layout: layout,
                      collapsed: _collapsed,
                      onToggle: _toggle,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mise en page de la carte (deux côtés, comme une carte mentale classique)
// ---------------------------------------------------------------------------

class _Placed {
  _Placed({
    required this.node,
    required this.path,
    required this.depth,
    required this.tone,
    required this.right,
    required this.parent,
  });

  final MindNode node;
  final String path;
  final int depth;
  final Tone tone;
  final bool right;
  final _Placed? parent;
  Rect rect = Rect.zero;
}

class _MindLayout {
  _MindLayout(this.nodes, this.size);

  final List<_Placed> nodes;
  final Size size;

  static const margin = 40.0;
  static const hgap = 54.0;
  static const centerW = 230.0;

  static double colW(int depth) => switch (depth) {
    1 => 200,
    2 => 250,
    _ => 230,
  };

  static double nodeHeight(BuildContext context, MindNode n, int depth) {
    final scaler = MediaQuery.textScalerOf(context);
    double h(String text, TextStyle style, double width) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: width);
      return tp.height;
    }

    if (depth == 0) {
      return max(
        90,
        h(n.label, _Styles.center, centerW - 32) +
            28 +
            (n.emoji != null ? 30 : 0),
      );
    }
    final inner = colW(depth) - 30;
    if (depth == 1) {
      return h([?n.emoji, n.label].join(' '), _Styles.branch, inner) +
          22 +
          (n.en != null ? h(n.en!, _Styles.en, inner) + 2 : 0);
    }
    var total = h(
      [?n.emoji, n.label].join(' '),
      depth == 2
          ? _Styles.leaf.copyWith(fontWeight: FontWeight.w700)
          : _Styles.leaf,
      inner,
    );
    if (n.en != null) total += h(n.en!, _Styles.en, inner) + 2;
    if (n.detail != null) total += h(n.detail!, _Styles.detail, inner) + 4;
    return total + 22;
  }

  static _MindLayout compute(
    BuildContext context,
    MindNode root,
    Set<String> collapsed,
  ) {
    final heights = <String, double>{};
    final subtree = <String, double>{};

    double gapFor(int depth) => depth == 1 ? 22 : 10;

    double measure(MindNode n, String path, int depth) {
      final h = nodeHeight(context, n, depth);
      heights[path] = h;
      var kids = 0.0;
      if (!collapsed.contains(path) && n.children.isNotEmpty) {
        for (final (i, c) in n.children.indexed) {
          kids += measure(c, '$path/$i', depth + 1);
        }
        kids += gapFor(depth + 1) * (n.children.length - 1);
      }
      return subtree[path] = max(h, kids);
    }

    measure(root, '0', 0);

    final branches = root.children;
    final rightCount = (branches.length / 2).ceil();
    final right = [for (var i = 0; i < rightCount; i++) i];
    final left = [for (var i = rightCount; i < branches.length; i++) i];

    int maxDepth(MindNode n, String path, int depth) {
      if (collapsed.contains(path) || n.children.isEmpty) return depth;
      var d = depth;
      for (final (i, c) in n.children.indexed) {
        d = max(d, maxDepth(c, '$path/$i', depth + 1));
      }
      return d;
    }

    double extent(List<int> side) {
      var d = 0;
      for (final i in side) {
        d = max(d, maxDepth(branches[i], '0/$i', 1));
      }
      var w = 0.0;
      for (var k = 1; k <= d; k++) {
        w += colW(k) + hgap;
      }
      return w;
    }

    double sideHeight(List<int> side) {
      if (side.isEmpty) return 0;
      return side.fold<double>(0, (s, i) => s + subtree['0/$i']!) +
          gapFor(1) * (side.length - 1);
    }

    final leftExtent = extent(left);
    final rightExtent = extent(right);
    final innerH = max(heights['0']!, max(sideHeight(right), sideHeight(left)));
    final size = Size(
      margin * 2 + leftExtent + centerW + rightExtent,
      margin * 2 + innerH,
    );
    final cx = margin + leftExtent + centerW / 2;
    final cy = margin + innerH / 2;

    double colX(int depth, bool isRight) {
      var offset = hgap;
      for (var k = 1; k < depth; k++) {
        offset += colW(k) + hgap;
      }
      return isRight
          ? cx + centerW / 2 + offset
          : cx - centerW / 2 - offset - colW(depth);
    }

    final placed = <_Placed>[];
    final rootPlaced =
        _Placed(
            node: root,
            path: '0',
            depth: 0,
            tone: Tone.blue,
            right: true,
            parent: null,
          )
          ..rect = Rect.fromCenter(
            center: Offset(cx, cy),
            width: centerW,
            height: heights['0']!,
          );
    placed.add(rootPlaced);

    void place(
      MindNode n,
      String path,
      int depth,
      double top,
      Tone tone,
      bool isRight,
      _Placed parent,
    ) {
      final h = heights[path]!;
      final sub = subtree[path]!;
      final p =
          _Placed(
              node: n,
              path: path,
              depth: depth,
              tone: tone,
              right: isRight,
              parent: parent,
            )
            ..rect = Rect.fromLTWH(
              colX(depth, isRight),
              top + (sub - h) / 2,
              colW(depth),
              h,
            );
      placed.add(p);
      if (collapsed.contains(path) || n.children.isEmpty) return;
      var kidsH = 0.0;
      for (final (i, _) in n.children.indexed) {
        kidsH += subtree['$path/$i']!;
      }
      kidsH += gapFor(depth + 1) * (n.children.length - 1);
      var y = top + (sub - kidsH) / 2;
      for (final (i, c) in n.children.indexed) {
        place(
          c,
          '$path/$i',
          depth + 1,
          y,
          _toneNamed(c.tone, tone),
          isRight,
          p,
        );
        y += subtree['$path/$i']! + gapFor(depth + 1);
      }
    }

    void placeSide(List<int> side, bool isRight) {
      var y = margin + (innerH - sideHeight(side)) / 2;
      for (final i in side) {
        final b = branches[i];
        final tone = _toneNamed(b.tone, rainbowTones[i % rainbowTones.length]);
        place(b, '0/$i', 1, y, tone, isRight, rootPlaced);
        y += subtree['0/$i']! + gapFor(1);
      }
    }

    placeSide(right, true);
    placeSide(left, false);
    return _MindLayout(placed, size);
  }
}

class _Styles {
  static TextStyle get center => TextStyle(
    letterSpacing: 0,
    wordSpacing: 0,
    fontFamily: Hand.title,
    fontSize: Hand.tsize(26),
    height: 1.1,
    fontWeight: Hand.titleWeight,
  );
  static TextStyle get branch => TextStyle(
    letterSpacing: 0,
    wordSpacing: 0,
    fontFamily: Hand.title,
    fontSize: Hand.tsize(23),
    height: 1.1,
    fontWeight: Hand.titleWeight,
  );
  static TextStyle get leaf => TextStyle(
    letterSpacing: 0,
    wordSpacing: 0,
    fontFamily: Hand.body,
    fontSize: Hand.bsize(17),
    height: 1.25,
  );
  static TextStyle get en => TextStyle(
    letterSpacing: 0,
    wordSpacing: 0,
    fontFamily: Hand.sans,
    fontSize: 12,
    height: 1.3,
    fontStyle: FontStyle.italic,
  );
  static TextStyle get detail => TextStyle(
    letterSpacing: 0,
    wordSpacing: 0,
    fontFamily: Hand.note,
    fontSize: Hand.bsize(13.5),
    height: 1.35,
  );
}

// ---------------------------------------------------------------------------
// Dessin de la carte
// ---------------------------------------------------------------------------

class _MindCanvas extends StatelessWidget {
  const _MindCanvas({
    required this.layout,
    required this.collapsed,
    required this.onToggle,
  });

  final _MindLayout layout;
  final Set<String> collapsed;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final paper = Paper.of(context);
    return SizedBox.fromSize(
      size: layout.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LinksPainter(layout, paper.page)),
          ),
          for (final p in layout.nodes)
            Positioned.fromRect(
              rect: p.rect,
              child: _MindNodeCard(
                placed: p,
                collapsed: collapsed.contains(p.path),
                onTap: p.node.children.isEmpty || p.depth == 0
                    ? null
                    : () => onToggle(p.path),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinksPainter extends CustomPainter {
  _LinksPainter(this.layout, this.background);

  final _MindLayout layout;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    for (final p in layout.nodes) {
      final parent = p.parent;
      if (parent == null) continue;
      final from = p.right
          ? Offset(parent.rect.right, parent.rect.center.dy)
          : Offset(parent.rect.left, parent.rect.center.dy);
      final to = p.right
          ? Offset(p.rect.left, p.rect.center.dy)
          : Offset(p.rect.right, p.rect.center.dy);
      final midX = (from.dx + to.dx) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = toneBright(p.tone)
              .withValues(alpha: p.depth == 1 ? 0.9 : 0.7)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = switch (p.depth) {
            1 => 5,
            2 => 3,
            _ => 2,
          },
      );
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) => old.layout != layout;
}

class _MindNodeCard extends StatelessWidget {
  const _MindNodeCard({
    required this.placed,
    required this.collapsed,
    required this.onTap,
  });

  final _Placed placed;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = placed.node;
    final brightness = Theme.of(context).brightness;
    final c = toneColors(placed.tone, brightness);
    final paper = Paper.of(context);
    final hidden = n.children.isEmpty ? 0 : n.children.length;

    Widget body;
    switch (placed.depth) {
      case 0:
        body = Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(60),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppLook.active.heroGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: AppLook.active.heroGradient[1].withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (n.emoji != null)
                Text(n.emoji!, style: const TextStyle(fontSize: 24)),
              Text(
                n.label,
                textAlign: TextAlign.center,
                style: _Styles.center.copyWith(color: Colors.white),
              ),
            ],
          ),
        );
      case 1:
        body = Container(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: [c.ink, toneBright(placed.tone)]),
            boxShadow: [
              BoxShadow(
                color: toneBright(placed.tone).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [?n.emoji, n.label].join(' '),
                style: _Styles.branch.copyWith(color: Colors.white),
              ),
              if (n.en != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    n.en!,
                    style: _Styles.en.copyWith(color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      default:
        body = HandBox(
          fill: placed.depth == 2 ? c.fill : paper.card,
          stroke: toneBright(placed.tone),
          strokeWidth: placed.depth == 2 ? 2 : 1.4,
          shadow: placed.depth == 2,
          radius: 12,
          seed: placed.path.hashCode,
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [?n.emoji, n.label].join(' '),
                style: _Styles.leaf.copyWith(
                  color: placed.depth == 2 ? c.ink : paper.ink,
                  fontWeight: placed.depth == 2
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              if (n.en != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    n.en!,
                    style: _Styles.en.copyWith(color: paper.inkSoft),
                  ),
                ),
              if (n.detail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    n.detail!,
                    style: _Styles.detail.copyWith(color: paper.ink),
                  ),
                ),
            ],
          ),
        );
    }

    final content = OverflowBox(
      alignment: Alignment.topLeft,
      maxHeight: double.infinity,
      child: body,
    );

    return Semantics(
      button: onTap != null,
      label: [
        n.label,
        ?n.en,
        ?n.detail,
        if (onTap != null) collapsed ? '$hidden sous-idées repliées' : 'déplié',
      ].join('. '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: ClipRect(child: content)),
            if (onTap != null)
              Positioned(
                right: placed.right ? -12 : null,
                left: placed.right ? null : -12,
                top: placed.rect.height / 2 - 12,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: toneBright(placed.tone),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    collapsed ? '+$hidden' : '−',
                    style: TextStyle(
                      fontFamily: Hand.sans,
                      fontSize: collapsed ? 10.5 : 15,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vue liste (téléphone) : la même carte, branche par branche
// ---------------------------------------------------------------------------

class _MindOutline extends StatelessWidget {
  const _MindOutline({required this.root});

  final MindNode root;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = Paper.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
          children: [
            GradientBanner(
              tone: Tone.blue,
              toTone: Tone.pink,
              seed: 201,
              child: Row(
                children: [
                  Text(
                    root.emoji ?? '🧠',
                    style: const TextStyle(fontSize: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      root.label.replaceAll('\n', ' · '),
                      style: _Styles.center.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, b) in root.children.indexed)
              Builder(
                builder: (context) {
                  final tone = _toneNamed(
                    b.tone,
                    rainbowTones[i % rainbowTones.length],
                  );
                  final c = toneColors(tone, brightness);
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: HandBox(
                      fill: paper.page,
                      stroke: toneBright(tone),
                      strokeWidth: 2.4,
                      seed: 210 + i,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [c.ink, toneBright(tone)],
                              ),
                            ),
                            child: Text(
                              [?b.emoji, b.label].join(' '),
                              style: _Styles.branch.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (b.en != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                b.en!,
                                style: _Styles.en.copyWith(color: c.ink),
                              ),
                            ),
                          if (b.detail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                b.detail!,
                                style: _Styles.detail.copyWith(
                                  color: paper.ink,
                                ),
                              ),
                            ),
                          for (final child in b.children)
                            _OutlineItem(node: child, tone: tone, depth: 0),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _OutlineItem extends StatelessWidget {
  const _OutlineItem({
    required this.node,
    required this.tone,
    required this.depth,
  });

  final MindNode node;
  final Tone tone;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final t = _toneNamed(node.tone, tone);
    final c = toneColors(t, Theme.of(context).brightness);
    final paper = Paper.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 8, left: depth * 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(
              width: depth == 0 ? 10 : 7,
              height: depth == 0 ? 10 : 7,
              decoration: BoxDecoration(
                color: toneBright(t),
                shape: depth == 0 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: depth == 0 ? null : BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [?node.emoji, node.label].join(' '),
                  style: _Styles.leaf.copyWith(
                    color: depth == 0 ? c.ink : paper.ink,
                    fontWeight: depth == 0 ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (node.en != null)
                  Text(
                    node.en!,
                    style: _Styles.en.copyWith(color: paper.inkSoft),
                  ),
                if (node.detail != null)
                  Text(
                    node.detail!,
                    style: _Styles.detail.copyWith(color: paper.ink),
                  ),
                for (final child in node.children)
                  _OutlineItem(node: child, tone: t, depth: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
