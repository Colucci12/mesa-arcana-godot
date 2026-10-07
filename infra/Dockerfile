FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libfontconfig1 libx11-6 libxcursor1 libxinerama1 \
    libxi6 libxrandr2 libgl1 libasound2 libpulse0 \
    && rm -rf /var/lib/apt/lists/*

FROM runtime AS builder
ARG GODOT_VERSION=4.6.2
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
    && curl -fSL "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /tmp/godot \
    && mv /tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot
WORKDIR /juno
# Mesmas regras do jogo; imagens, áudio, laboratórios e UI ficam fora do container.
COPY infra/servidor.project.godot ./project.godot
COPY config/rede.cfg ./config/rede.cfg
COPY scripts/cartas ./scripts/cartas
COPY scripts/logica ./scripts/logica
COPY scripts/rede/central_salas.gd scripts/rede/sala_central.gd scripts/rede/configuracao_central.gd ./scripts/rede/
COPY scripts/servidor ./scripts/servidor
COPY scenes/servidor ./scenes/servidor
RUN godot --headless --editor --path /juno --import > /tmp/import.log 2>&1 \
    && cat /tmp/import.log \
    && ! grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load script' /tmp/import.log

FROM runtime AS servidor
RUN useradd --system --uid 10001 --create-home juno
COPY --from=builder /usr/local/bin/godot /usr/local/bin/godot
COPY --from=builder --chown=juno:juno /juno /juno
USER juno
WORKDIR /juno
EXPOSE 9080
ENTRYPOINT ["godot", "--headless", "--path", "/juno"]

FROM builder AS exportador_web
ARG GODOT_VERSION=4.6.2
RUN curl -fsSL "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" -o /tmp/templates.tpz \
    && mkdir -p /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable \
    && unzip -j /tmp/templates.tpz 'templates/web*.zip' -d /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable \
    && rm /tmp/templates.tpz
COPY . /juno
COPY infra/export_presets_web.cfg /juno/export_presets.cfg
RUN mkdir -p /juno/build/web \
    && godot --headless --editor --path /juno --import > /tmp/import-web.log 2>&1 \
    && cat /tmp/import-web.log \
    && ! grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load script' /tmp/import-web.log \
    && godot --headless --path /juno --export-release Web /juno/build/web/index.html

FROM nginx:stable-alpine AS web
COPY infra/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=exportador_web /juno/build/web /usr/share/nginx/html
COPY docs/OFL-BarlowCondensed.txt /usr/share/nginx/html/third-party/BarlowCondensed-OFL.txt
