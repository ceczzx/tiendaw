import 'package:tiendaw/features/catalog/data/catalog_sources.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/catalog_repository.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required CatalogLocalDataSource local,
    required CatalogRemoteDataSource remote,
  }) : _local = local,
       _remote = remote;

  final CatalogLocalDataSource _local;
  final CatalogRemoteDataSource _remote;

  @override
  Future<List<Category>> getCategories() async {
    try {
      final categories = await _remote.getCategories();
      await _local.saveCategories(categories);
      return categories;
    } catch (_) {
      final cached = await _local.getCategories();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<List<InventoryMovement>> getInventoryMovements() async {
    try {
      final movements = await _remote.getInventoryMovements();
      await _local.saveInventoryMovements(movements);
      return movements;
    } catch (_) {
      final cached = await _local.getInventoryMovements();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async {
    try {
      final entries = await _remote.getPriceHistory(productId: productId);
      await _local.savePriceHistory(entries);
      return entries;
    } catch (_) {
      final cached = await _local.getPriceHistory(productId: productId);
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<List<Product>> getProducts() async {
    try {
      final products = await _remote.getProducts();
      await _local.saveProducts(products);
      return products;
    } catch (_) {
      final cached = await _local.getProducts();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    required String actorName,
  }) {
    return _remote.transferWarehouseToStore(
      productId: productId,
      quantity: quantity,
      actorName: actorName,
    );
  }
}
