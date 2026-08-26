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
}
