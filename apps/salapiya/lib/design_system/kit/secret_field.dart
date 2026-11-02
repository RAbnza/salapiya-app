import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'dashboard.dart';
import 'fields.dart';

/// The recovery secret's field and its controls. It's masked until asked, and
/// masks again when the app leaves the foreground. Nothing here stores it.
class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.readOnly = false,
    this.helper,
  });
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? errorText, helper;
  final bool readOnly;
  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> with WidgetsBindingObserver {
  bool masked = true, copied = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !masked) {
      setState(() => masked = true);
    }
  }

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: widget.controller.text));
    if (mounted) setState(() => copied = true);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HelpTextField(
        key: const ValueKey('backup-secret'),
        label: 'Recovery secret',
        controller: widget.controller,
        secret: true,
        obscured: masked,
        readOnly: widget.readOnly,
        keyboardType: TextInputType.visiblePassword,
        errorText: widget.errorText,
        helper: copied
            ? 'Copied. Clear your clipboard once it’s saved somewhere.'
            : widget.helper,
        onChanged: (_) => widget.onChanged(),
      ),
      const SizedBox(height: Space.xs),
      Wrap(
        spacing: Space.md,
        children: [
          CardLink(
            masked ? 'Show' : 'Hide',
            key: const ValueKey('backup-secret-show'),
            icon: masked
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            chevron: false,
            onPressed: () => setState(() => masked = !masked),
          ),
          if (widget.readOnly)
            CardLink(
              'Copy',
              key: const ValueKey('backup-secret-copy'),
              icon: Icons.copy_outlined,
              chevron: false,
              onPressed: copy,
            ),
        ],
      ),
    ],
  );
}
