// PowerCloud: barra lateral de la ventana principal (reemplaza las pestanas de la lista de equipos).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../common.dart';
import '../../consts.dart';
import '../../desktop/pages/desktop_setting_page.dart';
import '../../models/peer_tab_model.dart';
import '../../models/platform_model.dart';

/// La pone PeerTabPage al crearse: cambia de pestana y carga sus datos.
Future<void> Function(int)? pcSeleccionarPestana;

const kPcAzul = Color(0xFF38B6E8);

class PcBarraLateral extends StatelessWidget {
  const PcBarraLateral({Key? key}) : super(key: key);

  static const _iconos = <IconData>[
    Icons.history_rounded,
    Icons.star_outline_rounded,
    Icons.wifi_tethering_rounded,
    Icons.contacts_outlined,
    Icons.devices_other_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider.value(
      value: gFFI.peerTabModel,
      child: Consumer<PeerTabModel>(builder: (context, model, _) {
        return Container(
          width: 68,
          color: oscuro ? const Color(0xFF0B1117) : const Color(0xFFF2F5F8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: oscuro ? const Color(0xFF16222E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPcAzul.withOpacity(0.35)),
                ),
                child: SvgPicture.asset('assets/icon.svg'),
              ),
              const SizedBox(height: 18),
              for (final t in model.visibleEnabledOrderedIndexs)
                _Boton(
                  icono: t < _iconos.length ? _iconos[t] : model.tabIcon(t),
                  texto: translate(PeerTabModel.tabNames[t]),
                  activo: model.currentTab == t,
                  onTap: () async {
                    if (pcSeleccionarPestana != null) {
                      await pcSeleccionarPestana!(t);
                    } else {
                      model.setCurrentTab(t);
                    }
                    await bind.setLocalFlutterOption(
                        k: kOptionPeerTabIndex, v: t.toString());
                  },
                ),
              const Spacer(),
              _Boton(
                icono: Icons.settings_outlined,
                texto: translate('Settings'),
                activo: false,
                onTap: () {
                  if (DesktopSettingPage.tabKeys.isNotEmpty) {
                    DesktopSettingPage.switch2page(
                        DesktopSettingPage.tabKeys[0]);
                  }
                },
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Boton extends StatefulWidget {
  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback onTap;
  const _Boton(
      {required this.icono,
      required this.texto,
      required this.activo,
      required this.onTap});

  @override
  State<_Boton> createState() => _BotonState();
}

class _BotonState extends State<_Boton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
    final color = widget.activo
        ? (oscuro ? kPcAzul : MyTheme.accent)
        : base.withOpacity(_hover ? 0.85 : 0.55);
    final fondo = widget.activo
        ? kPcAzul.withOpacity(oscuro ? 0.16 : 0.14)
        : (_hover
            ? base.withOpacity(oscuro ? 0.06 : 0.05)
            : Colors.transparent);
    return Tooltip(
      message: widget.texto,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 46,
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(widget.icono, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}
