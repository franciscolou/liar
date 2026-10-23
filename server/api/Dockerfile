# The house: the API and, in the same container, the match servers it starts
# (the game exported with the "Linux Server" preset, see ../README.md).
FROM python:3.12-slim

# What a headless Godot build still links against.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY api/liar_api ./liar_api
COPY api/seed_demo.py .
# The exported match server (one file, the .pck embedded in it).
COPY game/ /opt/liar/
RUN chmod +x /opt/liar/liar_server.x86_64 || true

ENV LIAR_DATA=/data \
    LIAR_SERVER_CMD="/opt/liar/liar_server.x86_64 --headless --" \
    LIAR_INTERNAL_URL=http://127.0.0.1:8080
VOLUME /data
EXPOSE 8080
CMD ["uvicorn", "liar_api.main:app", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers"]
