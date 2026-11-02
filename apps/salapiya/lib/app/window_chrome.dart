import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/theme.dart';
import 'title_bar.dart';

/// Windows window chrome. With the runner's custom frame ([WindowFrame]),
/// it draws the title bar above every screen; otherwise the native caption
/// stays. It also keeps the native border and dark mode in step with the
/// theme.
class WindowChrome extends StatefulWidget {
  const WindowChrome({super.key, required this.popups, required this.child});

  /// The root navigator's popups, which make the bar's app controls inert.
  final PopupRouteTracker popups;
  final Widget child;
  @override
  State<WindowChrome> createState() => _WindowChromeState();
}

class _WindowChromeState extends State<WindowChrome> {
  final bar = TitleBarController();
  List<Object>? last;

  bool get custom =>
      WindowFrame.enabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    final c = CraftTheme.of(context);
    final args = <Object>[
      c.dark,
      c.titleBar.toARGB32() & 0xffffff,
      c.text.toARGB32() & 0xffffff,
      c.divider.toARGB32() & 0xffffff,
    ];
    if (listEquals(last, args)) return;
    last = args;
    unawaited(apply(args));
  }

  Future<void> apply(List<Object> args) async {
    try {
      await WindowFrame.channel.invokeMethod<void>('theme', args);
    } on MissingPluginException {
      // Widget tests and older runners retain the ordinary OS frame.
    } on PlatformException {
      // Unsupported DWM color attributes must not prevent app startup.
    }
  }

  @override
  void dispose() {
    bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!custom) return widget.child;
    // The bar's own overlay holds its tooltips, above the app's navigator.
    return TitleBarScope(
      controller: bar,
      child: Overlay.wrap(
        child: Column(
          children: [
            TitleBar(controller: bar, popups: widget.popups),
            // A route's modal barrier hides everything painted before it from
            // screen readers, up to the nearest container; this keeps the bar.
            Expanded(child: Semantics(container: true, child: widget.child)),
          ],
        ),
      ),
    );
  }
}
