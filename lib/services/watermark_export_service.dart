import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class WatermarkExportService {
  WatermarkExportService._();
  static final WatermarkExportService instance = WatermarkExportService._();

  // Draw Minimalist Luxury OJAS Watermark on Canvas
  void drawOjasWatermark({
    required Canvas canvas,
    required Size size,
    required String creatorHandle,
  }) {
    const double padding = 24.0;
    
    // Watermark Background Capsule
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - 160 - padding,
        size.height - 50 - padding,
        160,
        42,
      ),
      const Radius.circular(21),
    );
    canvas.drawRRect(rrect, paint);

    // OJAS Logo & Creator Handle Text
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: 'OJAS  ',
            style: TextStyle(
              color: Color(0xFFF5B942),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          TextSpan(
            text: creatorHandle.startsWith('@') ? creatorHandle : '@$creatorHandle',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - 150 - padding, size.height - 38 - padding),
    );
  }
}
