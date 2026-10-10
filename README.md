# AMIBA 2 + ISE 14.7 en Windows 11 (WSL2 + Docker + openFPGALoader)

> **Para quien ejecuta esto:** este documento lo ejecuta un agente asistente
> **directamente en la máquina Windows 11**. Cada sección es una serie de
> comandos que deben correrse en orden (con permisos de administrador cuando se
> indique), verificando los resultados esperados antes de continuar. Nada de ISE
> se instala en Windows: el ISE 14.7 corre headless dentro del contenedor
> `docked-ise-147` y se accede por WSL2. La USB de la placa se pasa del host
> Windows al WSL con `usbipd`.

---

## 0. Resultado final

Terminada la guía, en la terminal del WSL se podrá hacer el ciclo completo:

```bash
cd ~/fpga/amiba2/demo
nvim blink.vhd        # 1. editar (o cualquier archivo)
make                  # 2. sintetizar xst→ngdbuild→map→par→bitgen (en Docker)
make program          # 3. grabar SRAM por FT2232 (LED D1 rojo/verde/azul)
```

Todo 100% por terminal, sin abrir ISE Design Suite.

## 1. Requisitos

- Windows 11 x64 con actualizaciones (build 22H2+).
- Contraseña de administrador disponible.
- Conexión USB de la placa **AMIBA 2** (programador FT2232HL, `VID 0403 : PID 6010`, "INTESC AMIBA2-FTG").
- Disco con al menos **60 GB libres** en la unidad donde viva el WSL (por la imagen de ISE, 55 GB).
- Lo deseable (ver Paso 4): acceso al tar.gz de las imágenes Docker ya armadas en otra máquina, vía USB/red.

## 2. Instalar WSL2 con Ubuntu

Desde PowerShell **como administrador**:

```powershell
wsl --install -d Ubuntu
```

Se pedirá reiniciar. Al volver, Windows abre Ubuntu para crear usuario/contraseña de Linux.
Confirmar versión 2 y distribución instalada:

```bash
wsl -l -v
```

Dentro de Ubuntu (actualizar):

```bash
sudo apt update && sudo apt upgrade -y
```

> Si `wsl -l -v` muestra "VERSION 1", en PowerShell admin: `wsl --set-version Ubuntu 2`.

## 3. Docker dentro del WSL (motor, sin Docker Desktop)

En la terminal Ubuntu:

```bash
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Cerrar y reabrir la terminal Ubuntu (para que el grupo `docker` surta efecto). Comprobar:

```bash
docker info >/dev/null && echo "Docker OK (sin sudo)"
```

> Si `systemctl` no funciona (WSL sin systemd), crear `/etc/wsl.conf` con:
> ```ini
> [boot]
> systemd=true
> ```
> y reiniciar con `wsl --shutdown` desde PowerShell.

## 4. Traer las imágenes y el código

Hay **dos opciones**. La A es la recomendada (no depende de tu internet lento).

### Opción A — Exportar/importar las imágenes ya construidas (recomendada)

En la **máquina Arch Linux (ya configurada)**, exportar las imágenes a un USB
o unidad que lea Windows (FAT32/exFAT). recomendado gzip:

```bash
mkdir -p /media/transferir
docker save docked-ise-147:latest | gzip > /media/transferir/ise147.tar.gz
docker save fpgaload:latest        | gzip > /media/transferir/fpgaload.tar.gz
```

> Tamaños aproximados: `ise147.tar.gz` ~10–20 GB (la imagen sin comprimir son 55 GB),
> `fpgaload.tar.gz` ~200–600 MB. Copiar también la carpeta de este repo.

En la **máquina Windows 11**, dentro de Ubuntu WSL, cargar y verificar:

```bash
mkdir -p ~/fpga/transferir
# montar/copiar el USB → ~/fpga/transferir (p. ej. ls /mnt/*/transferir)
cd ~/fpga/transferir
docker load -i ise147.tar.gz
docker load -i fpgaload.tar.gz
docker images
# debe listar: docked-ise-147:latest (55GB) y fpgaload:latest
```

### Opción B — Construir desde cero (solo si no puedes transportar la imagen)

Requiere internet; con tu enlace lento tardará horas.

```bash
git clone https://github.com/I-A-S/Docked-ISE-147
cd Docked-ISE-147
mkdir -p Resources
# Poner aquí el instalador: Xilinx_ISE_DS_Lin_14.7_1015_1.tar (6.1 GB)
# Poner aquí la licencia: Resources/Xilinx.lic
docker build -t docked-ise-147 .
```

Para el programador:

```bash
docker build -f fpgaload.Dockerfile -t fpgaload .
```

## 5. Instalar el puente USB (usbipd-win)

Es lo que permite que el programador FT2232 de la AMIBA sea visible dentro del WSL.

Desde PowerShell **como administrador**:

```powershell
winget install usbipd
```

Conectar la AMIBA por USB. Listar y localizar el device:

```powershell
usbipd list
```

Buscar la línea tipo `0403:6010   ...  "INTESC AMIBA2-FTG"` y anotar su **BUSID**
(por ejemplo `1-2`). Luego:

```powershell
usbipd bind --busid <BUSID>
```

En la terminal Ubuntu:

```bash
usbipd attach --wsl --busid <BUSID> --auto-attach
```

Verificar dentro de WSL (debe aparecer `0403:6010`):

```bash
lsusb
```

> `--auto-attach` mantiene el passthrough tras reinicios. Si `lsusb` no muestra nada,
> correr el attach desde PowerShell admin y reintentar. Ocasionalmente hay que
> repetir `attach` después de cada reinicio de la placa.

## 6. Colocar el proyecto y el programador

Clonar este repo (o copiarlo del USB) y dejar el `oload` en `~/fpga/`:

```bash
mkdir -p ~/fpga
git clone https://github.com/joelcf86/amiba2-fpga ~/fpga/amiba2
chmod +x ~/fpga/amiba2/oload
# dejar el wrapper donde lo espera el Makefile:
ln -s ~/fpga/amiba2/oload ~/fpga/oload
```

Verificar que el contenedor encuentra la placa (desde `~/fpga/amiba2/demo`):

```bash
cd ~/fpga/amiba2/demo
docker run --rm --privileged -v /dev/bus/usb:/dev/bus/usb fpgaload -c ft2232 --detect
```

Resultado esperado:

```
idcode 0x4001093  manufacturer xilinx  family spartan6  model xc6slx9  irlength 6
```

## 7. Sintetizar (ISE 14.7 en Docker)

```bash
cd ~/fpga/amiba2/demo
make
```

Etapas y salidas:

| Etapa | Comando | Salida |
|---|---|---|
| Síntesis | `xst` | `blink.ngc` |
| Red de diseño | `ngdbuild -uc blink.ucf` | `blink.ngd` |
| Mapeo | `map -w` | `mapped.ncd` |
| Posicionamiento/enrutado | `par -w` | `routed.ncd` |
| Bitstream | `bitgen -w` | `blink.bit` (~340 KB) |

Éxito = `Number of errors: 0` en cada una.

## 8. Grabar la SRAM

```bash
make program
```

Final esperado:

```
Load SRAM: [========] 100.00%
Done
isc_done 1
```

El **LED D1** parpadea rojo → verde → azul (~0.67 s cada uno). Es volátil:
al apagar la placa se pierde (la Flash SPI no se toca salvo `make flash`).

## 9. Solución de problemas

- **`lsusb` no muestra la AMIBA** → el attach falló. PowerShell admin: `usbipd list`
  (verificar `Attached`), `usbipd attach --wsl --busid <BUSID> --auto-attach`, re-verificar.
- **`docker: permission denied`** → reabrir la terminal Ubuntu después del `usermod -aG docker`.
- **`Open file FAIL` al programar** → el documento se ejecutó fuera de `~/fpga/amiba2/demo`; `make program` monta la carpeta actual.
- **`ERROR:Security` / licencia** → asegúrate de que `Resources/Xilinx.lic` es la **WebPACK libre**
  (contiene `HOSTID=ANY`); en el contenedor no hay ancla a disco, el error habitual viene de una
  `Xilinx.lic` tipo Embedded anclada a serial. No se debe usar `Xilinx_embedded.lic`.
- **`output file mapped.ncd already exists`** → el `Makefile` ya usa `map -w`, no debería ocurrir.
- **Espacio** → revisar con `docker system df` y `du -sh /var/lib/docker`; la imagen pesa 55 GB.
- **Archivos con dueño `root`** → ejecutar `make fix-owner` dentro de `demo`.

## 10. Referencia rápida (dentro de `~/fpga/amiba2/demo`)

```bash
nvim blink.vhd    # editar diseño
make              # compilar
make program      # grabar SRAM
make flash        # grabar Flash SPI (carga al encender)
make clean        # borrar artefactos
make fix-owner    # arreglar permisos tras construir
```