# Google Stitch prompt — NEXORA

> **Status:** draft, pending Q-DESIGN-001 (`spec/questions.md`) — resolves the
> "no visual design source" gap by using Google Stitch to generate one from
> `documentation/Design.md`'s written spec.
>
> **This file is not the design source itself.** Once screens are generated
> in Stitch, export them (HTML preferred — see `docs/UI/README.md`) into
> `docs/UI/<export-folder>/`, wire that folder into `design/sources.yaml`,
> then run `make design-extract` → `make design-contract` to mint the actual
> golden contracts. This file only records the prompts used to get there, so
> the generation is reproducible and traceable back to the BRD/Design spec.

---

## Master prompt (paste first — establishes the design system + core screens)

```
Design a mobile app called NEXORA — tagline "Connect beyond the network."

App type: A secure, offline-first, peer-to-peer mesh communication app
(like a messenger, but it also works with no internet via Bluetooth/Wi-Fi
Direct, relayed through nearby devices). The tone should feel modern, calm,
reliable, technical without being complicated, and privacy-focused.

Design system: Material 3, strictly. Use real Material 3 components
(NavigationBar, Cards, FilledButton, FilterChip, Switch, BottomSheet,
Snackbar, Banner, ListTile) — no custom competing visual language.

Theme:
- Seed color: deep indigo / blue-violet, hex #4F46E5. Generate the full
  Material 3 color scheme from this seed (primary indigo, secondary
  blue/cyan, tertiary teal/emerald).
- Support light, dark, and system theme. Dark mode should use proper
  Material 3 dark tonal roles, not just inverted colors.
- Navigation: bottom NavigationBar on phone, adapting to a NavigationRail
  on tablet width.

Visual language should communicate: connection, trust, privacy, network
resilience, technology, human communication — without gradients, neon
colors, glassmorphism, or heavy shadows. Rounded but not overly playful
corners. Status must never rely on color alone — pair every status with an
icon (✓ success, ● active, △ warning, ! error, ○ offline, 🔒 secure).

Generate these core screens as one connected flow, sharing the same theme
and navigation shell:

1. Welcome / first-launch screen — app name, tagline, single primary
   "Get started" action.
2. Main Dashboard — a prominent "Network Status" card showing connection
   state (Connected / Connecting / Offline / Limited / Secure), a storage
   usage summary card that can show a subtle informational warning
   ("Smart Mode - older than 10 days"), and quick access to recent
   conversations.
3. Conversations list — two sections, "Personal" and "Groups", each a list
   of contacts/groups with avatar, name, last message preview, and an
   encryption/trust indicator badge.
4. Chat screen — message bubbles (sent/received), a small encryption
   indicator in the header ("🔒 End-to-end encrypted"), a bottom input bar
   with text input, voice message record button, and attachment button.
   Include a delivery-state indicator per message (queued/sent/delivered/
   read/failed).
5. Devices screen — list of paired/nearby devices with trust state badges
   (Trusted / Allowed / Unknown / Blocked), and a "Discover devices" empty
   state when no connections exist yet.
6. Settings home — a grouped list: Account, Privacy & Security, Storage,
   Network, Battery, Notifications, Security Center, About/Updates.

Use progressive disclosure: the default view should just say "You're
connected" — advanced technical detail (route path, transport, latency,
packet loss) should be one tap away, not shown by default.
```

---

## Follow-up prompts (run one at a time, after the master, to complete the screen inventory)

- *"Now design the Group Chat screen — same message bubble style, plus a way to see group members and a subtle indicator that some members may be invisible if blocked."*
- *"Design the Voice/PTT/Call screens — an active call screen with route/connection-quality indicator, and a push-to-talk button state."*
- *"Design the Location sharing screen — a global on/off toggle and a per-contact list of allowed/disabled location access."*
- *"Design the Storage Management settings screen — mode selector (Smart Mode / delete after X days / delete after X MB) and an expandable breakdown of what Smart Mode plans to remove and why."*
- *"Design the Mandatory Update screen — a non-dismissible full-screen state explaining the app must be updated, with a single 'Update NEXORA' action."*
- *"Design empty, offline, and error states for the Dashboard and Chat screens — offline should read as a normal state ('Messages will be sent when a route becomes available'), not an error."*

---

## Traceability

- **Source spec:** `documentation/Design.md` (§1–13 visual identity/tokens/nav, §16–39 dashboard/chat/device screens, §40–58 location/settings/update screens, §80–87 first-run flow)
- **Answers:** `spec/questions.md` → Q-DESIGN-001 (🟢 answered — all 7 screens extracted and contracted)
- **Next step:** 🧍 `design_contract_approval` — review `design/screens/*.md`, then UI task sharding can begin

## Status: closed

All 7 screens are in `docs/UI/stitch_nexora_mesh_messenger/`, wired in
`design/sources.yaml`, extracted (`design/golden/`), and contracted
(`design/screens/*.md`):

| Screen | Notes |
|---|---|
| welcome | CTA fixed to "Continue with Google" (Google-branded button) — the original export had a generic "Get started" button |
| dashboard | |
| conversations | |
| chat | |
| devices | |
| settings | |
| login | Added — "Signing in to NEXORA" transition state, wasn't in the original 6-screen master prompt |

Generated via a direct HTTP bridge to Stitch's MCP endpoint (Claude Code's
native MCP client can't connect to this server — see
`agent/mcp/stitch.md`), not through the manual web-UI flow this file
originally documented. The prompts above are kept for reference/reuse.
