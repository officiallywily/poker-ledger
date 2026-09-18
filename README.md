# Poker Ledger

A full-stack, real-time poker financial ledger for home games. It replaces manual spreadsheets and dispute-prone cash settlements with a shared session lifecycle: hosts start a room, players join, buy-ins and cash-outs sync live, and the session cannot close until the books balance.

## What it does

- Hosts create a game with a 6-character join code and an optional buy-in cap.
- Registered users and guests can join the same active room.
- Buy-ins, rebuys, voids, and cash-outs update across devices in real time.
- Sessions close only after zero-sum verification: Σ(non-voided buy-ins) = Σ(cash-outs).
- A centralized banker ledger tells every player what they owe or are owed through the host.

## MVP

### Live session lifecycle & real-time sync

- Host creates a room (`join_code`, optional `buy_in_cap_cents`).
- Authenticated users and guest players join active rooms.
- Supabase Realtime listens to `buy_ins` and `session_players` so rebuys, voids, and cash-outs appear immediately.
- `game_status` moves from `active` to `closed`.

### Financial ledger engine

- Append-only buy-in history (`amount_cents`, `buy_in_num`, `bought_in_at`).
- Soft-delete auditing (`is_voided`, `voided_at`) so hosts can invalidate mistakes without losing history.
- Player status (`active`, `sitting_out`, `cashed_out`) with final chip counts (`cash_out_amount_cents`).
- Automated zero-sum checks block finalization when cash-outs do not match active buy-ins.

### Centralized banker settlement

- Net balance per player: cash-out − Σ(active buy-ins).
- Single-banker debt map: net-negative players pay the host; the host pays net-positive players.

### Architecture & infrastructure

- Dual-path data access: client traffic goes through PostgREST with PostgreSQL Row-Level Security (JWT), Prisma is reserved for privileged admin work.
- Transaction-mode pooling (Supavisor) for runtime traffic; direct connections for Prisma migrations.
- NGINX reverse proxy on AWS EC2 for HTTP, SSL termination, and deployments.

## Tech stack

| Layer | Stack |
| --- | --- |
| Frontend | Next.js, React, TypeScript |
| Backend | Node.js, Express, TypeScript |
| Database & BaaS | PostgreSQL, Supabase |
| Realtime | Supabase Realtime (PostgreSQL CDC / logical replication) |
| Data access | PostgREST (client API + RLS), Prisma (admin access & migrations) |
| Pooling | Supavisor / PgBouncer (transaction mode) |
| Testing | Vitest, Supertest, React Testing Library |
| Infra | Docker, Docker Compose, OrbStack, AWS EC2, NGINX |

## Future scope

- **P2P debt minimization** — graph-reduction so players settle with each other instead of a central banker.
- **Persistent groups** — recurring home-game circles, carry-over balances, and group roles (organizers, regulars, guests).
- **Bankroll analytics** — $/hr, bb/hr, ROI, streaks, and drawdown views.
- **Payment links** — Venmo, Zelle, and Cash App deep links next to the settlement breakdown.
