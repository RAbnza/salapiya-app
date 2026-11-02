import 'package:flutter/material.dart';

import '../design_system/components.dart';
import 'demo_routes.dart';

class DemoActionPage extends StatefulWidget {
  const DemoActionPage({super.key, required this.label});
  final String label;
  @override
  State<DemoActionPage> createState() => _DemoActionPageState();
}

class _DemoActionPageState extends State<DemoActionPage> {
  final note = TextEditingController();
  bool asking = false, completed = false;
  bool get dirty => note.text.isNotEmpty;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (asking) return;
    asking = true;
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => AlertDialog(
        title: const Text('Discard demo draft?'),
        content: const Text(
          'Your note exists only in this session. No financial operation has occurred.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard demo draft'),
          ),
        ],
      ),
    );
    asking = false;
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: DemoPage(
      title: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            '${widget.label} · preview',
            caption: 'This is a bounded task preview. Amount entry, validation and financial review are not available yet.',
          ),
          const StatusNotice(
            'No financial record will be created. You can try a temporary note and Back behavior.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: note,
            key: const ValueKey('demo-task-note'),
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Temporary demo note',
              helperText: 'Use invented information only.',
            ),
            onChanged: (_) => setState(() => completed = false),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() => completed = true);
            },
            child: const Text('Preview outcome'),
          ),
          if (completed)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: StatusNotice(
                'Preview complete — no record created. Your note remains in memory until you leave.',
                live: true,
              ),
            ),
        ],
      ),
    ),
  );
}
