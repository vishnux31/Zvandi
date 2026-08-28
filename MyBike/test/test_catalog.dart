import 'package:mybike/data/models/catalog.dart';

BikeCatalog testBikeCatalog() {
  return BikeCatalog(
    brands: const [
      Brand(id: 'honda', name: 'Honda'),
      Brand(id: 'yamaha', name: 'Yamaha'),
    ],
    modelsByBrandId: const {
      'honda': [
        BikeModel(id: 'honda__activa-6g', brandId: 'honda', name: 'Activa 6G'),
      ],
      'yamaha': [
        BikeModel(id: 'yamaha__mt-09', brandId: 'yamaha', name: 'MT-09'),
      ],
    },
  );
}
