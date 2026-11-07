import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common.dart';
import '../common/formatter/id_formatter.dart';
import '../models/platform_model.dart';
import 'alias.dart';
import 'textos.dart';

/// Tunel TCP de PowerCloud Engine desde la PC del tecnico.
///
/// Lanza `pce-conector` (programa aparte que viaja junto a PowerCloud Remote) y muestra su estado.
/// Misma logica que el tunel de siempre: el tecnico elige el destino en el equipo del cliente y un
/// puerto local; con contrasena abre de una y sin ella la persona frente al equipo debe aceptar.

String? pcRutaConector() {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return null;
  final exe = Platform.isWindows ? 'pce-conector.exe' : 'pce-conector';
  final ruta =
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$exe';
  return File(ruta).existsSync() ? ruta : null;
}

String? pcRutaVisor() {
  if (!Platform.isWindows) return null;
  final ruta =
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}pce-visor.exe';
  return File(ruta).existsSync() ? ruta : null;
}

/// Escritorio remoto propio de PowerCloud Engine (etapa de prueba). Pide la contrasena del equipo
/// (como la conexion de siempre): con ella entra de una, tambien sin nadie frente al equipo; vacia,
/// la persona frente al equipo acepta en pantalla. Abre el visor en su propia ventana.
Future<void> pcAbrirEscritorioPropio(String idOAlias) async {
  final visor = pcRutaVisor();
  if (visor == null) return;
  if (!await pcExigirSesion()) return;
  final id = await pcResolveAlias(idOAlias.replaceAll(' ', ''));
  if (id == null) return;
  final clave = TextEditingController();
  var oculto = true;
  var recordar = bind.mainGetLocalOption(key: 'pc-engine-recordar') == 'Y';
  final aceptado = await gFFI.dialogManager.show<bool>((setState, close, context) {
    return CustomAlertDialog(
      title: Row(children: [
        const Icon(Icons.desktop_windows_outlined),
        const SizedBox(width: 10),
        Expanded(child: Text(pcT('PowerCloud remote desktop to %s', formatID(id)))),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: clave,
            autofocus: true,
            obscureText: oculto,
            decoration: InputDecoration(
              labelText: pcT('Password'),
              helperText: pcT('Leave it empty to use the remembered one, or so the person at the device accepts'),
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => oculto = !oculto),
              ),
            ),
            onSubmitted: (_) => close(true),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: recordar,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(pcT('Remember password on this PC')),
            onChanged: (v) => setState(() => recordar = v ?? false),
          ),
        ]),
      ),
      actions: [
        dialogButton('Cancel', onPressed: () => close(false), isOutline: true),
        dialogButton('Connect', onPressed: () => close(true)),
      ],
      onSubmit: () => close(true),
      onCancel: () => close(false),
    );
  });
  final texto = clave.text;
  clave.dispose();
  if (aceptado != true) return;
  await bind.mainSetLocalOption(key: 'pc-engine-recordar', value: recordar ? 'Y' : '');
  final tecnico = gFFI.userModel.userName.value.isNotEmpty
      ? gFFI.userModel.userName.value
      : Platform.localHostname;
  try {
    // La contrasena y el token de sesion van por variables de entorno: no quedan en la linea de
    // comandos del proceso.
    await Process.start(
      visor,
      ['--id', id, '--tecnico', tecnico, '--relay', await _relay()],
      environment: {
        'PCE_TOKEN': bind.mainGetLocalOption(key: 'access_token'),
        if (texto.isNotEmpty) 'PCE_CLAVE': texto,
        // El visor guarda solo el hash de la contrasena, cifrado para este usuario de Windows.
        if (recordar) 'PCE_RECORDAR': '1',
      },
      mode: ProcessStartMode.detached,
    );
  } catch (e) {
    showToast('$e');
  }
}

Future<String> _relay() async {
  final propio = bind.mainGetOptionSync(key: 'pc-engine-relay');
  if (propio.isNotEmpty) return propio;
  final host = Uri.tryParse(await bind.mainGetApiServer())?.host ?? '';
  return 'wss://${host.isEmpty ? 'monitoreo.powercloud.com.sv' : host}:21114/engine';
}

String _tamano(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1048576).toStringAsFixed(1)} MB';
}

/// Abre el dialogo del tunel hacia [id] (ya resuelto: ID numerico).
void pcAbrirTunel(String id) {
  final conector = pcRutaConector();
  if (conector == null) {
    showToast(pcT('The PowerCloud tunnel is not available in this installation'));
    return;
  }
  final destino = TextEditingController(
      text: bind.mainGetLocalOption(key: 'pc-tunel-destino').isEmpty
          ? '127.0.0.1:1433'
          : bind.mainGetLocalOption(key: 'pc-tunel-destino'));
  final local = TextEditingController(
      text: bind.mainGetLocalOption(key: 'pc-tunel-local').isEmpty
          ? '14330'
          : bind.mainGetLocalOption(key: 'pc-tunel-local'));
  final clave = TextEditingController();

  Process? proceso;
  String estado = 'formulario'; // formulario, conectando, esperando, listo, cerrado, error
  String mensaje = '';
  String direccion = '';
  int conexiones = 0, enviados = 0, recibidos = 0;
  DateTime? desde;
  Timer? reloj;

  gFFI.dialogManager.show((setState, close, context) {
    void cerrarTodo() {
      reloj?.cancel();
      proceso?.kill();
      proceso = null;
      close();
    }

    Future<void> abrir() async {
      final d = destino.text.trim();
      final p = int.tryParse(local.text.trim()) ?? -1;
      if (!RegExp(r'^[^\s:]+:\d{1,5}$').hasMatch(d) || p < 0 || p > 65535) {
        setState(() {
          estado = 'error';
          mensaje = pcT('Check the destination (host:port) and the local port');
        });
        return;
      }
      await bind.mainSetLocalOption(key: 'pc-tunel-destino', value: d);
      await bind.mainSetLocalOption(key: 'pc-tunel-local', value: '$p');
      final tecnico = gFFI.userModel.userName.value.isNotEmpty
          ? gFFI.userModel.userName.value
          : Platform.localHostname;
      setState(() => estado = 'conectando');
      try {
        proceso = await Process.start(
          conector,
          [
            '--json',
            '--id', id,
            '--destino', d,
            '--local', '127.0.0.1:$p',
            '--tecnico', tecnico,
            '--relay', await _relay(),
          ],
          // La contrasena y el token de sesion van por variables de entorno: no quedan en la linea de
          // comandos. El servidor exige la sesion del tecnico y su acceso al equipo.
          environment: {
            'PCE_CLAVE': clave.text,
            'PCE_TOKEN': bind.mainGetLocalOption(key: 'access_token'),
          },
        );
      } catch (e) {
        setState(() {
          estado = 'error';
          mensaje = '$e';
        });
        return;
      }
      clave.clear();
      proceso!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((linea) {
        Map<String, dynamic> v;
        try {
          v = jsonDecode(linea) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        setState(() {
          switch (v['t']) {
            case 'esperando':
              estado = 'esperando';
              break;
            case 'listo':
              estado = 'listo';
              direccion = (v['local'] ?? '').toString();
              desde = DateTime.now();
              reloj?.cancel();
              reloj = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
              break;
            case 'estado':
              conexiones = (v['conexiones'] as num?)?.toInt() ?? 0;
              enviados = (v['enviados'] as num?)?.toInt() ?? 0;
              recibidos = (v['recibidos'] as num?)?.toInt() ?? 0;
              break;
            case 'cerrado':
              estado = 'cerrado';
              reloj?.cancel();
              break;
            case 'error':
              estado = 'error';
              mensaje = (v['motivo'] ?? '').toString();
              reloj?.cancel();
              break;
          }
        });
      });
      proceso!.exitCode.then((_) {
        if (estado == 'listo' || estado == 'conectando' || estado == 'esperando') {
          setState(() {
            estado = 'cerrado';
            reloj?.cancel();
          });
        }
      });
    }

    Widget campo(String etiqueta, TextEditingController c,
        {String? ayuda, bool oculto = false, bool soloNumeros = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          obscureText: oculto,
          inputFormatters:
              soloNumeros ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
        ),
      );
    }

    Widget contenido() {
      final atenuado = Theme.of(context).hintColor;
      switch (estado) {
        case 'formulario':
          return Column(mainAxisSize: MainAxisSize.min, children: [
            campo(pcT('Destination on the remote device'), destino,
                ayuda: pcT('For example SQL Server: 127.0.0.1:1433')),
            campo(pcT('Local port on this computer'), local, soloNumeros: true),
            campo(pcT('Password'), clave,
                oculto: true,
                ayuda: pcT('Leave it empty so the person at the device accepts')),
          ]);
        case 'conectando':
        case 'esperando':
          return Row(children: [
            const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 14),
            Expanded(
                child: Text(estado == 'conectando'
                    ? pcT('Connecting to the device...')
                    : pcT('Waiting for the person at the device to accept...'))),
          ]);
        case 'listo':
          final t = desde == null ? Duration.zero : DateTime.now().difference(desde!);
          final reloj =
              '${t.inHours.toString().padLeft(2, '0')}:${(t.inMinutes % 60).toString().padLeft(2, '0')}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.circle, size: 10, color: Color(0xFF2FBF71)),
              const SizedBox(width: 8),
              Text(pcT('Tunnel open'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(reloj, style: TextStyle(color: atenuado)),
            ]),
            const SizedBox(height: 14),
            Text(pcT('Connect your program to'), style: TextStyle(color: atenuado)),
            const SizedBox(height: 4),
            Row(children: [
              SelectableText(direccion,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              IconButton(
                tooltip: pcT('Copy'),
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: direccion));
                  showToast(translate('Copied'));
                },
              ),
            ]),
            Text(pcT('Goes to %s on the remote device', destino.text),
                style: TextStyle(color: atenuado)),
            const SizedBox(height: 12),
            Text(
                '${pcT('Connections')}: $conexiones   ·   ${pcT('Sent')}: ${_tamano(enviados)}   ·   ${pcT('Received')}: ${_tamano(recibidos)}',
                style: TextStyle(color: atenuado, fontSize: 13)),
          ]);
        case 'cerrado':
          return Text(pcT('The tunnel was closed'));
        default:
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF6B6B)),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ]);
      }
    }

    final acciones = <Widget>[];
    if (estado == 'formulario') {
      acciones.addAll([
        dialogButton('Cancel', onPressed: cerrarTodo, isOutline: true),
        dialogButton(pcT('Open tunnel'), onPressed: abrir),
      ]);
    } else if (estado == 'listo' || estado == 'conectando' || estado == 'esperando') {
      acciones.add(dialogButton(pcT('Close tunnel'), onPressed: cerrarTodo));
    } else {
      acciones.addAll([
        dialogButton('Close', onPressed: cerrarTodo, isOutline: true),
        dialogButton(pcT('Try again'), onPressed: () {
          proceso?.kill();
          proceso = null;
          setState(() => estado = 'formulario');
        }),
      ]);
    }

    return CustomAlertDialog(
      title: Row(children: [
        const Icon(Icons.swap_horiz_rounded),
        const SizedBox(width: 10),
        Expanded(child: Text(pcT('TCP tunnel to %s', formatID(id)))),
      ]),
      content: SizedBox(width: 420, child: contenido()),
      actions: acciones,
      onSubmit: estado == 'formulario' ? abrir : null,
      onCancel: cerrarTodo,
    );
  });
}
