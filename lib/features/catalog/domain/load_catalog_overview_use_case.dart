import 'dart:async';

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

  Stream<CatalogOverview> watch() {
    late final StreamController<CatalogOverview> controller;
    StreamSubscription<List<Category>>? categoriesSubscription;
    StreamSubscription<List<Product>>? productsSubscription;
    var latestCategories = const <Category>[];
    var latestProducts = const <Product>[];
    var hasCategories = false;
    var hasProducts = false;

    void emitIfReady() {
      if (!hasCategories || !hasProducts || controller.isClosed) {
        return;
      }

      controller.add(
        CatalogOverview(
          categories: latestCategories,
          products: latestProducts,
        ),
      );
    }

    Future<void> start() async {
      categoriesSubscription = _repository.watchCategories().listen(
        (categories) {
          latestCategories = categories;
          hasCategories = true;
          emitIfReady();
        },
        onError: controller.addError,
      );
      productsSubscription = _repository.watchProducts().listen(
        (products) {
          latestProducts = products;
          hasProducts = true;
          emitIfReady();
        },
        onError: controller.addError,
      );
    }

    Future<void> stop() async {
      await categoriesSubscription?.cancel();
      await productsSubscription?.cancel();
      categoriesSubscription = null;
      productsSubscription = null;
    }

    controller = StreamController<CatalogOverview>.broadcast(
      onListen: start,
      onCancel: () async {
        if (!controller.hasListener) {
          await stop();
        }
      },
    );

    return controller.stream;
  }
}
