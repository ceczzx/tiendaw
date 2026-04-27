import 'package:tiendaw/features/catalog/data/catalog_sources.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/catalog_repository.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/shared/demo/system_w_store.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required CatalogLocalDataSource local,
    required CatalogRemoteDataSource remote,
    required SystemWStore store,
  }) : _local = local,
       _remote = remote,
       _store = store;

  final CatalogLocalDataSource _local;
  final CatalogRemoteDataSource _remote;
  final SystemWStore _store;

  @override
  Future<List<Category>> getCategories() {
    return _store.isOnline ? _remote.getCategories() : _local.getCategories();
  }

  @override
  Future<List<InventoryMovement>> getInventoryMovements() {
    return _local.getInventoryMovements();
  }

  @override
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) {
    return _local.getPriceHistory(productId: productId);
  }

  @override
  Future<List<Product>> getProducts() {
    return _store.isOnline ? _remote.getProducts() : _local.getProducts();
  }

  @override
  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    required String actorName,
  }) {
    return _local.transferWarehouseToStore(
      productId: productId,
      quantity: quantity,
      actorName: actorName,
    );
  }
}
