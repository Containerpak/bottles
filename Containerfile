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

ARG VERSION=main
RUN git clone --depth 1 https://github.com/bottlesdevs/Bottles.git --branch ${VERSION} bottles && \
    cd bottles && \
    sed -E '/^(pycairo|PyGObject)==/d' requirements.txt > /tmp/bottles-requirements.txt && \
    python3 -m pip install --ignore-installed --no-cache-dir --break-system-packages -r /tmp/bottles-requirements.txt && \
    touch /.flatpak-info && \
    meson setup --prefix=/usr build && \
    DESTDIR=/staging ninja -C build install

RUN git clone --depth 1 --branch v0.1.5 https://github.com/fvs-lab/fvs2.git /tmp/fvs2 && \
    git clone --depth 1 --branch v0.0.1 https://github.com/fvs-lab/core.git /tmp/core && \
    cd /tmp/fvs2 && go build -o /usr/local/bin/fvs2 ./cmd/fvs2

RUN mkdir -p /app/bin /app/etc/runtime /app/share/licenses/umu-launcher && \
    wget -qO /tmp/umu.tar https://github.com/Open-Wine-Components/umu-launcher/releases/download/1.4.4/umu-launcher-1.4.4-zipapp.tar && \
    tar -xf /tmp/umu.tar --strip-components=1 -C /tmp && \
    install -m755 /tmp/umu-run /app/bin/umu-run && \
    wget -qO /app/share/licenses/umu-launcher/LICENSE https://raw.githubusercontent.com/Open-Wine-Components/umu-launcher/cf3d1b107147480c447ffbfb3f789dc74335074c/LICENSE && \
    wget -qO /tmp/runtime.tar.gz https://github.com/bottlesdevs/runtime/releases/download/0.6.3/runtime-0.6.3.tar.gz && \
    tar -xzf /tmp/runtime.tar.gz --strip-components=1 -C /app/etc/runtime

# 2. RUNTIME
FROM ghcr.io/containerpak/gtk:main

RUN apt update && apt install -y --no-install-recommends \
    ca-certificates libdrm2 libegl1 libgl1 libglib2.0-0 libgles2 libgstreamer1.0-0 \
    libgstreamer-plugins-base1.0-0 libnotify4 libsdl2-2.0-0 libsecret-1-0 libvulkan1 \
    cabextract imagemagick p7zip-full unzip vmtouch vulkan-tools x11-utils xdg-utils \
    python3 python3-gi python3-gi-cairo python3-cairo python3-dbus python3-requests \
    libwebkit2gtk-4.1-0 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /staging/usr/ /usr/
COPY --from=builder /usr/local/ /usr/local/
COPY --from=builder /app/ /app/

RUN glib-compile-schemas /usr/share/glib-2.0/schemas && \
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor && \
    update-desktop-database -q /usr/share/applications

ENV PATH="/app/bin:/usr/local/bin:/usr/bin:/bin"

ENTRYPOINT ["/usr/bin/bottles"]
