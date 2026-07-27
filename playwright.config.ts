import { defineConfig, devices } from '@playwright/test';

// CLI không có flag --slow-mo. Dùng env SLOW_MO (ms), ví dụ: SLOW_MO=400
const slowMo = Number(process.env.SLOW_MO || 0);

export default defineConfig({
  testDir: './playwright-tests',
  fullyParallel: false, // run sequentially to avoid state conflicts on the db
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1, // run tests sequentially to avoid database conflicts
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:8080/Ban_Hoa_Qua_Online/',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    viewport: { width: 1280, height: 720 },
    actionTimeout: 15000,
    navigationTimeout: 30000,
    launchOptions: {
      ...(slowMo > 0 ? { slowMo } : {}),
    },
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'mobile-screens',
      testMatch: /screen-capture\.spec\.ts/,
      use: { ...devices['iPhone 12'] },
    },
  ],
});
