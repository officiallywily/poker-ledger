import { describe, it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/app.js";

describe("GET /health", () => {
    it("returns 200 with ok flag", async() => {
        const response = await request(app).get("/health");
        expect(response.status).toBe(200);
        expect(response.body.ok).toBe(true);
        expect(response.body.timestamp).toBeDefined();
    });
});