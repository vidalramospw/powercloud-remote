#!/usr/bin/env python3
"""
Aplica la marca PowerCloud Remote sobre el codigo de RustDesk antes de compilar.

- Se ejecuta en CI (y se puede ejecutar a mano) desde la raiz del repositorio.
- No se hace commit del resultado: el codigo de RustDesk queda intacto en git y la marca se
  aplica en cada compilacion. Asi incorporar versiones nuevas de RustDesk es un merge simple.
- Cada reemplazo exige encontrar el texto original. Si RustDesk cambia algo, el script FALLA
  con un mensaje claro en vez de compilar un cliente a medio cambiar.
- Idempotente: si ya se aplico, no vuelve a tocar nada.

Licencia: este fork sigue siendo AGPL-3.0. Se conserva el credito a RustDesk.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MARCA = json.loads((RAIZ / "powercloud" / "marca.json").read_text(encoding="utf-8"))
ACTIVOS = RAIZ / "powercloud" / "activos"

errores: list[str] = []


def reemplazar(ruta: str, original: str, nuevo: str, *, todas: bool = False) -> None:
    archivo = RAIZ / ruta
    with open(archivo, encoding="utf-8", newline="") as f:
        texto = f.read()
    if nuevo in texto:
        print(f"  = {ruta}: ya aplicado")
        return
    if original not in texto:
        errores.append(f"{ruta}: no se encontro el texto esperado:\n      {original!r}")
        return
    texto = texto.replace(original, nuevo) if todas else texto.replace(original, nuevo, 1)
    with open(archivo, "w", encoding="utf-8", newline="") as f:
        f.write(texto)
    print(f"  + {ruta}")


def rc_valor(campo: str, valor_original: str, valor_nuevo: str) -> None:
    reemplazar(
        "flutter/windows/runner/Runner.rc",
        f'VALUE "{campo}", {valor_original}',
        f'VALUE "{campo}", {valor_nuevo}',
    )


def main() -> int:
    visible = MARCA["nombre_visible"]
    tecnico = MARCA["nombre_tecnico"]
    print(f"Aplicando marca: {visible} ({tecnico}) -> {MARCA['servidor']}")

    # 1. Servidor, llave publica y nombre de la aplicacion (hbb_common/config.rs)
    cfg = "libs/hbb_common/src/config.rs"
    reemplazar(cfg, 'pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];',
               f'pub const RENDEZVOUS_SERVERS: &[&str] = &["{MARCA["servidor"]}"];')
    reemplazar(cfg, 'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";',
               f'pub const RS_PUB_KEY: &str = "{MARCA["llave_publica"]}";')
    reemplazar(cfg, 'pub static ref APP_NAME: RwLock<String> = RwLock::new("RustDesk".to_owned());',
               f'pub static ref APP_NAME: RwLock<String> = RwLock::new("{tecnico}".to_owned());')

    # 2. Valores por defecto (el usuario los puede cambiar) y opciones internas (fijas)
    def mapa(nombre: str, valores: dict, comentario: str) -> None:
        pares = "".join(
            f'        m.insert("{k}".to_owned(), "{v}".to_owned());\n' for k, v in valores.items()
        )
        reemplazar(
            cfg,
            f"pub static ref {nombre}: RwLock<HashMap<String, String>> = Default::default();",
            f"pub static ref {nombre}: RwLock<HashMap<String, String>> = {{\n"
            f"        // PowerCloud: {comentario}\n"
            "        let mut m = HashMap::new();\n"
            f"{pares}"
            "        RwLock::new(m)\n"
            "    };",
        )

    mapa("DEFAULT_SETTINGS", MARCA["valores_por_defecto"], "valores por defecto de la marca")
    mapa("BUILTIN_SETTINGS", MARCA["opciones_internas"], "opciones internas de la marca")

    # 2b. El servidor por defecto es de PowerCloud, no el publico de RustDesk: sin esto el cliente
    #     muestra "configure su propio servidor" y limita calidad/FPS como en el servidor gratuito.
    reemplazar(
        "src/common.rs",
        '    crate::get_custom_rendezvous_server(get_option("custom-rendezvous-server")).is_empty()',
        "    false // PowerCloud: servidor propio por defecto",
    )

    # 2c. Nada contra servidores de RustDesk:
    #     - servidor API por defecto (inicio de sesion, libreta) -> el de PowerCloud (puerto 21114)
    #     - consulta de actualizaciones a api.rustdesk.com -> desactivada
    reemplazar(
        "src/common.rs",
        '    "https://admin.rustdesk.com".to_owned()',
        f'    "https://{MARCA["servidor"]}:21114".to_owned() // PowerCloud',
    )
    reemplazar(
        "src/common.rs",
        "pub async fn do_check_software_update() -> hbb_common::ResultType<()> {",
        "pub async fn do_check_software_update() -> hbb_common::ResultType<()> {\n"
        "    if is_custom_client() {\n"
        "        return Ok(()); // PowerCloud: sin consultas a api.rustdesk.com\n"
        "    }",
    )

    # 3. Nombre del ejecutable (el codigo espera <nombre de app>.exe)
    reemplazar("flutter/windows/CMakeLists.txt", 'set(BINARY_NAME "rustdesk")',
               f'set(BINARY_NAME "{tecnico}")')
    reemplazar("flutter/windows/runner/main.cpp", 'std::wstring app_name = L"RustDesk";',
               f'std::wstring app_name = L"{tecnico}";')

    # 4. Recursos de version del .exe (Propiedades > Detalles en Windows)
    rc_valor("CompanyName", '"Purslane Tech Pte. Ltd." "\\0"', f'"{MARCA["empresa"]}" "\\0"')
    rc_valor("FileDescription", '"RustDesk Remote Desktop" "\\0"', f'"{visible}" "\\0"')
    rc_valor("InternalName", '"rustdesk" "\\0"', f'"{tecnico}" "\\0"')
    rc_valor("OriginalFilename", '"rustdesk.exe" "\\0"', f'"{tecnico}.exe" "\\0"')
    rc_valor("ProductName", '"RustDesk" "\\0"', f'"{visible}" "\\0"')
    reemplazar("flutter/windows/runner/Runner.rc",
               'VALUE "LegalCopyright", "Copyright © 2026 Purslane Tech Pte. Ltd. All rights reserved." "\\0"',
               f'VALUE "LegalCopyright", "{MARCA["copyright"]}" "\\0"')

    # 4b. Propiedades del portable autoextraible (libs/portable)
    portable = "libs/portable/Cargo.toml"
    reemplazar(portable, 'LegalCopyright = "Copyright © 2026 Purslane Tech Pte. Ltd. All rights reserved."',
               f'LegalCopyright = "{MARCA["copyright"]}"')
    reemplazar(portable, 'ProductName = "RustDesk"',
               f'CompanyName = "{MARCA["empresa"]}"\nProductName = "{visible}"')
    reemplazar(portable, 'OriginalFilename = "rustdesk.exe"', f'OriginalFilename = "{tecnico}.exe"')
    reemplazar(portable, 'FileDescription = "RustDesk Remote Desktop"', f'FileDescription = "{visible}"')

    # 4c. Version PowerCloud = <version RustDesk>.<numero de compilacion> (PC_BUILD lo pone CI).
    #     Va en el .exe (pubspec -> Runner.rc), en la leyenda de la app y en el actualizador.
    build = os.environ.get("PC_BUILD", "0").strip() or "0"
    if not build.isdigit():
        errores.append(f"PC_BUILD debe ser numerico: {build!r}")
        build = "0"
    reemplazar("flutter/pubspec.yaml", "version: 1.5.1+69", f"version: 1.5.1+{build}")
    reemplazar("flutter/lib/powercloud/version.dart", "const kPcVersion = '1.5.1.0';",
               f"const kPcVersion = '1.5.1.{build}';")
    print(f"  version PowerCloud: 1.5.1.{build}")

    # 5. Iconos y logos: se copian solo los que existan en powercloud/activos
    copias = {
        "icon.ico": ["res/icon.ico", "flutter/windows/runner/resources/app_icon.ico"],
        "tray-icon.ico": ["res/tray-icon.ico"],
        "icon.png": ["res/icon.png"],
        "32x32.png": ["res/32x32.png"],
        "64x64.png": ["res/64x64.png"],
        "128x128.png": ["res/128x128.png"],
        "128x128@2x.png": ["res/128x128@2x.png"],
        "icon.svg": ["flutter/assets/icon.svg"],
        "logo_dark.png": ["flutter/assets/logo_dark.png"],
        "logo_light.png": ["flutter/assets/logo_light.png"],
    }
    for origen, destinos in copias.items():
        src = ACTIVOS / origen
        if not src.exists():
            print(f"  ! activos/{origen} no existe: se deja el de RustDesk")
            continue
        for destino in destinos:
            shutil.copyfile(src, RAIZ / destino)
            print(f"  + {destino} <- activos/{origen}")

    if errores:
        print("\nERROR: la marca no se pudo aplicar completa (cambio el codigo de RustDesk?):")
        for e in errores:
            print("  - " + e)
        return 1
    print("Marca aplicada.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
