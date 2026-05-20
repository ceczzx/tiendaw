import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    super.key,
    this.detail,
    this.onTap,
  });

  final String label;
  final String value;
  final String? detail;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight =
            constraints.maxHeight.isFinite && constraints.maxHeight <= 180;
        final padding = isTight ? 16.0 : 18.0;
        final iconSize = isTight ? 40.0 : 42.0;
        final gapAfterIcon = isTight ? 12.0 : 16.0;
        final gapAfterLabel = isTight ? 6.0 : 8.0;
        final gapBeforeDetail = isTight ? 4.0 : 6.0;

        final content = Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(31),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.insights_rounded, color: accent),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: accent.withAlpha(190),
                    ),
                ],
              ),
              SizedBox(height: gapAfterIcon),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              SizedBox(height: gapAfterLabel),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              if (detail != null) ...[
                SizedBox(height: gapBeforeDetail),
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: isTight ? 2 : null,
                  overflow:
                      isTight ? TextOverflow.ellipsis : TextOverflow.visible,
                ),
              ],
            ],
          ),
        );

        return Card(
          child:
              onTap == null
                  ? content
                  : InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTap,
                    child: content,
                  ),
        );
      },
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({required this.title, required this.caption, super.key});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 28, color: Color(0xFF64748B)),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(caption, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

Future<void> showSystemWActionDialog(
  BuildContext context, {
  required String message,
  String? title,
  bool isError = false,
  String buttonLabel = 'Entendido',
}) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => SystemWActionDialog(
          title:
              title ??
              (isError ? 'No se completó la acción' : 'Acción registrada'),
          message: message,
          isError: isError,
          buttonLabel: buttonLabel,
        ),
  );
}

class SystemWActionDialog extends StatelessWidget {
  const SystemWActionDialog({
    required this.title,
    required this.message,
    super.key,
    this.isError = false,
    this.buttonLabel = 'Entendido',
  });

  final String title;
  final String message;
  final bool isError;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E);
    final softBackground =
        isError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final borderColor =
        isError ? const Color(0xFFFCA5A5) : const Color(0xFF99F6E4);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: softBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Icon(
              isError
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
        ],
      ),
      content: Container(
        width: 420,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: softBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}
