/// SMARTCARE+ Profile Screens
///
/// Profile management screens for elderly, guardian, and caregiver users
/// Allows users to add/edit their information and emergency contacts

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glassmorphic_card.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ELDERLY PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class ElderlyProfileScreen extends ConsumerStatefulWidget {
  const ElderlyProfileScreen({super.key});

  @override
  ConsumerState<ElderlyProfileScreen> createState() => _ElderlyProfileScreenState();
}

class _ElderlyProfileScreenState extends ConsumerState<ElderlyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;
  
  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _medicalConditionsController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;
  late TextEditingController _dietaryRestrictionsController;
  late TextEditingController _addressController;
  
  String _selectedGender = 'Male';
  String _selectedBloodType = 'O+';
  String _selectedMobilityLevel = 'Independent';
  
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _mobilityLevels = ['Independent', 'Uses Cane', 'Uses Walker', 'Wheelchair', 'Needs Assistance'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    final elderlyData = profile?.elderlyProfile ?? {};
    
    _nameController = TextEditingController(text: profile?.name ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _ageController = TextEditingController(text: elderlyData['age']?.toString() ?? '');
    _heightController = TextEditingController(text: elderlyData['height']?.toString() ?? '');
    _weightController = TextEditingController(text: elderlyData['weight']?.toString() ?? '');
    _emergencyContactController = TextEditingController(text: elderlyData['emergency_contact_name'] ?? '');
    _emergencyPhoneController = TextEditingController(text: elderlyData['emergency_contact_phone'] ?? '');
    _medicalConditionsController = TextEditingController(text: elderlyData['medical_conditions'] ?? '');
    _allergiesController = TextEditingController(text: elderlyData['allergies'] ?? '');
    _medicationsController = TextEditingController(text: elderlyData['medications'] ?? '');
    _dietaryRestrictionsController = TextEditingController(text: elderlyData['dietary_restrictions'] ?? '');
    _addressController = TextEditingController(text: elderlyData['address'] ?? '');
    
    _selectedGender = elderlyData['gender'] ?? 'Male';
    _selectedBloodType = elderlyData['blood_type'] ?? 'O+';
    _selectedMobilityLevel = elderlyData['mobility_level'] ?? 'Independent';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _medicalConditionsController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _dietaryRestrictionsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final elderlyProfile = {
        'age': int.tryParse(_ageController.text) ?? 0,
        'gender': _selectedGender,
        'height': double.tryParse(_heightController.text) ?? 0,
        'weight': double.tryParse(_weightController.text) ?? 0,
        'blood_type': _selectedBloodType,
        'mobility_level': _selectedMobilityLevel,
        'emergency_contact_name': _emergencyContactController.text,
        'emergency_contact_phone': _emergencyPhoneController.text,
        'medical_conditions': _medicalConditionsController.text,
        'allergies': _allergiesController.text,
        'medications': _medicationsController.text,
        'dietary_restrictions': _dietaryRestrictionsController.text,
        'address': _addressController.text,
      };
      
      await ref.read(authProvider.notifier).updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
        elderlyProfile: elderlyProfile,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: AppColors.neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: AppColors.neonRed),
        );
      }
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Personal Information', Icons.person),
                        const SizedBox(height: 12),
                        _buildTextField(_nameController, 'Full Name', Icons.badge, required: true),
                        _buildTextField(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_ageController, 'Age', Icons.cake, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDropdown('Gender', _selectedGender, _genders, (v) => setState(() => _selectedGender = v!))),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_heightController, 'Height (cm)', Icons.height, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(_weightController, 'Weight (kg)', Icons.monitor_weight, keyboardType: TextInputType.number)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildDropdown('Blood Type', _selectedBloodType, _bloodTypes, (v) => setState(() => _selectedBloodType = v!))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDropdown('Mobility', _selectedMobilityLevel, _mobilityLevels, (v) => setState(() => _selectedMobilityLevel = v!))),
                          ],
                        ),
                        _buildTextField(_addressController, 'Home Address', Icons.home, maxLines: 2),
                        
                        const SizedBox(height: 24),
                        _buildSectionTitle('Emergency Contact', Icons.emergency),
                        const SizedBox(height: 12),
                        _buildTextField(_emergencyContactController, 'Contact Name', Icons.person_outline, required: true),
                        _buildTextField(_emergencyPhoneController, 'Contact Phone', Icons.phone_callback, keyboardType: TextInputType.phone, required: true),
                        
                        const SizedBox(height: 24),
                        _buildSectionTitle('Medical Information', Icons.medical_information),
                        const SizedBox(height: 12),
                        _buildTextField(_medicalConditionsController, 'Medical Conditions', Icons.local_hospital, maxLines: 3, hint: 'e.g., Diabetes, Hypertension, Arthritis'),
                        _buildTextField(_allergiesController, 'Allergies', Icons.warning_amber, maxLines: 2, hint: 'e.g., Penicillin, Peanuts'),
                        _buildTextField(_medicationsController, 'Current Medications', Icons.medication, maxLines: 3, hint: 'e.g., Metformin 500mg, Aspirin 81mg'),
                        _buildTextField(_dietaryRestrictionsController, 'Dietary Restrictions', Icons.restaurant, maxLines: 2, hint: 'e.g., Low sodium, Diabetic diet'),
                        
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('My Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.elderly, color: AppColors.neonCyan, size: 24),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonCyan, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
  
  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.neonCyan),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.neonCyan)),
        ),
        validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
      ),
    );
  }
  
  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary),
        dropdownColor: AppColors.surface,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
  
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// GUARDIAN PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class GuardianProfileScreen extends ConsumerStatefulWidget {
  const GuardianProfileScreen({super.key});

  @override
  ConsumerState<GuardianProfileScreen> createState() => _GuardianProfileScreenState();
}

class _GuardianProfileScreenState extends ConsumerState<GuardianProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _relationshipController;
  late TextEditingController _addressController;
  late TextEditingController _workPhoneController;
  
  bool _receiveAlerts = true;
  bool _receiveFallAlerts = true;
  bool _receiveInactivityAlerts = true;
  bool _receiveGeofenceAlerts = true;
  bool _receiveMedicationReminders = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    final guardianData = profile?.guardianProfile ?? {};
    
    _nameController = TextEditingController(text: profile?.name ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
    _relationshipController = TextEditingController(text: guardianData['relationship'] ?? '');
    _addressController = TextEditingController(text: guardianData['address'] ?? '');
    _workPhoneController = TextEditingController(text: guardianData['work_phone'] ?? '');
    
    _receiveAlerts = guardianData['receive_alerts'] ?? true;
    _receiveFallAlerts = guardianData['receive_fall_alerts'] ?? true;
    _receiveInactivityAlerts = guardianData['receive_inactivity_alerts'] ?? true;
    _receiveGeofenceAlerts = guardianData['receive_geofence_alerts'] ?? true;
    _receiveMedicationReminders = guardianData['receive_medication_reminders'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _relationshipController.dispose();
    _addressController.dispose();
    _workPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final guardianProfile = {
        'relationship': _relationshipController.text,
        'address': _addressController.text,
        'work_phone': _workPhoneController.text,
        'receive_alerts': _receiveAlerts,
        'receive_fall_alerts': _receiveFallAlerts,
        'receive_inactivity_alerts': _receiveInactivityAlerts,
        'receive_geofence_alerts': _receiveGeofenceAlerts,
        'receive_medication_reminders': _receiveMedicationReminders,
      };
      
      await ref.read(authProvider.notifier).updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
        guardianProfile: guardianProfile,
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: AppColors.neonGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: AppColors.neonRed),
        );
      }
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Personal Information', Icons.person),
                        const SizedBox(height: 12),
                        _buildTextField(_nameController, 'Full Name', Icons.badge, required: true),
                        _buildTextField(_phoneController, 'Mobile Phone', Icons.phone, keyboardType: TextInputType.phone, required: true),
                        _buildTextField(_workPhoneController, 'Work Phone (Optional)', Icons.phone_android, keyboardType: TextInputType.phone),
                        _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                        _buildTextField(_relationshipController, 'Relationship to Elderly', Icons.family_restroom, hint: 'e.g., Son, Daughter, Spouse'),
                        _buildTextField(_addressController, 'Address', Icons.home, maxLines: 2),
                        
                        const SizedBox(height: 24),
                        _buildSectionTitle('Notification Preferences', Icons.notifications),
                        const SizedBox(height: 12),
                        _buildAlertInfo(),
                        const SizedBox(height: 12),
                        _buildSwitch('Receive All Alerts', _receiveAlerts, (v) => setState(() => _receiveAlerts = v)),
                        _buildSwitch('Fall Detection Alerts', _receiveFallAlerts, (v) => setState(() => _receiveFallAlerts = v)),
                        _buildSwitch('Inactivity Alerts', _receiveInactivityAlerts, (v) => setState(() => _receiveInactivityAlerts = v)),
                        _buildSwitch('Geofence Alerts', _receiveGeofenceAlerts, (v) => setState(() => _receiveGeofenceAlerts = v)),
                        _buildSwitch('Medication Reminders', _receiveMedicationReminders, (v) => setState(() => _receiveMedicationReminders = v)),
                        
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Guardian Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.neonRed.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shield, color: AppColors.neonRed, size: 24),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonCyan, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
  
  Widget _buildAlertInfo() {
    return GlassmorphicCard(
      glowColor: AppColors.neonOrange,
      glowIntensity: 0.1,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.neonOrange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your phone number will be used for emergency SMS alerts when falls or critical events are detected.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.neonCyan),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.neonCyan)),
        ),
        validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
      ),
    );
  }
  
  Widget _buildSwitch(String label, bool value, void Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textPrimary)),
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
  
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// CAREGIVER PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class CaregiverProfileScreen extends ConsumerStatefulWidget {
  const CaregiverProfileScreen({super.key});

  @override
  ConsumerState<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends ConsumerState<CaregiverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _qualificationsController;
  late TextEditingController _experienceController;
  late TextEditingController _specialtiesController;
  late TextEditingController _organizationController;
  late TextEditingController _licenseNumberController;
  
  bool _availableForEmergency = true;
  String _caregiverType = 'Professional';
  
  final List<String> _caregiverTypes = ['Professional', 'Family', 'Volunteer'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    final caregiverData = profile?.guardianProfile ?? {}; // Using guardianProfile for caregivers too
    
    _nameController = TextEditingController(text: profile?.name ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
    _qualificationsController = TextEditingController(text: caregiverData['qualifications'] ?? '');
    _experienceController = TextEditingController(text: caregiverData['experience'] ?? '');
    _specialtiesController = TextEditingController(text: caregiverData['specialties'] ?? '');
    _organizationController = TextEditingController(text: caregiverData['organization'] ?? '');
    _licenseNumberController = TextEditingController(text: caregiverData['license_number'] ?? '');
    
    _caregiverType = caregiverData['caregiver_type'] ?? 'Professional';
    _availableForEmergency = caregiverData['available_for_emergency'] ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _qualificationsController.dispose();
    _experienceController.dispose();
    _specialtiesController.dispose();
    _organizationController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final caregiverProfile = {
        'caregiver_type': _caregiverType,
        'qualifications': _qualificationsController.text,
        'experience': _experienceController.text,
        'specialties': _specialtiesController.text,
        'organization': _organizationController.text,
        'license_number': _licenseNumberController.text,
        'available_for_emergency': _availableForEmergency,
      };
      
      await ref.read(authProvider.notifier).updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
        guardianProfile: caregiverProfile, // Store under guardianProfile
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: AppColors.neonGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: AppColors.neonRed),
        );
      }
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Personal Information', Icons.person),
                        const SizedBox(height: 12),
                        _buildTextField(_nameController, 'Full Name', Icons.badge, required: true),
                        _buildTextField(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone, required: true),
                        _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                        _buildDropdown('Caregiver Type', _caregiverType, _caregiverTypes, (v) => setState(() => _caregiverType = v!)),
                        
                        const SizedBox(height: 24),
                        _buildSectionTitle('Professional Information', Icons.work),
                        const SizedBox(height: 12),
                        _buildTextField(_organizationController, 'Organization/Agency', Icons.business, hint: 'e.g., Home Care Plus'),
                        _buildTextField(_qualificationsController, 'Qualifications', Icons.school, maxLines: 2, hint: 'e.g., CNA, RN, Home Health Aide'),
                        _buildTextField(_experienceController, 'Years of Experience', Icons.timeline, keyboardType: TextInputType.number),
                        _buildTextField(_specialtiesController, 'Specialties', Icons.star, maxLines: 2, hint: 'e.g., Dementia care, Mobility assistance'),
                        _buildTextField(_licenseNumberController, 'License/Certification Number', Icons.verified_user),
                        
                        const SizedBox(height: 24),
                        _buildSectionTitle('Availability', Icons.access_time),
                        const SizedBox(height: 12),
                        _buildEmergencyInfo(),
                        const SizedBox(height: 12),
                        _buildSwitch('Available for Emergency Calls', _availableForEmergency, (v) => setState(() => _availableForEmergency = v)),
                        
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Caregiver Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.neonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.health_and_safety, color: AppColors.neonGreen, size: 24),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonCyan, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
  
  Widget _buildEmergencyInfo() {
    return GlassmorphicCard(
      glowColor: AppColors.neonGreen,
      glowIntensity: 0.1,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk, color: AppColors.neonGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'When enabled, you may receive emergency calls when the elderly needs immediate assistance.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.neonCyan),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.neonCyan)),
        ),
        validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
      ),
    );
  }
  
  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary),
        dropdownColor: AppColors.surface,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
  
  Widget _buildSwitch(String label, bool value, void Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary))),
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
  
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
