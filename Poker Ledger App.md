**Application Summary**

A full-stack, real-time poker financial ledger web application engineered to eliminate manual spreadsheets and dispute-prone cash settlements for home games. The system provides a frictionless session lifecycle where hosts spin up games with unique join codes and optional buy-in caps, allowing registered users and non-registered guests to join seamlessly. Powered by Supabase Realtime WebSocket synchronization via PostgreSQL logical replication, the platform tracks chronological buy-ins and end-of-game cash-outs live across player devices, enforces zero-sum mathematical verification *(Σ(non-voided buy-ins) \= Σ(cash-outs))* before closing sessions, and calculates a centralized banker debt-settlement ledger directing all player payments to and from the session host.

**MVP Scope**

* **Live Session Lifecycle & Real-Time Sync:**  
  * Host room creation generating a 6-character `join_code` and optional `buy_in_cap_cents`.  
  * Support for authenticated users and guest players joining active rooms.  
  * Real-time WebSocket updates via **Supabase Realtime** listening to database changes on `buy_ins` and `session_players`, instantly reflecting rebuys, voided entries, and cash-outs.  
  * Session state management transitioning `game_status` from `active` to `closed`.  
* **Financial Ledger Engine:**  
  * Append-only logging of chronological initial buy-ins and sequential rebuys (`amount_cents`, `buy_in_num`, `bought_in_at`).  
  * Soft-delete auditing mechanism (`is_voided`, `voided_at`) allowing hosts to invalidate erroneous entries while preserving full transaction history.  
  * Player status tracking (`active`, `sitting_out`, `cashed_out`) paired with final chip count logging (`cash_out_amount_cents`).  
  * Automated zero-sum reconciliation preventing session finalization if total cash-outs do not match total active buy-ins.  
* **Centralized Banker Settlement Engine:**  
  * Individual net balance calculation (Cash-Out−∑Active Buy-Ins).  
  * Single-banker debt ledger mapping all payouts directly between participants and the host (net-negative players owe the host; the host pays net-positive players).  
* **Architecture & Infrastructure:**  
  * Dual-path data access: Client queries routed through PostgREST to enforce PostgreSQL Row-Level Security (RLS) via JWT user authentication, reserving Prisma for privileged administrative operations.  
  * Connection pooling configured with transaction-mode pooling (Supavisor) for runtime traffic and direct connections for Prisma schema migrations.  
  * NGINX reverse proxy on AWS EC2 handling HTTP traffic, SSL termination, and automated build deployments.

**Updated Future Expansion Scope**

* **Optimized P2P Debt Minimization:**  
  * Graph-reduction debt simplification algorithm to compute the minimal set of direct peer-to-peer transfers, removing the requirement for a centralized banker.  
* **Persistent Groups & Social Management:**  
  * Dedicated group environments for recurring home game circles with persistent member rosters.  
  * Multi-session running debt ledgers, allowing player balances to carry over across nights.  
  * Group-level role management (organizers, regular players, guests).  
* **Player Performance & Bankroll Analytics:**  
  * Normalized profit tracking, including hourly win rates ($/hr, bb/hr) and Return on Investment (ROI).  
  * Long-term trend analysis, win/loss streak metrics, and downswing/drawdown visualizations.  
* **Digital Payment Integrations:**  
  * Direct payment deep links (Venmo, Zelle, Cash App) generated alongside the banker settlement breakdown for one-tap payments.  
  * 

**Tech Stack**

* **Frontend:** Next.js, React, TypeScript  
* **Backend:** Node.js, Express, TypeScript  
* **Database & BaaS:** PostgreSQL, Supabase  
* **Realtime & WebSockets:** Supabase Realtime (PostgreSQL CDC / Logical Replication)  
* **Data Access & APIs:** PostgREST (client-facing data API with JWT-enforced RLS), Prisma ORM (privileged administrative access & migrations)  
* **Connection Pooling:** Supavisor / PgBouncer (transaction-mode pooling)  
* **Testing:** Vitest, Supertest, React Testing Library  
* **DevOps & Infrastructure:** Docker, Docker Compose, OrbStack, AWS EC2, NGINX (reverse proxy)