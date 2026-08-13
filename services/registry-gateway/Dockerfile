# Soviez Registry Gateway — minimal production image
# No docker.sock; non-root; Node 20 Alpine.

FROM node:20-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
# Production image compiles app sources only (tests excluded from COPY)
RUN npx tsc --project tsconfig.json --skipLibCheck \
  && npm prune --omit=dev

FROM node:20-alpine AS runtime
WORKDIR /app

RUN addgroup -S soviez && adduser -S -G soviez -H -s /sbin/nologin soviez \
  && chown -R soviez:soviez /app

ENV NODE_ENV=production \
    PORT=8087

COPY --from=build --chown=soviez:soviez /app/package.json /app/package-lock.json ./
COPY --from=build --chown=soviez:soviez /app/node_modules ./node_modules
COPY --from=build --chown=soviez:soviez /app/dist ./dist

USER soviez
EXPOSE 8087

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8087)+'/live').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/src/index.js"]
