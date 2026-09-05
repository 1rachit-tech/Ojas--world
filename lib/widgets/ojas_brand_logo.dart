import 'package:flutter/material.dart';

class OjasBrandLogo extends StatelessWidget {
  const OjasBrandLogo({super.key, this.fontSize = 21});

  final double fontSize;

  static const LinearGradient _gradient = LinearGradient(
    colors: <Color>[
      Color(0xFF00E5FF),
      Color(0xFF0066FF),
      Color(0xFF8A00FF),
      Color(0xFFFF007A),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => _gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        'OJAS',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
