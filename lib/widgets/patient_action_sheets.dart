import 'package:flutter/material.dart';

class PatientActionSheets {
  /// Language Switcher Dialog
  static void showLanguageSelector(BuildContext context) {
    final languages = [
      {'name': 'English', 'native': 'English', 'code': 'en'},
      {'name': 'Hindi', 'native': 'हिन्दी', 'code': 'hi'},
      {'name': 'Bengali', 'native': 'বাংলা', 'code': 'bn'},
      {'name': 'Telugu', 'native': 'తెలుగు', 'code': 'te'},
      {'name': 'Marathi', 'native': 'मराठी', 'code': 'mr'},
      {'name': 'Tamil', 'native': 'தமிழ்', 'code': 'ta'},
      {'name': 'Gujarati', 'native': 'ગુજરાતી', 'code': 'gu'},
      {'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ', 'code': 'pa'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.translate_rounded, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text(
                  'Choose Language / भाषा चुनें',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: languages.map((lang) {
                return ActionChip(
                  avatar: const Icon(Icons.language, size: 16),
                  label: Text('${lang['name']} (${lang['native']})'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('App language changed to ${lang['name']} (${lang['native']})'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Contact Doctor / Tele-consultation Sheet
  static void showContactDoctorSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 30,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.support_agent_rounded, size: 32, color: colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'Contact On-Duty Doctor',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Instant audio/video tele-consultation & USSD assistance with registered district physicians.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connecting to On-Duty Medical Officer...')),
                      );
                    },
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Audio Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Starting Video Tele-consultation room...')),
                      );
                    },
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Video Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Voice Assistant Listening Modal
  static void showVoiceAssistant(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.redAccent,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Listening in your language...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Say "Doctor appointment book karo" or "Bukhar ki dawai dikhao"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  /// Buy Medicines / Prescription lookup modal
  static void showBuyMedicines(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  child: const Icon(Icons.medication_rounded, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Buy Medicines & Jan Aushadhi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              stylusHandwritingEnabled: false,
              decoration: InputDecoration(
                hintText: 'Search medicine name (e.g. Paracetamol, Azithromycin)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Generic Jan Aushadhi Alternatives (Up to 80% discount):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            _buildMedicineTile('Paracetamol 650mg (Jan Aushadhi)', '₹12 for 10 tabs', 'In Stock'),
            _buildMedicineTile('Amoxicillin 500mg', '₹28 for 10 caps', 'In Stock'),
            _buildMedicineTile('Metformin 500mg', '₹15 for 10 tabs', 'In Stock'),
          ],
        ),
      ),
    );
  }

  static Widget _buildMedicineTile(String name, String price, String status) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.medical_information_outlined, color: Colors.teal),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(price),
      trailing: FilledButton.tonal(
        onPressed: () {},
        child: const Text('Add', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  /// AI Assistant Multilingual Chatbot Modal
  static void showAiAssistant(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFE1BEE7),
                  child: Icon(Icons.smart_toy_rounded, color: Colors.purple),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Health Assistant', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('RAG Preliminary Diagnosis • Multilingual', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Namaste! Describe your symptoms or ask health questions in any Indian language. I will guide you with preliminary insights.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              stylusHandwritingEnabled: false,
              decoration: InputDecoration(
                hintText: 'Type your symptoms (e.g. सिरदर्द और बुखार)...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.purple),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI Health Assistant analysing symptoms...')),
                    );
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Emergency SOS Sheet
  static void showEmergency(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.emergency_rounded, size: 40, color: Colors.red),
            ),
            const SizedBox(height: 14),
            const Text(
              'EMERGENCY ESCALATION',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.red),
            ),
            const SizedBox(height: 6),
            const Text(
              'Immediate ambulance dispatch & hospital trauma team escalation with GPS location sharing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚨 SOS Alert Dispatched! Nearest Ambulance Unit Notified.'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              icon: const Icon(Icons.phone_in_talk_rounded),
              label: const Text('CALL 108 AMBULANCE (SOS)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
