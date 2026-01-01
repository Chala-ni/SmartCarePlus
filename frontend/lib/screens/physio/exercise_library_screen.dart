/// SMARTCARE+ Exercise Library Screen
///
/// Owner: Neelaka
/// Browse and start exercises from the prescribed library

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _selectedCategory = 'All';
  
  final List<String> _categories = ['All', 'Balance', 'Strength', 'Flexibility', 'Gait'];
  
  final List<Map<String, dynamic>> _exercises = [
    {
      'name': 'Chair Stand',
      'category': 'Strength',
      'duration': '10 min',
      'difficulty': 'Easy',
      'reps': '3 sets x 10 reps',
      'description': 'Stand up from chair without using hands',
      'isPrescribed': true,
    },
    {
      'name': 'Heel-to-Toe Walk',
      'category': 'Gait',
      'duration': '5 min',
      'difficulty': 'Medium',
      'reps': '2 sets x 20 steps',
      'description': 'Walk in a straight line, heel to toe',
      'isPrescribed': true,
    },
    {
      'name': 'Single Leg Stand',
      'category': 'Balance',
      'duration': '8 min',
      'difficulty': 'Medium',
      'reps': '3 sets x 30 sec',
      'description': 'Stand on one leg while holding support',
      'isPrescribed': true,
    },
    {
      'name': 'Ankle Circles',
      'category': 'Flexibility',
      'duration': '5 min',
      'difficulty': 'Easy',
      'reps': '10 circles each direction',
      'description': 'Rotate ankles to improve flexibility',
      'isPrescribed': false,
    },
    {
      'name': 'Wall Push-ups',
      'category': 'Strength',
      'duration': '8 min',
      'difficulty': 'Easy',
      'reps': '3 sets x 8 reps',
      'description': 'Push-ups against the wall for upper body',
      'isPrescribed': false,
    },
    {
      'name': 'Tandem Stand',
      'category': 'Balance',
      'duration': '5 min',
      'difficulty': 'Hard',
      'reps': '3 sets x 20 sec',
      'description': 'Stand with feet in tandem position',
      'isPrescribed': false,
    },
    {
      'name': 'Marching in Place',
      'category': 'Gait',
      'duration': '10 min',
      'difficulty': 'Easy',
      'reps': '100 steps',
      'description': 'March in place lifting knees high',
      'isPrescribed': true,
    },
    {
      'name': 'Seated Leg Raises',
      'category': 'Strength',
      'duration': '8 min',
      'difficulty': 'Easy',
      'reps': '3 sets x 10 each leg',
      'description': 'Lift legs while seated in chair',
      'isPrescribed': false,
    },
  ];

  List<Map<String, dynamic>> get _filteredExercises {
    if (_selectedCategory == 'All') {
      return _exercises;
    }
    return _exercises.where((e) => e['category'] == _selectedCategory).toList();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Balance':
        return AppColors.neonPurple;
      case 'Strength':
        return AppColors.neonRed;
      case 'Flexibility':
        return AppColors.neonGreen;
      case 'Gait':
        return AppColors.neonCyan;
      default:
        return AppColors.neonCyan;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return AppColors.neonGreen;
      case 'Medium':
        return AppColors.neonOrange;
      case 'Hard':
        return AppColors.neonRed;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescribedExercises = _filteredExercises.where((e) => e['isPrescribed']).toList();
    final otherExercises = _filteredExercises.where((e) => !e['isPrescribed']).toList();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        'Exercise Library',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.search, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              
              // Category Filters
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = category),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.neonCyan.withOpacity(0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.neonCyan : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? AppColors.neonCyan : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Exercise List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (prescribedExercises.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.neonOrange, size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Prescribed for You',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...prescribedExercises.map((exercise) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildExerciseCard(exercise, isPrescribed: true),
                      )),
                      const SizedBox(height: 16),
                    ],
                    
                    if (otherExercises.isNotEmpty) ...[
                      const Text(
                        'More Exercises',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...otherExercises.map((exercise) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildExerciseCard(exercise, isPrescribed: false),
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, {required bool isPrescribed}) {
    final categoryColor = _getCategoryColor(exercise['category']);
    final difficultyColor = _getDifficultyColor(exercise['difficulty']);

    return GestureDetector(
      onTap: () => _showExerciseDetail(exercise),
      child: GlassmorphicCard(
        glowColor: isPrescribed ? categoryColor : null,
        glowIntensity: 0.1,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.fitness_center, color: categoryColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise['name'],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isPrescribed)
                        const Icon(Icons.star, color: AppColors.neonOrange, size: 16),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        exercise['duration'],
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          exercise['category'],
                          style: TextStyle(fontSize: 9, color: categoryColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: difficultyColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          exercise['difficulty'],
                          style: TextStyle(fontSize: 9, color: difficultyColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showExerciseDetail(Map<String, dynamic> exercise) {
    final categoryColor = _getCategoryColor(exercise['category']);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Exercise Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: categoryColor, width: 2),
                ),
                child: Icon(Icons.fitness_center, color: categoryColor, size: 40),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Center(
              child: Text(
                exercise['name'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Tags
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTag(exercise['category'], categoryColor),
                  const SizedBox(width: 8),
                  _buildTag(exercise['difficulty'], _getDifficultyColor(exercise['difficulty'])),
                  const SizedBox(width: 8),
                  _buildTag(exercise['duration'], AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Description
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              exercise['description'],
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            
            // Reps
            GlassmorphicCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.repeat, color: categoryColor),
                  const SizedBox(width: 12),
                  const Text(
                    'Repetitions: ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    exercise['reps'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Start Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Navigate to exercise session screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow),
                    SizedBox(width: 8),
                    Text(
                      'Start Exercise',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}
