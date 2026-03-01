import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_analysis_result.dart';

/// Card showing a detected AI-service restriction with countdown.
class RestrictionCard extends StatefulWidget {
  const RestrictionCard({
    super.key,
    required this.restriction,
    this.onTap,
  });

  final RestrictionInfo restriction;
  final VoidCallback? onTap;

  @override
  State<RestrictionCard> createState() => _RestrictionCardState();
}

class _RestrictionCardState extends State<RestrictionCard> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final r = widget.restriction;
    if (r.availableAtUtc != null) {
      final diff = r.availableAtUtc!.difference(DateTime.now().toUtc());
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
    } else if (r.remainingDuration != null) {
      setState(() {
        _remaining = r.remainingDuration;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.restriction;
    final isResolved = _remaining != null && _remaining == Duration.zero;

    return Card(
      color: isResolved
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isResolved
                      ? Colors.green.withValues(alpha: 0.2)
                      : theme.colorScheme.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isResolved ? Icons.check_circle : Icons.timer,
                  color: isResolved ? Colors.green : theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.serviceName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.typeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    if (r.availableAtLocal != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '解除: ${r.availableAtLocal}${r.sourceTimezone != null ? ' (${r.sourceTimezone})' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),

              // Countdown
              if (_remaining != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isResolved ? '解除済み' : _formatDuration(_remaining!),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isResolved
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                    ),
                    if (!isResolved)
                      Text(
                        '残り',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
