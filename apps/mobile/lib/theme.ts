/**
 * TypeScript mirror of the CSS variables defined in apps/mobile/global.css.
 *
 * - `THEME` is the raw token object for inline styles, animations, and
 *   anywhere a Tailwind class can't reach.
 * - `NAV_THEME` is the React Navigation theme — passed into <ThemeProvider />
 *   in app/_layout.tsx so headers, modals, and the back button match.
 *
 * If you change a variable in global.css, update the matching key here.
 * See apps/mobile/AGENTS.md, "Theming model", for the sync rule.
 */
import { DarkTheme, DefaultTheme, type Theme } from "expo-router";

export const THEME = {
  light: {
    background: "hsl(0 0% 100%)",
    foreground: "hsl(0 0% 12.5%)",
    card: "hsl(0 0% 100%)",
    cardForeground: "hsl(0 0% 12.5%)",
    popover: "hsl(0 0% 100%)",
    popoverForeground: "hsl(0 0% 12.5%)",
    primary: "hsl(5 69.3% 55.3%)",
    primaryForeground: "hsl(0 0% 100%)",
    secondary: "hsl(30 23.1% 94.9%)",
    secondaryForeground: "hsl(0 0% 12.5%)",
    muted: "hsl(30 23.1% 94.9%)",
    mutedForeground: "hsl(0 0% 40%)",
    accent: "hsl(30 23.1% 94.9%)",
    accentForeground: "hsl(0 0% 12.5%)",
    destructive: "hsl(4 62% 52.5%)",
    destructiveForeground: "hsl(0 0% 100%)",
    border: "hsl(34 14.9% 90.8%)",
    input: "hsl(34 14.9% 90.8%)",
    ring: "hsl(5 69.3% 55.3%)",
    radius: "0.625rem",
    chart1: "hsl(12 76% 61%)",
    chart2: "hsl(173 58% 39%)",
    chart3: "hsl(197 37% 24%)",
    chart4: "hsl(43 74% 66%)",
    chart5: "hsl(27 87% 67%)",

    // Multica custom
    brand: "hsl(5 69.3% 55.3%)",
    brandForeground: "hsl(0 0% 100%)",
    success: "hsl(136 92.8% 27.1%)",
    warning: "hsl(34 92.6% 47.8%)",
    info: "hsl(216 75.2% 51%)",
    priority: "hsl(34 92.6% 47.8%)",
    codeSurface: "hsl(33 16% 91%)",
    // Surface elevation tiers — see global.css for the full scale.
    surface1: "hsl(30 40% 98%)",
    surface2: "hsl(33 17% 90%)",
  },
  dark: {
    background: "hsl(0 0% 12.2%)",
    foreground: "hsl(0 0% 90.2%)",
    card: "hsl(0 0% 14.9%)",
    cardForeground: "hsl(0 0% 90.2%)",
    popover: "hsl(0 0% 14.9%)",
    popoverForeground: "hsl(0 0% 90.2%)",
    primary: "hsl(1 69.2% 58%)",
    primaryForeground: "hsl(0 0% 100%)",
    secondary: "hsl(0 0% 18.4%)",
    secondaryForeground: "hsl(0 0% 90.2%)",
    muted: "hsl(0 0% 18.4%)",
    mutedForeground: "hsl(0 0% 65.9%)",
    accent: "hsl(0 0% 18.4%)",
    accentForeground: "hsl(0 0% 90.2%)",
    destructive: "hsl(1 69.2% 58%)",
    destructiveForeground: "hsl(0 0% 100%)",
    border: "hsl(0 0% 21%)",
    input: "hsl(0 0% 21%)",
    ring: "hsl(1 69.2% 58%)",
    radius: "0.625rem",
    chart1: "hsl(220 70% 50%)",
    chart2: "hsl(160 60% 45%)",
    chart3: "hsl(30 80% 55%)",
    chart4: "hsl(280 65% 60%)",
    chart5: "hsl(340 75% 55%)",

    // Multica custom (dark)
    brand: "hsl(4 100% 70%)",
    brandForeground: "hsl(0 0% 12.2%)",
    success: "hsl(136 66.5% 43.3%)",
    warning: "hsl(34 92.6% 47.8%)",
    info: "hsl(216 75.2% 58%)",
    priority: "hsl(34 92.6% 47.8%)",
    // Keep this in sync with .dark:root in global.css.
    codeSurface: "hsl(0 0% 22.7%)",
    // Dark elevation tiers — lightness INCREASES with elevation. See global.css.
    surface1: "hsl(0 0% 16.9%)",
    surface2: "hsl(0 0% 23%)",
  },
};

export const NAV_THEME: Record<"light" | "dark", Theme> = {
  light: {
    ...DefaultTheme,
    colors: {
      background: THEME.light.background,
      border: THEME.light.border,
      card: THEME.light.card,
      notification: THEME.light.destructive,
      primary: THEME.light.primary,
      text: THEME.light.foreground,
    },
  },
  dark: {
    ...DarkTheme,
    colors: {
      background: THEME.dark.background,
      border: THEME.dark.border,
      card: THEME.dark.card,
      notification: THEME.dark.destructive,
      primary: THEME.dark.primary,
      text: THEME.dark.foreground,
    },
  },
};
