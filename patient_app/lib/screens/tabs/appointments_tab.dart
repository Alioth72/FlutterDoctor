import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/dynamic_translated_text.dart';
import '../appointments/appointment_receipt_screen.dart';
import '../appointments/book_appointment_screen.dart';
import '../appointments/pre_call_heart_rate_screen.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  void _joinTelehealth(BuildContext context, Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreCallHeartRateScreen(appointment: appointment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = Provider.of<AppointmentProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final upcomingAppointments = appointmentProvider.upcomingAppointments;
    final pastAppointments = appointmentProvider.pastAppointments;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(langProvider.tr('my_appointments_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            IconButton(
              tooltip: 'Sync Appointments',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(langProvider.tr('syncing_appointments')),
                    duration: Duration(seconds: 1),
                  ),
                );
                await appointmentProvider.refreshAppointmentsFromBackend();
              },
            ),
            if (appointmentProvider.appointments.isNotEmpty)
              IconButton(
                tooltip: langProvider.tr('clear_all_appts'),
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                onPressed: () => _confirmClearAll(context),
              ),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF7C3AED),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF7C3AED),
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        langProvider.tr('upcoming'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (upcomingAppointments.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${upcomingAppointments.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        langProvider.tr('history'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pastAppointments.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${pastAppointments.length}',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Upcoming
            RefreshIndicator(
              onRefresh: () => appointmentProvider.refreshAppointmentsFromBackend(),
              child: upcomingAppointments.isEmpty
                  ? _buildEmptyState(
                      context,
                      title: langProvider.tr('no_appointments_yet'),
                      subtitle: langProvider.tr('no_appointments_sub'),
                      showBookButton: true,
                    )
                  : _buildAppointmentsList(context, upcomingAppointments, isUpcoming: true),
            ),
            // Tab 2: Past / History
            RefreshIndicator(
              onRefresh: () => appointmentProvider.refreshAppointmentsFromBackend(),
              child: pastAppointments.isEmpty
                  ? _buildEmptyState(
                      context,
                      title: langProvider.tr('no_past_appointments'),
                      subtitle: langProvider.tr('no_past_appointments_sub'),
                      showBookButton: false,
                    )
                  : _buildAppointmentsList(context, pastAppointments, isUpcoming: false),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BookAppointmentScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(
            langProvider.tr('book_appointment_title'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool showBookButton,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final langProvider = Provider.of<LanguageProvider>(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 54,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (showBookButton) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BookAppointmentScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: Text(langProvider.tr('book_doctor_appt_btn')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(
    BuildContext context,
    List<Appointment> appointments, {
    required bool isUpcoming,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final langProvider = Provider.of<LanguageProvider>(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final apt = appointments[index];
        final isConfirmed = apt.status.toLowerCase() == 'confirmed';
        final isCompleted = apt.status.toLowerCase() == 'completed';
        final isInProgress = apt.status.toLowerCase() == 'in progress' || apt.status.toLowerCase() == 'in_progress';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: (isConfirmed || isCompleted || isInProgress)
                  ? colorScheme.outlineVariant.withValues(alpha: 0.7)
                  : colorScheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Token, Type & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${langProvider.tr('token_prefix')} ${apt.tokenNumber.replaceAll('Token #', '').trim()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: apt.isOnline ? const Color(0xFFFAF5FF) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: apt.isOnline ? const Color(0xFFDDD6FE) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    apt.isOnline ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                                    size: 13,
                                    color: apt.isOnline ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    apt.isOnline
                                        ? (apt.appointmentType.toLowerCase() == 'telehealth'
                                            ? langProvider.tr('telehealth_badge')
                                            : langProvider.tr('online_badge'))
                                        : langProvider.tr('offline_badge'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: apt.isOnline ? const Color(0xFF7C3AED) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusBgColor(apt.status),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isConfirmed
        ? langProvider.tr('status_confirmed')
        : (apt.status.toLowerCase() == 'cancelled'
            ? langProvider.tr('status_cancelled')
            : (apt.status.toLowerCase() == 'completed'
                ? langProvider.tr('completed_status')
                : (isInProgress
                    ? langProvider.tr('in_progress_status')
                    : (apt.status.toLowerCase() == 'queued'
                        ? langProvider.tr('queued_status')
                        : apt.status)))),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _statusTextColor(apt.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Doctor Info
                DynamicTranslatedText(
                  text: apt.doctorName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                DynamicTranslatedText(
                  text: apt.doctorSpecialty,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: DynamicTranslatedText(
                        text: apt.hospitalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Date & Time Box
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${apt.appointmentDate} • ${apt.timeSlot}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // If Online/Telehealth & Active in Upcoming, show Join Consultation button
                if (isUpcoming && apt.isOnline && (isConfirmed || isInProgress || apt.status.toLowerCase() == 'queued')) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: () => _joinTelehealth(context, apt),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.videocam_rounded, size: 18, color: Colors.white),
                      label: Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            langProvider.tr('connect_video_consultation'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Action Buttons: View Receipt & Cancel
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AppointmentReceiptScreen(appointment: apt),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(langProvider.tr('view_online_receipt')),
                          ),
                        ),
                      ),
                    ),
                    if (isConfirmed) ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: langProvider.tr('cancel_appt_tooltip'),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        onPressed: () => _confirmCancel(context, apt),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: langProvider.tr('delete_history_tooltip'),
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: () => _confirmDelete(context, apt),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancel(BuildContext context, Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).tr('cancel_appointment_q')),
        content: Text('${Provider.of<LanguageProvider>(context, listen: false).tr('cancel_appointment_confirm')} ${appointment.doctorName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).tr('no_keep_it')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).tr('yes_cancel')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<AppointmentProvider>(context, listen: false);
      await provider.cancelAppointment(appointment.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).tr('appointment_cancelled'))),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).tr('delete_appointment_q')),
        content: Text(Provider.of<LanguageProvider>(context, listen: false).tr('delete_appointment_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).tr('close_btn')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).tr('delete_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<AppointmentProvider>(context, listen: false);
      await provider.deleteAppointment(appointment.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).tr('appointment_deleted'))),
        );
      }
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).tr('clear_all_appointments_q')),
        content: Text(Provider.of<LanguageProvider>(context, listen: false).tr('clear_all_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).tr('close_btn')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).tr('clear_all_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<AppointmentProvider>(context, listen: false);
      await provider.clearAllAppointments();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).tr('all_appointments_cleared'))),
        );
      }
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green.withValues(alpha: 0.12);
      case 'in progress':
      case 'in_progress':
        return Colors.orange.withValues(alpha: 0.15);
      case 'completed':
        return Colors.blue.withValues(alpha: 0.12);
      case 'queued':
        return Colors.purple.withValues(alpha: 0.12);
      case 'cancelled':
      default:
        return Colors.red.withValues(alpha: 0.12);
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green.shade700;
      case 'in progress':
      case 'in_progress':
        return Colors.orange.shade800;
      case 'completed':
        return Colors.blue.shade700;
      case 'queued':
        return Colors.purple.shade700;
      case 'cancelled':
      default:
        return Colors.red.shade700;
    }
  }
}
