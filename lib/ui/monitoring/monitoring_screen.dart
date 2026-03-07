import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'monitoring_controller.dart';

class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(monitoringControllerProvider);
    final controller = ref.read(monitoringControllerProvider.notifier);
    final timeFormat = DateFormat('HH:mm');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: state.trip == null
              ? const Center(child: Text('No active trip'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Route summary card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.trip_origin,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.trip!.originName,
                                    style: theme.textTheme.bodyLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.more_vert,
                                color: theme.colorScheme.outline,
                                size: 16,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.place,
                                  color: theme.colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.trip!.destinationName,
                                    style: theme.textTheme.bodyLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.flag, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Arrive by ${timeFormat.format(state.trip!.targetArrivalTime)}',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live status
                    if (state.isLoading)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Waiting for traffic data...'),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // Current travel duration
                      _StatusTile(
                        icon: Icons.timer,
                        label: 'Current travel time',
                        value: state.currentDuration != null
                            ? '${state.currentDuration!.inMinutes} min'
                            : '--',
                      ),
                      const SizedBox(height: 8),

                      // Leave by time
                      _StatusTile(
                        icon: Icons.departure_board,
                        label: 'Leave by',
                        value: state.requiredDeparture != null
                            ? timeFormat.format(state.requiredDeparture!)
                            : '--',
                        highlighted: true,
                        isUrgent: state.isLate,
                      ),
                      const SizedBox(height: 8),

                      // Delta
                      if (state.deltaMinutes != null && state.deltaMinutes! > 0)
                        _StatusTile(
                          icon: Icons.trending_up,
                          label: 'Traffic impact',
                          value:
                              'Leave ${state.deltaMinutes} min earlier than planned',
                          isUrgent: state.deltaMinutes! > 5,
                        ),

                      if (state.isLate)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You should have already left! '
                                  'You may arrive late.',
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const Spacer(),

                    // Stop monitoring button
                    OutlinedButton(
                      onPressed: () => _stopMonitoring(context, controller),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                      child: const Text(
                        'Stop Monitoring',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _stopMonitoring(
    BuildContext context,
    MonitoringController controller,
  ) async {
    await controller.stopMonitoring();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;
  final bool isUrgent;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isUrgent
          ? theme.colorScheme.errorContainer
          : highlighted
          ? theme.colorScheme.primaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isUrgent
                  ? theme.colorScheme.onErrorContainer
                  : highlighted
                  ? theme.colorScheme.onPrimaryContainer
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isUrgent
                          ? theme.colorScheme.onErrorContainer
                          : highlighted
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUrgent
                          ? theme.colorScheme.onErrorContainer
                          : highlighted
                          ? theme.colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
