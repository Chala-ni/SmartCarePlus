/// SMARTCARE+ Alerts Screen
///
/// Owner: Devin
/// Emergency alerts and notifications management

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

enum AlertType { fall, inactivity, sos, medication, geofence }
enum AlertSeverity { critical, warning, info }

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'All';
  
  final List<Map<String, dynamic>> _alerts = [
    {'type': AlertType.fall, 'severity': AlertSeverity.critical, 'title': 'Fall Detected', 'location': 'Living Room', 'time': '5 min ago', 'resolved': false, 'elderly': 'Margaret Johnson'},
    {'type': AlertType.inactivity, 'severity': AlertSeverity.warning, 'title': 'Unusual Inactivity', 'location': 'Bedroom', 'time': '15 min ago', 'resolved': false, 'elderly': 'Margaret Johnson'},
    {'type': AlertType.medication, 'severity': AlertSeverity.info, 'title': 'Medication Reminder Sent', 'location': 'System', 'time': '1 hour ago', 'resolved': true, 'elderly': 'Robert Smith'},
    {'type': AlertType.sos, 'severity': AlertSeverity.critical, 'title': 'SOS Button Pressed', 'location': 'Kitchen', 'time': '2 hours ago', 'resolved': true, 'elderly': 'Margaret Johnson'},
    {'type': AlertType.geofence, 'severity': AlertSeverity.warning, 'title': 'Left Safe Zone', 'location': 'Front Door', 'time': 'Yesterday', 'resolved': true, 'elderly': 'Robert Smith'},
  ];

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_filter == 'All') return _alerts;
    if (_filter == 'Active') return _alerts.where((a) => !a['resolved']).toList();
    if (_filter == 'Resolved') return _alerts.where((a) => a['resolved']).toList();
    return _alerts;
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical: return AppColors.neonRed;
      case AlertSeverity.warning: return AppColors.neonOrange;
      case AlertSeverity.info: return AppColors.neonCyan;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.fall: return Icons.person_off;
      case AlertType.inactivity: return Icons.hourglass_empty;
      case AlertType.sos: return Icons.emergency;
      case AlertType.medication: return Icons.medication;
      case AlertType.geofence: return Icons.location_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _alerts.where((a) => !a['resolved']).length;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppColors.backgroundGradient),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('Alerts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: activeCount > 0 ? AppColors.neonRed.withOpacity(0.15) : AppColors.neonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text('$activeCount Active', style: TextStyle(fontSize: 12, color: activeCount > 0 ? AppColors.neonRed : AppColors.neonGreen, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              
              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: ['All', 'Active', 'Resolved'].map((filter) {
                    final isSelected = _filter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.neonCyan.withOpacity(0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? AppColors.neonCyan : Colors.transparent),
                          ),
                          child: Text(filter, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.neonCyan : AppColors.textSecondary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Alerts List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = _filteredAlerts[index];
                    return Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildAlertCard(alert));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final color = _getSeverityColor(alert['severity']);
    final icon = _getAlertIcon(alert['type']);
    final isResolved = alert['resolved'] as bool;
    
    return GestureDetector(
      onTap: () => _showAlertDetail(alert),
      child: GlassmorphicCard(
        glowColor: isResolved ? null : color,
        glowIntensity: 0.1,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(isResolved ? 0.08 : 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: isResolved ? AppColors.textSecondary : color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(alert['title'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isResolved ? AppColors.textSecondary : AppColors.textPrimary))),
                      if (isResolved) const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(alert['elderly'], style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                      Text(alert['location'], style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Text(alert['time'], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showAlertDetail(Map<String, dynamic> alert) {
    final color = _getSeverityColor(alert['severity']);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
              child: Icon(_getAlertIcon(alert['type']), color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(alert['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('${alert['elderly']} • ${alert['location']}', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            if (!(alert['resolved'] as bool)) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Mark Resolved'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.neonCyan, side: const BorderSide(color: AppColors.neonCyan), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Call Elderly'),
                    ),
                  ),
                ],
              ),
            ] else
              const Text('This alert has been resolved', style: TextStyle(color: AppColors.neonGreen)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
