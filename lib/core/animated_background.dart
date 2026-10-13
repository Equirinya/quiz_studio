import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

/// The slowly shifting orange/magenta mesh gradient used behind onboarding.
Widget animatedBackground() => AnimatedMeshGradient(
  colors: const [
    Color.fromARGB(255, 246, 108, 93),
    Color.fromARGB(255, 204, 76, 216),
    Color.fromARGB(255, 255, 72, 0),
    Color.fromARGB(255, 255, 161, 68),
  ],
  options: AnimatedMeshGradientOptions(speed: 0.1),
);
