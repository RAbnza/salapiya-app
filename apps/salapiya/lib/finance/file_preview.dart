import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';

/// How large a preview is drawn: most of the window on Windows, and the
/// dialog's full width on a phone, with room left for its title and buttons.
({double width, double height}) previewSize(BuildContext context) {
  final window = MediaQuery.sizeOf(context);
  return isDesktop(context)
      ? (
          width: window.width * 0.8 < Space.dialogMaxWidth
              ? Space.dialogMaxWidth
              : window.width * 0.8,
          height: window.height * 0.6,
        )
      : (width: window.width, height: window.height * 0.5);
}

/// An image with zoom: pinch or wheel it, or use the buttons. It starts fitted
/// to the space, and at 100% it can't be moved off it.
class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.bytes,
    required this.decodeWidth,
    required this.height,
    this.problem,
  });
  final Uint8List bytes;

  /// Decoded no wider than this, so a huge image can't exhaust memory.
  final int decodeWidth;
  final double height;

  /// What went wrong opening it elsewhere, shown here over the dimmed page.
  final ValueListenable<String?>? problem;
  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  static const minimum = 1.0, maximum = 8.0, step = 1.5;
  final view = TransformationController();
  Size area = Size.zero;

  double get scale => view.value.getMaxScaleOnAxis();

  @override
  void dispose() {
    view.dispose();
    super.dispose();
  }

  /// Zooms about the middle of the space, so what's in view stays there.
  void zoom(double by) {
    final next = (scale * by).clamp(minimum, maximum);
    if (next == minimum) {
      view.value = Matrix4.identity();
      return;
    }
    final factor = next / scale;
    final middle = area.center(Offset.zero);
    view.value =
        Matrix4.translationValues(middle.dx, middle.dy, 0) *
        Matrix4.diagonal3Values(factor, factor, 1) *
        Matrix4.translationValues(-middle.dx, -middle.dy, 0) *
        view.value;
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.problem case final problem?)
          ValueListenableBuilder<String?>(
            valueListenable: problem,
            builder: (context, words, _) => words == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: InlineNotice(
                      words,
                      key: const ValueKey('preview-problem'),
                      tone: NoticeTone.warning,
                    ),
                  ),
          ),
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.controlOf(context)),
            child: ColoredBox(
              color: c.subtle,
              child: LayoutBuilder(
                builder: (context, box) {
                  area = box.biggest;
                  return InteractiveViewer(
                    key: const ValueKey('preview-image'),
                    transformationController: view,
                    minScale: minimum,
                    maxScale: maximum,
                    child: Center(
                      child: Image.memory(
                        widget.bytes,
                        cacheWidth: widget.decodeWidth,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) =>
                            const Text('This image can’t be shown here.'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
        ListenableBuilder(
          listenable: view,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconButton(
                key: const ValueKey('preview-zoom-out'),
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onPressed: scale <= minimum ? null : () => zoom(1 / step),
              ),
              const SizedBox(width: Space.sm),
              Text(
                '${(scale * 100).round()}%',
                key: const ValueKey('preview-zoom-level'),
                style: text.bodySmall?.copyWith(
                  color: c.secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: Space.sm),
              AppIconButton(
                key: const ValueKey('preview-zoom-in'),
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: scale >= maximum ? null : () => zoom(step),
              ),
              const SizedBox(width: Space.xs),
              AppIconButton(
                key: const ValueKey('preview-zoom-fit'),
                icon: Icons.fit_screen_outlined,
                tooltip: 'Fit to the space',
                onPressed: scale <= minimum
                    ? null
                    : () => view.value = Matrix4.identity(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
