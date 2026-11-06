import 'package:flutter/material.dart';

import '../textos.dart';

/// Indicador compacto del tipo de conexion en la pestana de la sesion remota:
/// punto de color + "Directa" / "Retransmitida" (o "Sin cifrar" en ambar si no va cifrada).
Widget pcEstadoConexion(bool cifrada, bool directa) {
  final color = !cifrada
      ? const Color(0xFFF0A13A)
      : directa
          ? const Color(0xFF2FBF71)
          : const Color(0xFF38B6E8);
  final texto = !cifrada
      ? pcT('Unencrypted')
      : directa
          ? pcT('Direct')
          : pcT('Relayed');
  return Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          texto,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );
}
