PART = xc6slx9-2ftg256
LIC  = $(CURDIR)/../Resources/Xilinx.lic
ISE  = docker run --rm -w /workspace \
        -v $(CURDIR):/workspace \
        -v $(LIC):/root/.Xilinx/Xilinx.lic \
        docked-ise-147
OLOAD ?= $(HOME)/fpga/oload

all: blink.bit

blink.ngc: blink.vhd blink.prj blink.xst
	$(ISE) xst -ifn blink.xst

blink.ngd: blink.ngc blink.ucf
	$(ISE) ngdbuild -uc blink.ucf -p $(PART) blink.ngc

mapped.ncd: blink.ngd
	$(ISE) map -w -p $(PART) -o mapped.ncd blink.ngd

routed.ncd: mapped.ncd
	$(ISE) par -w mapped.ncd routed.ncd

blink.bit: routed.ncd
	$(ISE) bitgen -w routed.ncd blink.bit

program: blink.bit
	$(OLOAD) -c ft2232 blink.bit

flash: blink.bit
	$(OLOAD) -c ft2232 -f blink.bit

clean:
	$(ISE) rm -rf .Xil xst *.ngc *.ngd *.ncd *.pcf *.bit *.log

fix-owner:
	$(ISE) chown -R 1000:1000 /workspace

.PHONY: all program flash clean fix-owner