import 'package:flutter/material.dart';

class GColores {
  static const primary = Color(0xFF1E3A5F);
  static const primaryLight = Color(0xFF2D5590);
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFB0BEC5);
  static const bronze = Color(0xFFCD7F32);
  static const textSecondary = Color(0xFF64748B);

  static const Color cuarto = Color(0xFF78909C);
  static const podioColors = [gold, silver, bronze, cuarto];
  static const podioFondos = [
    Color(0xFFFFFDE7),
    Color(0xFFF5F5F5),
    Color(0xFFFBE9E7),
    Color(0xFFECEFF1),
  ];
  static const podioIconos = ['🥇', '🥈', '🥉', '🏅'];
  static const podioEtiquetas = [
    '1er lugar',
    '2do lugar',
    '3er lugar',
    '4to lugar'
  ];
}

enum ModoVistaGanadores { lista, tabla, grafico }
