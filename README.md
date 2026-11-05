# PowerCloud Remote

**PowerCloud Remote** es el cliente de soporte remoto de **PowerCloud El Salvador**. Permite que
nuestros técnicos atiendan a los clientes de nuestros sistemas (punto de venta, facturación
electrónica, ERP) **siempre con el consentimiento del usuario**, que ve y acepta cada conexión.

Es un fork de [RustDesk](https://github.com/rustdesk/rustdesk) 1.5.1, distribuido bajo la
licencia **GNU AGPL-3.0** (ver [LICENCE](LICENCE)). El código original es © Purslane Tech
Pte. Ltd. y colaboradores. "RustDesk" es marca de sus dueños; este proyecto no está afiliado
ni respaldado por ellos.

- **Mantenedor:** Vidal Enrique Ramos Argueta — PowerCloud El Salvador (San Miguel, El Salvador)
- **Contacto:** vidal.ramos@powercloud.com.sv
- **Servidor:** `monitoreo.powercloud.com.sv` (servidor propio, RustDesk Server OSS)

## Qué cambia respecto a RustDesk

Los cambios están aislados en [`powercloud/`](powercloud/) y se aplican al compilar:

| Cambio | Archivo |
|---|---|
| Nombre de la aplicación y del ejecutable (`PowerCloudRemote.exe`) | `powercloud/marca.json` |
| Servidor de IDs/relay y llave pública fijos | `powercloud/marca.json` |
| Propiedades del ejecutable (empresa, descripción, copyright con crédito a RustDesk) | `powercloud/aplicar_marca.py` |
| Contraseña de un solo uso por defecto | `powercloud/marca.json` |

El resto del código es el de RustDesk sin modificar. Detalles en [`powercloud/LEEME.md`](powercloud/LEEME.md).

## Uso legítimo

PowerCloud Remote es una herramienta de **soporte asistido**:

- La persona frente al equipo abre el programa, comparte su ID y contraseña temporal y **acepta** la conexión.
- La sesión es visible en todo momento y el usuario puede terminarla cuando quiera.
- Cerrar el programa elimina todo acceso. No se instala de forma oculta ni silenciosa.

## Compilar

GitHub Actions → **PowerCloud Remote - Windows x64**
([`.github/workflows/powercloud-windows.yml`](.github/workflows/powercloud-windows.yml)).
El flujo descarga las dependencias, aplica `powercloud/aplicar_marca.py` y compila con las mismas
versiones que RustDesk 1.5.1 (Rust 1.75, Flutter 3.24.5, LLVM 15, vcpkg fijado).

## Firma de código

Los binarios publicados se firman con un certificado **Certum Open Source Code Signing**
emitido a *Vidal Enrique Ramos Argueta*. Solo se firman binarios compilados desde este
repositorio público mediante GitHub Actions; la firma la realiza el mantenedor
([`powercloud/firmar.ps1`](powercloud/firmar.ps1)).

## Privacidad

El programa se conecta al servidor `monitoreo.powercloud.com.sv` para registrar su ID y
establecer las sesiones que el usuario acepta. Las sesiones van cifradas de extremo a extremo.
PowerCloud Remote no agrega telemetría propia.

Pendiente en esta versión (heredado de RustDesk): la consulta de actualizaciones a
`api.rustdesk.com` y el servidor API por defecto `admin.rustdesk.com`. Se desactivarán o
apuntarán a servidores de PowerCloud en una próxima versión.

---

## English summary

**PowerCloud Remote** is the remote support client of **PowerCloud El Salvador**, an open source
fork of [RustDesk](https://github.com/rustdesk/rustdesk) 1.5.1 licensed under the **GNU AGPL-3.0**.
It lets our technicians help our customers **only with the user's explicit consent**: the user
shares a one-time password and accepts each session, which stays visible and can be ended at
any time.

- **Maintainer:** Vidal Enrique Ramos Argueta, PowerCloud El Salvador — vidal.ramos@powercloud.com.sv
- **Changes vs. upstream:** branding (name, executable, version resources), fixed rendezvous/relay
  server `monitoreo.powercloud.com.sv` and its public key, and one-time password by default. All
  changes live in [`powercloud/`](powercloud/) and are applied at build time.
- **Build:** GitHub Actions, workflow `powercloud-windows.yml`.
- **Code signing:** releases are signed with a Certum Open Source Code Signing certificate issued
  to Vidal Enrique Ramos Argueta. Only binaries built from this public repository are signed.
- **Privacy:** the client registers and connects through `monitoreo.powercloud.com.sv`; sessions
  are end-to-end encrypted; no telemetry is added. Inherited from upstream and pending removal:
  the update check against `api.rustdesk.com` and the default API server `admin.rustdesk.com`.

The original RustDesk README is kept in [docs/README-RustDesk.md](docs/README-RustDesk.md).
