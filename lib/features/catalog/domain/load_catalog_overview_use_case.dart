import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/catalog_repository.dart';

class CatalogOverview {
  const CatalogOverview({required this.categories, required this.products});

  final List<Category> categories;
  final List<Product> products;
}

class LoadCatalogOverviewUseCase {
  const LoadCatalogOverviewUseCase(this._repository);

  final CatalogRepository _repository;

  Future<CatalogOverview> call() async {
    final categories = await _repository.getCategories();
    final products = await _repository.getProducts();
    return CatalogOverview(categories: categories, products: products);
  }
}
