import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../app/colors.dart';
import '../../core/formatters.dart';
import '../../data/local_store.dart';
import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/pincode_service.dart';
import '../../services/reminder_service.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  late String _tempUnit;
  late bool _criticalAlerts;
  late bool _maintenanceReminders;

  @override
  void initState() {
    super.initState();
    final box = Hive.box(Boxes.settings);
    _tempUnit = box.get('tempUnit', defaultValue: '°C') as String;
    _criticalAlerts = box.get('criticalAlertsEnabled', defaultValue: true) as bool;
    _maintenanceReminders = box.get('maintenanceRemindersEnabled', defaultValue: true) as bool;
  }

  /// Toggles take effect immediately: re-sync scheduled notifications so a
  /// disabled channel actually stops firing without an app restart.
  void _resyncNotifications() {
    NotificationService.instance.syncReminders(ref.read(remindersProvider));
  }

  void _openRiderEditor() {
    final settings = ref.read(settingsProvider);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RiderEditDialog(initial: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final bikeCount = ref.watch(bikesProvider).length;
    final box = Hive.box(Boxes.settings);

    return Scaffold(
      backgroundColor: AppColors.darkBlack,
      body: ListView(
        key: const ValueKey('profile_screen_lazy_column'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Avatar block
          Card(
            color: AppColors.surfacePanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            child: InkWell(
              onTap: _openRiderEditor,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.surfaceLight,
                      radius: 36,
                      child: Icon(
                        Icons.person,
                        color: AppColors.accentCopper,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.riderName ?? "Rider",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$bikeCount ${bikeCount == 1 ? 'Machine' : 'Machines'}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Cockpit Preferences
          const Text(
            "COCKPIT PREFERENCES",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextZinc,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            color: AppColors.surfacePanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Distance & Speed
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.linear_scale, color: AppColors.labelZinc, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "Distance & Speed Unit",
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.darkBlack,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outlineGray),
                        ),
                        child: Row(
                          children: [
                            _UnitToggleBtn(
                              label: "Km",
                              isSelected: settings.distanceUnit == DistanceUnit.km,
                              onTap: () => notifier.setDistanceUnit(DistanceUnit.km),
                            ),
                            _UnitToggleBtn(
                              label: "Miles",
                              isSelected: settings.distanceUnit == DistanceUnit.mi,
                              onTap: () => notifier.setDistanceUnit(DistanceUnit.mi),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Temperature
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.thermostat, color: AppColors.labelZinc, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "Temperature Unit",
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.darkBlack,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outlineGray),
                        ),
                        child: Row(
                          children: [
                            _UnitToggleBtn(
                              label: "°C",
                              isSelected: _tempUnit == "°C",
                              onTap: () {
                                setState(() => _tempUnit = "°C");
                                box.put('tempUnit', "°C");
                              },
                            ),
                            _UnitToggleBtn(
                              label: "°F",
                              isSelected: _tempUnit == "°F",
                              onTap: () {
                                setState(() => _tempUnit = "°F");
                                box.put('tempUnit', "°F");
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Vehicle Notifications
          const Text(
            "VEHICLE NOTIFICATIONS",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.subtextZinc,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            color: AppColors.surfacePanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _NotificationToggleRow(
                    title: "Critical Alerts",
                    subtitle: "Overdue maintenance items",
                    checked: _criticalAlerts,
                    onChanged: (val) {
                      setState(() => _criticalAlerts = val);
                      box.put('criticalAlertsEnabled', val);
                      _resyncNotifications();
                    },
                  ),
                  const Divider(color: AppColors.outlineGray, height: 24),
                  _NotificationToggleRow(
                    title: "Maintenance Reminders",
                    subtitle: "Upcoming service items, before they're due",
                    checked: _maintenanceReminders,
                    onChanged: (val) {
                      setState(() => _maintenanceReminders = val);
                      box.put('maintenanceRemindersEnabled', val);
                      _resyncNotifications();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sign Out Button
          OutlinedButton.icon(
            key: const ValueKey('sign_out_button'),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                      'Your data stays safely in the cloud and will be restored when you sign back in.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out')),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authServiceProvider).signOut();
              }
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.dangerRed.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.dangerRed.withValues(alpha: 0.07),
            ),
            icon: const Icon(Icons.exit_to_app, color: AppColors.dangerRed),
            label: const Text(
              "Sign Out",
              style: TextStyle(color: AppColors.dangerRed, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _UnitToggleBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitToggleBtn({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.onPrimaryText : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleRow({
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.replaceAll(" ", "_").toLowerCase();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.subtextZinc, fontSize: 13),
              ),
            ],
          ),
        ),
        Switch(
          key: ValueKey('toggle_$cleanTitle'),
          value: checked,
          onChanged: onChanged,
          activeThumbColor: AppColors.onPrimaryText,
          activeTrackColor: AppColors.primaryOrange,
          inactiveThumbColor: AppColors.subtextZinc,
          inactiveTrackColor: AppColors.darkBlack,
        ),
      ],
    );
  }
}

class _RiderEditDialog extends ConsumerStatefulWidget {
  final AppSettings initial;
  const _RiderEditDialog({required this.initial});

  @override
  ConsumerState<_RiderEditDialog> createState() => _RiderEditDialogState();
}

class _RiderEditDialogState extends ConsumerState<_RiderEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _professionCtrl;
  late final TextEditingController _pincodeCtrl;

  late RiderGender? _gender;
  late DateTime? _dob;
  String? _state;
  String? _city;
  bool _pinVerified = false;
  bool _saving = false;
  bool _verifyingPin = false;
  String? _pinError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _nameCtrl = TextEditingController(text: s.riderName ?? '');
    _phoneCtrl = TextEditingController(text: s.riderPhone ?? '');
    _professionCtrl = TextEditingController(text: s.riderProfession ?? '');
    _pincodeCtrl = TextEditingController(text: s.riderPincode ?? '');
    _gender = s.riderGender;
    _dob = s.riderDateOfBirth;
    _state = s.riderState;
    _city = s.riderCity;
    _pinVerified = s.riderPincode != null &&
        s.riderState != null &&
        s.riderCity != null;
    _pincodeCtrl.addListener(_onPincodeChanged);
  }

  void _onPincodeChanged() {
    final pin = _pincodeCtrl.text.trim();
    if (pin == (widget.initial.riderPincode ?? '')) {
      setState(() {
        _pinVerified = widget.initial.riderPincode != null;
        _state = widget.initial.riderState;
        _city = widget.initial.riderCity;
        _pinError = null;
      });
    } else {
      setState(() {
        _pinVerified = false;
        _state = null;
        _city = null;
        _pinError = null;
      });
    }
  }

  @override
  void dispose() {
    _pincodeCtrl.removeListener(_onPincodeChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _professionCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyPincode() async {
    final pin = _pincodeCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() {
        _pinVerified = true;
        _state = null;
        _city = null;
        _pinError = null;
      });
      return;
    }
    if (!PincodeService.isValidFormat(pin)) {
      setState(() => _pinError = 'Enter a valid 6-digit Indian PIN code.');
      return;
    }
    setState(() {
      _verifyingPin = true;
      _pinError = null;
    });
    try {
      final result = await PincodeService.lookup(pin);
      if (!mounted) return;
      setState(() {
        _verifyingPin = false;
        _pinVerified = true;
        _state = result.state;
        _city = result.city;
      });
    } on PincodeLookupException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyingPin = false;
        _pinVerified = false;
        _pinError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifyingPin = false;
        _pinVerified = false;
        _pinError = 'Could not look up PIN code. Try again.';
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'Rider name is required.');
      return;
    }

    final pin = _pincodeCtrl.text.trim();
    if (pin.isNotEmpty) {
      if (!PincodeService.isValidFormat(pin)) {
        setState(() => _saveError = 'Enter a valid 6-digit PIN code.');
        return;
      }
      if (!_pinVerified) {
        await _verifyPincode();
        if (!_pinVerified) {
          setState(() => _saveError = _pinError ?? 'Verify PIN code before saving.');
          return;
        }
      }
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await ref.read(settingsProvider.notifier).saveRiderProfile(
            riderName: name,
            riderGender: _gender,
            riderDateOfBirth: _dob,
            riderPhone: _phoneCtrl.text.trim(),
            riderProfession: _professionCtrl.text.trim(),
            riderPincode: pin.isEmpty ? null : pin,
            riderState: pin.isEmpty ? null : _state,
            riderCity: pin.isEmpty ? null : _city,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not save profile. Try again.';
        });
      }
    }
  }

  void _discard() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit rider profile',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : _discard,
                    icon: const Icon(Icons.close),
                    tooltip: 'Discard',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Rider name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Gender',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<RiderGender>(
                      segments: const [
                        ButtonSegment(
                          value: RiderGender.male,
                          label: Text('Male'),
                        ),
                        ButtonSegment(
                          value: RiderGender.female,
                          label: Text('Female'),
                        ),
                        ButtonSegment(
                          value: RiderGender.other,
                          label: Text('Other'),
                        ),
                      ],
                      selected: _gender != null ? {_gender!} : {},
                      emptySelectionAllowed: true,
                      onSelectionChanged: (s) => setState(
                        () => _gender = s.isEmpty ? null : s.first,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cake_outlined),
                      title: const Text('Date of birth'),
                      subtitle: Text(
                        _dob != null ? formatDate(_dob!) : 'Not set',
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _dob ?? DateTime(DateTime.now().year - 25),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _dob = picked);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: '9876543210',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _professionCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Profession',
                        prefixIcon: Icon(Icons.work_outline),
                        hintText: 'e.g. Software engineer',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pincodeCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'PIN code',
                              prefixIcon: Icon(Icons.pin_outlined),
                              hintText: '560041',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton(
                            onPressed:
                                _verifyingPin || _saving ? null : _verifyPincode,
                            child: _verifyingPin
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Verify'),
                          ),
                        ),
                      ],
                    ),
                    if (_pinError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _pinError!,
                          style: TextStyle(color: scheme.error, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'State',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      child: Text(
                        _state ?? 'Verify PIN code to fill',
                        style: TextStyle(
                          color: _state != null
                              ? null
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      child: Text(
                        _city ?? 'Verify PIN code to fill',
                        style: TextStyle(
                          color: _city != null
                              ? null
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _saveError!,
                        style: TextStyle(color: scheme.error, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _discard,
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save'),
                    ),
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
