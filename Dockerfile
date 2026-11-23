FROM node:20-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install --global @openai/codex

WORKDIR /app
RUN git clone --depth 1 https://github.com/mehdic/codex-proxy.git . \
    && npm install \
    && npm run build

ENV CODEX_PROXY_HOST=0.0.0.0 \
    CODEX_PROXY_PORT=3466

EXPOSE 3466
CMD ["npm", "start"]
