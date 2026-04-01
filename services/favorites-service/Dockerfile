## Stage 1

FROM node:20-alpine AS builder 
WORKDIR /app 
COPY package*.json . 
RUN npm ci --only=production

## Stage 2

FROM node:20-alpine 
WORKDIR /app 

RUN addgroup -S appgroup && adduser -S appuser -G appgroup 

COPY --from=builder /app/node_modules ./node_modules 
COPY src/ ./src/

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 3003

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget -qO- http://localhost:3003/health || exit 1

CMD ["node", "src/index.js"]    