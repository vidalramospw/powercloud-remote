//! PowerCloud Engine: lanza el agente del tunel propio (`pce-agente`, programa aparte que viaja en
//! la misma carpeta) junto al servidor y le pasa por la entrada estandar el ID, el permiso de tunel
//! y los hash de las contrasenas, para que el tecnico use lo mismo que el cliente ve en pantalla.
//! Si el programa no esta en la carpeta no hace nada.
//!
//! La solicitud y el aviso de cada tunel se muestran en la ventana de conexiones (la misma de las
//! sesiones de escritorio remoto): con contrasena abre de una y queda el aviso con Desconectar; sin
//! contrasena aparece con Aceptar / Rechazar.

use hbb_common::{
    config::{decode_permanent_password_h1_from_storage, local_permanent_password_storage_is_usable_for_auth, Config},
    log,
    password_security as password,
    sha2::{Digest, Sha256},
};
use crate::ipc::Data;
use hbb_common::tokio::{runtime::Handle, sync::mpsc};
use std::collections::HashMap;
use std::io::{BufRead, BufReader, Write};
use std::path::Path;
use std::process::{ChildStdin, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::time::Duration;

type Entrada = Arc<Mutex<ChildStdin>>;

/// Ids de conexion para la ventana de conexiones, lejos de los de las sesiones normales.
const ID_BASE: i32 = 1_000_000_000;

lazy_static::lazy_static! {
    /// Tuneles mostrados en la ventana de conexiones: numero -> canal hacia esa ventana.
    static ref TUNELES: Mutex<HashMap<u64, mpsc::UnboundedSender<Data>>> = Default::default();
}

/// Usuario "de Windows" especial con que el tecnico pide la terminal de administrador sin
/// credenciales: la aprueba en pantalla la persona frente al equipo (si su usuario de Windows es
/// administrador), igual que el "Si" de un UAC. Los <> no son validos en usuarios de Windows.
pub const APROBACION_ADMIN: &str = "<pc-aprobacion-admin>";

pub fn es_aprobacion_admin(terminal: bool, usuario: &str) -> bool {
    terminal && usuario.trim() == APROBACION_ADMIN
}

pub fn iniciar() {
    let Ok(exe) = std::env::current_exe() else {
        return;
    };
    let agente = exe.with_file_name(if cfg!(windows) { "pce-agente.exe" } else { "pce-agente" });
    if !agente.exists() {
        return;
    }
    let _ = std::thread::Builder::new().name("powercloud-engine".into()).spawn(move || loop {
        if let Err(e) = ejecutar(&agente) {
            log::warn!("PowerCloud Engine: {e}");
        }
        std::thread::sleep(Duration::from_secs(10));
    });
}

fn ejecutar(agente: &Path) -> std::io::Result<()> {
    let _ = std::fs::create_dir_all(Config::log_path());
    let registro = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(Config::log_path().join("engine.log"))?;
    let mut cmd = Command::new(agente);
    cmd.arg("--datos")
        .arg(Config::path("engine"))
        .arg("integrado")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(registro);
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        cmd.creation_flags(CREATE_NO_WINDOW);
    }
    let rt = hbb_common::tokio::runtime::Builder::new_multi_thread()
        .worker_threads(1)
        .enable_all()
        .build()?;
    let mut hijo = cmd.spawn()?;
    log::info!("PowerCloud Engine iniciado");
    let Some(entrada) = hijo.stdin.take() else {
        let _ = hijo.kill();
        return Ok(());
    };
    let entrada: Entrada = Arc::new(Mutex::new(entrada));
    if let Some(salida) = hijo.stdout.take() {
        let entrada = entrada.clone();
        let handle = rt.handle().clone();
        std::thread::spawn(move || {
            for linea in BufReader::new(salida).lines().map_while(Result::ok) {
                log::info!("PowerCloud Engine: {linea}");
                if let Ok(v) = serde_json::from_str::<serde_json::Value>(&linea) {
                    evento(&handle, &entrada, &v);
                }
            }
        });
    }
    let mut anterior = String::new();
    loop {
        let actual = estado();
        if actual != anterior {
            if !enviar(&entrada, &actual) {
                break;
            }
            anterior = actual;
        }
        if hijo.try_wait()?.is_some() {
            break;
        }
        std::thread::sleep(Duration::from_secs(3));
    }
    let _ = hijo.kill();
    let _ = hijo.wait();
    for (_, tx) in TUNELES.lock().unwrap().drain() {
        let _ = tx.send(Data::Close);
    }
    Ok(())
}

fn enviar(entrada: &Entrada, linea: &str) -> bool {
    let mut e = entrada.lock().unwrap();
    writeln!(e, "{linea}").and_then(|_| e.flush()).is_ok()
}

/// Eventos del agente: solicitud (pide aceptar), abierto (tunel en uso) y cerrado.
fn evento(rt: &Handle, entrada: &Entrada, v: &serde_json::Value) {
    let n = v["n"].as_u64().unwrap_or_default();
    let texto = |k: &str| v[k].as_str().unwrap_or_default().to_owned();
    match v["t"].as_str() {
        Some("solicitud") => mostrar(rt, entrada, n, texto("tecnico"), texto("ip"), texto("destino"), false),
        Some("abierto") => {
            if !TUNELES.lock().unwrap().contains_key(&n) {
                mostrar(rt, entrada, n, texto("tecnico"), texto("ip"), texto("destino"), true);
            }
        }
        // Chat del tecnico (escritorio remoto propio): a la ventana de conexiones.
        Some("chat") => {
            if let Some(tx) = TUNELES.lock().unwrap().get(&n) {
                let _ = tx.send(Data::ChatMessage { text: texto("texto") });
            }
        }
        Some("cerrado") => {
            if let Some(tx) = TUNELES.lock().unwrap().remove(&n) {
                let _ = tx.send(Data::Close);
            }
        }
        _ => {}
    }
}

/// Agrega el tunel a la ventana de conexiones y reenvia al agente lo que la persona elija.
fn mostrar(rt: &Handle, entrada: &Entrada, n: u64, tecnico: String, ip: String, destino: String, autorizado: bool) {
    let (tx_a_cm, rx_a_cm) = mpsc::unbounded_channel();
    let (tx_de_cm, mut rx_de_cm) = mpsc::unbounded_channel();
    let _ = tx_a_cm.send(Data::Login {
        id: ID_BASE.saturating_add(n as i32),
        is_file_transfer: false,
        is_view_camera: false,
        is_terminal: false,
        peer_id: ip,
        name: tecnico,
        avatar: String::new(),
        authorized: autorizado,
        port_forward: destino,
        keyboard: false,
        clipboard: false,
        audio: false,
        file: false,
        file_transfer_enabled: false,
        restart: false,
        recording: false,
        block_input: false,
        privacy_mode: false,
        from_switch: false,
    });
    TUNELES.lock().unwrap().insert(n, tx_a_cm);
    rt.spawn(async move {
        if let Err(e) = crate::server::start_ipc(rx_a_cm, tx_de_cm).await {
            log::debug!("PowerCloud Engine: ventana de conexiones: {e}");
        }
    });
    let entrada = entrada.clone();
    rt.spawn(async move {
        let mut respondido = autorizado;
        while let Some(d) = rx_de_cm.recv().await {
            match d {
                Data::Authorize if !respondido => {
                    respondido = true;
                    enviar(&entrada, &serde_json::json!({"t": "respuesta", "n": n, "ok": true}).to_string());
                }
                // Lo que responde el cliente en el chat de la ventana de conexiones.
                Data::ChatMessage { text } => {
                    enviar(&entrada, &serde_json::json!({"t": "chat", "n": n, "texto": text}).to_string());
                }
                Data::Close => {
                    let orden = if respondido {
                        serde_json::json!({"t": "cerrar", "n": n})
                    } else {
                        serde_json::json!({"t": "respuesta", "n": n, "ok": false})
                    };
                    enviar(&entrada, &orden.to_string());
                    break;
                }
                _ => {}
            }
        }
    });
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn relay() -> String {
    let propio = Config::get_option("pc-engine-relay");
    if !propio.is_empty() {
        return propio;
    }
    let servidor = Config::get_rendezvous_server();
    let host = servidor.split(':').next().unwrap_or_default();
    if host.is_empty() {
        String::new()
    } else {
        // Puerta HTTPS del servidor API (IIS aun no tiene WebSocket en 443).
        format!("wss://{host}:21114/engine")
    }
}

/// Lo que el agente necesita saber, como una linea JSON.
fn estado() -> String {
    let sal = Config::get_effective_permanent_password_salt();
    let h1 = |clave: &str| {
        let mut h = Sha256::new();
        h.update(clave.as_bytes());
        h.update(sal.as_bytes());
        hex(&h.finalize())
    };
    let temporal = password::temporary_password();
    let temporal = if password::temporary_enabled() && !temporal.is_empty() { h1(&temporal) } else { String::new() };
    let (guardada, sal_guardada) = Config::get_local_permanent_password_storage_and_salt();
    let permanente = if password::permanent_enabled()
        && local_permanent_password_storage_is_usable_for_auth(&guardada, &sal_guardada)
    {
        match decode_permanent_password_h1_from_storage(&guardada) {
            Some(h) => hex(&h),
            // Almacenamiento antiguo en claro.
            None => h1(&guardada),
        }
    } else {
        String::new()
    };
    // Identidad del agente derivada de la llave del equipo: estable mientras el equipo conserve su ID,
    // aunque se borre la carpeta del agente o se use sin instalar.
    let semilla = {
        let mut h = Sha256::new();
        h.update(b"PowerCloudEngine/identidad/1");
        h.update(&Config::get_key_pair().0);
        hex(&h.finalize())
    };
    serde_json::json!({
        "semilla": semilla,
        "id": Config::get_id(),
        "relay": relay(),
        "tunel": crate::server::Connection::is_permission_enabled_locally("enable-tunnel"),
        "teclado": crate::server::Connection::is_permission_enabled_locally("enable-keyboard"),
        "portapapeles": crate::server::Connection::is_permission_enabled_locally("enable-clipboard"),
        "aprobacion": Config::get_option("approve-mode"),
        "sal": sal,
        "temporal": temporal,
        "permanente": permanente,
    })
    .to_string()
}
