/*
  Warnings:

  - You are about to drop the `HealthCheck` table. If the table is not empty, all the data it contains will be lost.

*/
-- CreateEnum
CREATE TYPE "SessionStatus" AS ENUM ('active', 'closed', 'cancelled');

-- CreateEnum
CREATE TYPE "PlayerStatus" AS ENUM ('active', 'sitting_out', 'cashed_out');

-- DropTable
DROP TABLE "HealthCheck";

-- CreateTable
CREATE TABLE "health_checks" (
    "id" SERIAL NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "health_checks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "game_sessions" (
    "id" UUID NOT NULL,
    "join_code" VARCHAR(6) NOT NULL,
    "host_user_id" UUID NOT NULL,
    "buy_in_cap_cents" INTEGER,
    "status" "SessionStatus" NOT NULL DEFAULT 'active',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_at" TIMESTAMP(3),

    CONSTRAINT "game_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "session_players" (
    "id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "user_id" UUID,
    "guest_name" TEXT,
    "status" "PlayerStatus" NOT NULL DEFAULT 'active',
    "cash_out_amount_cents" INTEGER,
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "left_at" TIMESTAMP(3),

    CONSTRAINT "session_players_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "buy_ins" (
    "id" UUID NOT NULL,
    "player_id" UUID NOT NULL,
    "amount_cents" INTEGER NOT NULL,
    "bought_in_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "buy_in_num" INTEGER NOT NULL,
    "is_voided" BOOLEAN NOT NULL DEFAULT false,
    "voided_at" TIMESTAMP(3),

    CONSTRAINT "buy_ins_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "username" VARCHAR(30) NOT NULL,
    "display_name" TEXT NOT NULL,
    "avatar_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "game_sessions_join_code_key" ON "game_sessions"("join_code");

-- CreateIndex
CREATE INDEX "session_players_session_id_user_id_idx" ON "session_players"("session_id", "user_id");

-- CreateIndex
CREATE INDEX "session_players_user_id_idx" ON "session_players"("user_id");

-- CreateIndex
CREATE INDEX "buy_ins_player_id_idx" ON "buy_ins"("player_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- AddForeignKey
ALTER TABLE "game_sessions" ADD CONSTRAINT "game_sessions_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_players" ADD CONSTRAINT "session_players_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "game_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_players" ADD CONSTRAINT "session_players_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "buy_ins" ADD CONSTRAINT "buy_ins_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "session_players"("id") ON DELETE CASCADE ON UPDATE CASCADE;

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