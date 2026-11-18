import 'package:material_ui/material_ui.dart';

import 'look.dart';
import 'palette.dart';
import 'typography.dart';

/// Apparence des tableaux selon le thème ([TableLook]) : bordures, en-tête
/// et lignes.
class LookTable {
  LookTable(BuildContext context)
    : look = AppLook.active,
      paper = Paper.of(context),
      head = toneColors(Tone.blue, Theme.of(context).brightness),
      _context = context;

  final AppLook look;
  final Paper paper;
  final ToneColors head;
  final BuildContext _context;

  TableBorder get border => switch (look.table) {
    TableLook.hand => TableBorder.symmetric(
      inside: BorderSide(color: paper.rule, width: 1.2),
    ),
    TableLook.grid => TableBorder.all(
      color: paper.ink.withValues(alpha: 0.35),
      width: 0.8,
    ),
    TableLook.zebra => TableBorder(
      horizontalInside: BorderSide(color: paper.rule, width: 0.8),
    ),
    TableLook.neon => TableBorder.all(
      color: head.ink.withValues(alpha: 0.6),
      width: 1,
      borderRadius: BorderRadius.circular(look.radius),
    ),
  };

  BoxDecoration get headerDecoration => switch (look.table) {
    TableLook.hand => BoxDecoration(
      color: head.fill,
      borderRadius: BorderRadius.circular(8),
    ),
    TableLook.grid => BoxDecoration(color: paper.ink.withValues(alpha: 0.07)),
    TableLook.zebra => BoxDecoration(
      color: head.ink,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(look.radius / 2),
      ),
    ),
    TableLook.neon => BoxDecoration(color: head.ink.withValues(alpha: 0.18)),
  };

  /// Fond d'une ligne de données (lignes alternées en mode « zebra »).
  BoxDecoration? row(int index) => look.table == TableLook.zebra && index.isOdd
      ? BoxDecoration(color: head.ink.withValues(alpha: 0.07))
      : null;

  TextStyle get headerStyle => switch (look.table) {
    TableLook.hand => TextStyle(
      fontFamily: Hand.title,
      fontSize: Hand.tsize(22),
      fontWeight: Hand.titleWeight,
      color: head.ink,
    ),
    TableLook.zebra => Hand.sansText(_context, size: 14).copyWith(
      fontWeight: FontWeight.w800,
      color: Theme.of(_context).brightness == Brightness.dark
          ? const Color(0xFF15171C)
          : Colors.white,
    ),
    TableLook.neon => TextStyle(
      fontFamily: Hand.mono,
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: head.ink,
    ),
    TableLook.grid => Hand.sansText(
      _context,
      size: 14,
    ).copyWith(fontWeight: FontWeight.w800, color: paper.ink),
  };
}
