import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/ab_model.dart';
import '../../models/peer_model.dart';
import '../textos.dart';

/// Directorio por carpetas (ramas) en lugar de etiquetas sueltas.
///
/// Por dentro sigue usando las etiquetas del directorio (compatible con lo ya guardado): cada carpeta
/// es una etiqueta con su ruta separada por "/" (por ejemplo "VILLAVAR/Sucursales") y cada equipo
/// lleva una sola. Los equipos sin etiqueta quedan en "General".

const kPcSeparador = '/';

/// Datos que viajan al arrastrar una tarjeta.
class PcEquipoArrastrado {
  final String id;
  const PcEquipoArrastrado(this.id);
}

/// Filtro de la vista: equipos de la carpeta elegida y de sus subcarpetas.
bool pcCoincideCarpeta(List<dynamic> seleccion, List<dynamic> etiquetas) {
  if (seleccion.isEmpty) return true;
  final carpeta = seleccion.first.toString();
  if (carpeta == kUntagged) return etiquetas.isEmpty;
  return etiquetas.any((t) => t == carpeta || t.toString().startsWith('$carpeta$kPcSeparador'));
}

/// Todas las carpetas (incluidas las intermedias de cada ruta), ordenadas.
List<String> pcCarpetas() {
  final todas = <String>{};
  for (final t in gFFI.abModel.currentAbTags) {
    final partes = t.split(kPcSeparador);
    for (var i = 1; i <= partes.length; i++) {
      todas.add(partes.sublist(0, i).join(kPcSeparador));
    }
  }
  final lista = todas.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return lista;
}

String _nombre(String ruta) => ruta.split(kPcSeparador).last;
int _nivel(String ruta) => ruta.split(kPcSeparador).length - 1;

Future<void> pcMoverAEquipoCarpeta(List<String> ids, String carpeta) async {
  await gFFI.abModel.changeTagForPeers(ids, carpeta == kUntagged ? [] : [carpeta]);
}

/// Panel izquierdo del directorio.
class PcCarpetasDirectorio extends StatefulWidget {
  const PcCarpetasDirectorio({Key? key}) : super(key: key);

  @override
  State<PcCarpetasDirectorio> createState() => _PcCarpetasDirectorioState();
}

class _PcCarpetasDirectorioState extends State<PcCarpetasDirectorio> {
  final Set<String> _cerradas = {};

  int _cuenta(String carpeta) => gFFI.abModel.currentAbPeers
      .where((p) => pcCoincideCarpeta([carpeta], p.tags))
      .length;

  bool _visible(String ruta) {
    final partes = ruta.split(kPcSeparador);
    for (var i = 1; i < partes.length; i++) {
      if (_cerradas.contains(partes.sublist(0, i).join(kPcSeparador))) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final carpetas = pcCarpetas();
      final puedeEditar = gFFI.abModel.current.canWrite();
      final seleccion =
          gFFI.abModel.selectedTags.isEmpty ? null : gFFI.abModel.selectedTags.first;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(pcT('Folders'),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          if (puedeEditar)
            IconButton(
              tooltip: pcT('New folder'),
              icon: const Icon(Icons.create_new_folder_outlined, size: 20),
              onPressed: () => pcNuevaCarpeta(null),
            ),
        ]).paddingOnly(left: 10, right: 2),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 6), children: [
            _fila(context, null, Icons.apps_rounded, pcT('All devices'),
                gFFI.abModel.currentAbPeers.length, seleccion == null, false),
            _fila(context, kUntagged, Icons.folder_outlined, pcT('General'),
                _cuenta(kUntagged), seleccion == kUntagged, false),
            for (final c in carpetas.where(_visible))
              _fila(context, c, Icons.folder_rounded, _nombre(c), _cuenta(c), seleccion == c,
                  puedeEditar,
                  nivel: _nivel(c),
                  tieneHijas: carpetas.any((x) => x.startsWith('$c$kPcSeparador'))),
          ]),
        ),
      ]);
    });
  }

  Widget _fila(BuildContext context, String? carpeta, IconData icono, String texto, int cuenta,
      bool elegida, bool menu,
      {int nivel = 0, bool tieneHijas = false}) {
    final acento = MyTheme.accent;
    final fila = Container(
      height: 34,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: EdgeInsets.only(left: 6.0 + nivel * 14, right: 2),
      decoration: BoxDecoration(
        color: elegida ? acento.withOpacity(0.16) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        SizedBox(
          width: 18,
          child: tieneHijas && carpeta != null
              ? InkWell(
                  onTap: () => setState(() => _cerradas.contains(carpeta)
                      ? _cerradas.remove(carpeta)
                      : _cerradas.add(carpeta)),
                  child: Icon(
                      _cerradas.contains(carpeta)
                          ? Icons.chevron_right_rounded
                          : Icons.expand_more_rounded,
                      size: 18),
                )
              : null,
        ),
        Icon(icono, size: 18, color: elegida ? acento : Theme.of(context).hintColor),
        const SizedBox(width: 8),
        Expanded(
            child: Text(texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: elegida ? FontWeight.w600 : FontWeight.w400))),
        Text('$cuenta', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        if (menu && carpeta != null)
          PopupMenuButton<String>(
            tooltip: '',
            iconSize: 18,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            onSelected: (v) {
              if (v == 'sub') pcNuevaCarpeta(carpeta);
              if (v == 'ren') pcRenombrarCarpeta(carpeta);
              if (v == 'del') pcEliminarCarpeta(carpeta);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'sub', child: Text(pcT('New subfolder'))),
              PopupMenuItem(value: 'ren', child: Text(pcT('Rename'))),
              PopupMenuItem(value: 'del', child: Text(pcT('Delete'))),
            ],
          )
        else
          const SizedBox(width: 8),
      ]),
    );
    final tocable = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        gFFI.abModel.selectedTags.clear();
        if (carpeta != null) gFFI.abModel.selectedTags.add(carpeta);
      },
      child: fila,
    );
    if (carpeta == null || !gFFI.abModel.current.canWrite()) return tocable;
    // Soltar una tarjeta aqui la mueve a esta carpeta.
    return DragTarget<PcEquipoArrastrado>(
      onAcceptWithDetails: (d) => pcMoverAEquipoCarpeta([d.data.id], carpeta),
      builder: (context, candidatos, _) => candidatos.isEmpty
          ? tocable
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: acento, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: tocable),
    );
  }
}

/// La tarjeta del directorio se puede arrastrar a una carpeta.
Widget pcTarjetaArrastrable(Peer peer, Widget tarjeta) {
  if (!gFFI.abModel.current.canWrite()) return tarjeta;
  return Draggable<PcEquipoArrastrado>(
    data: PcEquipoArrastrado(peer.id),
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: MyTheme.accent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.desktop_windows_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(peer.alias.isNotEmpty ? peer.alias : peer.id,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
    childWhenDragging: Opacity(opacity: 0.4, child: tarjeta),
    child: tarjeta,
  );
}

Future<String?> _pedirNombre(String titulo, {String inicial = ''}) async {
  final c = TextEditingController(text: inicial);
  return gFFI.dialogManager.show<String>((setState, close, context) {
    submit() {
      final t = c.text.trim().replaceAll(kPcSeparador, '-');
      if (t.isNotEmpty) close(t);
    }

    return CustomAlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(labelText: pcT('Name')),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        dialogButton('Cancel', onPressed: () => close(null), isOutline: true),
        dialogButton('OK', onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: () => close(null),
    );
  });
}

Future<void> pcNuevaCarpeta(String? padre) async {
  final nombre = await _pedirNombre(padre == null ? pcT('New folder') : pcT('New subfolder'));
  if (nombre == null) return;
  final ruta = padre == null ? nombre : '$padre$kPcSeparador$nombre';
  if (!gFFI.abModel.currentAbTags.contains(ruta)) await gFFI.abModel.addTags([ruta]);
}

Future<void> pcRenombrarCarpeta(String ruta) async {
  final nombre = await _pedirNombre(pcT('Rename'), inicial: _nombre(ruta));
  if (nombre == null || nombre == _nombre(ruta)) return;
  final partes = ruta.split(kPcSeparador)..removeLast();
  final nueva = [...partes, nombre].join(kPcSeparador);
  final afectadas = gFFI.abModel.currentAbTags
      .where((t) => t == ruta || t.startsWith('$ruta$kPcSeparador'))
      .toList();
  if (afectadas.isEmpty) {
    await gFFI.abModel.addTags([nueva]);
    return;
  }
  for (final t in afectadas) {
    await gFFI.abModel.renameTag(t, nueva + t.substring(ruta.length));
  }
}

Future<void> pcEliminarCarpeta(String ruta) async {
  final ok = await gFFI.dialogManager.show<bool>((setState, close, context) {
    return CustomAlertDialog(
      title: Text(pcT('Delete')),
      content: Text(pcT('Delete the folder %s? Its devices go to General.', _nombre(ruta))),
      actions: [
        dialogButton('Cancel', onPressed: () => close(false), isOutline: true),
        dialogButton('OK', onPressed: () => close(true)),
      ],
      onSubmit: () => close(true),
      onCancel: () => close(false),
    );
  });
  if (ok != true) return;
  final afectadas = gFFI.abModel.currentAbTags
      .where((t) => t == ruta || t.startsWith('$ruta$kPcSeparador'))
      .toList();
  for (final t in afectadas) {
    await gFFI.abModel.deleteTag(t);
  }
  gFFI.abModel.selectedTags.clear();
}

/// Al agregar un equipo al directorio: elegir la carpeta (por omision, General).
Future<String?> pcElegirCarpeta() async {
  final carpetas = pcCarpetas();
  String elegida = kUntagged;
  return gFFI.dialogManager.show<String>((setState, close, context) {
    return CustomAlertDialog(
      title: Text(pcT('Add to address book')),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pcT('Folder')),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView(shrinkWrap: true, children: [
              for (final c in [kUntagged, ...carpetas])
                RadioListTile<String>(
                  dense: true,
                  value: c,
                  groupValue: elegida,
                  onChanged: (v) => setState(() => elegida = v ?? kUntagged),
                  title: Text(c == kUntagged ? pcT('General') : _nombre(c)),
                  contentPadding: EdgeInsets.only(left: c == kUntagged ? 0 : _nivel(c) * 16.0),
                ),
            ]),
          ),
        ]),
      ),
      actions: [
        dialogButton('Cancel', onPressed: () => close(null), isOutline: true),
        dialogButton('OK', onPressed: () => close(elegida)),
      ],
      onSubmit: () => close(elegida),
      onCancel: () => close(null),
    );
  });
}
