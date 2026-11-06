import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../powercloud/textos.dart';

Widget getConnectionPageTitle(BuildContext context, bool isWeb) {
  if (!isWeb) {
    // PowerCloud: encabezado propio de la pantalla de conexion.
    final color = Theme.of(context).textTheme.titleLarge?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pcT('Connect to a device'),
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: color, height: 1.2)),
        const SizedBox(height: 4),
        Text(pcT('Type the ID or alias of the device you want to support'),
            style: TextStyle(fontSize: 13.5, color: color?.withOpacity(0.6))),
      ],
    );
  }
  return Row(
    children: [
      Expanded(
          child: Row(
        children: [
          AutoSizeText(
            translate('Control Remote Desktop'),
            maxLines: 1,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.merge(TextStyle(height: 1)),
          ), // PowerCloud: sin la ayuda de ID/IP/servidor publico
        ],
      )),
    ],
  );
}
