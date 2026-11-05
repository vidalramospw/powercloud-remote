// PowerCloud: alias nombre@dominio para los equipos.
//
// - El cliente registra el alias de SU equipo desde la pantalla principal (PcAliasBoard).
//   El servidor API lo identifica por id + uuid, que ya conoce por el heartbeat.
// - El tecnico escribe "caja01@pw" en "Controlar escritorio remoto" y pcResolveAlias()
//   lo traduce al ID numerico antes de conectar (requiere sesion iniciada).
//
// "pw" es el dominio publico. Los dominios privados (ej. @empresa) piden el codigo de
// registro que PowerCloud entrega al cliente con su plan.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/utils/http_service.dart' as http;

import '../common.dart';
import '../models/platform_model.dart';

const kPcDominioPublico = 'pw';
final _reNombre = RegExp(r'^[a-z0-9][a-z0-9_-]{1,31}$');
final _reDominio = RegExp(r'^[a-z0-9][a-z0-9-]{1,31}$');

/// "caja01@pw" es alias; "123456789@servidor.com" (formato id@servidor de RustDesk) no,
/// porque los dominios de alias no llevan punto, dos puntos ni parametros.
bool pcIsAlias(String texto) {
  final t = texto.trim().toLowerCase();
  final i = t.lastIndexOf('@');
  if (i <= 0) return false;
  return _reNombre.hasMatch(t.substring(0, i)) &&
      _reDominio.hasMatch(t.substring(i + 1));
}

Map<String, dynamic> _json(http.Response resp) {
  try {
    final v = jsonDecode(decode_http_response(resp));
    if (v is Map<String, dynamic>) return v;
  } catch (_) {}
  return {'error': 'HTTP ${resp.statusCode}'};
}

/// Devuelve el ID a usar: el mismo texto si no es alias, el ID resuelto si lo es,
/// o null si no se pudo resolver (ya se mostro el motivo).
Future<String?> pcResolveAlias(String id) async {
  if (!pcIsAlias(id)) return id;
  if (bind.mainGetLocalOption(key: 'access_token').isEmpty) {
    showToast('Inicie sesion en PowerCloud Remote para conectarse por alias');
    return null;
  }
  try {
    final api = await bind.mainGetApiServer();
    final uri = Uri.parse('$api/api/alias/resolver')
        .replace(queryParameters: {'alias': id.trim().toLowerCase()});
    final resp = await http.get(uri, headers: getHttpHeaders());
    final json = _json(resp);
    final resuelto = json['id'];
    if (resp.statusCode == 200 && resuelto is String && resuelto.isNotEmpty) {
      return resuelto;
    }
    showToast((json['error'] ?? 'No se pudo resolver el alias').toString());
  } catch (e) {
    showToast('No se pudo resolver el alias: $e');
  }
  return null;
}

Future<Map<String, dynamic>> _llamarEquipo(
    String ruta, Map<String, dynamic> extra) async {
  final api = await bind.mainGetApiServer();
  final body = {
    'id': await bind.mainGetMyId(),
    'uuid': await bind.mainGetUuid(),
    ...extra,
  };
  final resp = await http.post(Uri.parse('$api$ruta'),
      headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
  return _json(resp);
}

/// Fila "Alias" debajo del ID en la pantalla principal.
class PcAliasBoard extends StatefulWidget {
  const PcAliasBoard({Key? key}) : super(key: key);

  @override
  State<PcAliasBoard> createState() => _PcAliasBoardState();
}

class _PcAliasBoardState extends State<PcAliasBoard> {
  String _alias = '';

  @override
  void initState() {
    super.initState();
    _alias = bind.mainGetLocalOption(key: 'powercloud-alias');
    _refrescar();
  }

  Future<void> _refrescar() async {
    try {
      final json = await _llamarEquipo('/api/alias/mio', {});
      final a = json['alias'];
      if (a is String && mounted) {
        setState(() => _alias = a);
        await bind.mainSetLocalOption(key: 'powercloud-alias', value: a);
      }
    } catch (_) {
      // Sin conexion al servidor API: se muestra el ultimo alias conocido.
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.titleLarge?.color;
    return Container(
      margin: const EdgeInsets.only(left: 29, right: 11, top: 2),
      child: Row(
        children: [
          Text('Alias',
              style: TextStyle(fontSize: 14, color: color?.withOpacity(0.5))),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              _alias.isEmpty ? 'sin alias' : _alias,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 15,
                  color: _alias.isEmpty ? color?.withOpacity(0.4) : color),
            ),
          ),
          TextButton(
            onPressed: () => _dialogo(context),
            child: Text(_alias.isEmpty ? 'Crear' : 'Cambiar'),
          ),
        ],
      ),
    );
  }

  void _dialogo(BuildContext context) {
    final partes = _alias.split('@');
    final nombre =
        TextEditingController(text: partes.length == 2 ? partes[0] : '');
    final dominio = TextEditingController(
        text: partes.length == 2 ? partes[1] : kPcDominioPublico);
    final codigo = TextEditingController();
    var msg = '';
    var enProceso = false;

    gFFI.dialogManager.show((setState, close, context) {
      Future<void> guardar() async {
        final n = nombre.text.trim().toLowerCase();
        final d = dominio.text.trim().toLowerCase().isEmpty
            ? kPcDominioPublico
            : dominio.text.trim().toLowerCase();
        if (!_reNombre.hasMatch(n)) {
          setState(() => msg =
              'De 2 a 32 caracteres: letras, numeros, guion o guion bajo');
          return;
        }
        setState(() {
          msg = '';
          enProceso = true;
        });
        try {
          final json = await _llamarEquipo('/api/alias/registrar', {
            'alias': n,
            'dominio': d,
            if (codigo.text.trim().isNotEmpty) 'codigo': codigo.text.trim(),
          });
          final a = json['alias'];
          if (a is String && a.isNotEmpty) {
            await bind.mainSetLocalOption(key: 'powercloud-alias', value: a);
            if (mounted) this.setState(() => _alias = a);
            close();
            showToast('Alias registrado: $a');
            return;
          }
          setState(() {
            enProceso = false;
            msg = (json['error'] ?? 'No se pudo registrar el alias').toString();
          });
        } catch (e) {
          setState(() {
            enProceso = false;
            msg = 'No se pudo conectar con el servidor: $e';
          });
        }
      }

      Future<void> quitar() async {
        setState(() => enProceso = true);
        try {
          await _llamarEquipo('/api/alias/quitar', {});
          await bind.mainSetLocalOption(key: 'powercloud-alias', value: '');
          if (mounted) this.setState(() => _alias = '');
          close();
        } catch (e) {
          setState(() {
            enProceso = false;
            msg = 'No se pudo conectar con el servidor: $e';
          });
        }
      }

      final esPrivado =
          dominio.text.trim().toLowerCase() != kPcDominioPublico &&
              dominio.text.trim().isNotEmpty;
      return CustomAlertDialog(
        title: const Text('Alias de este equipo'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Con el alias, el tecnico de PowerCloud se conecta escribiendo '
                'nombre@dominio en lugar del ID. Igual debera aceptar cada conexion.'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: nombre,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Nombre', hintText: 'caja01'),
                    onChanged: (_) => setState(() => msg = ''),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('@', style: TextStyle(fontSize: 18)),
                ),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: dominio,
                    decoration: const InputDecoration(labelText: 'Dominio'),
                    onChanged: (_) => setState(() => msg = ''),
                  ),
                ),
              ],
            ),
            if (esPrivado)
              TextField(
                controller: codigo,
                decoration: const InputDecoration(
                    labelText: 'Codigo de registro del dominio',
                    hintText: 'XXXX-XXXX-XXXX'),
              ),
            if (msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(msg, style: const TextStyle(color: Colors.red)),
              ),
            if (enProceso)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
        actions: [
          if (_alias.isNotEmpty)
            dialogButton('Quitar alias', onPressed: quitar, isOutline: true),
          dialogButton('Cancel', onPressed: close, isOutline: true),
          dialogButton('OK', onPressed: guardar),
        ],
        onSubmit: guardar,
        onCancel: close,
      );
    });
  }
}
