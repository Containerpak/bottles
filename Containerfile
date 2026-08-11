# 1. BUILD
FROM ghcr.io/containerpak/gtk-sdk:main AS builder

WORKDIR /src

RUN apt update && apt install -y --no-install-recommends \
    ca-certificates build-essential golang-go gettext git make meson ninja-build \
    python3 python3-pip python3-dev python3-gi python3-gi-cairo python3-requests \
    python3-wheel python3-cairo python3-dbus python3-packaging python3-setproctitle \
    python3-venv libglib2.0-dev libgirepository1.0-dev libcurl4-openssl-dev \
    libwebkit2gtk-4.1-0 gir1.2-gtk-4.0 gir1.2-gtk-3.0 gir1.2-adw-1 \
    gir1.2-gstreamer-1.0 gir1.2-notify-0.7 xdg-utils wget && \
    rm -rf /var/lib/apt/lists/*

RUN apt update && apt install -y --no-install-recommends blueprint-compiler desktop-file-utils && \
    rm -rf /var/lib/apt/lists/*

ARG BOTTLES_REVISION=884f60ae7630349490cc7b77df98db39a56c981b
RUN git clone --depth 1 https://github.com/bottlesdevs/Bottles.git bottles && \
    cd bottles && git fetch --depth 1 origin ${BOTTLES_REVISION} && git checkout --detach FETCH_HEAD && \
    sed -E '/^(pycairo|PyGObject)==/d' requirements.txt > /tmp/bottles-requirements.txt && \
    python3 -m pip install --ignore-installed --no-cache-dir --break-system-packages -r /tmp/bottles-requirements.txt && \
    touch /.flatpak-info && \
    meson setup --prefix=/usr build && \
    DESTDIR=/staging ninja -C build install

RUN git clone --depth 1 --branch v0.1.5 https://github.com/fvs-lab/fvs2.git /tmp/fvs2 && \
    git clone --depth 1 --branch v0.0.1 https://github.com/fvs-lab/core.git /tmp/core && \
    cd /tmp/fvs2 && go build -o /usr/local/bin/fvs2 ./cmd/fvs2

RUN mkdir -p /app/share/bottles/winebridge && \
    wget -qO /tmp/winebridge.tar.xz https://github.com/bottlesdevs/winebridge/releases/download/1.2.0/WineBridge-75aa25e.tar.xz && \
    tar -xJf /tmp/winebridge.tar.xz -C /app/share/bottles/winebridge

# 2. RUNTIME
FROM ghcr.io/containerpak/wine:main

RUN apt update && apt install -y --no-install-recommends \
    ca-certificates libc-bin libcurl4 libdrm2 libegl1 libfreetype6 libfreetype6:i386 libgl1 libglib2.0-0 libglib2.0-bin libgles2 libgnutls30t64 libgnutls30t64:i386 libgstreamer1.0-0 libunwind8 libunwind8:i386 libusb-1.0-0 libusb-1.0-0:i386 \
    libgstreamer-plugins-base1.0-0 libnotify4 libsdl2-2.0-0 libsecret-1-0 libvulkan1 \
    cabextract desktop-file-utils imagemagick p7zip-full unzip vmtouch vulkan-tools x11-utils xdg-utils \
    python3 python3-gi python3-gi-cairo python3-cairo python3-dbus python3-requests python3-vkbasalt \
    libwebkit2gtk-4.1-0 gir1.2-adw-1 gir1.2-gdkpixbuf-2.0 gir1.2-gtk-4.0 \
    gir1.2-gst-plugins-base-1.0 gir1.2-gtksource-5 gir1.2-notify-0.7 \
    gir1.2-xdp-1.0 gir1.2-xdpgtk4-1.0 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /staging/usr/ /usr/
COPY --from=builder /usr/local/ /usr/local/
COPY --from=builder /app/ /app/
COPY cpak-bottles /usr/local/bin/cpak-bottles

RUN touch /.flatpak-info && \
    mv /usr/bin/bottles /usr/bin/bottles-real && \
    mv /usr/local/bin/cpak-bottles /usr/bin/bottles && \
    chmod 0755 /usr/bin/bottles && \
    glib-compile-schemas /usr/share/glib-2.0/schemas && \
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor && \
    update-desktop-database -q /usr/share/applications

ENV PATH="/app/bin:/usr/local/bin:/usr/bin:/bin"
ENV BOTTLES_CPAK=1

ENTRYPOINT ["/usr/bin/bottles"]
