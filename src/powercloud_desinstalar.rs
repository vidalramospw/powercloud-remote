//! Desinstalador de PowerCloud Remote con ventanas propias: confirma, corre el script oculto y
//! avisa al terminar (antes se veia la consola de cmd).

use crate::lang::translate;

const TITULO: &str = "PowerCloud Remote";

fn ancho(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}

fn mensaje(texto: &str, banderas: u32) -> i32 {
    use winapi::um::winuser::MessageBoxW;
    let (t, c) = (ancho(texto), ancho(TITULO));
    // SAFETY: ambos textos terminan en 0 y viven durante la llamada.
    unsafe { MessageBoxW(std::ptr::null_mut(), t.as_ptr(), c.as_ptr(), banderas) }
}

/// Entrada de `--uninstall` (Panel de control o menu Inicio).
pub fn ejecutar() {
    use winapi::um::winuser::{
        IDYES, MB_DEFBUTTON2, MB_ICONERROR, MB_ICONQUESTION, MB_SETFOREGROUND, MB_YESNO,
    };
    let pregunta = translate("Uninstall PowerCloud Remote from this device? Remote support will no longer be possible until it is installed again.".into());
    if mensaje(&pregunta, MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2 | MB_SETFOREGROUND) != IDYES {
        return;
    }
    let listo = translate("PowerCloud Remote was uninstalled.".into());
    if let Err(err) = crate::platform::uninstall_me_con_aviso(&listo) {
        hbb_common::log::error!("Failed to uninstall: {}", err);
        let texto = format!("{}\n\n{}", translate("PowerCloud Remote could not be uninstalled.".into()), err);
        mensaje(&texto, MB_ICONERROR | MB_SETFOREGROUND);
    }
}
