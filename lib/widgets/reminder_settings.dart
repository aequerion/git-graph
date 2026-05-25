import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

/// Widget for configuring daily contribution reminders
class ReminderSettingsCard extends StatefulWidget {
  const ReminderSettingsCard({super.key});

  @override
  State<ReminderSettingsCard> createState() => _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends State<ReminderSettingsCard> {
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await NotificationService.isReminderEnabled();
    
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleReminder(bool value) async {
    HapticFeedback.lightImpact();
    
    if (value) {
      // Request permission first
      final granted = await NotificationService.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission denied. Please enable in settings.'),
              backgroundColor: Color(0xFFf85149),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isEnabled = value);
    
    await NotificationService.saveReminderSettings(enabled: value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value 
            ? 'Daily reminders enabled (7:00 AM & 11:00 PM)'
            : 'Daily reminders disabled'),
          backgroundColor: const Color(0xFF238636),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161b22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF30363d)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _isEnabled ? Icons.notifications_active : Icons.notifications_outlined,
                  color: _isEnabled ? const Color(0xFF238636) : const Color(0xFF8b949e),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Daily Reminders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _isEnabled,
                    onChanged: _toggleReminder,
                    activeColor: const Color(0xFF238636),
                    activeTrackColor: const Color(0xFF238636).withValues(alpha: 0.5),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              'Get reminded twice daily to maintain your contribution streak.',
              style: TextStyle(
                color: Color(0xFF8b949e),
                fontSize: 13,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Notification schedule info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF21262d),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363d)),
              ),
              child: Column(
                children: [
                  // Morning notification
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isEnabled ? const Color(0xFF238636) : const Color(0xFF484f58),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.wb_sunny_outlined,
                        color: Color(0xFF8b949e),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '7:00 AM - Morning motivation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Evening notification
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isEnabled ? const Color(0xFFf85149) : const Color(0xFF484f58),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.nightlight_outlined,
                        color: Color(0xFF8b949e),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '11:00 PM - Final reminder',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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