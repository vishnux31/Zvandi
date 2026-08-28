import 'enums.dart';

/// Rider details stored in Firestore under `users/{uid}/profile/rider`.
class RiderProfile {
  final String? name;
  final RiderGender? gender;
  final DateTime? dateOfBirth;
  final String? phone;
  final String? profession;
  final String? pincode;
  final String? state;
  final String? city;

  const RiderProfile({
    this.name,
    this.gender,
    this.dateOfBirth,
    this.phone,
    this.profession,
    this.pincode,
    this.state,
    this.city,
  });

  bool get isComplete =>
      name != null &&
      name!.trim().length >= 2 &&
      gender != null &&
      dateOfBirth != null;

  RiderProfile copyWith({
    String? name,
    RiderGender? gender,
    DateTime? dateOfBirth,
    String? phone,
    String? profession,
    String? pincode,
    String? state,
    String? city,
    bool clearGender = false,
    bool clearDateOfBirth = false,
    bool clearPincode = false,
  }) =>
      RiderProfile(
        name: name ?? this.name,
        gender: clearGender ? null : (gender ?? this.gender),
        dateOfBirth:
            clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
        phone: phone ?? this.phone,
        profession: profession ?? this.profession,
        pincode: clearPincode ? null : (pincode ?? this.pincode),
        state: clearPincode ? null : (state ?? this.state),
        city: clearPincode ? null : (city ?? this.city),
      );

  factory RiderProfile.fromMap(Map<String, dynamic> map) {
    RiderGender? gender;
    final rawGender = map['gender'] as String?;
    if (rawGender != null) {
      gender = RiderGender.values.where((g) => g.name == rawGender).firstOrNull;
    }

    final dobRaw = map['dateOfBirth'] as String?;
    return RiderProfile(
      name: map['name'] as String?,
      gender: gender,
      dateOfBirth: dobRaw != null ? DateTime.tryParse(dobRaw) : null,
      phone: map['phone'] as String?,
      profession: map['profession'] as String?,
      pincode: map['pincode'] as String?,
      state: map['state'] as String?,
      city: map['city'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (gender != null) map['gender'] = gender!.name;
    if (dateOfBirth != null) {
      map['dateOfBirth'] = dateOfBirth!.toIso8601String();
    }
    if (phone != null && phone!.isNotEmpty) map['phone'] = phone;
    if (profession != null && profession!.isNotEmpty) {
      map['profession'] = profession;
    }
    if (pincode != null && pincode!.isNotEmpty) {
      map['pincode'] = pincode;
      if (state != null) map['state'] = state;
      if (city != null) map['city'] = city;
    }
    return map;
  }
}
