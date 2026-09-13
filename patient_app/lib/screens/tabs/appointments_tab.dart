import '../appointments/video_consultation_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/dynamic_translated_text.dart';
import '../appointments/book_appointment_screen.dart';
import '../appointments/appointment_receipt_screen.dart';

class AppointmentsTab extends StatelessWidget {
  const AppointmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = Provider.of<AppointmentProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final appointments = appointmentProvider.appointments;

    return Scaffold(
      appBar: AppBar(
        title: Text(langProvider.tr('my_appointments_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (appointments.isNotEmpty)
            IconButton(
              tooltip: langProvider.tr('clear_all_appts'),
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              onPressed: () => _confirmClearAll(context),
            ),
        ],
      ),
      body: appointments.isEmpty
          ? _buildEmptyState(context)
          : _buildAppointmentsList(context, appointments),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BookAppointmentScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(langProvider.tr('book_appointment_title')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              langProvider.tr('no_appointments_yet'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              langProvider.tr('no_appointments_sub'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(BuildContext context, List<Appointment> appointments) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final langProvider = Provider.of<LanguageProvider>(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final apt = appointments[index];
        final isConfirmed = apt.status == 'Confirmed';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isConfirmed
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
                    Row(
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
                                apt.isOnline ? langProvider.tr('online_badge') : langProvider.tr('offline_badge'),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isConfirmed
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isConfirmed ? langProvider.tr('status_confirmed') : (apt.status == 'Cancelled' ? langProvider.tr('status_cancelled') : apt.status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isConfirmed ? Colors.green : Colors.red,
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
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
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
                    Icon(Icons.access_time_rounded, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${apt.appointmentDate} • ${apt.timeSlot}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // If Online & Confirmed, show Connect Video Consultation Button
                if (apt.isOnline && isConfirmed) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VideoConsultationScreen(appointment: apt),
                          ),
                        );
                      },
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
        title: const Text('Cancel Appointment?'),
        content: Text('Are you sure you want to cancel your appointment with ${appointment.doctorName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, Keep It'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<AppointmentProvider>(context, listen: false);
      await provider.cancelAppointment(appointment.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled successfully.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Appointment?'),
        content: const Text('Do you want to permanently remove this appointment from your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<AppointmentProvider>(context, listen: false);
      await provider.deleteAppointment(appointment.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment deleted.')),
        );
      }
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Appointments?'),
        content: const Text('This will delete all appointment records from your phone. You can book fresh test appointments anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<AppointmentProvider>(context, listen: false);
      await provider.clearAllAppointments();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All appointments cleared.')),
        );
      }
    }
  }
}
