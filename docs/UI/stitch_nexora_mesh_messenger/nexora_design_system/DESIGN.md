---
name: Nexora Design System
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#464555'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#777587'
  outline-variant: '#c7c4d8'
  surface-tint: '#4d44e3'
  primary: '#3525cd'
  on-primary: '#ffffff'
  primary-container: '#4f46e5'
  on-primary-container: '#dad7ff'
  inverse-primary: '#c3c0ff'
  secondary: '#006591'
  on-secondary: '#ffffff'
  secondary-container: '#39b8fd'
  on-secondary-container: '#004666'
  tertiary: '#005338'
  on-tertiary: '#ffffff'
  tertiary-container: '#006e4b'
  on-tertiary-container: '#67f4b7'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2dfff'
  primary-fixed-dim: '#c3c0ff'
  on-primary-fixed: '#0f0069'
  on-primary-fixed-variant: '#3323cc'
  secondary-fixed: '#c9e6ff'
  secondary-fixed-dim: '#89ceff'
  on-secondary-fixed: '#001e2f'
  on-secondary-fixed-variant: '#004c6e'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Geist
    fontSize: 57px
    fontWeight: '600'
    lineHeight: 64px
    letterSpacing: -0.25px
  headline-lg:
    fontFamily: Geist
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Geist
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  title-lg:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-md:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 64px
---

## Brand & Style

This design system is built for secure, peer-to-peer communication where reliability and privacy are paramount. The aesthetic follows a refined **Modern Corporate** approach, heavily influenced by **Material 3 (M3)** principles. It prioritizes clarity, structural integrity, and functional precision to evoke a sense of calm resilience.

The target audience consists of privacy-conscious users and teams operating in decentralized or offline environments. The UI avoids "digital fluff"—there are no gradients, neon effects, or glassmorphism. Instead, it relies on solid tonal planes, intentional whitespace, and a rigorous icon-and-color status system to communicate the state of the mesh network. The atmosphere is technical yet accessible, ensuring that complex security protocols feel intuitive and trustworthy.

## Colors

The palette is rooted in a deep Indigo primary, signaling authority and security. The secondary Cyan and tertiary Emerald are reserved for connectivity states and technical success indicators.

### Tonal Application (Light Mode)
- **Primary:** Indigo (#4F46E5) for key actions and brand presence.
- **On-Primary:** White (#FFFFFF).
- **Secondary Container:** Soft Cyan-Blue for subtle highlights in chat or peer lists.
- **Surface:** Neutral Gray-Blue (#F8FAFC) to maintain a clean, airy feel.

### Tonal Application (Dark Mode)
- **Primary:** Desaturated Indigo (#818CF8) to ensure WCAG accessibility against dark backgrounds.
- **Surface:** Deep Charcoal-Navy (#0F172A) for the main background.
- **Surface Container:** Slightly lighter navy (#1E293B) to create visual separation without using shadows.

### Status Indicators
Status must always pair color with the specific iconography defined in the components section to ensure accessibility for color-blind users and high-stress environments.

## Typography

The typography system uses a tri-font approach to balance modernity, readability, and technical precision.

- **Geist** is used for headlines to provide a sharp, technical, and minimal appearance.
- **Inter** is the workhorse for body text and communication logs, chosen for its exceptional legibility in both light and dark modes.
- **JetBrains Mono** is utilized for metadata, status labels, and encryption keys, reinforcing the "offline-first/technical" nature of the app.

Text should always maintain high contrast. Avoid font weights below 400 for body text to ensure readability on mobile screens in varied lighting conditions.

## Layout & Spacing

The layout follows a **Fluid Grid** model based on an 8px base unit (with a 4px half-step for tight components).

- **Mobile:** 4-column grid with 16px margins and 16px gutters.
- **Tablet:** 8-column grid with 24px margins and 16px gutters.
- **Desktop:** 12-column grid with a maximum content width of 1200px, centered.

Spacing between functional groups (e.g., chat bubbles and input fields) should use `lg` (24px), while internal component spacing (e.g., icon to text) should use `sm` (8px).

## Elevation & Depth

In accordance with the "no heavy shadows" requirement, this design system communicates hierarchy through **Tonal Layering** (Surface-Container tiers) and **Low-Contrast Outlines**.

- **Level 0 (Floor):** Main background color (`surface`).
- **Level 1 (Cards/Lists):** A slightly lighter (light mode) or darker (dark mode) tonal variation (`surface-container-low`). Use a 1px solid border with 10% opacity of the on-surface color.
- **Level 2 (Modals/Overlays):** `surface-container-high`. Instead of a shadow, use a more distinct border or a subtle scrim to dim the background.
- **Active States:** Indicated by a subtle color fill change (e.g., Primary at 12% opacity) rather than a lift or glow.

## Shapes

The design system uses **Rounded** geometry to soften the technical nature of the app, making it feel approachable.

- **Small Components (Buttons, Chips):** 8px (0.5rem) corner radius.
- **Medium Components (Cards, Input Fields):** 12px (0.75rem) corner radius.
- **Large Components (Modals, Bottom Sheets):** 24px (1.5rem) top-only corner radius.
- **Status Pills:** Fully rounded (pill-shaped) to distinguish them from actionable buttons.

## Components

### Navigation
- **NavigationBar:** Positioned at the bottom for mobile. Use active-indicator pills (M3 style) behind icons. Icons should be 24px, accompanied by a `label-md` text.

### Buttons
- **Primary:** Solid fill with `on-primary` text. No gradients.
- **Secondary:** Outlined with a 1px stroke of the primary color.
- **Actionable Icons:** Minimal 48x48px touch targets with centered 24px icons.

### Status Indicators (Icon + Color)
- **Success/Secure:** `✓` icon + Tertiary Emerald.
- **Active/Connected:** `●` icon + Secondary Blue.
- **Warning:** `△` icon + Amber.
- **Error:** `!` icon + Red.
- **Offline:** `○` icon + Neutral Gray.
- **Privacy:** `🔒` icon + Primary Indigo (used for encrypted message markers).

### Input Fields
- Filled style (M3) with a bottom-line indicator and 12px corner radius.
- Leading icons are used for search or identity, trailing icons for encryption status.

### Chat Bubbles
- **Sender:** Primary color container with right-alignment.
- **Receiver:** Surface-container-low container with left-alignment.
- Both use `body-lg` and include a `label-md` timestamp and delivery status icon.

### Cards
- Use for "Peer Discovery" or "Network Node" info. Flat appearance with a subtle 1px border. No shadows.