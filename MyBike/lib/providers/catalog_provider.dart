import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/local_store.dart';
import '../data/models/catalog.dart';

const _assetPath = 'assets/data/bike_catalog.json';
const _cacheBrandsKey = 'brands';
const _cacheModelsKey = 'models';

BikeCatalog _build(List<Brand> brands, List<BikeModel> models) {
  brands.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final byBrand = <String, List<BikeModel>>{};
  for (final m in models) {
    (byBrand[m.brandId] ??= []).add(m);
  }
  for (final list in byBrand.values) {
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  return BikeCatalog(brands: brands, modelsByBrandId: byBrand);
}

/// Builds a catalog from the bundled asset shape:
/// `[{ id, name, models: [..] }]`.
BikeCatalog _fromAssetJson(List<dynamic> data) {
  final brands = <Brand>[];
  final models = <BikeModel>[];
  for (final raw in data) {
    final map = raw as Map<String, dynamic>;
    final brandId = map['id'] as String;
    brands.add(Brand(id: brandId, name: map['name'] as String));
    for (final modelName in (map['models'] as List<dynamic>)) {
      final name = modelName as String;
      models.add(BikeModel(
        id: BikeModel.idFor(brandId, name),
        brandId: brandId,
        name: name,
      ));
    }
  }
  return _build(brands, models);
}

Future<BikeCatalog> _loadFromAsset() async {
  final raw = await rootBundle.loadString(_assetPath);
  return _fromAssetJson(json.decode(raw) as List<dynamic>);
}

Future<BikeCatalog> _loadFromFirestore() async {
  final fs = FirebaseFirestore.instance;
  final results = await Future.wait([
    fs.collection('brands').get(),
    fs.collection('models').get(),
  ]);
  final brandDocs = results[0].docs;
  final modelDocs = results[1].docs;
  if (brandDocs.isEmpty) {
    throw StateError('brands collection is empty');
  }
  final brands = brandDocs.map((d) => Brand.fromMap(d.data())).toList();
  final models = modelDocs.map((d) => BikeModel.fromMap(d.data())).toList();
  return _build(brands, models);
}

Box<String> get _box => Hive.box<String>(Boxes.catalog);

void _cache(BikeCatalog catalog) {
  final brands = catalog.brands.map((b) => b.toMap()).toList();
  final models = [
    for (final list in catalog.modelsByBrandId.values)
      for (final m in list) m.toMap(),
  ];
  _box.put(_cacheBrandsKey, json.encode(brands));
  _box.put(_cacheModelsKey, json.encode(models));
}

BikeCatalog? _loadFromCache() {
  final brandsRaw = _box.get(_cacheBrandsKey);
  final modelsRaw = _box.get(_cacheModelsKey);
  if (brandsRaw == null || modelsRaw == null) return null;
  final brands = (json.decode(brandsRaw) as List<dynamic>)
      .map((e) => Brand.fromMap(e as Map<String, dynamic>))
      .toList();
  final models = (json.decode(modelsRaw) as List<dynamic>)
      .map((e) => BikeModel.fromMap(e as Map<String, dynamic>))
      .toList();
  return _build(brands, models);
}

/// Loads the bike catalog, preferring Firestore (the source of record),
/// falling back to the local Hive cache and then the bundled asset so the
/// dropdowns always work offline.
final catalogProvider = FutureProvider<BikeCatalog>((ref) async {
  try {
    final catalog =
        await _loadFromFirestore().timeout(const Duration(seconds: 8));
    _cache(catalog);
    return catalog;
  } catch (_) {
    final cached = _loadFromCache();
    if (cached != null && cached.brands.isNotEmpty) return cached;
    return _loadFromAsset();
  }
});

final brandsProvider = Provider<List<Brand>>((ref) {
  return ref.watch(catalogProvider).maybeWhen(
        data: (c) => c.brands,
        orElse: () => const [],
      );
});

final modelsForBrandProvider =
    Provider.family<List<BikeModel>, String?>((ref, brandId) {
  return ref.watch(catalogProvider).maybeWhen(
        data: (c) => c.modelsFor(brandId),
        orElse: () => const [],
      );
});
