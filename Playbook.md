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
  output   = "../src/generated/prisma"
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
import { PrismaClient } from "./generated/prisma/client.js";
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
  output   = "../src/generated/prisma"
}

datasource db {
  provider = "postgresql"
}

model HealthCheck {
  id        Int      @id @default(autoincrement())
  createdAt DateTime @default(now()) @map("created_at")

  @@map("health_checks")
}

enum SessionStatus {
  active
  closed
  cancelled
}

enum PlayerStatus {
  active
  sitting_out
  cashed_out
}

model GameSession {
  id            String        @id @default(uuid()) @db.Uuid
  joinCode      String        @unique @map("join_code") @db.VarChar(6)
  hostUserId    String        @map("host_user_id") @db.Uuid
  buyInCapCents Int?          @map("buy_in_cap_cents")
  status        SessionStatus @default(active)
  createdAt     DateTime      @default(now()) @map("created_at")
  closedAt      DateTime?     @map("closed_at")

  // Relations
  host    User            @relation("HostSessions", fields: [hostUserId], references: [id], onDelete: Restrict)
  players SessionPlayer[]
  buyIns  BuyIn[]

  @@map("game_sessions")
}

model SessionPlayer {
  id                 String       @id @default(uuid()) @db.Uuid
  sessionId          String       @map("session_id") @db.Uuid
  userId             String?      @map("user_id") @db.Uuid
  guestName          String?      @map("guest_name")
  status             PlayerStatus @default(active)
  cashOutAmountCents Int?         @map("cash_out_amount_cents")
  joinedAt           DateTime     @default(now()) @map("joined_at")
  leftAt             DateTime?    @map("left_at")

  // Relations
  session GameSession @relation(fields: [sessionId], references: [id], onDelete: Cascade)
  user    User?       @relation(fields: [userId], references: [id], onDelete: SetNull)
  buyIns  BuyIn[]

  @@index([sessionId, userId])
  @@index([userId])
  @@map("session_players")
}

model BuyIn {
  id          String    @id @default(uuid()) @db.Uuid
  sessionId   String    @map("session_id") @db.Uuid
  playerId    String    @map("player_id") @db.Uuid
  amountCents Int       @map("amount_cents")
  boughtInAt  DateTime  @default(now()) @map("bought_in_at")
  buyInNum    Int       @map("buy_in_num")
  isVoided    Boolean   @default(false) @map("is_voided")
  voidedAt    DateTime? @map("voided_at")

  // Relations
  session GameSession   @relation(fields: [sessionId], references: [id], onDelete: Cascade)
  player  SessionPlayer @relation(fields: [playerId], references: [id], onDelete: Cascade)

  @@unique([playerId, buyInNum])
  @@index([sessionId])
  @@map("buy_ins")
}

model User {
  id          String    @id @db.Uuid
  email       String    @unique
  username    String    @unique @db.VarChar(30)
  displayName String    @map("display_name")
  avatarUrl   String?   @map("avatar_url")
  createdAt   DateTime  @default(now()) @map("created_at")
  updatedAt   DateTime  @updatedAt @map("updated_at")
  deletedAt   DateTime? @map("deleted_at")

  // Relations
  hostedSessions GameSession[]   @relation("HostSessions")
  sessionPlayers SessionPlayer[]

  @@map("users")
}
```

Prisma `@@index([sessionId, userId])` only speeds lookups. One **active** seat per registered user (and per guest name) is a **partial unique index**. Leave/rejoin is a new `SessionPlayer` row with `left_at` set on the old row.

### Adding Active Seat Partial Unique Indexes to Prisma Migrations

Prisma does not support partial indexes (indexes with `WHERE` clauses) directly inside `schema.prisma`. To enforce at most one active seat per registered user or guest per session at the PostgreSQL level, apply them through a migration script using one of the two options below.

---



#### Option A: Include in Initial Schema Migration (Cleanest)

Use this if you haven't applied `add_poker_ledger_schema` to the database yet.

1. Generate the migration draft without executing it:
  ```bash
   pnpm exec prisma migrate dev --create-only --name add_poker_ledger_schema
  ```
2. Open the generated file at prisma/migrations/_add_poker_ledger_schema/migration.sql and append the following SQL to the bottom:
  ```bash
  -- At most one open seat per (session, user) for registered players.
  -- Rejoin is allowed after left_at is set.
  CREATE UNIQUE INDEX session_players_one_active_user
  ON session_players (session_id, user_id)
  WHERE left_at IS NULL AND user_id IS NOT NULL;

  -- At most one open guest seat per (session, guest_name), case-insensitive.
  CREATE UNIQUE INDEX session_players_one_active_guest 
  ON session_players (session_id, LOWER(guest_name)) 
  WHERE left_at IS NULL 
    AND user_id IS NULL 
    AND guest_name IS NOT NULL;
  ```
3. Apply the migration to your database and update the client:
  ```bash
  pnpm exec prisma migrate dev
  pnpm exec prisma generate
  ```



#### Option B: Add as a Separate Migration

Use this if add_poker_ledger_schema has already been run and applied.

1. Generate an empty migration file:
  ```bash
  pnpm exec prisma migrate dev --create-only --name add_active_seat_partial_unique_indexes
  ```
2. Open the newly generated migration.sql file and paste:
  ```sql
  -- At most one open seat per (session, user) for registered players.
  CREATE UNIQUE INDEX session_players_one_active_user
  ON session_players (session_id, user_id)
  WHERE left_at IS NULL AND user_id IS NOT NULL;

  -- At most one open guest seat per (session, guest_name), case-insensitive.
  CREATE UNIQUE INDEX session_players_one_active_guest 
  ON session_players (session_id, LOWER(guest_name)) 
  WHERE left_at IS NULL 
    AND user_id IS NULL 
    AND guest_name IS NOT NULL;
  ```
3. Run the migration
  ```bash
  pnpm exec prisma migrate dev
  pnpm exec prisma generate
  ```

---

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
ALTER PUBLICATION supabase_realtime ADD TABLE game_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE session_players;
ALTER PUBLICATION supabase_realtime ADD TABLE buy_ins;

-- Ensure full row state is broadcast on UPDATE/DELETE
ALTER TABLE game_sessions REPLICA IDENTITY FULL;
ALTER TABLE session_players REPLICA IDENTITY FULL;
ALTER TABLE buy_ins REPLICA IDENTITY FULL;
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
        {
          event: "*",
          schema: "public",
          table: "buy_ins",
          filter: `session_id=eq.${sessionId}`,
        },t
        () => onUpdate()
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "session_players",
          filter: `session_id=eq.${sessionId}`,
        },
        () => onUpdate()
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "game_sessions",
          filter: `id=eq.${sessionId}`,
        },
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

pnpm’s lockfile lives at the monorepo root (`pnpm-lock.yaml`). Docker can only `COPY` files inside the build **context**, so both images use `context: .` (repo root) and `dockerfile: apps/<app>/Dockerfile`. Do not use `context: ./apps/web` or `./apps/api`.

Pin Corepack to the same pnpm as `packageManager` in `apps/web/package.json` (not `pnpm@latest`). Use `--activate` as **one** flag (no space).

`apps/api/Dockerfile`

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@12.4.2 --activate
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
RUN pnpm install --frozen-lockfile --filter api...
COPY apps/api ./apps/api
WORKDIR /app/apps/api
RUN pnpm exec prisma generate
RUN pnpm build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN corepack enable && corepack prepare pnpm@12.4.2 --activate
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
RUN pnpm install --prod --frozen-lockfile --filter api...
COPY --from=builder /app/apps/api/dist ./dist
EXPOSE 4000
CMD ["node", "dist/server.js"]
```

`apps/web/Dockerfile`

The **builder** needs pnpm. The **runner** only executes `node server.js` (Next standalone); do not install pnpm there.

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@12.4.2 --activate
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY apps/api/package.json ./apps/api/
COPY apps/web/package.json ./apps/web/
RUN pnpm install --frozen-lockfile --filter web...
COPY apps/web ./apps/web
WORKDIR /app/apps/web
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
COPY --from=builder /app/apps/web/public ./public
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static
EXPOSE 3000
CMD ["node", "apps/web/server.js"]
```

Next standalone from a nested app often emits `server.js` under `apps/web/` inside the standalone folder. If `CMD` fails, check the image (`docker compose run --rm web ls -la`) and point `CMD` at the actual `server.js`.

In `apps/web/next.config.ts` set `output: "standalone"`.

### Root orchestration

```yaml
services:
  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile
    ports:
      - "4000:4000"
    env_file:
      - ./apps/api/.env

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
      args:
        NEXT_PUBLIC_API_URL: http://localhost:4000
        NEXT_PUBLIC_SUPABASE_URL: https://your-ref.supabase.co
        NEXT_PUBLIC_SUPABASE_ANON_KEY: your-publishable-or-anon-key
    ports:
      - "3000:3000"
    depends_on:
      - api
```

```bash
docker compose up --build
```

Verify [http://localhost:3000](http://localhost:3000) and [http://localhost:4000/health](http://localhost:4000/health), then:

```bash
docker compose down
```

Commit:

```bash
git add compose.yaml apps/api/Dockerfile apps/web/Dockerfile apps/web/next.config.ts
git commit -m "Add Dockerfiles and Compose orchestration"
```

---



## 10. AWS Deployment Workflow

Skip until `docker compose up --build` works on your laptop (section 9) and `pnpm test` is green.

This is a **one-box** workflow: the same `compose.yaml` as local, running on a single EC2 instance. Postgres stays on **Supabase**. Do not introduce ECS, ECR, or a load balancer for this stage.

```text
Laptop  --build linux/amd64 images-->  scp  -->  EC2
                                                    |
Browser --> EC2 public IP:3000 --> web container (Next standalone)
        --> EC2 public IP:4000 --> api container (Express)
                                        --> Supabase Postgres
```

`NEXT_PUBLIC_*` values are **baked into the web image at `docker compose build`**. The browser calls those URLs from the user's machine, so they must be the EC2 **public IP** (or later a domain), never `http://localhost:4000`. Changing the IP means rebuilding **web**.

**EC2** = one Linux VM you SSH into. You install Docker, load images, run Compose. You stop the instance when you are not using it.

**Do not** use this as a reason to run `docker compose build` on a `t3.micro`. `next build` on 1 GB RAM usually dies (OOM). Build on the laptop; copy images up.

### Cost (read before launching)

- **t3.micro** (1 vCPU, 1 GB): often Free Tier eligible for 12 months on a new account (750 hours/month). Confirm on the AWS Free Tier page for **your** account date.
- Use **t3.micro** only if you **load pre-built images**. Use **t3.small** (2 GB) only if you insist on building **on** the instance (~on-demand pricing; check the current EC2 price list).
- **Stop** vs **terminate:** Stop pauses most compute; the EBS volume can still cost a little. Terminate deletes the machine. An **Elastic IP** attached to a **stopped** instance can incur a small hourly charge; associate it only while you need a stable IP, or release it.
- Create a **Billing alarm** before you launch anything (notify at $5 and $15).

---

### A. One-time: AWS account and VM

Do this once. Daily work is section B.

#### Account

1. Create an account at aws.amazon.com (phone + credit card; AWS may authorize a small hold).
2. As **root**, only: enable MFA, turn on billing emails, create a budget alarm. Do not use root for daily work.
3. Create an IAM user (e.g. `will-admin`), console password, `AdministratorAccess` (too broad for a company; acceptable for a solo learning account), MFA. Sign in as that user.
4. Pick **one region** and never mix (example: `us-west-2`). The console region selector is top-right.

#### Security group

EC2 → Security Groups → Create. Do **not** open 5432.

| Type       | Port | Source                      | Why                          |
| ---------- | ---- | --------------------------- | ---------------------------- |
| SSH        | 22   | **My IP** (not `0.0.0.0/0`) | Only your laptop can SSH     |
| Custom TCP | 3000 | `0.0.0.0/0`                 | Next.js in the browser       |
| Custom TCP | 4000 | `0.0.0.0/0`                 | Express `/health` and API    |

#### Key pair

EC2 → Key pairs → Create → **ed25519** (or RSA). Download the `.pem` **once**.

```bash
chmod 400 ~/Downloads/poker-ledger-ec2.pem
```

Never commit this file.

#### Launch

EC2 → Launch instance:

- Name: `poker-ledger`
- AMI: Amazon Linux 2023
- Architecture: **x86_64** if you follow the `linux/amd64` image steps below
- Type: `t3.micro` (load images) or `t3.small` (build on box)
- Key pair + security group from above
- Auto-assign public IPv4: enable
- Storage: 20 GB gp3

Copy the **Public IPv4 address**. Examples below use `203.0.113.10` — replace it everywhere.

Optional: **Elastic IP** → Allocate → Associate. Then the IP survives stop/start. Put **that** IP in `NEXT_PUBLIC_API_URL` and `WEB_ORIGIN`.

#### SSH and Docker

Amazon Linux 2023 user is `ec2-user`:

```bash
ssh -i ~/Downloads/poker-ledger-ec2.pem ec2-user@203.0.113.10
```

If it hangs: security group SSH is not **My IP**, VPN, or the instance is still booting.

```bash
sudo dnf update -y
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
```

Log out and SSH back in. Then install the Compose plugin:

```bash
docker version
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version
```

Arm64 / `t4g` instances: use `docker-compose-linux-aarch64` and build `linux/arm64` images instead.

#### Put the repo on the instance (code only, no secrets)

**Git clone** (preferred once the repo is on GitHub):

```bash
git clone https://github.com/<you>/poker-ledger.git
cd poker-ledger
```

**Or rsync from the laptop** (repo not remote yet). Run this on the **laptop**, not inside SSH:

```bash
rsync -avz \
  --exclude node_modules --exclude .next --exclude dist \
  --exclude .env --exclude .env.local --exclude apps/api/.env \
  -e "ssh -i ~/Downloads/poker-ledger-ec2.pem" \
  ./ ec2-user@203.0.113.10:~/poker-ledger
```

#### Env files on the server

Compose reads **root** `.env` for web **build args**. The API reads **`apps/api/.env`** at **runtime**. Neither file belongs in git.

On EC2, `~/poker-ledger/apps/api/.env`:

```bash
DATABASE_URL="postgres://...pooler...:6543/postgres?pgbouncer=true"
DIRECT_URL="postgres://...:5432/postgres"
PORT=4000
WEB_ORIGIN="http://203.0.113.10:3000"
```

`WEB_ORIGIN` must match the URL in the browser or CORS blocks the frontend.

On EC2, `~/poker-ledger/.env` (and the **same** values on the laptop when you build images for AWS):

```bash
NEXT_PUBLIC_API_URL=http://203.0.113.10:4000
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

`compose.yaml` already interpolates those into the web Dockerfile `ARG`s. Local laptop deploys can keep `http://localhost:4000` in root `.env`; AWS image builds must not.

If Supabase has an IP allow-list, add the EC2 **public** IP.

Optional systemd unit so Compose comes back after reboot:

```bash
sudo tee /etc/systemd/system/poker-ledger.service <<'EOF'
[Unit]
Description=poker-ledger compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/poker-ledger
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=ec2-user

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now poker-ledger.service
```

---

### B. Recurring deploy loop (the actual workflow)

Every code change follows the same path. Do **not** rebuild on `t3.micro`.

#### 1. Local

```bash
pnpm test
```

Optional: `docker compose up --build` with **localhost** `NEXT_PUBLIC_*` to confirm Compose still works. Then `docker compose down`.

#### 2. Point the web build at the public API

On the **laptop**, set root `.env` to the EC2 URLs (section A) before building images destined for AWS. `apps/web/.env.local` is not used inside Docker.

#### 3. Build `linux/amd64` images on the laptop

From the repo root. Apple Silicon targeting an x86 `t3`:

```bash
export DOCKER_DEFAULT_PLATFORM=linux/amd64
docker compose build
docker images | grep poker-ledger
docker save poker-ledger-api poker-ledger-web | gzip > /tmp/poker-ledger-images.tar.gz
scp -i ~/Downloads/poker-ledger-ec2.pem /tmp/poker-ledger-images.tar.gz ec2-user@203.0.113.10:~/
```

Intel Mac or Linux → x86 EC2: omit `DOCKER_DEFAULT_PLATFORM`.

If `docker save` cannot find those names, Compose tagged them differently. Use `docker images` and save the two `poker-ledger-*` tags you actually have (`{directory}-{service}` is the default).

`prisma generate` during the API image build uses a dummy `DIRECT_URL` in the Dockerfile. It does not need a live database. Runtime still needs real `DATABASE_URL` in `apps/api/.env`.

#### 4. Load and start on EC2

```bash
ssh -i ~/Downloads/poker-ledger-ec2.pem ec2-user@203.0.113.10
cd ~/poker-ledger
gunzip -c ~/poker-ledger-images.tar.gz | docker load
docker compose up -d
```

No `--build` here. You want the images you just loaded.

If you also changed Compose or env files, `git pull` or `rsync` the repo **before** `up -d`.

#### 5. Smoke check from the laptop browser

- `http://203.0.113.10:3000` — Next app
- `http://203.0.113.10:4000/health` — `{"ok":true,...}`

On EC2:

```bash
docker compose ps
docker compose logs -f
```

| Symptom | Likely cause |
| --- | --- |
| Web loads, API calls fail | Stale `NEXT_PUBLIC_API_URL` (rebuild **web**), security group missing 4000, or `WEB_ORIGIN` mismatch |
| `/health` fails | Missing `apps/api/.env` `DATABASE_URL`, or Supabase IP allow-list blocking EC2 |
| `web` container exits immediately | Wrong standalone `CMD` path; `docker compose run --rm web ls -la` and confirm `apps/web/server.js` |
| Build OOM on the instance | You ran `--build` on `t3.micro`; go back to laptop `docker save` |

#### 6. What needs a rebuild vs a restart

| Change | Action |
| --- | --- |
| API TypeScript / Prisma schema | Rebuild **api** image on laptop, `docker save`/`load`, `docker compose up -d` |
| Web TypeScript or any `NEXT_PUBLIC_*` | Rebuild **web** image (public URL baked in) |
| `apps/api/.env` only | No image rebuild. `docker compose up -d api --force-recreate` |
| Root `.env` `NEXT_PUBLIC_*` | Rebuild **web**; restarting the old image does nothing |

Schema changes still run **locally** (or from a trusted machine) with `pnpm exec prisma migrate deploy` against `DIRECT_URL`. Do not run migrations from a random container unless you intend to.

#### Alternate: build on the instance

Only with ≥ 2 GB RAM (`t3.small`):

```bash
cd ~/poker-ledger
git pull
docker compose up -d --build
```

Last-resort swap on `t3.micro` (slow):

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

### C. Stop billing when you are done for the day

```bash
# on EC2
docker compose down
```

Console: instance → **Stop**. Recheck Elastic IP charges if one is associated.

---

### D. Out of scope for this workflow

- No HTTPS, custom domain, Nginx, load balancer, autoscaling, or zero-downtime.
- Single instance is a single point of failure. Fine for a personal ledger.
- Later: Nginx on 443 with Let's Encrypt, domain on the Elastic IP, then set `NEXT_PUBLIC_API_URL` and `WEB_ORIGIN` to `https://your.domain`. ECS + ALB is a different architecture when one VM is no longer enough.
