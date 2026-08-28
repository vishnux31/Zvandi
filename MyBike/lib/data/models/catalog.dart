// Reference data for bike brands and their models.
//
// These are global, read-only tables stored in Firestore (collections
// `brands` and `models`) and bundled as an offline fallback asset.

/// Converts a display name into a stable slug id (e.g. "Royal Enfield" ->
/// "royal-enfield"). Must match the seed script so ids line up with Firestore.
String slugify(String input) {
  final lower = input.toLowerCase().trim();
  final buffer = StringBuffer();
  var lastDash = false;
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final isAlphaNum = RegExp(r'[a-z0-9]').hasMatch(ch);
    if (isAlphaNum) {
      buffer.write(ch);
      lastDash = false;
    } else if (!lastDash) {
      buffer.write('-');
      lastDash = true;
    }
  }
  return buffer.toString().replaceAll(RegExp(r'^-+|-+$'), '');
}

class Brand {
  final String id;
  final String name;

  const Brand({required this.id, required this.name});

  factory Brand.fromMap(Map<String, dynamic> map) => Brand(
        id: map['id'] as String,
        name: map['name'] as String,
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}

class BikeModel {
  final String id;
  final String brandId;
  final String name;

  const BikeModel({
    required this.id,
    required this.brandId,
    required this.name,
  });

  factory BikeModel.fromMap(Map<String, dynamic> map) => BikeModel(
        id: map['id'] as String,
        brandId: map['brandId'] as String,
        name: map['name'] as String,
      );

  Map<String, dynamic> toMap() => {'id': id, 'brandId': brandId, 'name': name};

  static String idFor(String brandId, String name) =>
      '${brandId}__${slugify(name)}';
}

/// The whole catalog held in memory after loading.
class BikeCatalog {
  final List<Brand> brands;
  final Map<String, List<BikeModel>> modelsByBrandId;

  const BikeCatalog({required this.brands, required this.modelsByBrandId});

  static const empty = BikeCatalog(brands: [], modelsByBrandId: {});

  List<BikeModel> modelsFor(String? brandId) =>
      brandId == null ? const [] : (modelsByBrandId[brandId] ?? const []);
}
