import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/sync/sync_engine.dart';
import 'package:tiendaw/features/catalog/data/catalog_repository_impl.dart';
import 'package:tiendaw/features/catalog/data/catalog_sources.dart';
import 'package:tiendaw/features/catalog/domain/load_catalog_overview_use_case.dart';
import 'package:tiendaw/features/purchases/data/purchase_repository_impl.dart';
import 'package:tiendaw/features/purchases/data/purchase_sources.dart';
import 'package:tiendaw/features/purchases/domain/register_purchase_use_case.dart';
import 'package:tiendaw/features/sales/data/sales_repository_impl.dart';
import 'package:tiendaw/features/sales/data/sales_sources.dart';
import 'package:tiendaw/features/sales/domain/create_sale_use_case.dart';
import 'package:tiendaw/shared/demo/system_w_store.dart';

final systemWStoreProvider = Provider<SystemWStore>((ref) {
  return SystemWStore.seeded();
});

final catalogLocalDataSourceProvider = Provider<CatalogLocalDataSource>((ref) {
  return CatalogLocalDataSource(ref.read(systemWStoreProvider));
});

final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>((
  ref,
) {
  return CatalogRemoteDataSource(ref.read(systemWStoreProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepositoryImpl>((ref) {
  return CatalogRepositoryImpl(
    local: ref.read(catalogLocalDataSourceProvider),
    remote: ref.read(catalogRemoteDataSourceProvider),
    store: ref.read(systemWStoreProvider),
  );
});

final loadCatalogOverviewUseCaseProvider = Provider<LoadCatalogOverviewUseCase>(
  (ref) {
    return LoadCatalogOverviewUseCase(ref.read(catalogRepositoryProvider));
  },
);

final salesLocalDataSourceProvider = Provider<SalesLocalDataSource>((ref) {
  return SalesLocalDataSource(ref.read(systemWStoreProvider));
});

final salesRemoteDataSourceProvider = Provider<SalesRemoteDataSource>((ref) {
  return SalesRemoteDataSource(ref.read(systemWStoreProvider));
});

final salesRepositoryProvider = Provider<SalesRepositoryImpl>((ref) {
  return SalesRepositoryImpl(
    local: ref.read(salesLocalDataSourceProvider),
    remote: ref.read(salesRemoteDataSourceProvider),
    store: ref.read(systemWStoreProvider),
  );
});

final createSaleUseCaseProvider = Provider<CreateSaleUseCase>((ref) {
  return CreateSaleUseCase(ref.read(salesRepositoryProvider));
});

final purchaseLocalDataSourceProvider = Provider<PurchaseLocalDataSource>((
  ref,
) {
  return PurchaseLocalDataSource(ref.read(systemWStoreProvider));
});

final purchaseRemoteDataSourceProvider = Provider<PurchaseRemoteDataSource>((
  ref,
) {
  return PurchaseRemoteDataSource(ref.read(systemWStoreProvider));
});

final purchaseRepositoryProvider = Provider<PurchaseRepositoryImpl>((ref) {
  return PurchaseRepositoryImpl(
    local: ref.read(purchaseLocalDataSourceProvider),
    remote: ref.read(purchaseRemoteDataSourceProvider),
    store: ref.read(systemWStoreProvider),
  );
});

final registerPurchaseUseCaseProvider = Provider<RegisterPurchaseUseCase>((
  ref,
) {
  return RegisterPurchaseUseCase(ref.read(purchaseRepositoryProvider));
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    store: ref.read(systemWStoreProvider),
    salesRepository: ref.read(salesRepositoryProvider),
    purchaseRepository: ref.read(purchaseRepositoryProvider),
  );
});
