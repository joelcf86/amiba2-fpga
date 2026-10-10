FROM archlinux:base
RUN pacman -Sy --noconfirm --needed openfpgaloader usbutils && pacman -Scc --noconfirm
ENTRYPOINT ["openFPGALoader"]
