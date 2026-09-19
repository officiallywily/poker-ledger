import { describe, it, expect } from "vitest";

interface Buyin {
    amountCents: number;
    isVoided: boolean;
}

interface PlayerBalance {
    cashOutAmountCents: number;
    buyIns: Buyin[];
}

function verifyZeroSum(players: PlayerBalance[]): boolean {
    let totalBuyins = 0;
    let totalCashOuts = 0;

    for (const player of players) {
        if (player.cashOutAmountCents == null) return false;
        totalCashOuts += player.cashOutAmountCents;

        for (const b of player.buyIns) {
            if (!b.isVoided) totalBuyins += b.amountCents;
        }
    }
    return totalBuyins === totalCashOuts;
}

describe("Ledger Calculuation & Invariants", () => {
    it("validates zero-sum when cash outs match non-voided buy-ins", () => {
        const players: PlayerBalance[] = [
            {
                cashOutAmountCents: 15000,
                buyIns: [{amountCents: 10000, isVoided: false}],
            },
            {
                cashOutAmountCents: 5000,
                buyIns: [
                    {amountCents: 10000, isVoided: false},
                    {amountCents: 5000, isVoided: true} // voided rebuy ignored
                ],
            },
        ];

        expect(verifyZeroSum(players)).toBe(true);
    });

    it("fails zero-sum check on chip discrepancies", () => {
        const players: PlayerBalance[] = [
            {
                cashOutAmountCents: 12000, // missing 8000 cents
                buyIns: [{ amountCents: 10000, isVoided: false}],
            },
            {
                cashOutAmountCents: 0,
                buyIns: [{ amountCents: 10000, isVoided: false }],
            },
        ];

        expect(verifyZeroSum(players)).toBe(false);
    });
})