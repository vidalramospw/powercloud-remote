# PowerCloud Remote en Google Play

Paquete para publicar `sv.com.powercloud.remote`. Cuenta de desarrollador **personal**.

## Contenido

| Archivo | Para qué |
|---|---|
| `graficos/icono-512.png` | Ícono de la app (512×512, sin transparencia) |
| `graficos/grafico-destacado-es.png` / `-en.png` | Gráfico destacado (1024×500) |
| `graficos/capturas-es/*.png` / `capturas-en/*.png` | Capturas de teléfono (1080×2160) |
| `generar_graficos.py` | Vuelve a generar el ícono y el gráfico destacado |
| `capturas.py` | Vuelve a sacar las capturas de la app real (emulador o teléfono por adb) |

Al final está el orden de los pasos.

---

## 1. Ficha de Play Store

Agrega **inglés (en-US)** como segundo idioma en "Traducciones" y pega cada texto en su idioma.

### Español (es-419), idioma principal

**Nombre (máx. 30):**
```
PowerCloud Remote
```

**Descripción breve (máx. 80):**
```
Soporte remoto seguro: tú aceptas cada sesión y la terminas cuando quieras.
```

**Descripción completa:**
```
PowerCloud Remote permite que un técnico de confianza vea y controle tu teléfono para darte soporte, sin que tengas que llevarlo a ningún lado.

Cómo funciona
• Abre la app, toca "Compartir pantalla" e inicia el servicio.
• Dale al técnico el ID y la contraseña de un solo uso que aparecen en pantalla.
• Acepta la conexión. Mientras dura, ves un aviso y puedes terminarla en cualquier momento.

Tú tienes el control
• Ninguna conexión empieza sin tu aceptación o sin la contraseña que solo tú ves.
• Tú decides qué permites: ver la pantalla, controlar el toque, transferir archivos, audio y portapapeles.
• Un aviso te recuerda no compartir el acceso con desconocidos.

Seguridad
• Las sesiones van cifradas de extremo a extremo.
• Nuestros servidores no pueden ver ni guardan el contenido de tus sesiones.
• Cada conexión queda registrada: quién entró y cuándo.

También para técnicos
• Conéctate desde el teléfono a computadoras con Windows, Mac o Linux que tengan PowerCloud Remote.
• Chat con la persona del otro lado.

Uso del servicio de accesibilidad
PowerCloud Remote usa la API de Accesibilidad de Android solo para que el técnico al que le diste acceso pueda tocar, deslizar y escribir en tu teléfono durante una sesión que aceptaste. No la usa para recopilar, guardar ni compartir tu información. Este permiso es opcional: sin él, el técnico solo puede ver la pantalla.

PowerCloud Remote es de PowerCloud El Salvador y está basado en RustDesk (código abierto, AGPL-3.0).
Soporte: soporte@powercloud.com.sv
```

### Inglés (en-US)

**Name:**
```
PowerCloud Remote
```

**Short description:**
```
Secure remote support: you approve every session and can end it at any time.
```

**Full description:**
```
PowerCloud Remote lets a trusted technician view and control your phone to help you, without you having to take it anywhere.

How it works
• Open the app, tap "Share screen" and start the service.
• Give the technician the ID and the one-time password shown on screen.
• Accept the connection. While it lasts you see a notice, and you can end it at any time.

You are in control
• No connection starts without your approval or the password only you can see.
• You decide what is allowed: viewing the screen, touch control, file transfer, audio and clipboard.
• A warning reminds you never to give access to strangers.

Security
• Sessions are end-to-end encrypted.
• Our servers cannot see or store the content of your sessions.
• Every connection is logged: who connected and when.

For technicians too
• Connect from your phone to Windows, Mac or Linux computers running PowerCloud Remote.
• Chat with the person on the other side.

Use of the Accessibility service
PowerCloud Remote uses the Android Accessibility API only so that the technician you gave access to can tap, swipe and type on your phone during a session you accepted. It does not use it to collect, store or share your information. This permission is optional: without it, the technician can only view the screen.

PowerCloud Remote is made by PowerCloud El Salvador and is based on RustDesk (open source, AGPL-3.0).
Support: soporte@powercloud.com.sv
```

### Gráficos
- **Ícono:** `graficos/icono-512.png`
- **Gráfico destacado:** `graficos/grafico-destacado-es.png` (en la traducción inglesa, `-en.png`)
- **Capturas de teléfono:** las 3 de `capturas-es/` (en inglés, las de `capturas-en/`)

### Categoría y contacto (Configuración de la tienda)
- Tipo: **Aplicación** · Categoría: **Herramientas**
- Correo: `soporte@powercloud.com.sv`
- Sitio web: `https://monitoreo.powercloud.com.sv/descargar`

---

## 2. Contenido de la app (Política > Contenido de la app)

| Sección | Respuesta |
|---|---|
| **Política de privacidad** | `https://monitoreo.powercloud.com.sv/privacidad` (también en inglés: `/privacy`) |
| **Anuncios** | No, la app no contiene anuncios |
| **Acceso a la app** | "Todas las funciones están disponibles sin acceso especial". Para recibir soporte no se necesita cuenta; iniciar sesión es opcional y solo para técnicos |
| **Público objetivo** | Solo **18 años o más** |
| **Apps de noticias** | No |
| **Apps gubernamentales** | No |
| **Funciones financieras** | Ninguna |
| **Salud** | No es una app de salud |
| **ID de publicidad** | No usa el ID de publicidad |

### Clasificación de contenido (cuestionario IARC)
- Correo: `soporte@powercloud.com.sv`. Categoría: **"Todas las demás categorías de apps"** (utilidad, productividad, comunicación)
- Violencia, sexo, lenguaje, drogas y apuestas: **No** a todo
- ¿Los usuarios pueden interactuar o intercambiar contenido? **Sí**: chat entre el técnico y la persona atendida
- ¿Comparte la ubicación del usuario? **No**
- ¿Permite compras digitales? **No**
- Resultado esperado: apta para todo público, o "Para mayores de 3 años" con la nota "Los usuarios interactúan"

### Seguridad de los datos

**Preguntas generales**
- ¿Recopila o comparte datos del usuario? **Sí**
- ¿Los datos se cifran en tránsito? **Sí**
- ¿Ofrece una forma de pedir que se borren los datos? **Sí**, escribiendo a soporte@powercloud.com.sv (lo dice la sección 7 de la política)

**Datos recopilados** (no se comparte ninguno con terceros):

| Tipo de dato | ¿Obligatorio? | Para qué |
|---|---|---|
| **Identificadores del dispositivo u otros IDs** (el ID de PowerCloud Remote) | Obligatorio | Funcionalidad de la app; seguridad (registro de conexiones) |
| **Información personal > Nombre** | Opcional (solo técnicos con sesión) | Administración de la cuenta |
| **Información personal > Dirección de correo** | Opcional (solo técnicos con sesión) | Administración de la cuenta |
| **Información personal > IDs de usuario** | Opcional (solo técnicos con sesión) | Administración de la cuenta; seguridad |
| **Información y rendimiento de la app > Otros datos de la app** (nombre del equipo, sistema, memoria) | Obligatorio | Funcionalidad de la app (inventario de soporte) |

**Qué NO se declara y por qué:** el contenido de las sesiones (pantalla, audio, archivos, portapapeles y chat) viaja cifrado de extremo a extremo. Google no pide declarar los datos cifrados de extremo a extremo que el servidor no puede leer. No se usa la ubicación ni la libreta de contactos.

---

## 3. Declaraciones de permisos (Política > Contenido de la app)

Para estas dos declaraciones Google pide un **video**. Grábalo con la grabadora de pantalla del teléfono, súbelo a YouTube como **"No listado"** y pega el enlace. El guion está en la sección 4.

### 3a. API de Accesibilidad

- ¿La app es una herramienta de accesibilidad? **No** (no tiene `isAccessibilityTool`).
- **Descripción del uso (es):**
```
PowerCloud Remote es una app de soporte remoto. El servicio de accesibilidad "PowerCloud Remote Input" se usa solo durante una sesión de soporte que el usuario aceptó en pantalla, para que el técnico al que el usuario le dio acceso pueda tocar, deslizar y escribir en el teléfono (dispatchGesture y escribir en el campo de texto activo). No se usa para recopilar, guardar ni compartir datos, ni fuera de una sesión activa. Antes de abrir los ajustes, la app muestra un aviso destacado que explica este uso, y el usuario debe tocar "Acepto, abrir ajustes". El permiso es opcional: sin él, el técnico solo puede ver la pantalla.
```
- **Description (en), si el formulario sale en inglés:**
```
PowerCloud Remote is a remote support app. The "PowerCloud Remote Input" accessibility service is used only during a support session that the user accepted on screen, so that the technician the user gave access to can tap, swipe and type on the phone (dispatchGesture and typing into the active text field). It is not used to collect, store or share data, nor outside an active session. Before opening the settings, the app shows a prominent disclosure explaining this use and the user must tap "Agree and open settings". The permission is optional: without it, the technician can only view the screen.
```

### 3b. Servicios en primer plano (Android 14+)

| Tipo | Justificación (es) |
|---|---|
| **mediaProjection** | Transmitir la pantalla al técnico durante una sesión de soporte que el usuario inició con "Compartir pantalla" y aceptó en el diálogo del sistema. La notificación queda visible mientras dura. |
| **microphone** | Enviar el audio al técnico solo si el usuario activa "Captura de audio" durante la sesión. |
| **specialUse** | Mantener el servicio disponible para conexiones de soporte que el usuario autorizó (ID y contraseña), con una notificación visible, sin empezar a capturar la pantalla hasta que el usuario lo aprueba. |

English:
- **mediaProjection:** Stream the screen to the technician during a support session the user started with "Share screen" and accepted in the system dialog. The notification stays visible while it lasts.
- **microphone:** Send audio to the technician only if the user turns on "Audio capture" during the session.
- **specialUse:** Keep the service available for support connections the user authorized (ID and password), with a visible notification, without starting screen capture until the user approves it.

### 3c. Otros permisos (sin formulario, por si el revisor pregunta)
- **REQUEST_IGNORE_BATTERY_OPTIMIZATIONS:** sin esta excepción Android corta la conexión de soporte en segundo plano, que es la función principal de la app. Solo se pide si el usuario activa quedar disponible para soporte.
- **SYSTEM_ALERT_WINDOW:** muestra la ventana flotante con el aviso de que hay una sesión activa y el botón para terminarla.
- **RECEIVE_BOOT_COMPLETED:** solo si el usuario activa "Iniciar al encender".
- No se pide acceso a todos los archivos: la app solo usa la carpeta que el usuario elige.

---

## 4. Guion del video (un solo video sirve para las dos declaraciones, 1 a 2 minutos)

Graba con el APK nuevo (con el aviso de accesibilidad actualizado):
1. Abrir PowerCloud Remote y tocar **Compartir pantalla**.
2. Tocar **Iniciar servicio** y mostrar el aviso contra estafas. Tocar **Estoy de acuerdo**.
3. Aceptar el aviso del servicio y el diálogo del sistema **"Compartir pantalla"**. Mostrar la notificación del servicio.
4. Tocar el interruptor **Control de entrada**. Mostrar el aviso destacado completo y tocar **Acepto, abrir ajustes**.
5. En Ajustes > Accesibilidad, activar **PowerCloud Remote Input** y aceptar el diálogo de Android.
6. Desde una PC, conectarse con el ID y la contraseña. En el teléfono, aceptar la conexión.
7. Mostrar al técnico tocando y escribiendo en el teléfono (abrir una app, escribir en un campo).
8. Activar **Captura de audio** (microphone).
9. Terminar la sesión desde el teléfono y **Detener servicio**.

---

## 5. Prueba cerrada (obligatoria para cuentas personales)

Google no deja pedir el acceso a Producción hasta que una **prueba cerrada** haya tenido **al menos 12 testers inscritos durante 14 días seguidos**.

1. Pruebas > **Prueba cerrada** > Crear segmento (o usar "Alpha").
2. **Testers:** crea una lista de correos (cuentas de Google) con al menos **12 personas**, y de preferencia 15 por si alguno se sale. Sirven compañeros, clientes y familiares.
3. Sube el **AAB** nuevo al segmento y envía la versión a revisión.
4. Cuando esté aprobada, comparte el **enlace de inscripción** con los testers. Cada uno debe abrirlo, tocar "Convertirse en tester" e **instalar la app desde Play**.
5. Los testers no deben salirse durante los **14 días**. Conviene que abran la app algunas veces: Google pregunta cómo se usó durante la prueba.
6. Al día 14, en el Panel aparece **"Solicitar acceso a producción"**. Pide responder unas preguntas sobre la prueba; abajo hay sugerencias de respuesta.
7. Con el acceso aprobado, se promueve la misma versión a Producción.

**Sugerencias para el cuestionario de producción:**
- *¿Cómo reclutaste testers?* Técnicos de PowerCloud El Salvador y clientes de soporte que usan la app en sus teléfonos.
- *¿Qué probaron?* Iniciar el servicio, conectarse desde una PC, control táctil por accesibilidad, transferencia de archivos y chat.
- *¿Qué cambiaste por sus comentarios?* Anota los ajustes que salgan durante esos 14 días (textos, avisos, errores corregidos).
- *¿Para quién es la app?* Personas y empresas que reciben soporte técnico remoto de PowerCloud El Salvador.

---

## 6. Orden de los pasos

1. Compilar el AAB y el APK nuevos con el workflow **"PowerCloud Remote - Android"**, firmados con la llave de subida de los secretos.
2. Volver a sacar las capturas con el APK nuevo: instalarlo en el emulador, iniciar el servicio y correr `python powercloud/play/capturas.py`.
3. Llenar la ficha (sección 1) y Contenido de la app (secciones 2 y 3).
4. Grabar y subir el video (sección 4).
5. Prueba cerrada con 12 testers y 14 días (sección 5).
6. Pedir el acceso a Producción y publicar.
