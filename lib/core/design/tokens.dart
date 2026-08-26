// core/design — tokens measured from design/screens/*.md (rule 2).
//
// Genesis only pulls the tokens the two wired screens (welcome, login)
// actually use. Later screens' tokens get added here as they're built —
// never invented ahead of a contract.
import 'package:flutter/material.dart';

/// Colours copied verbatim from design/screens/welcome.md and
/// design/screens/login.md's "Tokens this screen actually uses" tables.
class NexoraColors {
  NexoraColors._();

  // welcome.md
  static const welcomeBg = Color(0xFF0B1420); // approximated page background
  static const welcomeTextPrimary = Color(0xFFD3E4FE);
  static const welcomeTextAccent = Color(0xFFDAD7FF);
  static const welcomeHeading = Color(0xFFC3C0FF);
  static const welcomeSubheading = Color(0xFFCBDBF5);
  static const welcomeButtonBg = Color(0xFFF8F9FF);
  static const welcomeButtonText = Color(0xFF3C4043);
  static const welcomeGlow = Color(0x4D4F46E5); // rgba(79,70,229,0.3)

  // login.md
  static const loginBg = Color(0xFFEFF4FF);
  static const loginBrand = Color(0xFF3525CD);
  static const loginHeading = Color(0xFF0B1C30);
  static const loginBody = Color(0xFF464555);
  static const loginSurface = Color(0xFFF8F9FF);

  // devices.md — reuses loginHeading/loginBody/loginBrand/welcomeHeading
  // where the measured value is identical (see "Tokens this screen
  // actually uses"); only the values not already named above are added
  // here.
  static const devicesHeaderBg = Color(0xFF213145); // rgb(33,49,69)
  static const devicesMuted = Color(0xFF777587); // rgb(119,117,135)
  static const devicesAllowedBlue = Color(0xFF89CEFF); // rgb(137,206,255)
  static const devicesBlockedRed = Color(0xFFBA1A1A); // rgb(186,26,26)
  static const devicesTrustedGreen = Color(0xFF4EDEA3); // rgb(78,222,163)
  static const devicesUnknownAmber = Color(0xFFF59E0B); // rgb(245,158,11)
  static const devicesActiveNavBg = Color(0xFF4F46E5); // rgb(79,70,229)
  static const devicesRowBorder = Color(0x1AC7C4D8); // rgba(199,196,216,0.1)
  static const devicesRowFill = Color(0x1AEFF4FF); // rgba(239,244,255,0.1)
  // Review fix (E02-T02, F1): the 40x40 tinted circular backdrop behind
  // each row's leading icon — dropped in the first pass. One per state,
  // measured from design/golden/devices/default@390x844/probe.json
  // elements 10/20/30/40 (not all four made it into the token table above
  // since it only lists the highest-count values; these are exact anyway).
  static const devicesIconBackdropTrusted = Color(0x334F46E5); // rgba(79,70,229,0.2)
  static const devicesIconBackdropAllowed = Color(0x3339B8FD); // rgba(57,184,253,0.2)
  static const devicesIconBackdropUnknown = Color(0x33D3E4FE); // rgba(211,228,254,0.2)
  static const devicesIconBackdropBlocked = Color(0x33FFDAD6); // rgba(255,218,214,0.2)
}

class NexoraTextStyles {
  NexoraTextStyles._();

  static const welcomeHeading = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w600,
    color: NexoraColors.welcomeHeading,
  );

  static const welcomeSubheading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: NexoraColors.welcomeSubheading,
  );

  static const welcomeBody = TextStyle(
    fontSize: 14,
    color: NexoraColors.welcomeTextPrimary,
  );

  static const welcomeCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: NexoraColors.welcomeTextPrimary,
  );

  static const buttonLabel = TextStyle(
    fontSize: 16,
    color: NexoraColors.welcomeButtonText,
  );

  static const loginBrandLabel = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: NexoraColors.loginBrand,
  );

  static const loginHeading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: NexoraColors.loginHeading,
  );

  static const loginBody = TextStyle(
    fontSize: 14,
    color: NexoraColors.loginBody,
  );

  // devices.md
  static const devicesBrandTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: NexoraColors.welcomeHeading,
  );

  static const devicesSectionHeading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: NexoraColors.loginHeading,
  );

  static const devicesSectionSubtitle = TextStyle(
    fontSize: 14,
    color: NexoraColors.loginBody,
  );

  static const devicesDiscoverLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static const devicesDeviceName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: NexoraColors.loginHeading,
  );

  static const devicesDeviceSubtitle = TextStyle(
    fontSize: 11,
    color: NexoraColors.loginBody,
  );

  static const devicesBadgeLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const devicesLastSeen = TextStyle(
    fontSize: 11,
    color: NexoraColors.loginBody,
  );

  static const devicesVerifyLabel = TextStyle(
    fontSize: 11,
    color: NexoraColors.loginBrand,
  );

  static const devicesNavLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: NexoraColors.loginBody,
  );

  static const devicesNavLabelActive = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: NexoraColors.welcomeTextAccent,
  );
}
