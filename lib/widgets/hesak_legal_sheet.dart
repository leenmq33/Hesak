import 'package:flutter/material.dart';
import '../core/data/hesak_legal_texts.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_text_styles.dart';

// =====================================================================
//  HESAK LEGAL SHEET — الشروط والأحكام / سياسة الخصوصية
//
//  A big window that rises from the bottom (90% of the screen):
//    grab handle · title + ✕ · "آخر تحديث: ..."
//    the text (scrolls): purple numbered titles, paragraphs, bullet points
//    "حسنًا" at the bottom
//  Closes with ✕, "حسنًا", tapping outside, or dragging it down.
//  Follows فاتح / داكن (colors come from HesakColors).
//
//  How to use:
//    showHesakLegalSheet(context, hesakTermsDoc);   // الشروط والأحكام
//    showHesakLegalSheet(context, hesakPrivacyDoc); // سياسة الخصوصية
//
//  The texts live in lib/core/data/hesak_legal_texts.dart.
//  NAMING: everything here starts with "Hesak". Keys: 'hesak_legal_<name>'.
// =====================================================================

/// Opens [doc] (الشروط والأحكام or سياسة الخصوصية) in the bottom window.
Future<void> showHesakLegalSheet(BuildContext context, HesakLegalDoc doc) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // Can be tall (90% of the screen)
    useRootNavigator: true,
    backgroundColor: Colors.transparent, // The sheet draws its own rounded top
    builder: (_) => _HesakLegalSheet(doc: doc),
  );
}

class _HesakLegalSheet extends StatelessWidget {
  final HesakLegalDoc doc;

  const _HesakLegalSheet({required this.doc});

  @override
  Widget build(BuildContext context) {
    // Drag the text up / down; drag further down to close.
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        key: Key('hesak_legal_sheet_${doc.title}'),
        decoration: BoxDecoration(
          color: HesakColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Grab handle ----
            Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: HesakColors.primaryLightBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            // ---- Title + ✕, then "آخر تحديث" ----
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      style: HesakTextStyles.dialogTitle.copyWith(color: HesakColors.primaryDark, fontSize: 19),
                    ),
                  ),
                  IconButton(
                    key: Key('hesak_legal_close_button'),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: HesakColors.textSecondary),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('آخر تحديث: $hesakLegalUpdatedAt', style: HesakTextStyles.caption),
            ),
            SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: HesakColors.cardTitleLine),

            // ---- The text (scrolls) ----
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                children: _buildBlocks(doc.body),
              ),
            ),

            // ---- حسنًا ----
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Material(
                  color: HesakColors.modeSelected,
                  shape: StadiumBorder(),
                  child: InkWell(
                    key: Key('hesak_legal_ok_button'),
                    customBorder: StadiumBorder(),
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      height: 46,
                      child: Center(
                        child: Text('حسنًا', style: HesakTextStyles.buttonLabel.copyWith(fontSize: 16)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Turns the simple text format into widgets:
  ///   "1. ..." = purple section title, "* ..." = bullet point, other lines = paragraph.
  static List<Widget> _buildBlocks(String body) {
    final RegExp sectionTitle = RegExp(r'^\d+\.\s');
    final TextStyle paragraphStyle = HesakTextStyles.body.copyWith(
      color: HesakColors.textPrimary,
      fontSize: 13.5,
      height: 1.75,
    );
    final List<Widget> blocks = [];

    for (final String rawLine in body.split('\n')) {
      final String line = rawLine.trim();
      if (line.isEmpty) continue;

      if (sectionTitle.hasMatch(line)) {
        // Section title (e.g. "1. عن حِسّك").
        blocks.add(Padding(
          padding: EdgeInsets.only(top: 14, bottom: 4),
          child: Text(line, style: HesakTextStyles.itemTitle.copyWith(color: HesakColors.modeSelected, fontSize: 15)),
        ));
      } else if (line.startsWith('* ')) {
        // Bullet point: the words before ":" are bold.
        final String text = line.substring(2).trim();
        final int colon = text.indexOf(':');
        blocks.add(Padding(
          padding: EdgeInsetsDirectional.only(start: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 9),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: HesakColors.modeSelected),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  colon > 0
                      ? TextSpan(children: [
                          TextSpan(text: text.substring(0, colon + 1), style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: text.substring(colon + 1)),
                        ])
                      : TextSpan(text: text),
                  style: paragraphStyle,
                ),
              ),
            ],
          ),
        ));
      } else {
        // Paragraph.
        blocks.add(Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(line, style: paragraphStyle),
        ));
      }
    }
    return blocks;
  }
}

/// Small purple link that opens a legal text (used next to the terms checkbox).
class HesakLegalLink extends StatelessWidget {
  final String label;
  final HesakLegalDoc doc;
  final TextStyle style;

  const HesakLegalLink({super.key, required this.label, required this.doc, required this.style});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Wins over the checkbox row behind it: opens the text, doesn't tick the box.
      onTap: () => showHesakLegalSheet(context, doc),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2), // A bit easier to tap
        child: Text(
          label,
          style: style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: style.color,
          ),
        ),
      ),
    );
  }
}
