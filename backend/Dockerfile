# stage 1: install the dependencies

FROM node:18-alpine AS dependencies

WORKDIR /app

COPY package*.json .

RUN npm ci --only=production


# stage 2: production

FROM node:18-alpine AS production

RUN apk add --no-cache dumb-init curl

RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -s /bin/sh -D appuser

WORKDIR /app

COPY --from=dependencies --chown=appuser:appgroup /app/node_modules ./node_modules

COPY --chown=appuser:appgroup . .

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
   CMD curl -f http://localhost:3000/health || exit 1


ENTRYPOINT ["dumb-init","--","/entrypoint.sh"]

CMD ["node","server.js"]
