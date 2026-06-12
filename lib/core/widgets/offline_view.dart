import 'package:flutter/material.dart';

/// Friendly full-area "you're offline" state shown whenever an AI feature can't
/// reach the network. Replaces raw provider/API errors.
class OfflineView extends StatelessWidget {
  final VoidCallback? onRetry;
  final String message;
  const OfflineView({
    super.key,
    this.onRetry,
    this.message = 'The AI features need an internet connection.',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 56, color: scheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Offline',
                style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7))),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline offline chip for message lists (e.g. the tutor chat).
class OfflineBubble extends StatelessWidget {
  const OfflineBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 18, color: scheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text("You're offline — reconnect to ask the tutor.",
                style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
