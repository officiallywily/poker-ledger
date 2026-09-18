import "dotenv/config";
import express, { type Express } from "express";
import cors from "cors";

export const app: Express = express();

app.use(cors({
    origin: process.env.WEB_ORIGIN || "localhost:3000"
}));

app.use(express.json());

app.get("/health", (_req, res) => {
        res.status(200).json({ok: true,
        timestamp: new Date().toISOString()
    });
});