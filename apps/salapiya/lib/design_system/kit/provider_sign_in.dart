import 'package:flutter/material.dart';

import '../theme.dart';
import 'focus_ring.dart';

// Provider buttons follow the provider's own branding, not the Salapiya theme
// (§1.11). They show the provider's official button artwork, unmodified;
// this file is the one place for provider-branding values (the §4 exception).

enum ProviderButtonTheme { light, dark, neutral }

enum ProviderButtonShape { rectangular, pill }

/// A provider's official sign-in button artwork: one image per theme and
/// shape, at 1x–4x, in `assetDirectory` as `<theme>_<square|pill>.png`.
@immutable
class ProviderBrand {
  const ProviderBrand({
    required this.name,
    required this.label,
    required this.assetDirectory,
    required this.size,
    required this.rectangularRadius,
    required this.lightInk,
    required this.darkInk,
    required this.neutralInk,
  });
  final String name, label, assetDirectory;

  /// Logical size of the artwork; it is never scaled or stretched.
  final Size size;
  final double rectangularRadius;

  /// The label color of each theme, used for hover and press state layers.
  final Color lightInk, darkInk, neutralInk;

  String asset(ProviderButtonTheme theme, ProviderButtonShape shape) =>
      '$assetDirectory/${theme.name}_'
      '${shape == ProviderButtonShape.pill ? 'pill' : 'square'}.png';

  Color ink(ProviderButtonTheme theme) => switch (theme) {
    ProviderButtonTheme.light => lightInk,
    ProviderButtonTheme.dark => darkInk,
    ProviderButtonTheme.neutral => neutralInk,
  };
}

abstract final class ProviderBrands {
  /// Google Identity branding guidelines, checked 2026-10-29:
  /// https://developers.google.com/identity/branding-guidelines
  /// Artwork: the "Android + Web" PNGs from Google's signin-assets.zip
  /// (Show text=Yes), copied unmodified and renamed for Flutter's 2.0x–4.0x
  /// variants. The label is part of the artwork, so no font is bundled.
  static const google = ProviderBrand(
    name: 'Google',
    label: 'Sign in with Google',
    assetDirectory: 'assets/branding/providers/google/buttons',
    size: Size(180, 40),
    rectangularRadius: 4,
    lightInk: Color(0xFF1F1F1F),
    darkInk: Color(0xFFE3E3E3),
    neutralInk: Color(0xFF1F1F1F),
  );
}

/// A third-party sign-in button showing the provider's official artwork.
/// Add a provider by adding a [ProviderBrand]. The theme follows the app's
/// brightness unless [theme] is given.
class ProviderSignInButton extends StatelessWidget {
  const ProviderSignInButton({
    super.key,
    required this.brand,
    required this.onPressed,
    this.theme,
    this.shape = ProviderButtonShape.rectangular,
    this.busy = false,
  });
  final ProviderBrand brand;
  final VoidCallback? onPressed;
  final ProviderButtonTheme? theme;
  final ProviderButtonShape shape;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final variant =
        theme ??
        (CraftTheme.of(context).dark
            ? ProviderButtonTheme.dark
            : ProviderButtonTheme.light);
    final enabled = onPressed != null && !busy;
    final radius = shape == ProviderButtonShape.pill
        ? brand.size.height / 2
        : brand.rectangularRadius;
    // The artwork stays 40 tall; on touch platforms the margin around it
    // still counts as the button, so the target is 48.
    return Semantics(
      container: true,
      onTap: enabled ? onPressed : null,
      button: true,
      enabled: enabled,
      label: brand.label,
      hint: busy ? 'Working' : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: hitTarget(context)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: onPressed == null ? .38 : 1,
                child: Pressable(
                  onTap: enabled ? onPressed : null,
                  radius: radius,
                  hoverColor: brand.ink(variant).withValues(alpha: .10),
                  overlay: true,
                  child: Image.asset(
                    brand.asset(variant, shape),
                    width: brand.size.width,
                    height: brand.size.height,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              if (busy) ...[
                const SizedBox(width: Space.sm),
                SizedBox.square(
                  dimension: Space.lg + Space.xs,
                  child: CircularProgressIndicator(
                    strokeWidth: Space.xxs,
                    color: CraftTheme.of(context).secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Google's official "Sign in with Google" button. The bundle has no other
/// label, so "Continue with" and "Sign up with" are not offered.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.theme,
    this.shape = ProviderButtonShape.rectangular,
    this.busy = false,
  });
  final VoidCallback? onPressed;
  final ProviderButtonTheme? theme;
  final ProviderButtonShape shape;
  final bool busy;
  @override
  Widget build(BuildContext context) => ProviderSignInButton(
    brand: ProviderBrands.google,
    onPressed: onPressed,
    theme: theme,
    shape: shape,
    busy: busy,
  );
}
