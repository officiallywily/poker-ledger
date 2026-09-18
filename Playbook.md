# Full-Stack Scaffold & Testing Playbook: Poker Ledger

Stack: Next.js (`apps/web`) → Express (`apps/api`) → Prisma 7 → Supabase Postgres → Vitest & Supertest → Docker Compose

**Golden Rule:** Get apps running and tested locally with `pnpm dev` and `pnpm test` before touching database schemas, Docker, or cloud infrastructure.

---

## 1. Architecture & Boundaries

- `apps/web` **(Next.js):** Browser presentation layer and state listener. Never stores database credentials, session pooler URLs, or `SUPABASE_SERVICE_ROLE_KEY`. Subscribes to Supabase Realtime CDC channels over WebSockets for live table updates.
- `apps/api` **(Express):** Authoritative business logic engine. Validates buy-ins, handles host administrative actions, enforces zero-sum constraints before session close, and executes database mutations via Prisma.
- **Prisma 7:** Type-safe database client and migration manager. Migrations run through CLI using `prisma.config.ts` over direct connection; runtime pooling uses `@prisma/adapter-pg`.
- **Supabase Postgres:** Managed database. Data API (PostgREST) is disabled for mutations—Express is the sole gatekeeper. Supabase Realtime CDC remains enabled on specific tables (`buy_ins`, `session_players`).
- **Testing Layer:** Vitest throughout. Supertest drives HTTP integration tests in `apps/api`; React Testing Library (RTL) handles component rendering and interaction tests in `apps/web`.

---



## 2. Prerequisites & Root Workspace

Ensure local machine tooling is installed:

```bash
node -v          # >= 20.x LTS
pnpm -v          # >= 9.x
git -v
docker compose version
```



### Initialize Monorepo Root

```bash
mkdir poker-ledger && cd poker-ledger
git init
mkdir apps
```

Create root `.gitignore`:

```text
node_modules/
.next/
dist/
generated/
coverage/
.env
.env.*
!.env.example
*.log
.DS_Store
```

Create root `pnpm-workspace.yaml`:

```yaml
packages:
  - 'apps/*'
```

Create root `package.json` to orchestrate multi-app workflows:

```json
{
  "name": "poker-ledger-monorepo",
  "private": true,
  "scripts": {
    "dev": "pnpm --parallel run dev",
    "build": "pnpm --recursive run build",
    "test": "pnpm --recursive run test",
    "test:watch": "pnpm --recursive run test:watch"
  }
}
```

Commit base repository:

```bash
git add .gitignore pnpm-workspace.yaml package.json
git commit -m "Initialize monorepo workspace and gitignore"
```

---



## 3. Web Client Scaffold (`apps/web`)

From repository root:

```bash
cd apps
pnpm create next-app@latest web --typescript --tailwind --eslint --app --src-dir --use-pnpm --disable-git
cd web
```

Create `apps/web/.env.example`:

```bash
NEXT_PUBLIC_API_URL=http://localhost:4000
NEXT_PUBLIC_SUPABASE_URL=[https://your-ref.supabase.co](https://your-ref.supabase.co)
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

Copy for local execution:

```bash
cp .env.example .env.local
```

Verify build and runtime:

```bash
pnpm dev
# Inspect http://localhost:3000, then terminate (Ctrl+C)
```

Commit:

```bash
git add .
git commit -m "Scaffold Next.js client in apps/web"
```

---



## 4. API Scaffold (`apps/api`)

From repository root:

```bash
cd apps/api
pnpm init
pnpm add express cors dotenv
pnpm add -D typescript tsx @types/express @types/node @types/cors
pnpm exec tsc --init
```

Update `apps/api/package.json`:

```json
{
  "name": "api",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js"
  }
}
```

Split app definition from server listener to facilitate integration testing:

`apps/api/src/app.ts`

```typescript
import "dotenv/config";
import express from "express";
import cors from "cors";

export const app = express();

app.use(cors({ origin: process.env.WEB_ORIGIN || "http://localhost:3000" }));
app.use(express.json());

app.get("/health", (_req, res) => {
  res.status(200).json({ ok: true, timestamp: new Date().toISOString() });
});
```

`apps/api/src/server.ts`

```typescript
import { app } from "./app.js";

const port = Number(process.env.PORT) || 4000;

app.listen(port, () => {
  console.log(`API listening on http://localhost:${port}`);
});
```

Create `apps/api/.env.example`:

```bash
PORT=4000
WEB_ORIGIN=http://localhost:3000
DATABASE_URL=
DIRECT_URL=
```

```bash
cp .env.example .env
```

Verify build and runtime:

```bash
pnpm dev
# curl http://localhost:4000/health -> {"ok":true,...}
```

Commit:

```bash
git add .
git commit -m "Scaffold Express API with decoupled server app"
```

---



## 5. Testing Framework Setup

Establish unit and integration test harnesses before writing business logic.

### API Testing: Vitest + Supertest

From `apps/api`:

```bash
pnpm add -D vitest supertest @types/supertest
```

Add test script to `apps/api/package.json`:

```json
"scripts": {
  "dev": "tsx watch src/server.ts",
  "build": "tsc",
  "start": "node dist/server.js",
  "test": "vitest run",
  "test:watch": "vitest"
}
```

Create `apps/api/vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    globals: true,
    include: ["src/**/*.test.ts", "tests/**/*.test.ts"],
  },
});
```

Create first API integration test `apps/api/tests/health.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/app.js";

describe("GET /health", () => {
  it("returns 200 with ok flag", async () => {
    const response = await request(app).get("/health");
    expect(response.status).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.timestamp).toBeDefined();
  });
});
```

Run test:

```bash
pnpm test
```



### Web Testing: Vitest + React Testing Library

From `apps/web`:

```bash
pnpm add -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/dom @testing-library/jest-dom
```

Add test scripts to `apps/web/package.json`:

```json
"scripts": {
  "dev": "next dev",
  "build": "next build",
  "start": "next start",
  "lint": "next lint",
  "test": "vitest run",
  "test:watch": "vitest"
}
```

Create `apps/web/vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./tests/setup.ts"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

Create `apps/web/tests/setup.ts`:

```typescript
import "@testing-library/jest-dom/vitest";
```

Create smoke test `apps/web/tests/home.test.tsx`:

```typescript
import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import Home from "../src/app/page";

describe("Home Page", () => {
  it("renders without crashing", () => {
    render(<Home/>);
    expect(document.body).toBeDefined();
  });
});
```

Run web test:

```bash
pnpm test
```

From monorepo root, run all workspace suites simultaneously:

```bash
pnpm test
```

Commit:

```bash
git add .
git commit -m "Configure Vitest test suites for web and api"
```

---



## 6. Database Provisioning & Prisma 7 Integration



### Configure Supabase Database Role

Execute in Supabase Dashboard SQL Editor:

```sql
-- Dedicated role for backend application operations
create user "prisma" with password 'your_secure_password' bypassrls createdb;
grant "prisma" to "postgres";

grant usage on schema public to prisma;
grant create on schema public to prisma;
grant all on all tables in schema public to prisma;
grant all on all routines in schema public to prisma;
grant all on all sequences in schema public to prisma;

alter default privileges for role postgres in schema public grant all on tables to prisma;
alter default privileges for role postgres in schema public grant all on routines to prisma;
alter default privileges for role postgres in schema public grant all on sequences to prisma;
```

Collect Connection Strings:

- **Session Pooler (Port 5432):** Direct connection for migrations (`DIRECT_URL`).
- **Transaction Pooler (Port 6543):** Pooled connection for runtime application (`DATABASE_URL`). Must include `?pgbouncer=true`.

Update `apps/api/.env`:

```bash
DATABASE_URL="postgres://prisma.[REF]:[PASSWORD]@aws-0-[REGION][.pooler.supabase.com:6543/postgres?pgbouncer=true](https://.pooler.supabase.com:6543/postgres?pgbouncer=true)"
DIRECT_URL="postgres://prisma.[REF]:[PASSWORD]@aws-0-[REGION][.pooler.supabase.com:5432/postgres](https://.pooler.supabase.com:5432/postgres)"
```



### Install Prisma 7 Tooling

From `apps/api`:

```bash
pnpm add @prisma/client @prisma/adapter-pg pg
pnpm add -D prisma @types/pg
pnpm exec prisma init
```

Configure `apps/api/prisma.config.ts`:

```typescript
import "dotenv/config";
import { defineConfig, env } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: env("DIRECT_URL"),
  },
});
```

Configure `apps/api/prisma/schema.prisma`:

```prisma
generator client {
  provider = "prisma-client"
  output   = "../generated/prisma"
}

datasource db {
  provider = "postgresql"
}

model HealthCheck {
  id        Int      @id @default(autoincrement())
  createdAt DateTime @default(now())
}
```

Instantiate the adapter client in `apps/api/src/db.ts`:

```typescript
import { PrismaClient } from "../generated/prisma/client.js";
import { PrismaPg } from "@prisma/adapter-pg";

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error("DATABASE_URL environment variable is missing.");
}

const adapter = new PrismaPg({ connectionString });
export const prisma = new PrismaClient({ adapter });
```

Run test migration:

```bash
pnpm exec prisma migrate dev --name init_health
pnpm exec prisma generate
```

Commit:

```bash
git add .
git commit -m "Set up Prisma 7 with Postgres driver adapter"
```

---



## 7. Domain Modeling & Invariant Unit Tests



### Test Ledger Zero-Sum Math

Before saving schemas or endpoints, write unit tests for the core calculation rules.

Create `apps/api/tests/ledger.test.ts`:

```typescript
import { describe, it, expect } from "vitest";

interface BuyIn {
  amountCents: number;
  isVoided: boolean;
}

interface PlayerBalance {
  cashOutAmountCents: number | null;
  buyIns: BuyIn[];
}

function verifyZeroSum(players: PlayerBalance[]): boolean {
  let totalBuyIns = 0;
  let totalCashOuts = 0;

  for (const player of players) {
    if (player.cashOutAmountCents === null) return false;
    totalCashOuts += player.cashOutAmountCents;
    
    for (const b of player.buyIns) {
      if (!b.isVoided) totalBuyIns += b.amountCents;
    }
  }

  return totalBuyIns === totalCashOuts;
}

describe("Ledger Calculation & Invariants", () => {
  it("validates zero-sum when cash outs match non-voided buy-ins", () => {
    const players: PlayerBalance[] = [
      {
        cashOutAmountCents: 15000,
        buyIns: [{ amountCents: 10000, isVoided: false }],
      },
      {
        cashOutAmountCents: 5000,
        buyIns: [
          { amountCents: 10000, isVoided: false },
          { amountCents: 5000, isVoided: true }, // voided rebuy ignored
        ],
      },
    ];

    expect(verifyZeroSum(players)).toBe(true);
  });

  it("fails zero-sum check on chip discrepancies", () => {
    const players: PlayerBalance[] = [
      {
        cashOutAmountCents: 12000, // missing 8000 cents
        buyIns: [{ amountCents: 10000, isVoided: false }],
      },
      {
        cashOutAmountCents: 0,
        buyIns: [{ amountCents: 10000, isVoided: false }],
      },
    ];

    expect(verifyZeroSum(players)).toBe(false);
  });
});
```

Verify tests:

```bash
pnpm test
```



### Poker Ledger Prisma Schema

Replace `apps/api/prisma/schema.prisma` with domain definitions:

```prisma
generator client {
  provider = "prisma-client"
  output   = "../generated/prisma"
}

datasource db {
  provider = "postgresql"
}

enum SessionStatus {
  active
  closed
}

enum PlayerStatus {
  active
  sitting_out
  cashed_out
}

model GameSession {
  id              String          @id @default(uuid())
  joinCode        String          @unique @db.VarChar(6)
  hostUserId      String
  buyInCapCents   Int?
  status          SessionStatus   @default(active)
  createdAt       DateTime        @default(now())
  closedAt        DateTime?
  players         SessionPlayer[]
}

model SessionPlayer {
  id                 String       @id @default(uuid())
  sessionId          String
  userId             String?
  guestName          String?
  status             PlayerStatus @default(active)
  cashOutAmountCents Int?
  joinedAt           DateTime     @default(now())
  session            GameSession  @relation(fields: [sessionId], references: [id], onDelete: Cascade)
  buyIns             BuyIn[]

  @@unique([sessionId, userId])
  @@index([sessionId])
}

model BuyIn {
  id          String        @id @default(uuid())
  playerId    String
  amountCents Int
  buyInNum    Int
  isVoided    Boolean       @default(false)
  voidedAt    DateTime?
  boughtInAt  DateTime      @default(now())
  player      SessionPlayer @relation(fields: [playerId], references: [id], onDelete: Cascade)

  @@index([playerId])
}
```

Run domain migration:

```bash
pnpm exec prisma migrate dev --name add_poker_ledger_schema
pnpm exec prisma generate
```

Commit:

```bash
git add .
git commit -m "Add domain schema and invariant tests for poker ledger"
```

---



## 8. Supabase Realtime CDC Activation

Run in the Supabase SQL editor to allow client WebSocket subscriptions directly to database changes without routing reads through Express:

```sql
-- Enable PostgreSQL logical replication publication for targeted ledger tables
alter publication supabase_realtime add table buy_ins;
alter publication supabase_realtime add table session_players;
```

In `apps/web`, install the client:

```bash
cd apps/web
pnpm add @supabase/supabase-js
```

Create typed listener wrapper in `apps/web/src/lib/realtime.ts`:

```typescript
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export function subscribeToSession(
  sessionId: string,
  onUpdate: () => void
) {
  const channel = supabase
    .channel(`session-${sessionId}`)
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "buy_ins" },
      () => onUpdate()
    )
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "session_players" },
      () => onUpdate()
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
```

---



## 9. Containerization (`compose.yaml`)

Run Docker Compose checks only after `pnpm test` and `pnpm dev` function cleanly across both applications.

### Dockerfiles

`apps/api/Dockerfile`

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm exec prisma generate
RUN pnpm build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --prod --frozen-lockfile
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/generated ./generated
EXPOSE 4000
CMD ["node", "dist/server.js"]
```

`apps/web/Dockerfile`

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile
COPY . .
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY
RUN pnpm build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
EXPOSE 3000
CMD ["node", "server.js"]
```

*(Note: Add* `output: "standalone"` *inside* `apps/web/next.config.ts` *to support the lightweight web runner).*

### Root Orchestration

Create `compose.yaml` in the monorepo root:

```yaml
services:
  api:
    build:
      context: ./apps/api
      dockerfile: Dockerfile
    ports:
      - "4000:4000"
    env_file:
      - ./apps/api/.env

  web:
    build:
      context: ./apps/web
      dockerfile: Dockerfile
      args:
        NEXT_PUBLIC_API_URL: http://localhost:4000
    ports:
      - "3000:3000"
    depends_on:
      - api
```

Validate local container boot:

```bash
docker compose up --build
# Verify http://localhost:3000 and http://localhost:4000/health
docker compose down
```

Commit:

```bash
git add compose.yaml apps/api/Dockerfile apps/web/Dockerfile apps/web/next.config.ts
git commit -m "Add Dockerfiles and Compose orchestration"
```

---



## 10. AWS Deployment Workflow



### Target Architecture

1. **Compute:** ECS Fargate tasks running `apps/web` and `apps/api` independently.
2. **Traffic Management:** Application Load Balancer (ALB) routing:
  - Rule 1: Path `/api/*` forwards to the `api` target group (Express).
  - Default Rule: All other traffic forwards to the `web` target group (Next.js).
3. **Secrets Management:** `DATABASE_URL` and `DIRECT_URL` stored in AWS Systems Manager (SSM) Parameter Store or Secrets Manager, injected into ECS task definitions at startup.
4. **Database:** Supabase-hosted PostgreSQL.



### Pre-Deployment Pipeline Checklist

1. Monorepo tests pass: `pnpm test`.
2. Static type checks pass: `pnpm --recursive run build`.
3. Build container images targeting `linux/amd64` architecture:
  ```bash
   docker build --platform linux/amd64 -t [AWS_ACCOUNT_ID].dkr.ecr.[REGION][.amazonaws.com/poker-ledger-api:latest](https://.amazonaws.com/poker-ledger-api:latest) ./apps/api
   docker build --platform linux/amd64 -t [AWS_ACCOUNT_ID].dkr.ecr.[REGION][.amazonaws.com/poker-ledger-web:latest](https://.amazonaws.com/poker-ledger-web:latest) ./apps/web
  ```
4. Authenticate Docker CLI to AWS ECR and push images.
5. Trigger ECS service update to deploy revised task definitions.

