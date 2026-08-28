import 'dart:async';



import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hive/hive.dart';



import '../data/local_store.dart';

import '../data/models/enums.dart';

import '../data/models/rider_profile.dart';

import '../services/auth_service.dart';

import '../services/pincode_service.dart';

import '../services/rider_profile_service.dart';



class AppSettings {

  final DistanceUnit distanceUnit;

  final RiderProfile riderProfile;

  final bool riderProfileLoaded;



  const AppSettings({

    this.distanceUnit = DistanceUnit.km,

    this.riderProfile = const RiderProfile(),

    this.riderProfileLoaded = false,

  });



  String? get riderName => riderProfile.name;

  String? get riderPhone => riderProfile.phone;

  String? get riderCity => riderProfile.city;

  DateTime? get riderDateOfBirth => riderProfile.dateOfBirth;

  RiderGender? get riderGender => riderProfile.gender;

  String? get riderProfession => riderProfile.profession;

  String? get riderState => riderProfile.state;

  String? get riderPincode => riderProfile.pincode;



  bool get isRiderProfileComplete => riderProfile.isComplete;



  AppSettings copyWith({

    DistanceUnit? distanceUnit,

    RiderProfile? riderProfile,

    bool? riderProfileLoaded,

  }) =>

      AppSettings(

        distanceUnit: distanceUnit ?? this.distanceUnit,

        riderProfile: riderProfile ?? this.riderProfile,

        riderProfileLoaded: riderProfileLoaded ?? this.riderProfileLoaded,

      );

}



class SettingsNotifier extends StateNotifier<AppSettings> {

  SettingsNotifier(this._ref) : super(const AppSettings()) {

    _loadDistanceUnit();

    _ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {

      _onAuthChanged(next.valueOrNull);

    }, fireImmediately: true);

  }



  final Ref _ref;

  StreamSubscription<RiderProfile?>? _profileSub;

  String? _uid;



  Box get _box => Hive.box(Boxes.settings);



  RiderProfileService get _riderService =>

      _ref.read(riderProfileServiceProvider);



  void _loadDistanceUnit() {

    state = state.copyWith(

      distanceUnit: DistanceUnit.values.firstWhere(

        (e) => e.name == _box.get('distanceUnit'),

        orElse: () => DistanceUnit.km,

      ),

    );

  }



  Future<void> _onAuthChanged(User? user) async {

    await _profileSub?.cancel();

    _profileSub = null;

    _uid = user?.uid;



    if (user == null) {

      state = state.copyWith(

        riderProfile: const RiderProfile(),

        riderProfileLoaded: true,

      );

      return;

    }



    state = state.copyWith(riderProfileLoaded: false);



    await _migrateLegacyHiveProfile(user.uid);



    _profileSub = _riderService.watch(user.uid).listen(

      (profile) {

        state = state.copyWith(

          riderProfile: profile ?? const RiderProfile(),

          riderProfileLoaded: true,

        );

      },

      onError: (_) {

        state = state.copyWith(riderProfileLoaded: true);

      },

    );

  }



  /// One-time migration: push legacy Hive rider fields to Firestore, then clear Hive.

  Future<void> _migrateLegacyHiveProfile(String uid) async {

    final legacyName = _box.get('riderName') as String?;

    if (legacyName == null || legacyName.trim().isEmpty) return;



    final existing = await _riderService.get(uid);

    if (existing != null && existing.isComplete) {

      await _clearLegacyHiveRiderFields();

      return;

    }



    final dobRaw = _box.get('riderDateOfBirth') as String?;

    final genderRaw = _box.get('riderGender') as String?;

    final gender = genderRaw == null

        ? null

        : RiderGender.values.where((g) => g.name == genderRaw).firstOrNull;



    final profile = RiderProfile(

      name: legacyName.trim(),

      gender: gender,

      dateOfBirth: dobRaw != null ? DateTime.tryParse(dobRaw) : null,

      phone: _box.get('riderPhone') as String?,

      profession: _box.get('riderProfession') as String?,

      pincode: _box.get('riderPincode') as String?,

      state: _box.get('riderState') as String?,

      city: _box.get('riderCity') as String?,

    );



    await _riderService.save(uid, profile);

    await _clearLegacyHiveRiderFields();

  }



  Future<void> _clearLegacyHiveRiderFields() async {

    for (final key in [

      'riderName',

      'riderPhone',

      'riderCity',

      'riderDateOfBirth',

      'riderGender',

      'riderProfession',

      'riderState',

      'riderPincode',

    ]) {

      await _box.delete(key);

    }

  }



  Future<void> _requireUid() async {

    if (_uid == null) throw StateError('Not signed in');

  }



  Future<void> setDistanceUnit(DistanceUnit unit) async {

    await _box.put('distanceUnit', unit.name);

    state = state.copyWith(distanceUnit: unit);

  }



  /// Validates PIN via India Post API and returns lookup result.

  /// Caller should include pincode/state/city in [saveRiderProfile].

  Future<PincodeLookupResult> lookupPincode(String pincode) {

    return PincodeService.lookup(pincode);

  }



  Future<void> saveRiderProfile({

    required String riderName,

    required RiderGender? riderGender,

    required DateTime? riderDateOfBirth,

    required String riderPhone,

    required String riderProfession,

    required String? riderPincode,

    required String? riderState,

    required String? riderCity,

  }) async {

    await _requireUid();



    final profile = RiderProfile(

      name: riderName.trim(),

      gender: riderGender,

      dateOfBirth: riderDateOfBirth,

      phone: riderPhone.trim().isEmpty ? null : riderPhone.trim(),

      profession:

          riderProfession.trim().isEmpty ? null : riderProfession.trim(),

      pincode: riderPincode?.isEmpty == true ? null : riderPincode,

      state: riderPincode?.isEmpty == true ? null : riderState,

      city: riderPincode?.isEmpty == true ? null : riderCity,

    );



    await _riderService.save(_uid!, profile);

    state = state.copyWith(riderProfile: profile, riderProfileLoaded: true);

  }



  Future<void> saveRiderBasics({

    required String riderName,

    required RiderGender riderGender,

    required DateTime riderDateOfBirth,

  }) async {

    await _requireUid();



    final profile = state.riderProfile.copyWith(

      name: riderName.trim(),

      gender: riderGender,

      dateOfBirth: riderDateOfBirth,

    );



    await _riderService.save(_uid!, profile);

    state = state.copyWith(riderProfile: profile, riderProfileLoaded: true);

  }



  @override

  void dispose() {

    _profileSub?.cancel();

    super.dispose();

  }

}



final settingsProvider =

    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {

  return SettingsNotifier(ref);

});



final riderProfileCompleteProvider = Provider<bool>((ref) {

  final settings = ref.watch(settingsProvider);

  if (!settings.riderProfileLoaded) return false;

  return settings.isRiderProfileComplete;

});



final riderProfileLoadingProvider = Provider<bool>((ref) {

  final user = ref.watch(authStateProvider).valueOrNull;

  if (user == null) return false;

  return !ref.watch(settingsProvider).riderProfileLoaded;

});


