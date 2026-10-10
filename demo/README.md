# AMIBA 2 — Blink LED (Spartan-6 XC6SLX9-2FTG256)

Guía completa para programar la FPGA de la AMIBA 2 **100% desde la terminal**.

## ¿Necesito entrar a ISE Design Suite (la interfaz gráfica)?

**No.** Todo el flujo es de terminal:

- **Neovim** → escribes los archivos del diseño (VHDL y restricciones de pines).
- **Docker** → compila tu código con ISE 14.7 real, corriendo "headless" (sin
  ventanas) dentro de un contenedor. Las herramientas de línea de comandos de
  ISE (`xst`, `ngdbuild`, `map`, `par`, `bitgen`) hacen todo: lo mismo que haría
  el Project Navigator pero desde una consola.
- **USB** → otro contenedor (openFPGALoader) graba la FPGA usando el
  **programador USB interno** de la placa (chip FT2232HL), sin cables JTAG
  externos y **sin sudo**.

No instalas nada en tu sistema: el compilador vive dentro del contenedor
`docked-ise-147` y el programador dentro de `fpgaload`.

## Lo que ya está resuelto (no tienes que repetirlo)

| Pieza | Dónde vive | Para qué sirve |
|---|---|---|
| ISE 14.7 + licencia | contenedor `docked-ise-147` (+ `~/fpga/Docked-ISE-147/Resources/Xilinx.lic`) | sintetiza y genera el `.bit` (licencia ISE WebPACK libre, HOSTID=ANY, sirve para el Spartan-6) |
| openFPGALoader | contenedor `fpgaload` + script `~/fpga/oload` | graba la FPGA por el programador USB |
| Proyecto de ejemplo | `~/fpga/demo` | tu punto de partida |

---

## Paso 1 — Crea la carpeta de tu proyecto

Copia la plantilla `demo` (así heredas el `Makefile`, la UCF y el VHDL listos):

```bash
mkdir -p ~/fpga
cp -r ~/fpga/demo ~/fpga/mi_proyecto
cd ~/fpga/mi_proyecto
```

Esto es lo que hay dentro (y para qué sirve):

```
blink.vhd    →  tu diseño (VHDL): el LED que parpadea
blink.ucf    →  restricciones: a qué pines del FPGA va cada señal
blink.prj    →  lista de archivos VHDL que debe leer el sintetizador
blink.xst    →  opciones del sintetizador xst (parte xc6slx9-2ftg256, etc.)
Makefile     →  las órdenes de compilación y grabado (todo encadenado)
```

## Paso 2 — Edita el diseño con Neovim

```bash
nvim blink.vhd
```

El código es muy corto y vale la pena entenderlo:

- `clk` : el reloj de 50 MHz de la placa (pin E7). Cada flanco de subida cuenta `cnt = cnt + 1`.
- `cnt(24)` : el bit 24 del contador; cambia de estado cada `2^25 / 50 MHz = 0.67 s`, o sea parpadea ~cada 1.3 segundos.
- `led_r` : LED D1 rojo (pin N1); `led_g` : LED D1 verde (pin P1). Los LEDs de la AMIBA 2 son de cátodo común, así que se encienden con un `1`.

Guarda con `:wq`.

## Paso 3 — (Opcional) Cambia qué pines usas

Si quieres mover el LED o usar un switch, edita `blink.ucf`:

```ucf
NET "clk"   LOC = E7;      # oscilador de 50 MHz
NET "led_r" LOC = N1;      # LED D1 rojo
NET "led_g" LOC = P1;      # LED D1 verde
```

Pines de la AMIBA 2 (manual Rev C, Tabla 3): D1→N1/P1/M4, D2→R2/T4/R1, ..., `E7` reloj.

## Paso 4 — Compila (dentro del contenedor)

```bash
make
```

No tienes que instalar ISE ni abrir ninguna ventana: este comando lanza
`docker run` sobre `docked-ise-147` que hace la cadena completa, y verás
claramente las 5 etapas:

| Etapa | Orden | Qué hace | Salida |
|---|---|---|---|
| `xst` | 1 | Sintetiza el VHDL → compuertas lógicas | `blink.ngc` |
| `ngdbuild` | 2 | Junta tu diseño + pines de la UCF | `blink.ngd` |
| `map` | 3 | Asigna LUTs/Flip-flops del Spartan-6 | `mapped.ncd` |
| `par` | 4 | Coloca y enruta («Routing: Completed») | `routed.ncd` |
| `bitgen` | 5 | Genera el binario para la FPGA (+DRC) | `blink.bit` |

Éxito = cada etapa termina con `Number of errors: 0` y te queda `blink.bit`
(unos 340 KB). Tardará unos pocos minutos la primera vez y segundos después.

## Paso 5 — Verifica que la placa esté conectada

```bash
~/fpga/oload -c ft2232 --detect
```

Debe responder algo así:

```
idcode 0x4001093
model  xc6slx9
irlength 6
```

Si no aparece, revisa que el cable USB esté conectado. El programador es el
USB integrado de la AMIBA 2 (FT2232HL, `0403:6010`): no hace falta cable JTAG
ni drivers especiales.

## Paso 6 — Graba la FPGA (SRAM)

```bash
make program
```

Al final verás:

```
Load SRAM: [========] 100.00%
Done
isc_done 1
```

…y el **LED D1 de la placa parpadea rojo/verde**.

> Nota: estás grabando la **SRAM** → el diseño es **volátil**: si apagas la
> placa, se borra y vuelve a estar vacía. Es lo más seguro para probar.

---

## Tu ciclo de trabajo de aquí en adelante

```bash
cd ~/fpga/mi_proyecto
nvim blink.vhd        # 1. editar
make                  # 2. compilar
make program          # 3. grabar en SRAM
```

Si no cambiaste nada, `make` no recompila (usa las fechas de los archivos).
`make program` siempre compila primero y luego graba.

---

## Solución de problemas

- **`Open file FAIL`** al programar → estás corriendo `make program` desde otra
  carpeta. Entra a la carpeta del proyecto (`cd ~/fpga/mi_proyecto`).
- **No detecta la placa** → revisa el USB y repite el Paso 5.
- **Archivos con dueño `root`** → el contenedor los creó; recupera el control
  con `make fix-owner`.
- **Quieres que cargue al encender (persistente)** → `make flash` graba la
  **Flash SPI** en vez de la SRAM. (En esta práctica se dejó deliberadamente
  sin tocar.)
- **Cambiar velocidad JTAG** → por defecto 6 MHz (ideal para el FT2232HL).

## Datos de la placa

- FPGA: Xilinx Spartan-6 **XC6SLX9-2FTG256** (idcode `0x4001093`).
- Reloj: oscilador de **50 MHz** en pin `E7`.
- LEDs RGB propósitos generales D1–D8, cátodo común (se encienden con `1`).
- Programador integrado FT2232HL (FIFO dual), usado por el contenedor `fpgaload`.