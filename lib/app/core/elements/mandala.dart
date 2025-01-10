import 'dart:math';

import 'package:flutter/material.dart';

class Mandala extends StatefulWidget {
  const Mandala({super.key});

  @override
  State<Mandala> createState() => _MandalaState();
}

class _MandalaState extends State<Mandala> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 10),
    vsync: this,
  )..repeat();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle, // Makes the container a circle
          gradient: RadialGradient(
            colors: const [
              Color(0xFFEEFFBB),
              Color(0xFF00B481),
              Color(0xFF1B318F),
              Color(0xFF9E2B3D),
              Color(0xFFFF9A6B),
            ], //
            stops: [
              0,
              0.28,
              0.62 - 0.05 + 0.05 * sin(_controller.value * pi * 2),
              0.7,
              1,
            ],
          ),
          //glow
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(153, 255, 165, 63),
              blurRadius: sin(_controller.value * pi * 2) * 10 + 15,
            ),
          ],
        ),
      ),
    );
  }
}
