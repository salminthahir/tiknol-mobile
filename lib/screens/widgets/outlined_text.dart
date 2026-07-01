import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

/// Renders text with an outlined (stroked) style, emulating the
/// `WebkitTextStroke` effect used on nol.coffee ("CULTURE", "OUTLETS").
///
/// Uses two stacked [Text] widgets: one paints the stroke via
/// [TextStyle.foreground] (Paint style = stroke), the other paints the
/// fill. Multiline (`\n`) is supported by default.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.data, {
    super.key,
    required this.fontSize,
    this.strokeWidth = 2,
    this.strokeColor = AppColors.reserveOutline,
    this.fillColor = Colors.transparent,
    this.fontWeight = FontWeight.w900,
    this.letterSpacing = -1,
    this.height = 0.85,
    this.fontFamily,
    this.textAlign = TextAlign.left,
  });

  final String data;
  final double fontSize;
  final double strokeWidth;
  final Color strokeColor;
  final Color fillColor;
  final FontWeight fontWeight;
  final double letterSpacing;
  final double height;
  final String? fontFamily;
  final TextAlign textAlign;

  TextStyle _baseStyle() {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      fontFamily: fontFamily,
    );
    return fontFamily == null ? GoogleFonts.inter().merge(style) : style;
  }

  @override
  Widget build(BuildContext context) {
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = strokeColor;

    return Stack(
      children: [
        Text(
          data,
          textAlign: textAlign,
          style: _baseStyle().copyWith(foreground: strokePaint),
        ),
        Text(
          data,
          textAlign: textAlign,
          style: _baseStyle().copyWith(color: fillColor),
        ),
      ],
    );
  }
}
