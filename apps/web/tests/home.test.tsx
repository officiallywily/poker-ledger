import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import Home from "@/app/page";

describe("Home Page", () => {
    it("renders without crashing", () => {
        render(<Home />);
        expect(document.body).toBeDefined();
    })
});