FROM node:22-alpine AS builder
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@12.4.2 --activate
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
RUN pnpm install --frozen-lockfile --filter api...
COPY apps/api/ ./apps/api
WORKDIR /app/apps/api
ENV DIRECT_URL="postgresql://dummy:dummy@localhost:5432/dummy"
RUN pnpm exec prisma generate
RUN pnpm build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

RUN corepack enable && corepack prepare pnpm@12.4.2 --activate

# 1. Install production dependencies at workspace root so pnpm can hoist properly
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
RUN pnpm install --prod --frozen-lockfile --filter api...

# 2. Copy the compiled build into its actual workspace subdirectory
COPY --from=builder /app/apps/api/dist ./apps/api/dist

# 3. Switch working directory to apps/api before running Node
WORKDIR /app/apps/api
EXPOSE 4000
CMD ["node", "dist/server.js"]