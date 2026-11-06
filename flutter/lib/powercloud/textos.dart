// PowerCloud: textos propios en el idioma del usuario.
//
// La clave es el texto en ingles (asi se ve en cualquier idioma sin traduccion) y la
// traduccion vive en src/lang/<idioma>.rs, como el resto del programa.
// Un valor variable se marca con %s en la clave.

import '../common.dart';

/// Nombre visible del programa (el tecnico, sin espacio, es para carpetas y servicio).
const kPcNombre = 'PowerCloud Remote';

String pcT(String clave, [Object? valor]) {
  final t = translate(clave);
  return valor == null ? t : t.replaceFirst('%s', valor.toString());
}
