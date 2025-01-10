import 'package:flutter/material.dart';

class Mandala extends StatefulWidget {
  const Mandala({super.key});

  @override
  State<Mandala> createState() => _MandalaState();
}

class _MandalaState extends State<Mandala> {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        shape: BoxShape.circle, // Makes the container a circle
        gradient: RadialGradient(
          colors: [
            Color(0xFFEEFFBB),
            Color(0xFF00B481),
            Color(0xFF1B318F),
            Color(0xFF9E2B3D),
            Color(0xFFFF9A6B),
          ], //
          stops: [0, 0.28, 0.62, 0.7, 1],
        ),
        //glow
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(153, 255, 165, 63),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}
