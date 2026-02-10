/// SMARTCARE+ Physio Profile Setup Screen
///
/// Multi-step form for collecting physiotherapy-specific patient data
/// needed by the exercise plan generator (medical history, affected joints,
/// lifestyle factors, baselines, and goals).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../providers/physio_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glassmorphic_card.dart';

class PhysioProfileSetupScreen extends ConsumerStatefulWidget {
  const PhysioProfileSetupScreen({super.key});

  @override
  ConsumerState<PhysioProfileSetupScreen> createState() =>
      _PhysioProfileSetupScreenState();
}

class _PhysioProfileSetupScreenState
    extends ConsumerState<PhysioProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSaving = false;
  bool _hasLoadedProfile = false;

  // ── Step 0: Basic Info ──────────────────────────────────────────────────────
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _gender = 'male';
  String _dateOfBirth = '';

  // ── Step 1: Medical History ─────────────────────────────────────────────────
  String _arthritisType = 'none';
  String _arthritisSeverity = 'none';
  bool _hasOsteoporosis = false;
  bool _hasCardiovascularIssues = false;
  bool _hasBalanceIssues = false;
  int _fallsLastYear = 0;
  bool _fearOfFalling = false;

  // ── Step 2: Affected Joints ─────────────────────────────────────────────────
  final List<Map<String, dynamic>> _affectedJoints = [];

  // ── Step 3: Lifestyle & Equipment ───────────────────────────────────────────
  String _activityLevel = 'lightly_active';
  String _mobilityLevel = 'independent';
  bool _hasChairForSupport = true;
  bool _hasWallForSupport = true;
  bool _livesAlone = false;

  // ── Step 4: Baselines & Goals ───────────────────────────────────────────────
  String _painTolerance = 'moderate';
  int _baselinePainLevel = 2;
  int _baselineFatigueLevel = 3;
  int _baselineMobilityScore = 50;
  String _primaryGoal = 'maintain_mobility';

  // ── Option lists ────────────────────────────────────────────────────────────
  static const _arthritisTypes = [
    {'value': 'none', 'label': 'None'},
    {'value': 'osteoarthritis', 'label': 'Osteoarthritis'},
    {'value': 'rheumatoid_arthritis', 'label': 'Rheumatoid Arthritis'},
    {'value': 'psoriatic_arthritis', 'label': 'Psoriatic Arthritis'},
    {'value': 'gout', 'label': 'Gout'},
    {'value': 'other', 'label': 'Other'},
  ];

  static const _severityLevels = [
    {'value': 'none', 'label': 'None'},
    {'value': 'mild', 'label': 'Mild'},
    {'value': 'moderate', 'label': 'Moderate'},
    {'value': 'severe', 'label': 'Severe'},
  ];

  static const _activityLevels = [
    {'value': 'sedentary', 'label': 'Sedentary'},
    {'value': 'lightly_active', 'label': 'Lightly Active'},
    {'value': 'moderately_active', 'label': 'Moderately Active'},
    {'value': 'active', 'label': 'Active'},
  ];

  static const _mobilityLevels = [
    {'value': 'independent', 'label': 'Independent'},
    {'value': 'needs_assistance', 'label': 'Needs Assistance'},
    {'value': 'wheelchair', 'label': 'Wheelchair'},
    {'value': 'bedridden', 'label': 'Bedridden'},
  ];

  static const _painToleranceLevels = [
    {'value': 'low', 'label': 'Low'},
    {'value': 'moderate', 'label': 'Moderate'},
    {'value': 'high', 'label': 'High'},
  ];

  static const _goalOptions = [
    {'value': 'maintain_mobility', 'label': 'Maintain Mobility'},
    {'value': 'reduce_pain', 'label': 'Reduce Pain'},
    {'value': 'improve_balance', 'label': 'Improve Balance'},
    {'value': 'increase_strength', 'label': 'Increase Strength'},
    {'value': 'fall_prevention', 'label': 'Fall Prevention'},
    {'value': 'post_surgery_recovery', 'label': 'Post-Surgery Recovery'},
  ];

  static const _jointLocations = [
    'left_knee', 'right_knee',
    'left_hip', 'right_hip',
    'left_shoulder', 'right_shoulder',
    'left_ankle', 'right_ankle',
    'left_wrist', 'right_wrist',
    'lower_back', 'neck',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingProfile();
    });
  }

  void _loadExistingProfile() {
    if (_hasLoadedProfile) return;
    _hasLoadedProfile = true;

    final profile = ref.read(physioProvider).patientProfile;
    if (profile == null) return;

    _firstNameController.text = profile.firstName ?? '';
    _lastNameController.text = profile.lastName ?? '';
    _heightController.text =
        profile.heightCm > 0 ? profile.heightCm.toString() : '';
    _weightController.text =
        profile.weightKg > 0 ? profile.weightKg.toString() : '';
    _gender = profile.gender ?? 'male';
    _dateOfBirth = profile.dateOfBirth ?? '';

    if (profile.medicalHistory != null) {
      final mh = profile.medicalHistory!;
      _arthritisType = mh.arthritisType;
      _arthritisSeverity = mh.arthritisSeverity;
      _hasOsteoporosis = mh.hasOsteoporosis;
      _hasCardiovascularIssues = mh.hasCardiovascularIssues;
      _hasBalanceIssues = mh.hasBalanceIssues;
      _fallsLastYear = mh.fallsLastYear;
      _fearOfFalling = mh.fearOfFalling;

      _affectedJoints.clear();
      for (final j in mh.affectedJoints) {
        _affectedJoints.add({
          'location': j.location,
          'severity': j.severity,
          'pain_level': j.painLevel,
        });
      }
    }

    if (profile.lifestyle != null) {
      final ls = profile.lifestyle!;
      _activityLevel = ls.activityLevel;
      _mobilityLevel = ls.mobilityLevel;
      _hasChairForSupport = ls.hasChairForSupport;
      _hasWallForSupport = ls.hasWallForSupport;
      _livesAlone = ls.livesAlone;
    }

    _painTolerance = profile.painTolerance;
    _baselinePainLevel = profile.baselinePainLevel;
    _baselineFatigueLevel = profile.baselineFatigueLevel;
    _baselineMobilityScore = profile.baselineMobilityScore;
    _primaryGoal = profile.primaryGoal;

    setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAVE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.uid ?? 'demo_user';

      final profileData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        if (_dateOfBirth.isNotEmpty) 'date_of_birth': _dateOfBirth,
        'gender': _gender,
        'height_cm': double.tryParse(_heightController.text) ?? 0,
        'weight_kg': double.tryParse(_weightController.text) ?? 0,
        'pain_tolerance': _painTolerance,
        'baseline_pain_level': _baselinePainLevel,
        'baseline_fatigue_level': _baselineFatigueLevel,
        'baseline_mobility_score': _baselineMobilityScore,
        'primary_goal': _primaryGoal,
        'medical_history': {
          'arthritis_type': _arthritisType,
          'arthritis_severity': _arthritisSeverity,
          'affected_joints': _affectedJoints,
          'has_osteoporosis': _hasOsteoporosis,
          'has_cardiovascular_issues': _hasCardiovascularIssues,
          'has_balance_issues': _hasBalanceIssues,
          'falls_last_year': _fallsLastYear,
          'fear_of_falling': _fearOfFalling,
        },
        'lifestyle': {
          'activity_level': _activityLevel,
          'mobility_level': _mobilityLevel,
          'has_chair_for_support': _hasChairForSupport,
          'has_wall_for_support': _hasWallForSupport,
          'lives_alone': _livesAlone,
        },
      };

      await ref
          .read(physioProvider.notifier)
          .updatePatientProfile(userId, profileData);

      // Also reload profile & BMI
      await ref.read(physioProvider.notifier).loadPatientProfile(userId);
      await ref.read(physioProvider.notifier).loadBMI(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Physio profile saved successfully!'),
            backgroundColor: AppColors.neonGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Basic Info',
      'Medical History',
      'Affected Joints',
      'Lifestyle',
      'Goals & Baselines',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Physio Profile Setup',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: List.generate(steps.length, (i) {
                final isActive = i == _currentStep;
                final isDone = i < _currentStep;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentStep = i),
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.neonGreen
                                : isActive
                                    ? AppColors.neonCyan
                                    : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          steps[i],
                          style: TextStyle(
                            fontSize: 9,
                            color: isActive
                                ? AppColors.neonCyan
                                : AppColors.textSecondary,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // Form content
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStep(),
              ),
            ),
          ),

          // Bottom buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.neonCyan),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back',
                            style: TextStyle(color: AppColors.neonCyan)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (_currentStep < steps.length - 1) {
                                setState(() => _currentStep++);
                              } else {
                                _saveProfile();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentStep == steps.length - 1
                            ? AppColors.neonGreen
                            : AppColors.neonCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              _currentStep == steps.length - 1
                                  ? 'Save Profile'
                                  : 'Next',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildMedicalHistoryStep();
      case 2:
        return _buildAffectedJointsStep();
      case 3:
        return _buildLifestyleStep();
      case 4:
        return _buildGoalsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 0 – Basic Info
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Personal Information',
            'Enter your basic details for personalized exercises'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(
                    'First Name', _firstNameController, Icons.person)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildTextField(
                    'Last Name', _lastNameController, Icons.person_outline)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Gender',
          _gender,
          [
            {'value': 'male', 'label': 'Male'},
            {'value': 'female', 'label': 'Female'},
            {'value': 'other', 'label': 'Other'},
          ],
          (v) => setState(() => _gender = v),
          icon: Icons.wc,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'Height (cm)',
                _heightController,
                Icons.height,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final h = double.tryParse(v);
                  if (h == null || h < 100 || h > 250) return '100–250 cm';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Weight (kg)',
                _weightController,
                Icons.monitor_weight,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final w = double.tryParse(v);
                  if (w == null || w < 30 || w > 300) return '30–300 kg';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1 – Medical History
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMedicalHistoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Medical History',
            'Help us understand your conditions for safe exercise planning'),
        const SizedBox(height: 16),
        _buildDropdown('Arthritis Type', _arthritisType, _arthritisTypes,
            (v) => setState(() => _arthritisType = v),
            icon: Icons.medical_services),
        const SizedBox(height: 12),
        _buildDropdown(
            'Arthritis Severity', _arthritisSeverity, _severityLevels,
            (v) => setState(() => _arthritisSeverity = v),
            icon: Icons.thermostat),
        const SizedBox(height: 20),
        _sectionSubheader('Health Conditions'),
        const SizedBox(height: 8),
        _buildToggleRow('Osteoporosis', _hasOsteoporosis,
            (v) => setState(() => _hasOsteoporosis = v),
            icon: Icons.broken_image_outlined),
        _buildToggleRow('Cardiovascular Issues', _hasCardiovascularIssues,
            (v) => setState(() => _hasCardiovascularIssues = v),
            icon: Icons.favorite),
        _buildToggleRow('Balance Issues', _hasBalanceIssues,
            (v) => setState(() => _hasBalanceIssues = v),
            icon: Icons.accessibility_new),
        _buildToggleRow('Fear of Falling', _fearOfFalling,
            (v) => setState(() => _fearOfFalling = v),
            icon: Icons.warning_amber),
        const SizedBox(height: 16),
        GlassmorphicCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.report_outlined,
                  color: AppColors.neonCyan, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Falls in the Last Year',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [0, 1, 2, 3].map((v) {
                        final selected = _fallsLastYear == v;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(v == 3 ? '3+' : '$v'),
                            selected: selected,
                            selectedColor: AppColors.neonCyan,
                            backgroundColor: AppColors.surfaceLight,
                            labelStyle: TextStyle(
                              color:
                                  selected ? Colors.black : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) =>
                                setState(() => _fallsLastYear = v),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2 – Affected Joints
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAffectedJointsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Affected Joints',
            'Select joints with pain or limited mobility to avoid unsafe exercises'),
        const SizedBox(height: 16),
        ..._affectedJoints.asMap().entries.map((entry) {
          final i = entry.key;
          final joint = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassmorphicCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.radio_button_checked,
                          color: AppColors.neonCyan, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatJointName(joint['location']),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.redAccent, size: 20),
                        onPressed: () =>
                            setState(() => _affectedJoints.removeAt(i)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _miniDropdown(
                          'Severity',
                          joint['severity'],
                          ['mild', 'moderate', 'severe'],
                          (v) => setState(() => joint['severity'] = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Pain: ${joint['pain_level']}/10',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                            Slider(
                              value: (joint['pain_level'] as int).toDouble(),
                              min: 0,
                              max: 10,
                              divisions: 10,
                              activeColor: AppColors.neonCyan,
                              onChanged: (v) =>
                                  setState(() => joint['pain_level'] = v.round()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        _buildAddJointButton(),
      ],
    );
  }

  Widget _buildAddJointButton() {
    // Filter out already-added joints
    final addedLocations =
        _affectedJoints.map((j) => j['location'] as String).toSet();
    final available =
        _jointLocations.where((l) => !addedLocations.contains(l)).toList();

    if (available.isEmpty) {
      return const Text('All joints added',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13));
    }

    return GestureDetector(
      onTap: () => _showJointPicker(available),
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_circle_outline, color: AppColors.neonCyan),
            SizedBox(width: 8),
            Text('Add Affected Joint',
                style: TextStyle(
                    color: AppColors.neonCyan, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showJointPicker(List<String> available) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Select Joint',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
                const Divider(color: AppColors.surfaceLight),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final loc = available[index];
                      return ListTile(
                        leading: const Icon(Icons.radio_button_unchecked, color: AppColors.neonCyan),
                        title: Text(_formatJointName(loc),
                            style: const TextStyle(color: AppColors.textPrimary)),
                        onTap: () {
                          setState(() {
                            _affectedJoints.add({
                              'location': loc,
                              'severity': 'mild',
                              'pain_level': 3,
                            });
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3 – Lifestyle & Equipment
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLifestyleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Lifestyle & Equipment',
            'Tell us about your daily activity and available support'),
        const SizedBox(height: 16),
        _buildDropdown('Activity Level', _activityLevel, _activityLevels,
            (v) => setState(() => _activityLevel = v),
            icon: Icons.directions_walk),
        const SizedBox(height: 12),
        _buildDropdown('Mobility Level', _mobilityLevel, _mobilityLevels,
            (v) => setState(() => _mobilityLevel = v),
            icon: Icons.accessible),
        const SizedBox(height: 20),
        _sectionSubheader('Available Equipment'),
        const SizedBox(height: 8),
        _buildToggleRow('Sturdy Chair for Support', _hasChairForSupport,
            (v) => setState(() => _hasChairForSupport = v),
            icon: Icons.chair),
        _buildToggleRow('Wall Nearby for Support', _hasWallForSupport,
            (v) => setState(() => _hasWallForSupport = v),
            icon: Icons.window),
        const SizedBox(height: 16),
        _sectionSubheader('Living Situation'),
        const SizedBox(height: 8),
        _buildToggleRow('Lives Alone', _livesAlone,
            (v) => setState(() => _livesAlone = v),
            icon: Icons.home),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4 – Goals & Baselines
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGoalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Goals & Baselines',
            'Set your goals and current condition for personalized planning'),
        const SizedBox(height: 16),
        _buildDropdown('Primary Goal', _primaryGoal, _goalOptions,
            (v) => setState(() => _primaryGoal = v),
            icon: Icons.flag),
        const SizedBox(height: 12),
        _buildDropdown(
            'Pain Tolerance', _painTolerance, _painToleranceLevels,
            (v) => setState(() => _painTolerance = v),
            icon: Icons.sentiment_neutral),
        const SizedBox(height: 20),
        _sectionSubheader('Current Baseline Levels'),
        const SizedBox(height: 12),
        _buildSliderCard('Baseline Pain Level', _baselinePainLevel, 0, 10,
            (v) => setState(() => _baselinePainLevel = v),
            icon: Icons.healing),
        const SizedBox(height: 10),
        _buildSliderCard(
            'Baseline Fatigue Level', _baselineFatigueLevel, 0, 10,
            (v) => setState(() => _baselineFatigueLevel = v),
            icon: Icons.battery_alert),
        const SizedBox(height: 10),
        _buildSliderCard(
            'Mobility Score', _baselineMobilityScore, 0, 100,
            (v) => setState(() => _baselineMobilityScore = v),
            icon: Icons.accessibility,
            divisions: 20,
            suffix: '/100'),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REUSABLE FORM WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _sectionSubheader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary));
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(icon, color: AppColors.neonCyan, size: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String currentValue,
    List<Map<String, String>> options,
    ValueChanged<String> onChanged, {
    IconData? icon,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: icon != null
              ? Icon(icon, color: AppColors.neonCyan, size: 20)
              : null,
          border: InputBorder.none,
        ),
        items: options
            .map((o) => DropdownMenuItem(
                  value: o['value'],
                  child: Text(o['label']!),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _miniDropdown(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          underline: Container(height: 1, color: AppColors.surfaceLight),
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o[0].toUpperCase() + o.substring(1)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _buildToggleRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.neonCyan, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textPrimary)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.neonCyan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderCard(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    IconData? icon,
    int? divisions,
    String? suffix,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.neonCyan, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
              Text('$value${suffix ?? '/$max'}',
                  style: const TextStyle(
                      color: AppColors.neonCyan, fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions ?? (max - min),
            activeColor: AppColors.neonCyan,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  String _formatJointName(String location) {
    return location
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
