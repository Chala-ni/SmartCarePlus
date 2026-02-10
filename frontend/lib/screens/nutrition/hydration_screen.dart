/// SMARTCARE+ Hydration Tracking Screen
///
/// Owner: Dilshan
/// Track daily water intake with backend persistence

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';
import '../../core/services/api_service.dart';
import '../../providers/auth_provider.dart';

class HydrationScreen extends ConsumerStatefulWidget {
  const HydrationScreen({super.key});

  @override
  ConsumerState<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends ConsumerState<HydrationScreen> {
  int _totalMl = 0;
  final int _goalMl = 2000;
  bool _isLoading = true;
  bool _isAdding = false;
  List<Map<String, dynamic>> _hydrationLog = [];

  int get _glassesConsumed => _totalMl ~/ 250;
  int get _goalGlasses => _goalMl ~/ 250;

  final List<Map<String, dynamic>> _beverageTypes = [
    {'name': 'Water', 'icon': Icons.water_drop, 'color': Colors.blue, 'ml': 250},
    {'name': 'Tea', 'icon': Icons.emoji_food_beverage, 'color': Colors.orange, 'ml': 200},
    {'name': 'Coffee', 'icon': Icons.coffee, 'color': Colors.brown, 'ml': 150},
    {'name': 'Juice', 'icon': Icons.local_drink, 'color': Colors.green, 'ml': 200},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHydrationData();
    });
  }

  String get _userId {
    return ref.read(currentUserProvider)?.uid ?? 'demo_user';
  }

  Future<void> _loadHydrationData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/api/nutrition/hydration/$_userId');
      if (response.success && response.data != null) {
        setState(() {
          _totalMl = (response.data['total_ml'] as num?)?.toInt() ?? 0;
          final log = response.data['log'] as List<dynamic>?;
          if (log != null) {
            _hydrationLog = log.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading hydration: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addBeverage(String beverageType, int amountMl) async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/api/nutrition/hydration/log', body: {
        'user_id': _userId,
        'amount_ml': amountMl,
        'beverage_type': beverageType.toLowerCase(),
      });
      if (response.success) {
        setState(() {
          _totalMl += amountMl;
          _hydrationLog.insert(0, {
            'time': TimeOfDay.now().format(context),
            'amount_ml': amountMl,
            'beverage_type': beverageType.toLowerCase(),
          });
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${amountMl}ml $beverageType'),
              backgroundColor: AppColors.neonGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error logging hydration: $e');
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _showAddDrinkSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Drink',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ...(_beverageTypes.map((bev) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _addBeverage(bev['name'], bev['ml']);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (bev['color'] as Color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              bev['icon'] as IconData,
                              color: bev['color'] as Color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bev['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${bev['ml']}ml per serving',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.add_circle, color: bev['color'] as Color, size: 28),
                        ],
                      ),
                    ),
                  ),
                );
              })),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _goalMl > 0 ? (_totalMl / _goalMl).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();

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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
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
                              'Hydration',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Progress Circle
                          GlassmorphicCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 160,
                                      height: 160,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 14,
                                        backgroundColor: AppColors.glassBorder,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          percent >= 100 ? AppColors.neonGreen : AppColors.neonPurple,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Icon(
                                          Icons.water_drop,
                                          size: 32,
                                          color: percent >= 100 ? AppColors.neonGreen : AppColors.neonPurple,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_totalMl}ml',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'of ${_goalMl}ml',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Glass indicators
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: List.generate(_goalGlasses, (index) {
                                    final filled = index < _glassesConsumed;
                                    return Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: filled
                                            ? AppColors.neonPurple.withOpacity(0.2)
                                            : AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: filled ? AppColors.neonPurple : AppColors.glassBorder,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.water_drop,
                                        size: 14,
                                        color: filled ? AppColors.neonPurple : AppColors.textSecondary,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_glassesConsumed / $_goalGlasses glasses',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Quick Add Beverages
                          const Text(
                            'Quick Add',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _beverageTypes.map((bev) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: GestureDetector(
                                    onTap: _isAdding ? null : () => _addBeverage(bev['name'], bev['ml']),
                                    child: GlassmorphicCard(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: (bev['color'] as Color).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              bev['icon'] as IconData,
                                              color: bev['color'] as Color,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            bev['name'] as String,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${bev['ml']}ml',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          // Today's Log
                          const Text(
                            "Today's Log",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_hydrationLog.isEmpty)
                            GlassmorphicCard(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.water_drop_outlined, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No drinks logged today',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tap a beverage above to get started',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...(_hydrationLog.map((entry) {
                              final bevType = (entry['beverage_type'] as String?) ?? 'water';
                              final amountMl = (entry['amount_ml'] as num?)?.toInt() ?? 250;
                              final time = (entry['time'] as String?) ?? '';
                              final bevInfo = _beverageTypes.firstWhere(
                                (b) => (b['name'] as String).toLowerCase() == bevType,
                                orElse: () => _beverageTypes[0],
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassmorphicCard(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (bevInfo['color'] as Color).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          bevInfo['icon'] as IconData,
                                          color: bevInfo['color'] as Color,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bevType[0].toUpperCase() + bevType.substring(1),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              time,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${amountMl}ml',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.neonPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            })),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
