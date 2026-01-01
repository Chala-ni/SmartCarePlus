/// SMARTCARE+ TUG Test Screen
///
/// Owner: Neelaka
/// Timed Up and Go test with guided instructions and timer

import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/constants/colors.dart';
import '../../widgets/common/glassmorphic_card.dart';

class TUGTestScreen extends StatefulWidget {
  const TUGTestScreen({super.key});

  @override
  State<TUGTestScreen> createState() => _TUGTestScreenState();
}

class _TUGTestScreenState extends State<TUGTestScreen> {
  TestPhase _phase = TestPhase.ready;
  Timer? _timer;
  int _elapsedMilliseconds = 0;
  double? _finalTime;
  String? _riskLevel;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _phase = TestPhase.running;
      _elapsedMilliseconds = 0;
      _finalTime = null;
      _riskLevel = null;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _elapsedMilliseconds += 100;
      });
    });
  }

  void _stopTest() {
    _timer?.cancel();
    final time = _elapsedMilliseconds / 1000;
    
    String risk;
    if (time < 10) {
      risk = 'Low';
    } else if (time < 20) {
      risk = 'Moderate';
    } else if (time < 30) {
      risk = 'High';
    } else {
      risk = 'Very High';
    }

    setState(() {
      _phase = TestPhase.completed;
      _finalTime = time;
      _riskLevel = risk;
    });
  }

  void _resetTest() {
    setState(() {
      _phase = TestPhase.ready;
      _elapsedMilliseconds = 0;
      _finalTime = null;
      _riskLevel = null;
    });
  }

  Color _getRiskColor() {
    switch (_riskLevel) {
      case 'Low':
        return AppColors.neonGreen;
      case 'Moderate':
        return AppColors.neonOrange;
      case 'High':
        return AppColors.neonRed;
      case 'Very High':
        return AppColors.neonRed;
      default:
        return AppColors.neonCyan;
    }
  }

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
          child: Padding(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TUG Test',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Timed Up and Go',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.timer, color: AppColors.neonGreen),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // Timer Display
                Center(
                  child: _buildTimerDisplay(),
                ),
                
                const SizedBox(height: 30),
                
                // Phase-specific content
                Expanded(
                  child: _buildPhaseContent(),
                ),
                
                // Action Button
                _buildActionButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final seconds = (_elapsedMilliseconds / 1000).toStringAsFixed(1);
    final displayTime = _finalTime?.toStringAsFixed(1) ?? seconds;
    
    Color timerColor;
    if (_phase == TestPhase.completed) {
      timerColor = _getRiskColor();
    } else if (_phase == TestPhase.running) {
      timerColor = AppColors.neonGreen;
    } else {
      timerColor = AppColors.neonCyan;
    }

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: timerColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: timerColor.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            displayTime,
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: timerColor,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'seconds',
            style: TextStyle(
              fontSize: 16,
              color: timerColor.withOpacity(0.7),
            ),
          ),
          if (_phase == TestPhase.completed && _riskLevel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: timerColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_riskLevel Risk',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: timerColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case TestPhase.ready:
        return _buildInstructions();
      case TestPhase.running:
        return _buildRunningContent();
      case TestPhase.completed:
        return _buildResultsContent();
    }
  }

  Widget _buildInstructions() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Instructions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildInstructionStep(1, 'Sit in a standard chair', Icons.chair),
          _buildInstructionStep(2, 'Stand up from the chair', Icons.arrow_upward),
          _buildInstructionStep(3, 'Walk 3 meters (10 feet)', Icons.directions_walk),
          _buildInstructionStep(4, 'Turn around', Icons.rotate_right),
          _buildInstructionStep(5, 'Walk back to the chair', Icons.directions_walk),
          _buildInstructionStep(6, 'Sit down again', Icons.chair_alt),
          
          const SizedBox(height: 20),
          
          GlassmorphicCard(
            glowColor: AppColors.neonCyan,
            glowIntensity: 0.1,
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.neonCyan),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap START when ready, then tap STOP when you sit back down.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int step, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonCyan,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.directions_walk,
            size: 80,
            color: AppColors.neonGreen,
          ),
          const SizedBox(height: 20),
          const Text(
            'Test in Progress',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete the walk and sit back down',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),
          GlassmorphicCard(
            glowColor: AppColors.neonGreen,
            glowIntensity: 0.2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, color: AppColors.neonGreen),
                SizedBox(width: 10),
                Text(
                  'Timing your movement...',
                  style: TextStyle(
                    color: AppColors.neonGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    final color = _getRiskColor();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          GlassmorphicCard(
            glowColor: color,
            glowIntensity: 0.2,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fall Risk Assessment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_riskLevel Risk',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _riskLevel == 'Low' ? Icons.check_circle : Icons.warning,
                      size: 48,
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.glassBorder),
                const SizedBox(height: 12),
                _buildScoreRangeInfo(),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          const Text(
            'Interpretation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getInterpretation(),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 20),
          
          GlassmorphicCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.save, color: AppColors.neonCyan),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Result saved to your health record',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(Icons.check, color: AppColors.neonGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRangeInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildRangeItem('< 10s', 'Low', AppColors.neonGreen),
        _buildRangeItem('10-19s', 'Moderate', AppColors.neonOrange),
        _buildRangeItem('20-29s', 'High', AppColors.neonRed),
        _buildRangeItem('≥ 30s', 'Very High', AppColors.neonRed),
      ],
    );
  }

  Widget _buildRangeItem(String range, String risk, Color color) {
    final isActive = _riskLevel == risk;
    return Column(
      children: [
        Text(
          range,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? color : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          risk,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? color : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getInterpretation() {
    switch (_riskLevel) {
      case 'Low':
        return 'Excellent mobility! Your movement speed and balance are within normal range. Continue with regular exercises to maintain your mobility.';
      case 'Moderate':
        return 'Your mobility shows some areas for improvement. Consider balance exercises and consult with your caregiver about a personalized exercise plan.';
      case 'High':
        return 'Your test indicates increased fall risk. We recommend using walking aids and discussing fall prevention strategies with your healthcare provider.';
      case 'Very High':
        return 'Your test indicates significant fall risk. Please use walking aids and consult your healthcare provider immediately for a comprehensive assessment.';
      default:
        return '';
    }
  }

  Widget _buildActionButton() {
    switch (_phase) {
      case TestPhase.ready:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, size: 24),
                SizedBox(width: 8),
                Text(
                  'START TEST',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      
      case TestPhase.running:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _stopTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stop, size: 24),
                SizedBox(width: 8),
                Text(
                  'STOP',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      
      case TestPhase.completed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetTest,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.textSecondary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Test Again',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
    }
  }
}

enum TestPhase { ready, running, completed }
