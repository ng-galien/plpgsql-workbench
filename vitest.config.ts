import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["src/**/__tests__/**/*.test.ts"],
    testTimeout: 120_000,
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "json-summary"],
      reportsDirectory: "coverage/vitest",
      include: ["src/core/plx/**/*.ts"],
      exclude: ["src/**/__tests__/**", "src/core/plx/cli.ts", "src/core/plx/index.ts"],
    },
  },
});
