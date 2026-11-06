// PowerCloud: actualizador propio de PowerCloud Remote.
//
// - Consulta el portal de descargas de PowerCloud (/api/descargas/actual) al abrir y cada 4 h.
// - Muestra la version instalada y, si hay una mas nueva, un aviso con "Actualizar".
// - Descarga al temporal, verifica el SHA-256 publicado (y la firma Authenticode si la version
//   publicada esta firmada) y la aplica:
//     * instalado: ejecuta el nuevo .exe con --update (mecanismo de RustDesk; pide UAC)
//     * portable : cierra los procesos de esta copia y abre la nueva
// Nada se actualiza sin que la persona presione "Actualizar".

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart' as win32;
import 'package:window_manager/window_manager.dart';
import 'package:flutter_hbb/utils/http_service.dart' as http;

import '../common.dart';
import '../models/platform_model.dart';
import 'version.dart';

const _cadaCuanto = Duration(hours: 4);

class PcVersionPublicada {
  final String version, nombre, sha256, firmante, notas, url;
  final int tamano;
  PcVersionPublicada(Map<String, dynamic> j)
      : version = (j['version'] ?? '').toString(),
        nombre = (j['nombre'] ?? 'PowerCloudRemote.exe').toString(),
        sha256 = (j['sha256'] ?? '').toString().toUpperCase(),
        firmante = (j['firmante'] ?? '').toString(),
        notas = (j['notas'] ?? '').toString(),
        url = (j['url'] ?? '/descargas/PowerCloudRemote.exe').toString(),
        tamano = j['tamano'] is int ? j['tamano'] as int : 0;
}

/// Compara "1.5.1.42" con "1.5.1.7" numero por numero. >0 si a es mas nueva.
int pcCompararVersiones(String a, String b) {
  List<int> partes(String v) => RegExp(r'\d+')
      .allMatches(v)
      .map((m) => int.tryParse(m.group(0)!) ?? 0)
      .toList();
  final x = partes(a), y = partes(b);
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

class PcActualizador {
  PcActualizador._();
  static final instancia = PcActualizador._();

  final disponible = ValueNotifier<PcVersionPublicada?>(null);
  Timer? _timer;
  String _avisada = '';

  void iniciar() {
    if (_timer != null || !Platform.isWindows) return;
    Future.delayed(const Duration(seconds: 15), revisar);
    _timer = Timer.periodic(_cadaCuanto, (_) => revisar());
  }

  /// Consulta el portal. Devuelve la version nueva o null si ya esta al dia.
  /// Con [manual] los errores se lanzan (para avisarle a la persona); si no, se ignoran.
  Future<PcVersionPublicada?> revisar({bool manual = false}) async {
    try {
      final api = await bind.mainGetApiServer();
      final resp = await http.get(Uri.parse('$api/api/descargas/actual'));
      if (resp.statusCode != 200) throw 'El servidor respondió ${resp.statusCode}';
      final j = jsonDecode(decode_http_response(resp));
      if (j is! Map<String, dynamic> || j['error'] != null) {
        throw 'No hay versiones publicadas';
      }
      final v = PcVersionPublicada(j);
      if (v.version.isEmpty || pcCompararVersiones(v.version, kPcVersion) <= 0) {
        disponible.value = null;
        return null;
      }
      disponible.value = v;
      if (!manual && _avisada != v.version) {
        _avisada = v.version;
        showToast('Hay una nueva versión de PowerCloud Remote: ${v.version}');
      }
      return v;
    } catch (e) {
      debugPrint('PowerCloud actualizador: $e');
      if (manual) rethrow;
      return null;
    }
  }

  /// Descarga a %TEMP%\PowerCloudRemote-update y devuelve la ruta del archivo.
  Future<String> descargar(PcVersionPublicada v, void Function(double) progreso) async {
    final api = await bind.mainGetApiServer();
    final dir = Directory('${Directory.systemTemp.path}\\PowerCloudRemote-update');
    if (!await dir.exists()) await dir.create(recursive: true);
    final nombre = v.nombre.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final archivo = File('${dir.path}\\$nombre');
    final cliente = HttpClient();
    try {
      final req = await cliente.getUrl(Uri.parse('$api${v.url}'));
      final resp = await req.close();
      if (resp.statusCode != 200) throw 'El servidor respondió ${resp.statusCode}';
      final total = resp.contentLength > 0 ? resp.contentLength : v.tamano;
      final salida = archivo.openWrite();
      var recibido = 0;
      try {
        await for (final trozo in resp) {
          salida.add(trozo);
          recibido += trozo.length;
          if (total > 0) progreso(recibido / total);
        }
      } finally {
        await salida.close();
      }
    } finally {
      cliente.close();
    }
    return archivo.path;
  }

  /// SHA-256 igual al publicado y, si la version publicada esta firmada, firma valida.
  Future<void> verificar(PcVersionPublicada v, String ruta) async {
    final r = ruta.replaceAll("'", "''");
    final res = await Process.run('powershell', [
      '-NoProfile', '-NonInteractive', '-Command',
      "\$h=(Get-FileHash -Algorithm SHA256 -LiteralPath '$r').Hash; "
          "\$s=(Get-AuthenticodeSignature -LiteralPath '$r').Status; Write-Output \"\$h|\$s\"",
    ]);
    final partes = res.stdout.toString().trim().split('|');
    if (partes.length != 2) throw 'No se pudo verificar el archivo descargado';
    if (v.sha256.isEmpty || partes[0].toUpperCase() != v.sha256) {
      throw 'El archivo descargado no coincide con el publicado (SHA-256). No se instaló.';
    }
    if (v.firmante.isNotEmpty && partes[1] != 'Valid') {
      throw 'La firma digital del archivo no es válida (${partes[1]}). No se instaló.';
    }
  }

  /// Aplica la actualizacion. En la version instalada Windows pide permiso (UAC).
  ///
  /// La elevacion se pide desde esta misma ventana (ShellExecuteEx "runas" con la ventana como
  /// duena). Si la pidiera un proceso en segundo plano, Windows no muestra el aviso al frente:
  /// solo hace parpadear un boton en la barra de tareas y parece que no pasa nada.
  Future<void> aplicar(String ruta) async {
    if (bind.mainIsInstalled()) {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 200));
      _ejecutarElevado(ruta, '--update');
    } else {
      final r = ruta.replaceAll("'", "''");
      final actual = Platform.resolvedExecutable.replaceAll("'", "''");
      await Process.start('powershell', [
        '-NoProfile', '-WindowStyle', 'Hidden', '-Command',
        "Start-Sleep -Seconds 1; "
            "Get-Process | Where-Object { \$_.Path -eq '$actual' } | Stop-Process -Force; "
            "Start-Sleep -Seconds 1; Start-Process -FilePath '$r'",
      ], mode: ProcessStartMode.detached);
    }
  }

  void _ejecutarElevado(String exe, String argumentos) {
    final info = calloc<win32.SHELLEXECUTEINFO>();
    final verbo = 'runas'.toNativeUtf16();
    final archivo = exe.toNativeUtf16();
    final params = argumentos.toNativeUtf16();
    final carpeta = File(exe).parent.path.toNativeUtf16();
    try {
      final hwnd = win32.GetForegroundWindow();
      final ref = info.ref
        ..cbSize = sizeOf<win32.SHELLEXECUTEINFO>()
        ..fMask = 0x00000040 // SEE_MASK_NOCLOSEPROCESS
        ..hwnd = hwnd
        ..lpVerb = verbo
        ..lpFile = archivo
        ..lpParameters = params
        ..lpDirectory = carpeta
        ..nShow = 1; // SW_SHOWNORMAL
      if (win32.ShellExecuteEx(info) == 0) {
        final err = win32.GetLastError();
        if (err == 1223) {
          // ERROR_CANCELLED
          throw 'Se canceló el permiso de Windows. No se instaló la actualización.';
        }
        throw 'Windows no pudo iniciar la actualización (código $err).';
      }
      if (ref.hProcess != 0) win32.CloseHandle(ref.hProcess);
    } finally {
      calloc.free(verbo);
      calloc.free(archivo);
      calloc.free(params);
      calloc.free(carpeta);
      calloc.free(info);
    }
  }
}

/// Leyenda de version + aviso de actualizacion, bajo el ID en la pantalla principal.
class PcVersionBoard extends StatefulWidget {
  const PcVersionBoard({Key? key}) : super(key: key);

  @override
  State<PcVersionBoard> createState() => _PcVersionBoardState();
}

class _PcVersionBoardState extends State<PcVersionBoard> {
  @override
  void initState() {
    super.initState();
    PcActualizador.instancia.iniciar();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.titleLarge?.color;
    return ValueListenableBuilder<PcVersionPublicada?>(
      valueListenable: PcActualizador.instancia.disponible,
      builder: (context, v, _) => Container(
        margin: const EdgeInsets.only(left: 20, right: 11, top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: 'PowerCloud Remote versión $kPcVersion',
              child: Text('v$kPcVersion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: color?.withOpacity(0.4))),
            ),
            if (v != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF38B6E8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38B6E8).withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.system_update_alt, size: 16, color: Color(0xFF38B6E8)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Nueva versión',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${v.version} disponible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: color?.withOpacity(0.7))),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: () => pcDialogoActualizar(v),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38B6E8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Actualizar', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialogo para descargar, verificar y aplicar una version.
void pcDialogoActualizar(PcVersionPublicada v) {
  double? progreso;
  var msg = '';
  var trabajando = false;
  gFFI.dialogManager.show((setState, close, context) {
    Future<void> actualizar() async {
      setState(() {
        trabajando = true;
        msg = '';
        progreso = 0;
      });
      try {
        final ruta = await PcActualizador.instancia
            .descargar(v, (p) => setState(() => progreso = p));
        setState(() {
          progreso = null;
          msg = 'Verificando…';
        });
        await PcActualizador.instancia.verificar(v, ruta);
        setState(() => msg = bind.mainIsInstalled()
            ? 'Acepte el aviso de Windows para instalar la actualización. Si no lo ve, búsquelo en la barra de tareas.'
            : 'Reiniciando PowerCloud Remote con la nueva versión…');
        await PcActualizador.instancia.aplicar(ruta);
      } catch (e) {
        setState(() {
          trabajando = false;
          progreso = null;
          msg = e.toString();
        });
      }
    }

    return CustomAlertDialog(
      title: Text('Actualizar a la versión ${v.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Versión actual: $kPcVersion'),
          if (v.firmante.isNotEmpty) Text('Firmado por: ${v.firmante}'),
          if (v.notas.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Novedades', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(v.notas),
          ],
          const SizedBox(height: 10),
          const Text(
              'Si hay una sesión de soporte abierta, se cerrará al actualizar.'),
          if (progreso != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progreso),
            Text('${((progreso ?? 0) * 100).round()}%'),
          ],
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(msg),
          ],
        ],
      ),
      actions: [
        dialogButton('Cancel', onPressed: trabajando ? null : close, isOutline: true),
        dialogButton('Actualizar', onPressed: trabajando ? null : actualizar),
      ],
      onCancel: trabajando ? null : close,
    );
  });
}

/// Boton "Buscar actualizaciones" (pantalla Acerca de).
class PcBuscarActualizaciones extends StatefulWidget {
  const PcBuscarActualizaciones({Key? key}) : super(key: key);

  @override
  State<PcBuscarActualizaciones> createState() => _PcBuscarActualizacionesState();
}

class _PcBuscarActualizacionesState extends State<PcBuscarActualizaciones> {
  var _buscando = false;

  Future<void> _buscar() async {
    setState(() => _buscando = true);
    try {
      final v = await PcActualizador.instancia.revisar(manual: true);
      if (!mounted) return;
      if (v == null) {
        showToast('Ya tiene la versión más reciente ($kPcVersion).');
      } else {
        pcDialogoActualizar(v);
      }
    } catch (e) {
      showToast('No se pudo buscar actualizaciones: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _buscando ? null : _buscar,
      icon: _buscando
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.system_update_alt, size: 16),
      label: Text(_buscando ? 'Buscando…' : 'Buscar actualizaciones'),
    );
  }
}
