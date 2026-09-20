/*
  Warnings:

  - A unique constraint covering the columns `[player_id,buy_in_num]` on the table `buy_ins` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `session_id` to the `buy_ins` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX "buy_ins_player_id_idx";

-- AlterTable
ALTER TABLE "buy_ins" ADD COLUMN     "session_id" UUID NOT NULL;

-- CreateIndex
CREATE INDEX "buy_ins_session_id_idx" ON "buy_ins"("session_id");

-- CreateIndex
CREATE UNIQUE INDEX "buy_ins_player_id_buy_in_num_key" ON "buy_ins"("player_id", "buy_in_num");

-- AddForeignKey
ALTER TABLE "buy_ins" ADD CONSTRAINT "buy_ins_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "game_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
