# PowerCloud Engine (binario)

`pce-agente` (equipo del cliente) y `pce-conector` (PC del técnico) son el túnel de **PowerCloud Engine**. Son programas independientes,
propiedad de PowerCloud El Salvador, distribuido junto a PowerCloud Remote. **No es parte del
código fuente de este repositorio** ni está cubierto por su licencia AGPL-3.0.

PowerCloud Remote lo ejecuta como proceso aparte (`src/powercloud_engine.rs`) y se comunica con él
solo por su entrada y salida estándar. Si el binario no está, PowerCloud Remote funciona igual.

| Plataforma | Archivo | Versión del Engine |
|---|---|---|
| Windows x64 | windows-x64/pce-agente.exe, pce-conector.exe, pce-visor.exe | b4f8ebf |
