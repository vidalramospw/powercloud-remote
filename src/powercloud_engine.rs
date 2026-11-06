//! PowerCloud Engine: lanza el agente del tunel propio (`pce-agente`, programa aparte que viaja en
//! la misma carpeta) junto al servidor y le pasa por la entrada estandar el ID, el permiso de tunel
//! y los hash de las contrasenas, para que el tecnico use lo mismo que el cliente ve en pantalla.
//! Si el programa no esta en la carpeta no hace nada.

use hbb_common::{
    config::{decode_permanent_password_h1_from_storage, local_permanent_password_storage_is_usable_for_auth, Config},
    log,
    password_security as password,
    sha2::{Digest, Sha256},
};
use std::io::{BufRead, BufReader, Write};
use std::path::Path;
use std::process::{Command, Stdio};
use std::time::Duration;

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
    let mut hijo = cmd.spawn()?;
    log::info!("PowerCloud Engine iniciado");
    if let Some(salida) = hijo.stdout.take() {
        std::thread::spawn(move || {
            for linea in BufReader::new(salida).lines().map_while(Result::ok) {
                log::info!("PowerCloud Engine: {linea}");
            }
        });
    }
    let Some(mut entrada) = hijo.stdin.take() else {
        let _ = hijo.kill();
        return Ok(());
    };
    let mut anterior = String::new();
    loop {
        let actual = estado();
        if actual != anterior {
            if writeln!(entrada, "{actual}").and_then(|_| entrada.flush()).is_err() {
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
    Ok(())
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
    serde_json::json!({
        "id": Config::get_id(),
        "relay": relay(),
        "tunel": crate::server::Connection::is_permission_enabled_locally("enable-tunnel"),
        "aprobacion": Config::get_option("approve-mode"),
        "sal": sal,
        "temporal": temporal,
        "permanente": permanente,
    })
    .to_string()
}
