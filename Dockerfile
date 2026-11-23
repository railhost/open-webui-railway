# Open WebUI for Railway.
# Builds on the official Open WebUI image, pinned to a release tag. The update
# workflow (.github/workflows/update.yml) bumps OPEN_WEBUI_VERSION after a
# smoke test.
#
# The additions: an unprivileged user, data on the Railway volume at /data, and
# docker-entrypoint.sh, which fixes volume ownership and makes sure an admin
# account exists before the server takes its first request.
ARG OPEN_WEBUI_VERSION=0.13.4
FROM ghcr.io/open-webui/open-webui:v${OPEN_WEBUI_VERSION}

# The upstream image runs as root. Open WebUI writes to its static folders at
# startup, and the bundled embedding, Whisper and tiktoken models stay in the
# image under /app/backend/data/cache, so the volume never holds a stale copy.
RUN groupadd --gid 1000 webui \
    && useradd --uid 1000 --gid webui --home-dir /home/webui --create-home webui \
    && chown -R webui:webui /app/build /app/backend/open_webui/static /app/backend/data

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# DATA_DIR holds the SQLite database, uploads and the vector index; Railway
# mounts the volume there.
# Signup stays closed: the entrypoint creates the admin from the variables.
# The bundled embedding model is used as is; upstream would otherwise
# download it again on every boot, since the container's copy is not kept.
# There is no Ollama in this template, so its connection starts switched off.
# The admin can turn either back on under Admin Panel → Settings.
ENV PORT=8080 \
    DATA_DIR=/data \
    HOME=/home/webui \
    ENABLE_SIGNUP=false \
    ENABLE_OLLAMA_API=false \
    RAG_EMBEDDING_MODEL_AUTO_UPDATE=false \
    WEBUI_ADMIN_NAME=Admin \
    ANONYMIZED_TELEMETRY=false \
    DO_NOT_TRACK=true \
    SCARF_NO_ANALYTICS=true

EXPOSE 8080
ENTRYPOINT ["docker-entrypoint.sh"]
