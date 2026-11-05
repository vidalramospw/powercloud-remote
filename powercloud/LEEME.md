# PowerCloud Remote

Cliente de soporte remoto de PowerCloud, basado en [RustDesk](https://github.com/rustdesk/rustdesk)
1.5.1. Licencia **AGPL-3.0**: este repositorio es público y conserva el crédito a RustDesk
(© Purslane Tech Pte. Ltd.). "RustDesk" es marca de sus dueños; este producto no está
afiliado ni respaldado por ellos.

## Cómo está organizado

| Ruta | Qué es |
|---|---|
| `powercloud/marca.json` | Nombre, empresa, servidor, llave pública y valores por defecto |
| `powercloud/aplicar_marca.py` | Aplica la marca sobre el código de RustDesk **en cada compilación** (no se hace commit del resultado) |
| `powercloud/activos/` | Íconos y logos PowerCloud (opcional: si falta uno se usa el original) |
| `.github/workflows/powercloud-windows.yml` | Compilación Windows x64 en GitHub Actions |

El código de RustDesk queda sin tocar en git. Para actualizar a una versión nueva de RustDesk:
`git merge <tag>`, lanzar la compilación y, si `aplicar_marca.py` falla, ajustar el texto que
cambió.

## Activos esperados en `powercloud/activos/`

| Archivo | Uso |
|---|---|
| `icon.ico` | Ícono del .exe y de la ventana (multi-tamaño 16-256 px) |
| `tray-icon.ico` | Ícono de la bandeja del sistema |
| `icon.png`, `32x32.png`, `64x64.png`, `128x128.png`, `128x128@2x.png` | Logos PNG |
| `icon.svg` | Logo dentro de la interfaz Flutter |

## Compilar

GitHub → Actions → **PowerCloud Remote - Windows x64** → *Run workflow*
(o crear un tag `pc-*`). Resultado (sin firmar):

- `powercloud-remote-windows-x64-portable`: `PowerCloudRemote-1.5.1-x64.exe`
- `powercloud-remote-windows-x64-carpeta`: carpeta completa

Antes de entregarlo a clientes: **firmar** con el certificado de firma de código de PowerCloud.

## Probar la marca en local

```bash
python powercloud/aplicar_marca.py      # aplica
git checkout -- . && git -C libs/hbb_common checkout -- .   # deshace
```
