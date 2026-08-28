import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/colors.dart';
import '../../core/formatters.dart';
import '../../core/units.dart';
import '../../data/models/bike.dart';
import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/maintenance_schedule_provider.dart';
import '../bikes/widgets/bike_catalog_pickers.dart';

class RiderOnboardingScreen extends ConsumerStatefulWidget {
  const RiderOnboardingScreen({super.key});

  @override
  ConsumerState<RiderOnboardingScreen> createState() =>
      _RiderOnboardingScreenState();
}

class _RiderOnboardingScreenState extends ConsumerState<RiderOnboardingScreen> {
  int _currentStep = 1;
  bool _saving = false;
  String _errorText = '';

  // Step 1 Controllers
  final _fullNameCtrl = TextEditingController();
  RiderGender _gender = RiderGender.male;
  DateTime? _dob;

  // Step 2 Controllers
  final _nicknameCtrl = TextEditingController();
  final _odometerCtrl = TextEditingController();

  String? _brandId;
  String? _modelId;
  int? _modelYear;
  String _selectedBikeType = 'Sport';

  final List<String> _types = ["Sport", "Naked", "Cruiser", "Adventure", "Touring"];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _nicknameCtrl.dispose();
    _odometerCtrl.dispose();
    super.dispose();
  }

  void _onCompleteStep1() {
    final name = _fullNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = "Please enter your full name");
      return;
    }
    if (_dob == null) {
      setState(() => _errorText = "Date of birth is required");
      return;
    }

    final today = DateTime.now();
    final age = today.year -
        _dob!.year -
        ((today.month < _dob!.month ||
                (today.month == _dob!.month && today.day < _dob!.day))
            ? 1
            : 0);

    if (_dob!.isAfter(today)) {
      setState(() => _errorText = 'Date of birth cannot be in the future');
      return;
    }
    if (age < 16) {
      setState(() => _errorText = 'You must be at least 16 years old');
      return;
    }
    if (age > 100) {
      setState(() => _errorText = 'Enter a valid date of birth');
      return;
    }

    setState(() {
      _errorText = '';
      _currentStep = 2;
    });
  }

  void _onCompleteStep2() {
    final nickname = _nicknameCtrl.text.trim();
    final odometerStr = _odometerCtrl.text.trim();
    final odoValue = double.tryParse(odometerStr);

    if (nickname.isEmpty) {
      setState(() => _errorText = "Please enter a bike nickname");
      return;
    }
    if (_brandId == null) {
      setState(() => _errorText = "Please select a manufacturer");
      return;
    }
    if (_modelId == null) {
      setState(() => _errorText = "Please select a model");
      return;
    }
    if (_modelYear == null) {
      setState(() => _errorText = "Please select a model year");
      return;
    }
    if (odoValue == null || odoValue < 0) {
      setState(() => _errorText = "Please enter a valid positive odometer");
      return;
    }

    final brands = ref.read(brandsProvider);
    final models = ref.read(modelsForBrandProvider(_brandId));
    final brand = brands.where((b) => b.id == _brandId).firstOrNull;
    final model = models.where((m) => m.id == _modelId).firstOrNull;
    if (brand == null || model == null) {
      setState(() => _errorText = "Invalid manufacturer or model selection");
      return;
    }

    final unit = ref.read(settingsProvider).distanceUnit;
    final odoKm = unit.toKm(odoValue);

    setState(() {
      _saving = true;
      _errorText = '';
    });

    ref
        .read(settingsProvider.notifier)
        .saveRiderBasics(
          riderName: _fullNameCtrl.text.trim(),
          riderGender: _gender,
          riderDateOfBirth: _dob!,
        )
        .then((_) {
      final bike = Bike(
        id: const Uuid().v4(),
        name: nickname,
        make: brand.name,
        model: model.name,
        brandId: brand.id,
        modelId: model.id,
        year: _modelYear,
        type: _bikeTypeFromString(_selectedBikeType),
        odometerKm: odoKm,
        createdAt: DateTime.now(),
      );

      ref.read(bikesProvider.notifier).save(bike);
      ref.read(garageSelectedBikeIdProvider.notifier).state = bike.id;
    }).catchError((err) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = "Could not save profile. Try again.";
        });
      }
    });
  }

  BikeType _bikeTypeFromString(String val) {
    return BikeType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => BikeType.other,
    );
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(DateTime.now().year - 25, 1, 1),
      firstDate: DateTime(DateTime.now().year - 100),
      lastDate: DateTime.now(),
      helpText: 'Select date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryOrange,
                  onPrimary: AppColors.onPrimaryText,
                  surface: AppColors.surfacePanel,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.darkBlack,
        appBar: AppBar(
          backgroundColor: AppColors.darkBlack,
          centerTitle: true,
          title: Text(
            _currentStep == 1 ? "Step 1 of 3" : "Step 2 of 3",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryOrange,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_currentStep == 2) {
                setState(() => _currentStep = 1);
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Progress Track Visuals
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 1 ? AppColors.primaryOrange : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentStep >= 2 ? AppColors.primaryOrange : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_currentStep == 1) ...[
                // Rider Profile Step
                const Text(
                  "Rider Profile Setup",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Personalize your telemetry dashboard and community identity.",
                  style: TextStyle(color: AppColors.subtextZinc, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                Card(
                  color: AppColors.surfacePanel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.outlineGray),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Full Name *",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fullNameCtrl,
                          key: const ValueKey('name_input_field'),
                          decoration: const InputDecoration(
                            hintText: 'E.g. Rossi',
                            prefixIcon: Icon(Icons.person, color: AppColors.accentCopper),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          "Gender Identity",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _GenderBox(
                              gender: RiderGender.male,
                              label: "Male",
                              selectedGender: _gender,
                              onTap: () => setState(() => _gender = RiderGender.male),
                            ),
                            const SizedBox(width: 10),
                            _GenderBox(
                              gender: RiderGender.female,
                              label: "Female",
                              selectedGender: _gender,
                              onTap: () => setState(() => _gender = RiderGender.female),
                            ),
                            const SizedBox(width: 10),
                            _GenderBox(
                              gender: RiderGender.other,
                              label: "Other",
                              selectedGender: _gender,
                              onTap: () => setState(() => _gender = RiderGender.other),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          "Date of Birth (dd-mm-yyyy)",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const ValueKey('dob_input_field'),
                          readOnly: true,
                          onTap: _pickDob,
                          decoration: const InputDecoration(
                            hintText: 'dd-mm-yyyy',
                            prefixIcon: Icon(Icons.calendar_today, color: AppColors.accentCopper),
                          ),
                          controller: TextEditingController(
                            text: _dob != null ? formatDate(_dob!) : '',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_errorText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText,
                    style: const TextStyle(color: AppColors.dangerRed),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 40),

                FilledButton(
                  key: const ValueKey('continue_setup_button'),
                  onPressed: _onCompleteStep1,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Continue Setup",
                        style: TextStyle(color: AppColors.onPrimaryText, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: AppColors.onPrimaryText, size: 18),
                    ],
                  ),
                ),
              ] else ...[
                // Step 2: Add First Bike
                const Text(
                  "Add First Bike",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Identification card
                Card(
                  color: AppColors.surfacePanel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.outlineGray),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge, color: AppColors.accentCopper, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "IDENTIFICATION",
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          "Bike Nickname",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nicknameCtrl,
                          key: const ValueKey('bike_nickname_input'),
                          decoration: const InputDecoration(
                            hintText: 'e.g. Night Rider',
                          ),
                        ),
                        const SizedBox(height: 16),

                        BikeCatalogPickers(
                          brandId: _brandId,
                          modelId: _modelId,
                          modelYear: _modelYear,
                          brandKey: const ValueKey('manufacturer_dropdown'),
                          modelKey: const ValueKey('bike_model_input'),
                          modelYearKey: const ValueKey('bike_year_input'),
                          onBrandChanged: (value) => setState(() => _brandId = value),
                          onModelChanged: (value) => setState(() => _modelId = value),
                          onModelYearChanged: (value) => setState(() => _modelYear = value),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          "Bike Type",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: const ValueKey('bike_type_dropdown'),
                          initialValue: _selectedBikeType,
                          dropdownColor: AppColors.surfaceLight,
                          items: _types
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t, style: const TextStyle(color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedBikeType = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Usage card
                Card(
                  color: AppColors.surfacePanel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.outlineGray),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.speed, color: AppColors.accentCopper, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "USAGE",
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          "Current Odometer (Km)",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _odometerCtrl,
                          key: const ValueKey('bike_odometer_input'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: 'e.g. 12500',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_errorText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText,
                    style: const TextStyle(color: AppColors.dangerRed),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 40),

                FilledButton(
                  key: const ValueKey('add_bike_button'),
                  onPressed: _saving ? null : _onCompleteStep2,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Add Bike",
                          style: TextStyle(color: AppColors.onPrimaryText, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderBox extends StatelessWidget {
  final RiderGender gender;
  final String label;
  final RiderGender selectedGender;
  final VoidCallback onTap;

  const _GenderBox({
    required this.gender,
    required this.label,
    required this.selectedGender,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedGender == gender;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceLight : AppColors.darkBlack,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryOrange : AppColors.outlineGray,
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primaryOrange : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
