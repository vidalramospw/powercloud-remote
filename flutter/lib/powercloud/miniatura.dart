import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Miniatura de la ultima pantalla de cada equipo, como fondo de su tarjeta. Se guarda solo en la
/// PC del tecnico (carpeta de datos de la app). La ventana de la sesion la escribe al cerrar y la
/// ventana principal la lee del disco (son motores distintos y no comparten memoria).

String? _carpeta;

/// Se llama al arrancar cada ventana para conocer la carpeta sin esperar despues.
Future<void> pcPrepararMiniaturas() async {
  if (_carpeta != null) return;
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}miniaturas');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  _carpeta = dir.path;
}

String? _ruta(String id) {
  if (_carpeta == null || id.isEmpty) return null;
  return '$_carpeta${Platform.pathSeparator}${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.png';
}

/// Guarda una version reducida (ancho 480) de la ultima imagen de la sesion.
Future<void> pcGuardarMiniatura(String id, ui.Image? imagen) async {
  if (imagen == null || imagen.width == 0) return;
  try {
    await pcPrepararMiniaturas();
    final ruta = _ruta(id);
    if (ruta == null) return;
    const ancho = 480.0;
    final alto = (imagen.height * ancho / imagen.width).roundToDouble();
    final grabador = ui.PictureRecorder();
    Canvas(grabador).drawImageRect(
      imagen,
      Rect.fromLTWH(0, 0, imagen.width.toDouble(), imagen.height.toDouble()),
      Rect.fromLTWH(0, 0, ancho, alto),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final reducida = await grabador.endRecording().toImage(ancho.toInt(), alto.toInt());
    final datos = await reducida.toByteData(format: ui.ImageByteFormat.png);
    reducida.dispose();
    if (datos == null) return;
    await File(ruta).writeAsBytes(datos.buffer.asUint8List(), flush: true);
  } catch (_) {
    // Sin miniatura no pasa nada: la tarjeta muestra el logo del sistema.
  }
}

/// Cache en memoria por fecha de modificacion: si la sesion guarda una miniatura nueva, se recarga.
final Map<String, (DateTime, Uint8List)> _cache = {};

Uint8List? _bytes(String id) {
  final ruta = _ruta(id);
  if (ruta == null) return null;
  final f = File(ruta);
  try {
    if (!f.existsSync()) return null;
    final fecha = f.lastModifiedSync();
    final previo = _cache[ruta];
    if (previo != null && previo.$1 == fecha) return previo.$2;
    final b = f.readAsBytesSync();
    _cache[ruta] = (fecha, b);
    return b;
  } catch (_) {
    return null;
  }
}

bool pcTieneMiniatura(String id) => _bytes(id) != null;

/// Fondo de la tarjeta: la miniatura, oscurecida abajo para que el texto se lea.
Widget? pcFondoMiniatura(String id) {
  final b = _bytes(id);
  if (b == null) return null;
  return Stack(fit: StackFit.expand, children: [
    Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true),
    const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x220B1118), Color(0xD90B1118)],
        ),
      ),
    ),
  ]);
}
