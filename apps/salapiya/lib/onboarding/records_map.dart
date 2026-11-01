import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';

/// Which way of starting the map is showing.
enum RecordsView { local, google, chosen, restore, restoreConnected }

/// The places a person's records can be.
enum RecordsPlace { device, service, google, backup }

/// One place in one view. [lit] means records are there or going there.
class PlaceFacts {
  const PlaceFacts(this.lit, this.holds);
  final bool lit;

  /// What this place holds, in a few words.
  final String holds;
}

const _unused = PlaceFacts(false, 'Not used');
const _everything = PlaceFacts(true, 'Your records, files and drafts');
const _maybeBackup = PlaceFacts(false, 'Only if you save one');

/// What each place holds in [view]. Only what's true of that way of starting.
Map<RecordsPlace, PlaceFacts> recordsPlaces(RecordsView view) => switch (view) {
  RecordsView.local => const {
    RecordsPlace.device: _everything,
    RecordsPlace.service: _unused,
    RecordsPlace.google: _unused,
    RecordsPlace.backup: _maybeBackup,
  },
  RecordsView.google => const {
    RecordsPlace.device: _everything,
    RecordsPlace.service: PlaceFacts(true, 'Your records and file list'),
    RecordsPlace.google: PlaceFacts(true, 'Confirms who you are'),
    RecordsPlace.backup: _maybeBackup,
  },
  RecordsView.chosen => const {
    RecordsPlace.device: _everything,
    RecordsPlace.service: PlaceFacts(false, 'Knows this device’s type'),
    RecordsPlace.google: PlaceFacts(true, 'Knows you signed in'),
    RecordsPlace.backup: _maybeBackup,
  },
  RecordsView.restore => const {
    RecordsPlace.device: PlaceFacts(true, 'Your records come back here'),
    RecordsPlace.service: _unused,
    RecordsPlace.google: _unused,
    RecordsPlace.backup: PlaceFacts(true, 'Stays where it is'),
  },
  RecordsView.restoreConnected => const {
    RecordsPlace.device: PlaceFacts(true, 'Your records come back here'),
    RecordsPlace.service: PlaceFacts(false, 'Checks it after you sign in'),
    RecordsPlace.google: PlaceFacts(false, 'Confirms who you are'),
    RecordsPlace.backup: PlaceFacts(true, 'Stays where it is'),
  },
};

/// The map in one sentence. Screen readers hear this, so it says everything
/// the picture does.
String recordsWords(RecordsView view, {required bool desktop}) =>
    switch (view) {
      RecordsView.local =>
        'Your records stay on this device unless you choose to connect.',
      RecordsView.google =>
        'Your records would sync through Salapiya’s service. Google only '
            'confirms who you are. File contents stay on this device.',
      RecordsView.chosen =>
        'Google knows you signed in. Salapiya’s service knows this is '
            '${desktop ? 'a Windows' : 'an Android'} device. No records have '
            'left this device.',
      RecordsView.restore =>
        'Your backup opens on this device. Nothing goes online.',
      RecordsView.restoreConnected =>
        'After you sign in, it’s checked against your connected account.',
    };

/// One line under the picture. The places say the rest; [recordsWords] is what
/// a screen reader hears in full.
String recordsCaption(RecordsView view) => switch (view) {
  RecordsView.local => 'Your records stay here unless you choose to connect.',
  RecordsView.google => 'Your records would sync through Salapiya’s service.',
  RecordsView.chosen => 'No records have left this device.',
  RecordsView.restore =>
    'Your backup opens on this device. Nothing goes online.',
  RecordsView.restoreConnected =>
    'After you sign in, it’s checked against your account.',
};

String _placeName(RecordsPlace place) => switch (place) {
  RecordsPlace.device => 'This device',
  RecordsPlace.service => 'Salapiya’s service',
  RecordsPlace.google => 'Google',
  RecordsPlace.backup => 'Backup file',
};

/// The map in its card, beside a first-run step.
Widget recordsCard(RecordsView view) => OverviewCard(
  key: const ValueKey('records-map'),
  title: 'Where your records live',
  fill: true,
  child: RecordsMap(view: view),
);

/// Where a person's records would live for each way of starting. A lit place
/// on a solid line holds them; a quiet one on a dashed line doesn't, and every
/// place says so in words, so nothing rests on color.
class RecordsMap extends StatelessWidget {
  const RecordsMap({super.key, required this.view, this.slim = false});
  final RecordsView view;

  /// One row, for the top of a phone's page.
  final bool slim;
  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final places = recordsPlaces(view);
    final style = text.bodySmall?.copyWith(color: c.secondary);
    // The longest line holds the height, so nothing moves as the view changes.
    final caption = Stack(
      children: [
        Opacity(
          opacity: 0,
          child: Text(
            recordsCaption(RecordsView.restore),
            style: style,
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.topLeft,
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.short),
              child: Text(
                recordsCaption(view),
                key: ValueKey(view),
                style: style,
              ),
            ),
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      label: recordsWords(view, desktop: desktop),
      excludeSemantics: true,
      child: slim
          // Large text leaves the circles' labels no room, and the sentence
          // says everything they do.
          ? MediaQuery.textScalerOf(context).scale(1) >= 1.5
                ? Text(recordsWords(view, desktop: desktop), style: style)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SlimMap(places: places),
                      const SizedBox(height: Space.md),
                      caption,
                    ],
                  )
          // A card's height reaches this only as a minimum. Taking it here
          // lets the lines between places grow, so the map fills the card.
          : LayoutBuilder(
              builder: (context, box) {
                final fill = box.minHeight > 0;
                final map = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._fullMap(context, places, fill: fill, desktop: desktop),
                    const SizedBox(height: Space.md),
                    caption,
                  ],
                );
                return fill
                    ? SizedBox(height: box.minHeight, child: map)
                    : map;
              },
            ),
    );
  }
}

IconData _icon(RecordsPlace place, {required bool desktop}) => switch (place) {
  RecordsPlace.device =>
    desktop ? Icons.laptop_windows_outlined : Icons.smartphone_outlined,
  RecordsPlace.service => Icons.cloud_outlined,
  RecordsPlace.google => Icons.badge_outlined,
  RecordsPlace.backup => Icons.description_outlined,
};

/// Google and the service above, this device in the middle, the backup below.
List<Widget> _fullMap(
  BuildContext context,
  Map<RecordsPlace, PlaceFacts> places, {
  required bool fill,
  required bool desktop,
}) {
  Widget place(RecordsPlace p) =>
      _Place(place: p, facts: places[p]!, desktop: desktop);
  Widget link(Widget child) => fill
      ? Expanded(child: child)
      : SizedBox(height: Space.xl, child: child);
  return [
    // If one wraps in a narrow window, both stay the same height.
    IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: place(RecordsPlace.google)),
          const SizedBox(width: Space.md),
          Expanded(child: place(RecordsPlace.service)),
        ],
      ),
    ),
    link(
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Link(lit: places[RecordsPlace.google]!.lit)),
          const SizedBox(width: Space.md),
          Expanded(child: _Link(lit: places[RecordsPlace.service]!.lit)),
        ],
      ),
    ),
    place(RecordsPlace.device),
    link(_Link(lit: places[RecordsPlace.backup]!.lit)),
    Center(
      child: FractionallySizedBox(
        widthFactor: 0.5,
        child: place(RecordsPlace.backup),
      ),
    ),
  ];
}

class _Place extends StatelessWidget {
  const _Place({
    required this.place,
    required this.facts,
    required this.desktop,
  });
  final RecordsPlace place;
  final PlaceFacts facts;
  final bool desktop;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final duration = Motion.of(context, Motion.short);
    final ink = facts.lit ? c.onSelection : c.secondary;
    return AnimatedContainer(
      duration: duration,
      curve: Motion.enter,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: facts.lit ? c.selection : c.canvas,
        borderRadius: BorderRadius.circular(Radii.controlOf(context)),
        border: Border.all(color: facts.lit ? c.primary : c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _icon(place, desktop: desktop),
                size: Space.lg,
                color: ink,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  _placeName(place),
                  style: text.titleSmall?.copyWith(
                    color: facts.lit ? c.onSelection : c.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            facts.holds,
            style: text.bodySmall?.copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}

/// The line between two places: solid when records go that way. As tall as
/// the space it's given.
class _Link extends StatelessWidget {
  const _Link({required this.lit});
  final bool lit;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return CustomPaint(
      painter: _LinkPainter(lit: lit, color: lit ? c.primary : c.border),
    );
  }
}

class _LinkPainter extends CustomPainter {
  const _LinkPainter({required this.lit, required this.color});
  final bool lit;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = lit ? Space.xxs : 1;
    final x = (size.width / 2).floorToDouble() + 0.5;
    if (lit) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }
    for (var y = 0.0; y < size.height; y += Space.sm) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + Space.xs).clamp(0, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.lit != lit || old.color != color;
}

/// The same places in one row, this device first, with the lines behind them.
class _SlimMap extends StatelessWidget {
  const _SlimMap({required this.places});
  final Map<RecordsPlace, PlaceFacts> places;
  static const order = [
    RecordsPlace.device,
    RecordsPlace.service,
    RecordsPlace.google,
    RecordsPlace.backup,
  ];
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return CustomPaint(
      painter: _SlimLinksPainter(
        lit: [for (final place in order.skip(1)) places[place]!.lit],
        solid: c.primary,
        dashed: c.border,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final place in order)
            Expanded(child: _SlimPlace(place: place, lit: places[place]!.lit)),
        ],
      ),
    );
  }
}

class _SlimPlace extends StatelessWidget {
  const _SlimPlace({required this.place, required this.lit});
  final RecordsPlace place;
  final bool lit;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final name = switch (place) {
      RecordsPlace.service => 'Service',
      RecordsPlace.backup => 'Backup',
      _ => _placeName(place),
    };
    return Column(
      children: [
        AnimatedContainer(
          duration: Motion.of(context, Motion.short),
          curve: Motion.enter,
          width: Space.xxl,
          height: Space.xxl,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? c.selection : c.surface,
            border: Border.all(color: lit ? c.primary : c.divider),
          ),
          child: Icon(
            _icon(place, desktop: isDesktop(context)),
            size: Space.lg,
            color: lit ? c.onSelection : c.secondary,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          name,
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(
            color: lit ? c.text : c.secondary,
          ),
        ),
      ],
    );
  }
}

/// A line from each place's circle to the next, level with the circles.
class _SlimLinksPainter extends CustomPainter {
  const _SlimLinksPainter({
    required this.lit,
    required this.solid,
    required this.dashed,
  });
  final List<bool> lit;
  final Color solid, dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / (lit.length + 1);
    const radius = Space.xxl / 2, y = Space.xxl / 2;
    for (final (i, on) in lit.indexed) {
      final from = cell * (i + 0.5) + radius;
      final to = cell * (i + 1.5) - radius;
      final paint = Paint()
        ..color = on ? solid : dashed
        ..strokeWidth = on ? Space.xxs : 1;
      if (on) {
        canvas.drawLine(Offset(from, y), Offset(to, y), paint);
        continue;
      }
      for (var x = from + Space.xs; x < to; x += Space.sm) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + Space.xs).clamp(from, to), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SlimLinksPainter old) =>
      !listEquals(old.lit, lit) ||
      old.solid != solid ||
      old.dashed != dashed;
}
