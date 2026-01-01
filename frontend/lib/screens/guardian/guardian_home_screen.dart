/// SMARTCARE+ Guardian Home Screen
///
/// Owner: Devin
/// Main dashboard for guardian monitoring elderly

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/config/routes.dart';
import '../../widgets/common/glassmorphic_card.dart';

class GuardianHomeScreen extends StatelessWidget {
  const GuardianHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Guardian Monitor',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.neonRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield, color: AppColors.neonRed, size: 24),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Alert Summary
                GlassmorphicCard(
                  glowColor: AppColors.neonOrange,
                  glowIntensity: 0.1,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.neonOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.warning_amber, color: AppColors.neonOrange, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('2 Active Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('1 fall detected, 1 inactivity warning', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, Routes.alerts),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.neonOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('View', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Quick Actions
                Row(
                  children: [
                    Expanded(child: _buildQuickAction(context, Icons.videocam, 'Live Feed', AppColors.neonCyan, () => Navigator.pushNamed(context, Routes.liveMonitor))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildQuickAction(context, Icons.notifications_active, 'Alerts', AppColors.neonOrange, () => Navigator.pushNamed(context, Routes.alerts))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildQuickAction(context, Icons.history, 'Activity', AppColors.neonGreen, () => Navigator.pushNamed(context, Routes.activityLog))),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Elderly Status Cards
                const Text('Monitored Elderly', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                
                _buildElderlyCard('Margaret Johnson', 'Living Room', 'Active', AppColors.neonGreen, '2 min ago'),
                const SizedBox(height: 10),
                _buildElderlyCard('Robert Smith', 'Bedroom', 'Resting', AppColors.neonCyan, '15 min ago'),
                
                const SizedBox(height: 24),
                
                // Recent Activity
                const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                
                _buildActivityItem('Movement detected', 'Living Room Camera', '2 min ago', Icons.directions_walk, AppColors.neonGreen),
                _buildActivityItem('Meal time reminder sent', 'System', '30 min ago', Icons.restaurant, AppColors.neonOrange),
                _buildActivityItem('Medication taken', 'Confirmed by user', '1 hour ago', Icons.medication, AppColors.neonCyan),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildElderlyCard(String name, String location, String status, Color statusColor, String lastSeen) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundColor: AppColors.surfaceLight, child: Text(name[0], style: const TextStyle(fontSize: 18, color: AppColors.textPrimary))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(location, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Text(lastSeen, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(time, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
