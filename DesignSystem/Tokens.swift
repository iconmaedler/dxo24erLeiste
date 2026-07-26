// DXO24Controller/DesignSystem/Tokens.swift
//
// Design token reference (documentation only). The authoritative, compiled
// token values live in DesignSystem/Core.swift (enum DS). This file intentionally
// contains no executable code so it cannot drift from Core.swift and cannot
// break the build.
//
// Color System
// - Background: systemBackground
// - Surface: secondarySystemBackground
// - Elevated: tertiarySystemBackground
// - Accent: accentColor (system-assigned, respects tint)
// - Success: green / Warning: orange / Error: red
//
// Typography
// - Large title: .largeTitle, Title: .title, Headline: .headline
// - Body: .body, Caption: .caption, Mono: .body.monospaced()
//
// Spacing (DS.Spacing) — 4pt grid: xs 4, sm 8, md 12, lg 16, xl 24, xxl 32
// Radius (DS.Radius) — sm 6, md 10, lg 14, xl 20, pill 999
// Animation (DS.Animation) — spring: response 0.35, damping 0.82; easeOut: 0.22s
// Elevation (DS.Elevation) — level1 2pt, level2 6pt, level3 12pt
//
// Accessibility
// - Minimum touch target: 44 x 44 pt
// - Minimum contrast: 7:1 for text
// - Reduce Motion: respect accessibilityReduceMotion
// - Dynamic Type: use semantic fonts, avoid fixed sizes
