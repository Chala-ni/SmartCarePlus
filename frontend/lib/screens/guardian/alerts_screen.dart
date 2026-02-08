/// SMARTCARE+ Alerts Screen
///
/// Owner: Devin
/// Emergency alerts and notifications management - fetches real alert data from backend

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glassmorphic_card.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _filter = 'All';
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }
  
  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final profile = ref.read(authProvider).profile;
      final guardianId = profile?.uid ?? 'unknown';
      
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/alerts/$guardianId',
        requireAuth: false,
      );
      
      if (response.success && response.data != null) {
        final data = response.data!;
        final alertsList = data['alerts'] as List<dynamic>? ?? [];
        setState(() {
          _alerts = alertsList.map((a) => Map<String, dynamic>.from(a as Map)).toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch alerts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_filter == 'All') return _alerts;
    if (_filter == 'Critical') return _alerts.where((a) => a['severity'] == 'critical').toList();
    if (_filter == 'Falls') return _alerts.where((a) => a['type'] == 'fall').toList();
    return _alerts;
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'critical': return AppColors.neonRed;
      case 'warning': return AppColors.neonOrange;
      default: return AppColors.neonCyan;
    }
  }

  IconData _getAlertIcon(String? type) {
    switch (type) {
      case 'fall': return Icons.person_off;
      case 'gait': return Icons.directions_walk;
      case 'inactivity': return Icons.hourglass_empty;
      case 'sos': return Icons.emergency;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _alerts.where((a) => !(a['resolved'] ?? false)).length;
    final canPop = Navigator.of(context).canPop();
    
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
                    if (canPop) ...[
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alerts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text('$activeCount unacknowledged alerts', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _fetchAlerts,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh, color: AppColors.textSecondary, size: 16),
                            SizedBox(width: 4),
                            Text('Refresh', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: ['All', 'Critical', 'Falls'].map((filter) {
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.neonCyan))
                    : _filteredAlerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 16),
                                Text(
                                  _filter == 'All' ? 'No alerts yet' : 'No $_filter alerts',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchAlerts,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _filteredAlerts.length,
                              itemBuilder: (context, index) {
                                final alert = _filteredAlerts[index];
                                return Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildAlertCard(alert));
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'info';
    final type = alert['type'] as String? ?? 'unknown';
    final color = _getSeverityColor(severity);
    final icon = _getAlertIcon(type);
    final isResolved = alert['resolved'] ?? false;
    final title = alert['title'] ?? _getAlertTitle(type);
    final elderlyName = alert['elderly_name'] ?? 'Unknown';
    final createdAt = alert['created_at'] ?? '';
    
    // Format time
    String timeAgo = createdAt;
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours} hours ago';
      } else {
        timeAgo = '${diff.inDays} days ago';
      }
    } catch (_) {}
    
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
                      Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isResolved ? AppColors.textSecondary : AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (isResolved) const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(elderlyName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                      Text(severity.toUpperCase(), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Text(timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  /// Show emergency contacts for a specific elderly
  Future<void> _showEmergencyContactsForElderly(String? elderlyId) async {
    if (elderlyId == null || elderlyId.isEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
      return;
    }
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>(
        '${ApiConfig.guardian}/emergency-contacts/$elderlyId',
        requireAuth: false,
      );
      
      if (!response.success || response.data == null) {
        final Uri phoneUri = Uri(scheme: 'tel', path: '911');
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        }
        return;
      }
      
      final contacts = (response.data!['contacts'] as List?) ?? [];
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.phone, color: AppColors.neonCyan),
              SizedBox(width: 12),
              Text('Emergency Contacts', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: contacts.map<Widget>((contact) {
              final name = contact['name'] ?? 'Unknown';
              final phone = contact['phone'] ?? '';
              final role = contact['role'] ?? '';
              final isEmergency = role == 'emergency';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassmorphicCard(
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isEmergency ? AppColors.neonRed.withOpacity(0.2) : AppColors.neonCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isEmergency ? Icons.local_hospital : Icons.person,
                        color: isEmergency ? AppColors.neonRed : AppColors.neonCyan,
                        size: 20,
                      ),
                    ),
                    title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.phone, color: AppColors.neonGreen),
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                        if (await canLaunchUrl(phoneUri)) {
                          await launchUrl(phoneUri);
                        }
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error fetching emergency contacts: $e');
      final Uri phoneUri = Uri(scheme: 'tel', path: '911');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    }
  }

  String _getAlertTitle(String type) {
    switch (type) {
      case 'fall': return 'Fall Detected';
      case 'gait': return 'Abnormal Gait';
      case 'inactivity': return 'Inactivity Warning';
      case 'sos': return 'SOS Emergency';
      default: return 'Alert';
    }
  }

  void _showAlertDetail(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'info';
    final type = alert['type'] as String? ?? 'unknown';
    final color = _getSeverityColor(severity);
    final isResolved = alert['resolved'] ?? false;
    final title = alert['title'] ?? _getAlertTitle(type);
    final description = alert['description'] ?? '';
    final alertId = alert['id'] ?? '';
    final elderlyId = alert['elderly_id'] as String? ?? '';
    final elderlyName = alert['elderly_name'] ?? 'Unknown';
    
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
              child: Icon(_getAlertIcon(type), color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('$elderlyName • ${severity.toUpperCase()}', style: const TextStyle(color: AppColors.textSecondary)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            if (!isResolved) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Acknowledge the alert via API
                        try {
                          final apiService = ref.read(apiServiceProvider);
                          await apiService.put<Map<String, dynamic>>(
                            '${ApiConfig.guardian}/alerts/$alertId/acknowledge',
                            body: {'response_action': 'resolved', 'notes': ''},
                            requireAuth: false,
                          );
                          if (mounted) Navigator.pop(context);
                          _fetchAlerts(); // Refresh
                        } catch (e) {
                          debugPrint('Failed to acknowledge alert: $e');
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Mark Resolved'),
                    ),
                  ),
                  if (type == 'fall') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEmergencyContactsForElderly(elderlyId);
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.neonRed, side: const BorderSide(color: AppColors.neonRed), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Call Emergency'),
                      ),
                    ),
                  ],
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
