# NEXORA

## Connect beyond the network

# Product Design Specification

**Document:** `design.md`
**Product:** NEXORA
**Tagline:** Connect beyond the network
**Design System:** Material 3
**Platform:** Android-first
**Framework:** Flutter
**Design Approach:** Material 3 + Adaptive + Privacy-first + Offline-first
**Status:** Design Baseline v1.0

---

# 1. Design Philosophy

NEXORA is a communication application designed around:

- Privacy
- Trust
- Reliability
- Offline-first operation
- Network resilience
- Simplicity
- Low battery usage
- Clear system feedback

The interface should feel:

> **Modern, calm, reliable, technical without being complicated, and privacy-focused.**

The application must use **Material 3** consistently.

No independent visual design system should compete with Material 3.

---

# 2. Design Principles

## 2.1 Material 3 First

All primary UI components should use Material 3 components.

Examples:

- `NavigationBar`
- `NavigationRail`
- `NavigationDrawer`
- `AppBar`
- `Card`
- `FilledButton`
- `OutlinedButton`
- `TextButton`
- `FloatingActionButton`
- `SegmentedButton`
- `FilterChip`
- `AssistChip`
- `InputChip`
- `ChoiceChip`
- `Switch`
- `Checkbox`
- `Radio`
- `Slider`
- `BottomSheet`
- `Dialog`
- `Snackbar`
- `Banner`
- `ListTile`
- `ExpansionTile`
- `Badge`
- `Tooltip`

---

# 3. Visual Identity

## 3.1 Brand

```text
NEXORA

Connect beyond the network
````

The visual identity should communicate:

* Connection
* Trust
* Privacy
* Network resilience
* Technology
* Human communication

---

# 4. Color System

NEXORA should use Material 3's semantic color system rather than hard-coded colors throughout the application.

The application shall support:

* Light theme
* Dark theme
* System theme

Recommended primary brand direction:

```text
Primary:
Deep indigo / blue-violet family

Secondary:
Blue / cyan family

Tertiary:
Teal / emerald family
```

The exact values should be finalized during visual prototyping.

---

# 5. Material 3 Color Roles

The application should use semantic Material 3 color roles.

Example:

```dart
final colorScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF4F46E5),
  brightness: Brightness.light,
);
```

Dark mode:

```dart
final colorScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF4F46E5),
  brightness: Brightness.dark,
);
```

Components should use:

```dart
Theme.of(context).colorScheme.primary
```

instead of:

```dart
Colors.blue
```

---

# 6. Typography

NEXORA shall use Material 3 typography.

Recommended hierarchy:

```text
Display Large
Display Medium
Display Small

Headline Large
Headline Medium
Headline Small

Title Large
Title Medium
Title Small

Body Large
Body Medium
Body Small

Label Large
Label Medium
Label Small
```

Typography should prioritize readability.

Chat messages should primarily use:

```text
Body Large
```

or:

```text
Body Medium
```

depending on screen density.

---

# 7. Iconography

Use Material Symbols / Material Icons wherever possible.

Examples:

```text
chat
groups
call
mic
location_on
devices
security
block
person
settings
storage
sync
wifi
bluetooth
battery
lock
route
notifications
```

Icons should communicate functionality without requiring excessive explanatory text.

---

# 8. Spacing System

Use an 8dp-based spacing system.

```text
4dp   → micro spacing
8dp   → small
12dp  → compact
16dp  → standard
24dp  → section
32dp  → large
48dp  → major
64dp  → hero spacing
```

Avoid arbitrary spacing values unless required for component alignment.

---

# 9. Shape System

Material 3 shapes shall be used consistently.

Recommended:

```text
Small:
8dp

Medium:
12dp

Large:
16dp

Extra Large:
28dp
```

Cards and prominent containers should generally use larger rounded corners.

---

# 10. Elevation

Use Material 3 elevation tokens.

Avoid excessive shadows.

The application should primarily communicate hierarchy through:

* Surface color
* Tonal elevation
* Shape
* Spacing

rather than heavy shadows.

---

# 11. Application Navigation

The primary application structure should use Material 3 `NavigationBar` on phones.

Primary destinations:

```text
Home
Chats
Groups
Devices
Settings
```

Possible implementation:

```dart
NavigationBar(
  selectedIndex: controller.selectedIndex,
  onDestinationSelected: controller.changeTab,
  destinations: const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: 'Chats',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
      label: 'Groups',
    ),
    NavigationDestination(
      icon: Icon(Icons.devices_outlined),
      selectedIcon: Icon(Icons.devices),
      label: 'Devices',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ],
)
```

---

# 12. Responsive Navigation

NEXORA should adapt to device size.

## Compact

Use:

```text
NavigationBar
```

## Medium

Use:

```text
NavigationRail
```

## Expanded

Use:

```text
NavigationRail
+
Content
```

or:

```text
NavigationDrawer
```

The application should be designed for:

* Phones
* Foldables
* Tablets
* Large Android screens

---

# 13. Main Dashboard

The Home screen is the primary system overview.

It should show:

```text
NEXORA
────────────────────────

Connection status

Connected peers

Network quality

Battery

Storage warning

Security status

Recent activity
```

---

# 14. Dashboard Header

Example:

```text
┌─────────────────────────────────────┐
│ NEXORA                         ⚙    │
│ Connect beyond the network          │
└─────────────────────────────────────┘
```

The header should remain visually lightweight.

---

# 15. Network Status Card

The dashboard should show current connectivity.

Example:

```text
┌─────────────────────────────────────┐
│  ● Connected                        │
│                                     │
│  Network: Mesh                      │
│  Route: A → C → B                   │
│  Quality: Excellent                 │
│                                     │
│  2 active peers                     │
└─────────────────────────────────────┘
```

Use Material 3 `Card`.

---

# 16. Network Status States

## Connected

```text
● Connected
```

## Connecting

```text
◌ Connecting...
```

## Offline

```text
○ Offline
```

## Limited

```text
△ Limited connection
```

## Secure

```text
🔒 Secure
```

---

# 17. Route Visualization

When appropriate, the dashboard may visualize the current route.

Example:

```text
You
 │
 ▼
Device C
 │
 ▼
Device B
```

The visualization should remain simple.

It should not expose sensitive information about other users unnecessarily.

---

# 18. Storage Warning

Storage warnings appear on the dashboard when the configured policy predicts cleanup.

Example:

```text
┌─────────────────────────────────────┐
│ Storage management                  │
│                                     │
│ Smart Mode — Older than 10 days     │
│                                     │
│ 1.8 GB may be removed automatically │
│                                     │
│            [ View details ]         │
└─────────────────────────────────────┘
```

The user does **not** manually trigger cleanup from this warning.

---

# 19. Storage Warning Expansion

When expanded:

```text
Storage management

Smart Mode

Will remove:

🎤 Voice messages
820 MB
Older than 45 days

📞 Call recordings
620 MB
Older than 60 days

📎 Old attachments
310 MB
Rarely accessed

🗂 Temporary cache
50 MB
No longer required

Why?

Storage pressure is high and these
items have low recent usage.
```

This is an informational explanation of the automatic policy.

---

# 20. Chat Architecture

Chats shall be divided into:

```text
Personal
Groups
```

The Chats screen may use a Material 3 segmented control or tabs.

Example:

```text
┌────────────────────────────┐
│ Personal     Groups        │
└────────────────────────────┘
```

---

# 21. Personal Chat List

Example:

```text
Chats

┌──────────────────────────────┐
│ 👤 Ahmed                     │
│ Can you send the file?       │
│                        10:42 │
├──────────────────────────────┤
│ 👤 Nusrat                    │
│ 🎤 Voice message             │
│                        09:31 │
└──────────────────────────────┘
```

Use `ListTile`.

---

# 22. Group Chat List

Example:

```text
Groups

👥 Family
   Ahmed: Dinner at 8

👥 Work
   Panna: Build is ready

👥 Hiking
   Rahim: Let's go tomorrow
```

---

# 23. Chat Screen

Chat should follow familiar messaging patterns.

```text
┌──────────────────────────────┐
│ ← Ahmed              🔒 📞  │
├──────────────────────────────┤
│                              │
│        Hello                 │
│                              │
│                         Hi   │
│                              │
│        Are you there?        │
│                              │
├──────────────────────────────┤
│ +  Message...        🎤      │
└──────────────────────────────┘
```

---

# 24. Encryption Indicator

The chat header may show:

```text
🔒 End-to-end encrypted
```

Tapping the indicator opens security information.

Example:

```text
Encryption

✓ End-to-end encrypted

Only you and Ahmed can decrypt
this conversation.

Connection:
A → C → B

Relay devices cannot read
message content.
```

---

# 25. Message Bubble

Material 3 surface roles should be used.

Outgoing messages:

```text
primaryContainer
```

Incoming messages:

```text
surfaceContainerHighest
```

Avoid hard-coded colors.

---

# 26. Message Types

The UI shall support:

* Text
* Voice
* PTT
* Image
* Video
* File
* Location
* System event

---

# 27. Voice Message UI

Example:

```text
┌───────────────────────────┐
│ ▶  ━━━━━━━●━━━━━━        │
│    0:23                   │
└───────────────────────────┘
```

Include:

* Play/pause
* Progress
* Duration
* Playback state

---

# 28. PTT UI

Push-to-talk should use a prominent Material 3 control.

Example:

```text
Hold to talk

        🎙

    Release to send
```

The interface should provide clear feedback while recording.

---

# 29. Call UI

Call screen:

```text
┌──────────────────────────────┐
│                              │
│            👤                │
│                              │
│          Ahmed               │
│                              │
│       00:42                  │
│                              │
│    🔊     🎙     📞          │
│                              │
└──────────────────────────────┘
```

---

# 30. Call Connection Status

Show:

```text
Connecting...
Connected
Poor connection
Reconnecting...
Route changed
Call ended
```

Example:

```text
Connected

Route changed
Bluetooth → Wi-Fi
```

This feedback should not interrupt the call unnecessarily.

---

# 31. Group Chat

Group chat header:

```text
← Family             📞 ⋮
```

Group information:

```text
Family

12 members

Owner:
Ahmed

Admins:
Rahim
Panna
```

---

# 32. Blocked Users in Groups

When a blocked user exists in the same group, the blocked user must be visually hidden.

Example:

```text
Visible:

Ahmed
C
D

Hidden:
Blocked user
```

No avatar, activity, location, typing indicator, or message attribution should reveal the blocked user's presence to the blocker.

---

# 33. Connection Requests

Connection requests should use Material 3 cards.

Example:

```text
┌──────────────────────────────┐
│ 👤 Rahim                     │
│ Wants to connect with you    │
│                              │
│ [ Accept ]    [ Decline ]    │
└──────────────────────────────┘
```

---

# 34. Trusted Device

Trusted devices should have a clear visual indicator.

Example:

```text
✓ Trusted
```

Use a `Badge` or supporting icon.

---

# 35. Device Screen

The Devices screen shows the user's own registered devices.

Example:

```text
Your devices

📱 Pixel 9
   This device
   ✓ Active

📱 Samsung S25
   Last active 12 min ago

💻 Tablet
   Last active yesterday
```

---

# 36. Device Details

Device detail screen:

```text
Pixel 9

This device

Security
✓ Verified

Connection
Connected

Battery
78%

Last synchronization
2 minutes ago

[ Revoke device ]
```

---

# 37. Trusted People

A separate relationship screen may show:

```text
Trusted

Ahmed
✓ Trusted

Rahim
✓ Trusted

Nusrat
✓ Trusted
```

---

# 38. Blocked People

Blocked users should be clearly separated.

```text
Blocked

User A
User B
User C
```

Actions:

```text
Unblock
```

---

# 39. Relationship Detail

Example:

```text
Ahmed

✓ Connected
✓ Trusted

Communication
Allowed

Location
Allowed

Auto Accept
Enabled

[ Block ]
```

---

# 40. Per-User Location Setting

Each relationship may have:

```text
Location sharing

[ ON ]
```

or:

```text
Location sharing

[ OFF ]
```

Global location sharing overrides per-user access.

---

# 41. Global Location Setting

Settings:

```text
Location Sharing

Share my live location

[ ON ]
```

When disabled:

```text
Location sharing is disabled
for everyone.
```

---

# 42. Location Screen

Example:

```text
Live Location

┌─────────────────────────────┐
│                             │
│           MAP               │
│                             │
│     ● Ahmed                 │
│                             │
└─────────────────────────────┘

Last updated:
12 seconds ago
```

---

# 43. Location Privacy

If a user is not authorized:

```text
Location unavailable
```

Do not show:

* Approximate location
* Last location
* Timestamp
* Distance

unless policy explicitly allows it.

---

# 44. Settings Architecture

Settings should use Material 3 `ListTile` sections.

Example:

```text
Settings

Account
  Account
  Devices

Privacy & Security
  Trusted people
  Blocked people
  Location sharing
  Encryption

Communication
  Notifications
  Calls
  Voice

Storage
  Storage management

Network
  Connectivity
  Relay settings

Application
  Appearance
  Language
  About
```

---

# 45. Account Settings

```text
Account

Profile
Email
Google account
Connected devices
Sign out
```

---

# 46. Privacy & Security

```text
Privacy & Security

Trusted people
Blocked people
Location sharing
Security information
Device verification
```

---

# 47. Storage Settings

```text
Storage management

Current usage:
8.4 GB

Available:
42 GB

Management mode:

● Smart Mode
○ Delete after X days
○ Delete when storage exceeds X MB
```

---

# 48. Smart Mode Settings

```text
Smart Mode

Automatic cleanup decisions

Current decision:

Voice messages
Older than 45 days

Call recordings
Older than 60 days

Attachments
Rarely accessed

Temporary cache
When no longer required
```

The user sees the policy, not a manual cleanup action.

---

# 49. Age-Based Storage Policy

```text
Delete data older than

[ 30 ] days
```

Supported categories may include:

* Voice messages
* Call recordings
* Attachments
* Cached media

---

# 50. Size-Based Storage Policy

```text
Delete old data when storage exceeds

[ 10 ] GB
```

The application automatically determines which eligible old data to remove.

---

# 51. Network Settings

Example:

```text
Network

Mesh networking       ON
Background discovery  ON

Available transports:

✓ Bluetooth
✓ Wi-Fi
✓ Wi-Fi Direct
✓ Internet
```

---

# 52. Battery Settings

Because battery efficiency is important:

```text
Battery

Network efficiency
    Balanced

Background activity
    Optimized

Voice quality
    Battery Saver
```

Voice quality remains in Battery Saver mode by default.

---

# 53. Notifications

Settings:

```text
Notifications

Messages          ON
Calls             ON
Connection        ON
Groups            ON
Location          ON
Storage warnings  ON
```

---

# 54. Security Center

NEXORA should provide a security overview.

Example:

```text
Security

✓ End-to-end encryption
✓ Device verified
✓ No security warnings

Trusted devices
2

Blocked users
3
```

---

# 55. Application Update UI

Settings should show:

```text
About NEXORA

Version
1.8.0 (108)

✓ Up to date
```

If an update exists:

```text
Update available

1.8.1

[ Update ]
```

If mandatory:

```text
Update required

Your version is no longer supported.

[ Update NEXORA ]
```

---

# 56. Mandatory Update Screen

Mandatory update should be full-screen.

```text
┌───────────────────────────────┐
│                               │
│            NEXORA             │
│                               │
│       Update Required         │
│                               │
│ Your version is no longer     │
│ supported.                    │
│                               │
│ Update NEXORA to continue.    │
│                               │
│       [ Update Now ]          │
│                               │
└───────────────────────────────┘
```

No dismiss action.

---

# 57. Maintenance Mode

If enabled:

```text
NEXORA

Temporarily unavailable

We're performing maintenance.

Please try again later.
```

Offline functionality should not unnecessarily be blocked if the maintenance operation does not affect local functionality.

---

# 58. Search

NEXORA should support global search.

Search targets:

* People
* Groups
* Messages
* Files
* Voice messages

Search must respect blocking and encryption boundaries.

---

# 59. Empty States

Empty states should be helpful.

Example:

```text
No conversations yet

Connect with someone to start
a secure conversation.

[ Add connection ]
```

---

# 60. Error States

Errors should be understandable.

Avoid:

```text
ERR_NETWORK_102
```

Prefer:

```text
Connection unavailable

NEXORA could not find a route
to this device.

We'll retry automatically.
```

---

# 61. Offline State

When offline:

```text
Offline

Messages will be queued and
sent when a route becomes available.
```

This should be informational rather than alarming.

---

# 62. Connection Lost

Example:

```text
Connection interrupted

Searching for another route...

A → C → B

Trying:
A → D → B
```

---

# 63. Route Migration Notification

Route changes should generally be silent.

For significant changes:

```text
Connection optimized

Switched from Bluetooth to Wi-Fi.
```

Use `Snackbar`.

---

# 64. Sync Indicator

Synchronization status may appear subtly.

```text
↻ Syncing
✓ Synced
○ Offline
```

Avoid constantly displaying synchronization indicators if they add noise.

---

# 65. Security Event

Security-sensitive events should be explicit.

Example:

```text
Security change

Ahmed has been removed from
your trusted devices.

Future communication requires
authentication.
```

---

# 66. Group Member Removal

Example confirmation:

```text
Remove Ahmed?

Ahmed will no longer be able to
participate in this group.

[ Cancel ] [ Remove ]
```

---

# 67. Block Confirmation

Blocking is a significant action.

```text
Block Ahmed?

Ahmed will no longer be able to:

• Communicate with you
• See your activity
• Access your location

You will also be unable to
communicate with Ahmed.

[ Cancel ] [ Block ]
```

---

# 68. Delete Conversation

Conversation deletion should distinguish:

```text
Delete locally
```

from:

```text
Delete for everyone
```

The first should be the default because local storage is device-specific.

---

# 69. Accessibility

NEXORA must follow Material accessibility principles.

Support:

* Screen readers
* Large fonts
* High contrast
* Touch target sizes
* Semantic labels
* Keyboard navigation where applicable
* Reduced motion

---

# 70. Touch Targets

Interactive controls should generally provide at least a 48dp touch target.

---

# 71. Motion

Animations should be subtle.

Use motion for:

* Navigation
* Route changes
* Message insertion
* Expand/collapse
* Dialogs
* Connection states

Avoid excessive animation during:

* Calls
* PTT
* Background synchronization

---

# 72. Loading States

Use Material 3-friendly loading states.

Prefer:

* Progress indicators
* Skeleton placeholders
* Shimmer only where justified

Avoid blocking full-screen loaders for simple operations.

---

# 73. Dialog Guidelines

Dialogs should be used for:

* Confirmation
* Destructive actions
* Important security decisions

Do not use dialogs for every informational event.

Prefer:

* Snackbar
* Banner
* Inline status

when appropriate.

---

# 74. Bottom Sheets

Use Material 3 bottom sheets for:

* Attachment selection
* Connection options
* Route information
* Message actions
* Device actions

---

# 75. Context Menus

Long-press or overflow menus may provide:

```text
Reply
Forward
Copy
Save
Delete
Information
```

Only actions allowed by the user's security relationship should be shown.

---

# 76. Message Security Menu

A message may expose:

```text
Message information

Encrypted
Delivered
Read

Route:
A → C → B

Relay:
C

Payload:
End-to-end encrypted
```

Sensitive metadata should not be exposed unnecessarily.

---

# 77. Group Information

Group information screen:

```text
Family

12 members

Owner
Ahmed

Admins
Rahim
Panna

Members
...
```

---

# 78. Group Security

```text
Group security

✓ Encrypted

Current key version:
12

Members:
12

Last key rotation:
Today
```

---

# 79. Device Revocation

Device revocation should be prominent but protected.

```text
Revoke device?

This device will no longer be
trusted by your account.

Existing encrypted data on the
device may remain locally stored
until manually removed.

[ Cancel ] [ Revoke ]
```

---

# 80. First Launch

First launch flow:

```text
NEXORA
   |
   v
Welcome
   |
   v
Google Authentication
   |
   v
Device Setup
   |
   v
Permissions
   |
   v
Security Setup
   |
   v
Ready
```

---

# 81. Welcome Screen

```text
NEXORA

Connect beyond the network

Secure communication that keeps
working when the network doesn't.

[ Continue with Google ]
```

---

# 82. Permission Flow

Permissions should be requested contextually.

Potential permissions:

* Bluetooth / Nearby devices
* Location
* Notifications
* Microphone
* Camera
* Storage/media where required

Do not request every permission at first launch unless necessary.

---

# 83. Permission Explanation

Before system permission dialogs, explain why.

Example:

```text
Nearby devices

NEXORA uses nearby connections
to communicate with trusted devices
without relying on the Internet.

[ Continue ]
```

---

# 84. First Device Setup

After authentication:

```text
Setting up your device...

✓ Account connected
✓ Device identity created
✓ Security keys generated
✓ Local storage initialized
✓ Network services initialized
```

---

# 85. Device Pairing

Pairing should emphasize verification.

```text
Verify device

Code:

      482 193

Ask the other device to confirm
this code.

[ Confirm ]
```

---

# 86. Trust Establishment

After successful verification:

```text
Device verified

Ahmed's device is now trusted.

✓ Encrypted communication enabled
✓ Automatic reconnection enabled
```

---

# 87. First Dashboard

After setup:

```text
Welcome to NEXORA

No active connections yet.

Discover nearby devices or
add someone you trust.

[ Discover devices ]
```

---

# 88. Visual Status Language

NEXORA should use consistent status semantics.

```text
Success:
✓

Active:
●

Warning:
△

Error:
!

Offline:
○

Secure:
🔒
```

The UI should not rely on color alone.

---

# 89. Privacy UX

Privacy decisions should be visible but not intrusive.

Examples:

```text
🔒 End-to-end encrypted
✓ Trusted device
🚫 Blocked
📍 Location shared
```

---

# 90. Material 3 Implementation

The Flutter application should centralize its theme.

Example:

```dart
class NexoraTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
    );
  }
}
```

---

# 91. Application Theme

The application should support:

```text
System default
Light
Dark
```

Default:

```text
System default
```

---

# 92. Component Architecture

Reusable design components should be created.

Example:

```text
lib/
└── core/
    └── design/
        ├── theme/
        │   ├── nexora_theme.dart
        │   ├── nexora_colors.dart
        │   ├── nexora_typography.dart
        │   └── nexora_shapes.dart
        │
        ├── components/
        │   ├── nexora_card.dart
        │   ├── nexora_status_card.dart
        │   ├── nexora_avatar.dart
        │   ├── nexora_badge.dart
        │   ├── nexora_empty_state.dart
        │   ├── nexora_message_bubble.dart
        │   ├── nexora_network_status.dart
        │   └── nexora_storage_warning.dart
        │
        └── widgets/
```

---

# 93. Design Tokens

The application should avoid hard-coded values.

Example:

```dart
class NexoraSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
```

---

# 94. Chat Architecture

Suggested Flutter structure:

```text
features/
└── chat/
    ├── presentation/
    │   ├── pages/
    │   │   ├── chats_page.dart
    │   │   └── chat_page.dart
    │   │
    │   ├── widgets/
    │   │   ├── message_bubble.dart
    │   │   ├── voice_message.dart
    │   │   ├── chat_input.dart
    │   │   └── chat_header.dart
    │   │
    │   └── controllers/
    │
    ├── domain/
    └── data/
```

---

# 95. Dashboard Architecture

```text
features/
└── dashboard/
    ├── presentation/
    │   ├── pages/
    │   │   └── dashboard_page.dart
    │   │
    │   └── widgets/
    │       ├── network_status_card.dart
    │       ├── storage_warning.dart
    │       ├── active_devices.dart
    │       └── security_status.dart
    │
    ├── domain/
    └── data/
```

---

# 96. Settings Architecture

```text
features/
└── settings/
    ├── presentation/
    │   ├── pages/
    │   └── widgets/
    │
    ├── domain/
    └── data/
```

---

# 97. Design State Management

UI state should distinguish:

```text
Loading
Loaded
Empty
Offline
Error
Restricted
```

Example:

```dart
sealed class UiState<T> {
  const UiState();
}

class Loading<T> extends UiState<T> {}

class Loaded<T> extends UiState<T> {
  final T data;

  const Loaded(this.data);
}

class Empty<T> extends UiState<T> {}

class Offline<T> extends UiState<T> {}

class Error<T> extends UiState<T> {
  final Object error;

  const Error(this.error);
}
```

---

# 98. Offline UI Principle

Offline should not automatically mean error.

Example:

```text
Offline

Messages will be sent when
a route becomes available.
```

This is a valid application state.

---

# 99. Security UI Principle

Security-related failures should be explicit.

Example:

```text
Secure connection unavailable

NEXORA could not establish a
verified encrypted connection.

Communication has been paused.
```

Never silently downgrade security.

---

# 100. Network UI Principle

The user should not need to understand the underlying routing system.

Instead of:

```text
BLE GATT channel 3
```

show:

```text
Connected through nearby devices
```

Advanced users may open:

```text
Connection details
```

to see technical information.

---

# 101. Advanced Network Details

Optional technical view:

```text
Connection details

Route:
You → Device C → Device B

Transport:
Bluetooth

Latency:
42 ms

Packet loss:
0.4%

Battery cost:
Low

Stability:
Excellent
```

---

# 102. Progressive Disclosure

NEXORA should hide complexity by default.

Basic user:

```text
Connected
Excellent
```

Advanced user:

```text
Route:
A → C → B

Transport:
Bluetooth

Latency:
42 ms
```

This keeps the product accessible while retaining technical transparency.

---

# 103. User Experience Priority

When making UI decisions, prioritize:

```text
1. Security
2. Communication reliability
3. User understanding
4. Accessibility
5. Battery efficiency
6. Visual polish
```

---

# 104. Design Anti-Patterns

Avoid:

* Excessive gradients
* Excessive glassmorphism
* Heavy shadows
* Neon colors
* Excessive animations
* Constant network technical details
* Full-screen loading screens
* Too many dialogs
* Excessive notifications
* Hard-coded colors
* Inconsistent corner radii
* Different component styles for the same purpose

---

# 105. Material 3 Compliance

All new screens should be reviewed against:

* Material 3 component usage
* Color roles
* Typography
* Accessibility
* Touch targets
* Dark mode
* Dynamic sizing
* Responsive layout

---

# 106. Dark Mode

Dark mode should be a first-class design.

Avoid simply inverting colors.

Material 3 dark color schemes should be generated using semantic roles.

Example:

```dart
ThemeMode.system
```

should be the default.

---

# 107. Dynamic Color

Where supported, NEXORA may support Android Dynamic Color.

Example:

```dart
ColorScheme.fromSeed(...)
```

or platform-derived dynamic color.

Brand identity should remain recognizable while respecting the user's system theme.

---

# 108. Tablet Layout

Tablet:

```text
┌────────────┬─────────────────────────────┐
│ Navigation │                             │
│            │       Current Screen        │
│ Home       │                             │
│ Chats      │                             │
│ Groups     │                             │
│ Devices    │                             │
│ Settings   │                             │
└────────────┴─────────────────────────────┘
```

For messaging:

```text
┌──────────────┬─────────────────────────────┐
│ Conversations│ Conversation                │
│              │                             │
│ Ahmed        │ Messages                    │
│ Rahim        │                             │
│ Family       │                             │
└──────────────┴─────────────────────────────┘
```

---

# 109. Foldable Layout

The application should adapt to foldable screen states.

Chat may use:

```text
Conversation list
+
Active conversation
```

when enough space is available.

---

# 110. Large Screen Calls

Call controls should remain reachable.

Avoid placing important controls at extreme corners.

---

# 111. Localization

The design should support localization from the beginning.

All visible strings must come from localization resources.

Do not hard-code user-facing text.

Example:

```dart
Text(
  context.l10n.updateRequired,
)
```

---

# 112. RTL Support

The UI should support RTL languages where required.

Avoid hard-coded:

```dart
EdgeInsets.only(left: ...)
```

when logical directional padding is more appropriate.

Prefer:

```dart
EdgeInsetsDirectional.only(
  start: 16,
)
```

---

# 113. Text Expansion

The UI must tolerate translated text being longer than English.

Avoid fixed-width labels where possible.

---

# 114. Accessibility Labels

Icons without visible labels must provide semantic labels.

Example:

```dart
Semantics(
  label: 'Start voice call',
  button: true,
  child: IconButton(
    onPressed: onCall,
    icon: const Icon(Icons.call),
  ),
)
```

---

# 115. Voice Accessibility

Voice messages should provide:

* Duration
* Playback controls
* Accessible labels
* Optional transcription in future versions

---

# 116. Security Confirmation Patterns

High-impact operations should use confirmation.

Examples:

```text
Block user
Revoke device
Remove group member
Delete conversation
Reset security
Sign out
```

Low-impact operations should not require confirmation.

---

# 117. Destructive Actions

Destructive actions should be visually distinct using Material 3 error roles.

Example:

```dart
FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: colorScheme.error,
    foregroundColor: colorScheme.onError,
  ),
  onPressed: onDelete,
  child: const Text('Delete'),
)
```

---

# 118. Snackbar Usage

Use Snackbar for transient events.

Examples:

```text
Message queued
Route changed
Settings saved
Device connected
Location sharing disabled
```

---

# 119. Persistent Banner Usage

Use banners for important persistent conditions.

Examples:

```text
Storage is nearly full
Update required
Security verification required
Offline
```

---

# 120. Progress Indicators

Use progress indicators for operations such as:

```text
Connecting
Synchronizing
Uploading
Downloading
Generating secure session
```

---

# 121. Network Connection Animation

Connection transitions may use subtle animations.

Example:

```text
Connecting...
   ↓
Connected
```

Avoid flashy network animations.

---

# 122. Privacy-First Defaults

Default settings should be conservative.

Examples:

```text
Location sharing:
OFF

Unknown auto-accept:
OFF

Trusted auto-accept:
ON

Voice quality:
Battery Saver

Storage:
Smart Mode

Theme:
System
```

---

# 123. Trust-First UX

When connecting to a new person/device:

```text
Unknown device

Not trusted

[ Verify ]
```

After verification:

```text
✓ Trusted device
```

---

# 124. Blocked State UX

If a user attempts to communicate with a blocked user:

```text
Communication unavailable

This user is blocked.
```

Do not reveal unnecessary information.

---

# 125. Group Block UX

In groups, blocked users should effectively disappear from the blocker's perspective.

The UI must not reveal:

* Their messages
* Their typing
* Their presence
* Their location
* Their reactions
* Their profile information

---

# 126. Group Message Layout

Messages from visible members:

```text
Ahmed
Let's meet at 8.

Rahim
Okay.
```

Messages belonging to a blocked member should not be rendered to the blocker.

---

# 127. Storage Transparency

Automatic deletion must never feel mysterious.

The dashboard should always be able to explain:

```text
What will be removed
When it will be removed
Why it will be removed
How much storage it affects
```

---

# 128. Update Transparency

Mandatory update should explain why.

Example:

```text
Update required

This version is no longer supported
because a newer secure communication
protocol is required.

Your local conversations will remain
on this device.

[ Update NEXORA ]
```

---

# 129. Data Preservation UX

Before application update:

```text
Your conversations and local files
will remain on this device.

Updating NEXORA does not delete
your local conversation history.
```

---

# 130. Final Design Direction

NEXORA should feel like:

```text
                    NEXORA
                       |
          +------------+------------+
          |                         |
       SIMPLE                     POWERFUL
          |                         |
          v                         v
     Easy to use             Advanced network
                             capabilities
          |                         |
          +------------+------------+
                       |
                       v
                  MATERIAL 3
                       |
        +--------------+--------------+
        |              |              |
      Privacy       Reliability     Adaptability
        |              |              |
        +--------------+--------------+
                       |
                       v
               Connect beyond
                  the network
```

---

# 131. Design Acceptance Criteria

The design baseline is considered complete when:

* [x] Material 3 is the primary design system.
* [x] Light theme is defined.
* [x] Dark theme is defined.
* [x] System theme is supported.
* [x] Responsive navigation is defined.
* [x] Phone layout is defined.
* [x] Tablet layout is defined.
* [x] Chat UI is defined.
* [x] Group UI is defined.
* [x] Call UI is defined.
* [x] PTT UI is defined.
* [x] Device management UI is defined.
* [x] Trust UI is defined.
* [x] Block UI is defined.
* [x] Location UI is defined.
* [x] Storage management UI is defined.
* [x] Smart storage explanation is defined.
* [x] Offline states are defined.
* [x] Network states are defined.
* [x] Route migration feedback is defined.
* [x] Security states are defined.
* [x] Mandatory update UI is defined.
* [x] Accessibility requirements are defined.
* [x] Localization requirements are defined.
* [x] RTL considerations are defined.
* [x] Dynamic/adaptive layouts are defined.
* [x] Progressive disclosure is defined.

---

# 132. Final Product Design Statement

NEXORA's design must never make the user understand the complexity of the underlying mesh network unless they explicitly want to.

The default experience should simply communicate:

> **"You're connected."**

The advanced experience can reveal:

> **"How you're connected, why this route was selected, how secure it is, and what happens when the network changes."**

The product should therefore combine:

**Material 3 + privacy + simplicity + network intelligence + offline resilience.**

---

# NEXORA

## Connect beyond the network

```
```
