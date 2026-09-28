# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM node:24-bookworm-slim AS build
WORKDIR /app
ENV ENABLE_CONTENT_SYNC=false ASTRO_TELEMETRY_DISABLED=1
RUN npm install -g pnpm@11.5.3
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

FROM nginx:stable-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=6 CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
