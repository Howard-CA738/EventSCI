import 'package:flutter/material.dart';

class PColores {
  static const primary = Color(0xFF1E3A5F);
  static const primaryLight = Color(0xFF2D5590);
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFB0BEC5);
  static const bronze = Color(0xFFCD7F32);
  static const textSecondary = Color(0xFF64748B);
  static const bg = Color(0xFFEEF2F7);
}

enum ModoVista { lista, tabla }

Color posColor(int pos, bool tieneEval) {
  if (!tieneEval) return Colors.grey.shade400;
  if (pos == 0) return PColores.gold;
  if (pos == 1) return PColores.silver;
  if (pos == 2) return PColores.bronze;
  return PColores.primaryLight;
}

String posIcono(int pos, bool tieneEval) {
  if (!tieneEval) return '—';
  if (pos == 0) return '🥇';
  if (pos == 1) return '🥈';
  if (pos == 2) return '🥉';
  return '${pos + 1}°';
}
