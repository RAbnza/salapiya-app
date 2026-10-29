import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Tokens for the redesign. docs/DESIGN_SYSTEM.md §3 names each one and its
// use; widgets read them here and never write their own literals.

/// Width classes from §2. At text scale 150% or more, drop one class.
enum WidthClass {
  compact,
  medium,
  expanded,
  wide;

  static WidthClass forWidth(double width, {double textScale = 1}) {
    final c = width < 600
        ? compact
        : width < 1000
        ? medium
        : width < 1440
        ? expanded
        : wide;
    return textScale >= 1.5 && c != compact ? values[c.index - 1] : c;
  }

  static WidthClass of(BuildContext context) => forWidth(
    MediaQuery.sizeOf(context).width,
    textScale: MediaQuery.textScalerOf(context).scale(16) / 16,
  );
}

/// The Windows compact scale (§3, Windows density). Pointer platforms
/// (Windows, macOS, Linux) are compact; touch platforms keep the full scale.
abstract final class Density {
  static bool isCompact(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
    _ => true,
  };

  /// Reads the theme's platform, so tests and the gallery can switch it.
  static bool of(BuildContext context) => isCompact(Theme.of(context).platform);
}

abstract final class Space {
  static const double xxs = 2, xs = 4, sm = 8, md = 12, lg = 16, xl = 24;
  static const double xxl = 32, xxxl = 48;
  static const double target = 48, paneInset = 8, titleBarHeight = 40;

  /// Control height where input is pointer-only (Windows): buttons, fields,
  /// segmented controls and icon buttons.
  static const double pointerTarget = xxl;

  /// List rows on Windows: one line and two lines (Android: 48 and 56).
  static const double compactRow = navItem, compactTwoLineRow = target;

  /// Icons on Windows: standalone, and inside controls and rows.
  static const double compactIcon = lg + xxs, compactControlIcon = lg;
  static const double formMaxWidth = 640, reviewMaxWidth = 760;
  static const double contentMaxWidth = 1280;
  static const double fieldGap = lg, labelGap = sm, helperGap = xs;
  static const double groupGap = xl, actionsGap = xl;
  static const double cardHeaderGap = md, captionGap = xs;
  static const double dialogPadding = xl, dialogTitleGap = md;
  static const double dialogMaxWidth = 560, popoverMaxWidth = 320;

  /// App shell: the Windows sidebar's width as a rail and expanded, and the
  /// Android dock's width.
  static const double railWidth = 64, sidebarWidth = 224, dockMaxWidth = 480;

  /// Windows sidebar metrics (compact pointer navigation, sized after
  /// Windows 11 navigation and the owner's references): item and tab row
  /// heights, icon, avatar, search box and collapse-handle sizes.
  static const double navItem = 36, navTab = 32, navIcon = lg;
  static const double navAvatar = 28, navSearch = xxl;

  /// The rail's square buttons, and the rail flyout's offset from them.
  static const double navRailButton = xxl + sm;

  /// The Windows app bar over the content, and the sidebar's logo row that
  /// lines up with it. Both sit below the title bar.
  static const double appBarHeight = target + sm;

  /// The Go to field, centered in the Windows title bar.
  static const double goToWidth = popoverMaxWidth;
  static const pillPadding = EdgeInsets.symmetric(horizontal: 10, vertical: xs);
  static double pageGutter(WidthClass w) => switch (w) {
    WidthClass.compact => lg,
    WidthClass.medium || WidthClass.expanded => xl,
    WidthClass.wide => xxl,
  };
  static double pageTop(WidthClass w) => w == WidthClass.compact ? lg : xl;
  static double headerGap(WidthClass w) => pageTop(w);
  static double sectionGap(WidthClass w) => w == WidthClass.compact ? xl : xxl;

  /// Compact pages add the dock height to this.
  static double pageBottom(WidthClass w) => w == WidthClass.compact ? xl : xxl;

  /// Card gap and padding. Windows ([dense]) keeps the compact-width values
  /// at every width.
  static double cardGap(WidthClass w, {bool dense = false}) =>
      dense || w == WidthClass.compact ? md : lg;
  static double cardPadding(WidthClass w, {bool dense = false}) =>
      dense || w == WidthClass.compact ? lg : 20;
  static double cardGapOf(BuildContext context) =>
      cardGap(WidthClass.of(context), dense: Density.of(context));
  static double cardPaddingOf(BuildContext context) =>
      cardPadding(WidthClass.of(context), dense: Density.of(context));

  // Legacy aliases kept for existing screens; new code uses Radii and Motion.
  static const double cardRadius = Radii.card, controlRadius = Radii.control;
  static const double floatingRadius = 28;
  static const menuDuration = Motion.short;
}

/// The Windows sidebar's label size: 13 / 18, a step between `bodySmall`
/// and `bodyMedium`, as Windows 11 navigation uses. Tabs use `bodySmall`.
abstract final class NavType {
  static TextStyle? label(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium
          ?.copyWith(fontSize: 13, height: 18 / 13);
}

/// Windows 11 caption buttons: OS geometry and glyphs (Segoe Fluent Icons,
/// with Segoe MDL2 Assets on Windows 10). §4 allows these OS values here.
abstract final class CaptionButtons {
  static const double width = 46;
  static const minimize = '\uE921', maximize = '\uE922';
  static const restore = '\uE923', close = '\uE8BB';
  static const glyph = TextStyle(
    fontFamily: 'Segoe Fluent Icons',
    fontFamilyFallback: ['Segoe MDL2 Assets'],
    fontSize: 10,
    height: 1,
  );
}

abstract final class Radii {
  static const double control = 10, card = 14, overlay = 20, pill = 999;

  /// Windows' tighter corners for controls, cards and overlays.
  static const double compactControl = 6, compactCard = 10;
  static const double compactOverlay = 12;

  /// Dense navigation: the sidebar's highlights, profile card and Go to box.
  static const double nav = compactControl;

  static double controlFor(bool dense) => dense ? compactControl : control;
  static double cardFor(bool dense) => dense ? compactCard : card;
  static double overlayFor(bool dense) => dense ? compactOverlay : overlay;
  static double controlOf(BuildContext context) =>
      controlFor(Density.of(context));
  static double cardOf(BuildContext context) => cardFor(Density.of(context));
  static double overlayOf(BuildContext context) =>
      overlayFor(Density.of(context));
}

abstract final class Motion {
  static const quick = Duration(milliseconds: 100);
  static const short = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 200);
  static const Curve enter = Curves.easeOutCubic, exit = Curves.easeInCubic;

  /// [duration], or zero when reduced motion is on.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Legacy raw colors. Screens still reference these directly; section chats
/// replace those uses with [CraftTheme] roles.
abstract final class Palette {
  static const porcelain = Color(0xFFF3F4F6), midnight = Color(0xFF14151A);
  static const violet = Color(0xFF6546A3), lavender = Color(0xFFCABDFA);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF222126), lilac = Color(0xFFD9CEF8);
  static const mint = Color(0xFFD9E8BC), peach = Color(0xFFF5D1BC);
}

enum NoticeTone { neutral, information, success, warning, error }

@immutable
class CraftTheme extends ThemeExtension<CraftTheme> {
  const CraftTheme({required this.dark, this.highContrast = false});
  final bool dark, highContrast;

  // Neutrals and surfaces.
  Color get canvas => dark ? const Color(0xFF131318) : const Color(0xFFF4F4F7);
  Color get surface => dark ? const Color(0xFF1C1C23) : Palette.white;
  Color get raised => dark ? const Color(0xFF25242D) : Palette.white;
  Color get subtle => dark ? const Color(0xFF2A2932) : const Color(0xFFEFEEF3);
  Color get text => dark ? const Color(0xFFF2F1F5) : const Color(0xFF1D1B22);
  Color get secondary => highContrast
      ? text
      : dark
      ? const Color(0xFFB9B7C3)
      : const Color(0xFF5E5C68);
  Color get border => highContrast
      ? text
      : dark
      ? const Color(0xFF8D8B99)
      : const Color(0xFF7A7886);
  Color get divider => highContrast
      ? text
      : dark
      ? const Color(0xFF35343E)
      : const Color(0xFFE4E3EA);

  // Brand.
  Color get primary => dark ? Palette.lavender : Palette.violet;
  Color get onPrimary => dark ? const Color(0xFF1E1730) : Palette.white;
  Color get hover => dark ? const Color(0xFFD7CDFB) : const Color(0xFF573A91);
  Color get pressed => dark ? const Color(0xFFBBABF3) : const Color(0xFF4A2F7E);
  Color get selection =>
      dark ? const Color(0xFF30284A) : const Color(0xFFEEE9F8);
  Color get onSelection =>
      dark ? const Color(0xFFDDD3FC) : const Color(0xFF4A2F7E);
  Color get focus => primary;
  Color get modalScrim => Colors.black.withValues(alpha: dark ? .64 : .44);

  // Status pairs: foreground on its tinted surface.
  (Color, Color) tone(NoticeTone tone) => switch (tone) {
    NoticeTone.neutral => (secondary, subtle),
    NoticeTone.information => _status(
      const Color(0xFF235EA7),
      const Color(0xFFEDF4FF),
      const Color(0xFF9AC5FF),
      const Color(0xFF19283B),
    ),
    NoticeTone.success => _status(
      const Color(0xFF146C43),
      const Color(0xFFEDF8F1),
      const Color(0xFF75D5A5),
      const Color(0xFF142B22),
    ),
    NoticeTone.warning => _status(
      const Color(0xFF8A4B0F),
      const Color(0xFFFFF4DF),
      const Color(0xFFF3C16B),
      const Color(0xFF312716),
    ),
    NoticeTone.error => _status(
      const Color(0xFFB42318),
      const Color(0xFFFFF0ED),
      const Color(0xFFFDA29B),
      const Color(0xFF371D22),
    ),
  };
  (Color, Color) get overdue => _status(
    const Color(0xFFA1173F),
    const Color(0xFFFDEEF2),
    const Color(0xFFFF9DB6),
    const Color(0xFF3A1A26),
  );
  (Color, Color) get owedToYou => _status(
    const Color(0xFF0E6A63),
    const Color(0xFFE6F5F2),
    const Color(0xFF6FD3C7),
    const Color(0xFF102E2B),
  );
  (Color, Color) _status(Color fg, Color bg, Color darkFg, Color darkBg) =>
      (dark ? darkFg : fg, highContrast ? surface : (dark ? darkBg : bg));

  // Chart series, in order: violet, teal, plum, ochre, blue, neutral.
  List<Color> get chartSeries => dark
      ? const [
          Color(0xFFCABDFA),
          Color(0xFF79C4D2),
          Color(0xFFE6BCD4),
          Color(0xFFE4C572),
          Color(0xFFA9BCFF),
          Color(0xFFB9B9C6),
        ]
      : const [
          Color(0xFF6546A3),
          Color(0xFF266C80),
          Color(0xFF9A4C72),
          Color(0xFF80631B),
          Color(0xFF395EB2),
          Color(0xFF59616F),
        ];

  // Windows title bar. Minimize and maximize use Windows 11's subtle fills
  // (text at 6% on hover, 4% pressed); high contrast fills with `text`.
  // Close is the OS convention, not the theme.
  Color get titleBar => canvas;
  Color get windowControlHover =>
      highContrast ? text : text.withValues(alpha: .06);
  Color get windowControlPressed =>
      highContrast ? text : text.withValues(alpha: .04);
  static const windowCloseHover = Color(0xFFC42B1C);
  static const windowClosePressed = Color(0xE6C42B1C);
  static const onWindowCloseHover = Palette.white;

  // Elevation: cards are level 1 (surface, divider hairline, no shadow);
  // overlays are level 2 (raised surface with this shadow).
  List<BoxShadow> get overlayShadow => dark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: .36),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ];
  List<BoxShadow> get shadow => overlayShadow;

  // Legacy craft accents, decorative only; section chats retire them.
  Color get warm => dark ? const Color(0xFFD9BE97) : const Color(0xFF82603A);
  Color get warmSurface => highContrast
      ? surface
      : dark
      ? const Color(0xFF30291F)
      : const Color(0xFFF5EEE5);
  Color get plum => dark ? const Color(0xFFF3B6EF) : const Color(0xFF80456F);
  Color get plumSurface => highContrast
      ? surface
      : dark
      ? const Color(0xFF38203F)
      : const Color(0xFFF4E5EE);
  Color get blue => dark ? const Color(0xFF8BDCFF) : const Color(0xFF245E87);
  Color get blueSurface => highContrast
      ? surface
      : dark
      ? const Color(0xFF132C45)
      : const Color(0xFFE5F1FA);
  Color get focalStart =>
      dark ? const Color(0xFF302153) : const Color(0xFFEEE8FF);
  Color get focalEnd =>
      dark ? const Color(0xFF142C49) : const Color(0xFFE1EFFF);
  Color get latticeEdge => Color.lerp(divider, primary, .28)!;

  static CraftTheme of(BuildContext context) =>
      Theme.of(context).extension<CraftTheme>()!;
  @override
  CraftTheme copyWith({bool? dark, bool? highContrast}) => CraftTheme(
    dark: dark ?? this.dark,
    highContrast: highContrast ?? this.highContrast,
  );
  @override
  CraftTheme lerp(covariant CraftTheme? other, double t) =>
      t < .5 ? this : other ?? this;
}

class CraftPreferences extends InheritedWidget {
  const CraftPreferences({
    super.key,
    required this.effects,
    required super.child,
  });
  final bool effects;
  static bool effectsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CraftPreferences>()?.effects ??
      true;
  @override
  bool updateShouldNotify(CraftPreferences oldWidget) =>
      effects != oldWidget.effects;
}

abstract final class SalapiyaTheme {
  /// [platform] defaults to the running one. Windows (and the other pointer
  /// platforms) get the compact scale from §3; Android keeps the full one.
  static ThemeData build(
    Brightness brightness, {
    bool highContrast = false,
    TargetPlatform? platform,
  }) {
    platform ??= defaultTargetPlatform;
    final dense = Density.isCompact(platform);
    final c = CraftTheme(
      dark: brightness == Brightness.dark,
      highContrast: highContrast,
    );
    // Controls are 32 tall where input is pointer-only, 48 where it is touch.
    const target = Space.target;
    final controlHeight = dense ? Space.pointerTarget : target;
    // Size and line height in logical px; amounts use tabular figures.
    TextStyle type(
      double size,
      double line,
      FontWeight weight, {
      double tracking = 0,
      bool amount = false,
    }) => TextStyle(
      fontFamily: 'Geist',
      fontSize: size,
      fontWeight: weight,
      height: line / size,
      letterSpacing: tracking,
      color: c.text,
      fontFeatures: amount ? const [FontFeature.tabularFigures()] : null,
    );
    // Android's size and line height, then Windows' one step down.
    TextStyle role(
      (double, double) full,
      (double, double) compact,
      FontWeight weight, {
      double tracking = 0,
      bool amount = false,
    }) {
      final (size, line) = dense ? compact : full;
      return type(size, line, weight, tracking: tracking, amount: amount);
    }

    final textTheme = TextTheme(
      displayLarge: role((45, 52), (40, 48), FontWeight.w600, amount: true),
      displayMedium: role((36, 44), (32, 40), FontWeight.w600, amount: true),
      displaySmall: role((28, 36), (24, 32), FontWeight.w600, amount: true),
      headlineLarge: role((32, 40), (28, 36), FontWeight.w600),
      headlineMedium: role((24, 32), (20, 28), FontWeight.w600),
      headlineSmall: role((20, 28), (18, 24), FontWeight.w600),
      titleLarge: role((18, 26), (16, 22), FontWeight.w600),
      titleMedium: role((16, 24), (14, 20), FontWeight.w600),
      titleSmall: role((14, 20), (13, 18), FontWeight.w600),
      bodyLarge: role((16, 24), (14, 20), FontWeight.w400),
      bodyMedium: role((14, 20), (13, 18), FontWeight.w400),
      bodySmall: type(12, 16, FontWeight.w400),
      labelLarge: role((14, 20), (13, 18), FontWeight.w600),
      labelMedium: type(12, 16, FontWeight.w500),
      labelSmall: role((11, 16), (11, 14), FontWeight.w600, tracking: .6),
    );
    final controlRadius = Radii.controlFor(dense);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(controlRadius),
      borderSide: BorderSide(color: c.border),
    );
    final (error, errorSurface) = c.tone(NoticeTone.error);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.selection,
      onPrimaryContainer: c.onSelection,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.selection,
      onSecondaryContainer: c.onSelection,
      tertiary: c.primary,
      onTertiary: c.onPrimary,
      error: error,
      onError: c.surface,
      errorContainer: errorSurface,
      onErrorContainer: error,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.secondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.raised,
      surfaceContainerHigh: c.raised,
      surfaceContainerHighest: c.subtle,
      outline: c.border,
      outlineVariant: c.divider,
      inverseSurface: c.text,
      onInverseSurface: c.surface,
      inversePrimary: c.dark ? Palette.violet : Palette.lavender,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
    final overlayRadius = Radii.overlayFor(dense);
    final overlayShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(overlayRadius),
    );
    final controlShape = WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(controlRadius),
      ),
    );
    // Icons inside buttons and segmented controls; Android keeps the default.
    final controlIcon = dense
        ? const WidgetStatePropertyAll(Space.compactControlIcon)
        : null;
    ButtonStyle button({bool filled = false}) => ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(target, controlHeight)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: dense ? Space.md : Space.lg,
          vertical: dense ? Space.xs + Space.xxs : Space.md,
        ),
      ),
      shape: controlShape,
      iconSize: controlIcon,
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? c.secondary
            : filled
            ? c.onPrimary
            : c.primary,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? c.subtle
            : !filled
            ? null
            : s.contains(WidgetState.pressed)
            ? c.pressed
            : s.contains(WidgetState.hovered)
            ? c.hover
            : c.primary,
      ),
      side: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused)
            ? BorderSide(color: filled ? c.onPrimary : c.focus, width: 2)
            : null,
      ),
    );
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      platform: platform,
      fontFamily: 'Geist',
      extensions: [c],
      textTheme: textTheme,
      // Standalone icons on Windows; Android keeps Flutter's default.
      iconTheme: dense
          ? IconThemeData(
              size: Space.compactIcon,
              color: c.dark ? kDefaultIconLightColor : kDefaultIconDarkColor,
            )
          : null,
      filledButtonTheme: FilledButtonThemeData(style: button(filled: true)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button().copyWith(
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.focused) ? c.focus : c.border,
              width: s.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: button()),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size.square(dense ? Space.pointerTarget : target),
          ),
          padding: dense ? const WidgetStatePropertyAll(EdgeInsets.zero) : null,
          iconSize: dense
              ? const WidgetStatePropertyAll(Space.compactIcon)
              : null,
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.secondary : c.primary,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused)
                ? BorderSide(color: c.focus, width: 2)
                : null,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(target, controlHeight)),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          iconSize: controlIcon,
          shape: controlShape,
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? c.secondary
                : s.contains(WidgetState.selected)
                ? c.onSelection
                : c.text,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.selection : c.surface,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.focused) ? c.focus : c.border,
              width: s.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? c.secondary
              : s.contains(WidgetState.selected)
              ? c.primary
              : c.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? c.subtle
              : s.contains(WidgetState.selected)
              ? c.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: WidgetStateBorderSide.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? null
              : BorderSide(color: c.border, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.border,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.subtle,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.border,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.subtle : c.surface,
        ),
        hoverColor: Colors.transparent,
        border: outline,
        enabledBorder: WidgetStateInputBorder.resolveWith(
          (s) => s.contains(WidgetState.hovered)
              ? outline.copyWith(borderSide: BorderSide(color: c.text))
              : outline,
        ),
        disabledBorder: outline.copyWith(
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: c.focus, width: 2),
        ),
        errorBorder: outline.copyWith(borderSide: BorderSide(color: error)),
        focusedErrorBorder: outline.copyWith(
          borderSide: BorderSide(color: error, width: 2),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: dense
            ? const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.xs + Space.xxs,
              )
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        isDense: dense,
        // Without these, a prefix or suffix icon makes a field 48 tall.
        prefixIconConstraints: dense
            ? const BoxConstraints(
                minWidth: Space.pointerTarget + Space.xs,
                minHeight: Space.pointerTarget,
              )
            : null,
        suffixIconConstraints: dense
            ? const BoxConstraints(
                minWidth: Space.pointerTarget + Space.xs,
                minHeight: Space.pointerTarget,
              )
            : null,
        helperMaxLines: 4,
        errorMaxLines: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.selection,
        side: BorderSide(color: c.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        labelStyle: type(12, 16, FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.cardFor(dense)),
          side: BorderSide(color: c.divider),
        ),
      ),
      listTileTheme: ListTileThemeData(dense: dense, iconColor: c.secondary),
      dividerTheme: DividerThemeData(color: c.divider, space: Space.xl),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.subtle,
        circularTrackColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.raised,
        surfaceTintColor: Colors.transparent,
        shape: overlayShape,
        barrierColor: c.modalScrim,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.raised,
        surfaceTintColor: Colors.transparent,
        shape: overlayShape,
        headerForegroundColor: c.text,
        dividerColor: c.divider,
        todayBorder: BorderSide(color: c.primary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.raised,
        modalBarrierColor: c.modalScrim,
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(overlayRadius),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.raised,
        surfaceTintColor: Colors.transparent,
        shape: overlayShape,
        textStyle: textTheme.bodyMedium,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.raised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(overlayShape),
        ),
      ),
      // Menu items are rows: 36 tall with 16 icons on Windows.
      menuButtonTheme: dense
          ? MenuButtonThemeData(
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(
                  Size(Space.xxxl + Space.lg, Space.compactRow),
                ),
                iconSize: controlIcon,
              ),
            )
          : null,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.text,
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        textStyle: type(12, 16, FontWeight.w400).copyWith(color: c.surface),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.surface),
        actionTextColor: c.dark ? Palette.violet : Palette.lavender,
      ),
    );
  }
}
