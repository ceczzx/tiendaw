import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/core/sync/realtime_refresh_stream.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.prefix,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      prefix: map['prefix']?.toString() ?? '',
    );
  }
}

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.sku,
    required super.categoryId,
    required super.name,
    required super.productType,
    required super.unitsPerPackage,
    required super.costDetails,
    required super.salePrice,
    required super.lastPurchaseCost,
    required super.stockStore,
    required super.stockWarehouse,
    required super.lowStockThreshold,
    required super.packageName,
    required super.unitName,
    super.nextExpiryDate,
    required super.coldStockUnits,
    required super.coldPriceIncrement,
    super.promotionalPrice,
    super.promotionNote,
    super.promotionOffers,
  });

  factory ProductModel.fromSupabase(
    Map<String, dynamic> map, {
    required _ProductInventorySnapshot inventory,
    required _ProductPricingSnapshot pricing,
    required double lastPurchaseCost,
    required _LatestPurchaseSnapshot latestPurchaseSnapshot,
    required DateTime? nextExpiryDate,
    List<ProductPromotionOffer> promotionOffers = const [],
  }) {
    final productType = map['product_type']?.toString() ?? 'proveedor';
    final unitsPerPackage = (map['units_per_package'] as num?)?.toInt() ?? 1;
    final packageName = map['package_name']?.toString() ?? 'caja';
    final unitName = map['unit_name']?.toString() ?? 'unid';
    final packageCost =
        lastPurchaseCost > 0 ? lastPurchaseCost * unitsPerPackage : 0;
    final normalizedCostDetails = <String, dynamic>{
      'tipo': productType,
      'cantidad_caja': unitsPerPackage,
      'package_name': packageName,
      'unit_name': unitName,
      if (packageCost > 0) 'precio_caja': packageCost,
      if (_normalizedText(map['brand']) != null)
        'marca': _normalizedText(map['brand']),
      if (_normalizedText(map['presentation']) != null)
        'presentacion': _normalizedText(map['presentation']),
      if (latestPurchaseSnapshot.costNotes != null)
        'observaciones': latestPurchaseSnapshot.costNotes,
      if (productType == 'artesanal' &&
          latestPurchaseSnapshot.costNotes != null)
        'observaciones_producto': latestPurchaseSnapshot.costNotes,
    };

    return ProductModel(
      id: map['id'] as String,
      sku: map['sku']?.toString() ?? '',
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      productType: productType,
      unitsPerPackage: unitsPerPackage,
      costDetails: normalizedCostDetails,
      salePrice: pricing.salePrice,
      lastPurchaseCost: lastPurchaseCost,
      stockStore: inventory.storeUnits,
      stockWarehouse: inventory.warehouseUnits,
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt() ?? 20,
      packageName: packageName,
      unitName: unitName,
      nextExpiryDate: nextExpiryDate,
      coldStockUnits: inventory.coldStoreUnits,
      coldPriceIncrement: pricing.coldPriceIncrement,
      promotionalPrice:
          promotionOffers.isNotEmpty
              ? promotionOffers
                  .map((offer) => offer.promotionalPrice)
                  .reduce((left, right) => left < right ? left : right)
              : pricing.promotionalPrice,
      promotionNote:
          promotionOffers.isNotEmpty
              ? promotionOffers.first.note
              : pricing.promotionNote,
      promotionOffers: List<ProductPromotionOffer>.unmodifiable(
        promotionOffers,
      ),
    );
  }
}

class CatalogLocalDataSource {
  List<Category> _categories = const [];
  List<Product> _products = const [];
  List<LotPromotion> _activeLotPromotions = const [];
  List<PriceHistoryEntry> _priceHistory = const [];
  List<InventoryMovement> _movements = const [];
  final Map<String, List<InventoryLotAlert>> _inventoryLotAlerts = {};
  final Map<String, List<PromotableLot>> _promotableLots = {};
  final Map<bool, List<PromotionNotice>> _promotionNotices = {};
  final Map<String, List<WarehouseSupplierLot>> _warehouseSupplierLots = {};

  Future<List<Category>> getCategories() async =>
      List.unmodifiable(_categories);

  Future<List<Product>> getProducts() async => List.unmodifiable(_products);

  Future<List<PromotableLot>> getPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    return List.unmodifiable(
      _promotableLots[_inventoryLotAlertsKey(daysAhead, expiredOnly)] ??
          const [],
    );
  }

  Future<List<LotPromotion>> getActiveLotPromotions() async {
    return List.unmodifiable(_activeLotPromotions);
  }

  Future<List<PromotionNotice>> getPromotionNotices({
    bool openOnly = true,
  }) async {
    return List.unmodifiable(_promotionNotices[openOnly] ?? const []);
  }

  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async {
    final source =
        productId == null
            ? _priceHistory
            : _priceHistory
                .where((entry) => entry.productId == productId)
                .toList();
    return List.unmodifiable(source);
  }

  Future<List<InventoryMovement>> getInventoryMovements() async {
    return List.unmodifiable(_movements);
  }

  Future<List<InventoryLotAlert>> getInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    return List.unmodifiable(
      _inventoryLotAlerts[_inventoryLotAlertsKey(daysAhead, expiredOnly)] ??
          const [],
    );
  }

  Future<List<WarehouseSupplierLot>> getWarehouseSupplierLots({
    required String productId,
    String? supplierId,
  }) async {
    final cacheKey = _warehouseSupplierLotsKey(
      productId: productId,
      supplierId: supplierId,
    );
    return List.unmodifiable(_warehouseSupplierLots[cacheKey] ?? const []);
  }

  Future<void> saveCategories(List<Category> categories) async {
    _categories = List<Category>.unmodifiable(categories);
  }

  Future<void> saveProducts(List<Product> products) async {
    _products = List<Product>.unmodifiable(products);
  }

  Future<void> savePromotableLots({
    required int daysAhead,
    required bool expiredOnly,
    required List<PromotableLot> lots,
  }) async {
    _promotableLots[_inventoryLotAlertsKey(
      daysAhead,
      expiredOnly,
    )] = List<PromotableLot>.unmodifiable(lots);
  }

  Future<void> saveActiveLotPromotions(List<LotPromotion> promotions) async {
    _activeLotPromotions = List<LotPromotion>.unmodifiable(promotions);
  }

  Future<void> savePromotionNotices({
    required bool openOnly,
    required List<PromotionNotice> notices,
  }) async {
    _promotionNotices[openOnly] = List<PromotionNotice>.unmodifiable(notices);
  }

  Future<void> savePriceHistory(List<PriceHistoryEntry> entries) async {
    _priceHistory = List<PriceHistoryEntry>.unmodifiable(entries);
  }

  Future<void> saveInventoryMovements(List<InventoryMovement> movements) async {
    _movements = List<InventoryMovement>.unmodifiable(movements);
  }

  Future<void> saveInventoryLotAlerts({
    required int daysAhead,
    required bool expiredOnly,
    required List<InventoryLotAlert> alerts,
  }) async {
    _inventoryLotAlerts[_inventoryLotAlertsKey(
      daysAhead,
      expiredOnly,
    )] = List<InventoryLotAlert>.unmodifiable(alerts);
  }

  Future<void> saveWarehouseSupplierLots({
    required String productId,
    String? supplierId,
    required List<WarehouseSupplierLot> lots,
  }) async {
    final cacheKey = _warehouseSupplierLotsKey(
      productId: productId,
      supplierId: supplierId,
    );
    _warehouseSupplierLots[cacheKey] = List<WarehouseSupplierLot>.unmodifiable(
      lots,
    );
  }
}

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Category>> getCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, name, prefix')
        .order('name');

    return _mapRows(rows).map(CategoryModel.fromMap).toList();
  }

  Stream<List<Category>> watchCategories() {
    return createRealtimeRefreshStream(
      load: getCategories,
      triggers: [
        _tableTrigger('categories', primaryKey: const ['id']),
      ],
    );
  }

  Future<Category> ensureCategory({
    required String name,
    required String prefix,
  }) async {
    final normalizedName = name.trim();
    final normalizedPrefix = prefix.trim().toUpperCase();
    if (normalizedName.isEmpty) {
      throw StateError('La categoria no puede estar vacia.');
    }
    if (!RegExp(r'^[A-Z]{3,5}$').hasMatch(normalizedPrefix)) {
      throw StateError(
        'El prefix de la categoria debe tener entre 3 y 5 letras mayusculas.',
      );
    }

    final rows = await _client
        .from('categories')
        .select('id, name, prefix')
        .eq('name', normalizedName)
        .limit(1);
    final data = _mapRows(rows);
    if (data.isNotEmpty) {
      return CategoryModel.fromMap(data.first);
    }

    final inserted =
        await _client
            .from('categories')
            .insert({'name': normalizedName, 'prefix': normalizedPrefix})
            .select('id, name, prefix')
            .single();

    return CategoryModel.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<List<Product>> getProducts() async {
    final productRows = await _client
        .from('products')
        .select(
          '$_productSelectClause, '
          'price_history('
          'id, sale_price, promotional_price, promotion_note, '
          'cold_price_increment, effective_from, effective_to'
          ')',
        )
        .eq('is_active', true)
        .isFilter('price_history.effective_to', null)
        .order('name');
    final mappedProductRows = _mapRows(productRows);
    final inventoryByProduct = await _loadStockByProduct();
    final nextExpiryByProduct = await _loadNextExpiryByProduct();
    final promotionOffersByProduct = await _loadPromotionOffersByProduct();
    final pricingByProduct = <String, _ProductPricingSnapshot>{};
    final missingPriceIds = <String>[];
    final lastPurchaseCostByProduct = await _loadLastPurchaseCostByProduct();
    final latestPurchaseSnapshotsByProduct =
        await _loadLatestPurchaseSnapshotsByProduct();

    for (final row in mappedProductRows) {
      final productId = row['id'] as String;
      final priceRows = row['price_history'];
      if (priceRows is List && priceRows.isNotEmpty) {
        final priceRow = Map<String, dynamic>.from(priceRows.first as Map);
        pricingByProduct[productId] = _ProductPricingSnapshot(
          id: priceRow['id']?.toString() ?? '',
          salePrice: _toDoubleValue(priceRow['sale_price']),
          promotionalPrice: _toNullableDoubleValue(
            priceRow['promotional_price'],
          ),
          promotionNote: priceRow['promotion_note']?.toString(),
          coldPriceIncrement: _toDoubleValue(
            priceRow['cold_price_increment'],
            fallback: 0.50,
          ),
        );
      } else {
        missingPriceIds.add(productId);
      }
    }

    if (missingPriceIds.isNotEmpty) {
      final fallbackSnapshots = await Future.wait(
        missingPriceIds.map(_loadLatestPricingForProduct),
      );
      for (var index = 0; index < missingPriceIds.length; index += 1) {
        final snapshot = fallbackSnapshots[index];
        if (snapshot != null) {
          pricingByProduct[missingPriceIds[index]] = snapshot;
        }
      }
    }

    return mappedProductRows.map((row) {
      final productId = row['id'] as String;
      return ProductModel.fromSupabase(
        row,
        inventory: inventoryByProduct[productId] ?? _ProductInventorySnapshot(),
        pricing:
            pricingByProduct[productId] ??
            const _ProductPricingSnapshot.empty(),
        lastPurchaseCost: lastPurchaseCostByProduct[productId] ?? 0,
        latestPurchaseSnapshot:
            latestPurchaseSnapshotsByProduct[productId] ??
            const _LatestPurchaseSnapshot(),
        nextExpiryDate: nextExpiryByProduct[productId],
        promotionOffers: promotionOffersByProduct[productId] ?? const [],
      );
    }).toList();
  }

  Stream<List<Product>> watchProducts() {
    return createRealtimeRefreshStream(
      load: getProducts,
      triggers: [
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger(
          'inventory_stock',
          primaryKey: const [
            'product_id',
            'location_id',
            'batch_id',
            'storage_condition',
          ],
        ),
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('price_history', primaryKey: const ['id']),
        _tableTrigger('lot_promotions', primaryKey: const ['id']),
        _tableTrigger('promotion_notices', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<PromotableLot>> getPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    final today = _dateOnly(DateTime.now());
    final limitDate = today.add(Duration(days: daysAhead));
    final lots = await _loadLotContexts();
    final filtered = <PromotableLot>[];

    for (final lot in lots) {
      final expiryDate = lot.expiryDate;
      if (expiryDate == null || lot.totalAvailableUnits <= 0) {
        continue;
      }

      final normalizedExpiry = _dateOnly(expiryDate);
      final isExpired = normalizedExpiry.isBefore(today);
      final isWithinWindow =
          !isExpired &&
          (normalizedExpiry.isAtSameMomentAs(today) ||
              normalizedExpiry.isBefore(limitDate) ||
              normalizedExpiry.isAtSameMomentAs(limitDate));

      if (expiredOnly && !isExpired) {
        continue;
      }
      if (!expiredOnly && !isWithinWindow) {
        continue;
      }

      filtered.add(
        PromotableLot(
          purchaseItemId: lot.purchaseItemId,
          productId: lot.productId,
          productName: lot.productName,
          supplierId: lot.supplierId,
          supplierName: lot.supplierName,
          receivedAt: lot.receivedAt,
          expiryDate: expiryDate,
          warehouseAvailableUnits: lot.warehouseAvailableUnits,
          storeAvailableUnits: lot.storeAvailableUnits,
          totalAvailableUnits: lot.totalAvailableUnits,
          recommendedLocation:
              lot.storeAvailableUnits > 0 || lot.warehouseAvailableUnits > 0
                  ? 'store'
                  : 'warehouse',
        ),
      );
    }

    filtered.sort((left, right) {
      final expiryCompare = left.expiryDate.compareTo(right.expiryDate);
      if (expiryCompare != 0) {
        return expiryCompare;
      }
      return left.productName.toLowerCase().compareTo(
        right.productName.toLowerCase(),
      );
    });

    return filtered;
  }

  Stream<List<PromotableLot>> watchPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) {
    return createRealtimeRefreshStream(
      load:
          () =>
              getPromotableLots(daysAhead: daysAhead, expiredOnly: expiredOnly),
      triggers: [
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('purchases', primaryKey: const ['id']),
        _tableTrigger(
          'inventory_stock',
          primaryKey: const [
            'product_id',
            'location_id',
            'batch_id',
            'storage_condition',
          ],
        ),
        _tableTrigger('lot_promotions', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger('suppliers', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<LotPromotion>> getActiveLotPromotions() async {
    final rows = await _client
        .from('lot_promotions')
        .select(
          'id, purchase_item_id, product_id, supplier_id, promotional_price, '
          'promo_quantity_total, promo_quantity_remaining, note, status, created_at, '
          'supplier:suppliers!lot_promotions_supplier_id_fkey(name), '
          'product:products!lot_promotions_product_id_fkey(name), '
          'purchase_item:purchase_items!lot_promotions_purchase_item_id_fkey(expiry_date)',
        )
        .order('created_at');

    final stockByBatch = await _loadBatchStockSummaries();
    final result = <LotPromotion>[];

    for (final row in _mapRows(rows)) {
      final status = row['status']?.toString() ?? 'pending_transfer';
      if (status == 'cancelled' || status == 'exhausted') {
        continue;
      }

      final purchaseItemId = row['purchase_item_id'] as String;
      final stock = stockByBatch[purchaseItemId] ?? _BatchStockSummary();
      final supplier = _mapNullable(row['supplier']);
      final product = _mapNullable(row['product']);
      final purchaseItem = _mapNullable(row['purchase_item']);
      final remaining = (row['promo_quantity_remaining'] as num?)?.toInt() ?? 0;
      if (remaining <= 0) {
        continue;
      }

      result.add(
        LotPromotion(
          promotionId: row['id'] as String,
          purchaseItemId: purchaseItemId,
          productId: row['product_id'] as String,
          productName: product['name']?.toString() ?? 'Producto',
          supplierId: row['supplier_id']?.toString(),
          supplierName: supplier['name']?.toString() ?? 'Proveedor',
          expiryDate:
              purchaseItem['expiry_date'] == null
                  ? null
                  : DateTime.parse(purchaseItem['expiry_date'] as String),
          promotionalPrice: (row['promotional_price'] as num).toDouble(),
          promoQuantityTotal: (row['promo_quantity_total'] as num).toInt(),
          promoQuantityRemaining: remaining,
          warehouseAvailableUnits: stock.warehouseUnits,
          storeAvailableUnits: stock.storeUnits,
          status: status,
          note: row['note']?.toString(),
          createdAt: _parseSupabaseDateTime(row['created_at'] as String),
        ),
      );
    }

    return result;
  }

  Stream<List<LotPromotion>> watchActiveLotPromotions() {
    return createRealtimeRefreshStream(
      load: getActiveLotPromotions,
      triggers: [
        _tableTrigger('lot_promotions', primaryKey: const ['id']),
        _tableTrigger(
          'inventory_stock',
          primaryKey: const [
            'product_id',
            'location_id',
            'batch_id',
            'storage_condition',
          ],
        ),
        _tableTrigger('sale_item_lot_allocations', primaryKey: const ['id']),
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger('suppliers', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<PromotionNotice>> getPromotionNotices({
    bool openOnly = true,
  }) async {
    dynamic query = _client
        .from('promotion_notices')
        .select(
          'id, promotion_id, notice_type, message, created_at, resolved_at',
        );

    if (openOnly) {
      query = query.isFilter('resolved_at', null);
    }

    final rows = await query.order('created_at', ascending: false);
    return _mapRows(rows).map((row) {
      return PromotionNotice(
        id: row['id'] as String,
        promotionId: row['promotion_id'] as String,
        noticeType: row['notice_type']?.toString() ?? 'promo_exhausted',
        message: row['message']?.toString() ?? '',
        createdAt: _parseSupabaseDateTime(row['created_at'] as String),
        resolvedAt:
            row['resolved_at'] == null
                ? null
                : _parseSupabaseDateTime(row['resolved_at'] as String),
      );
    }).toList();
  }

  Stream<List<PromotionNotice>> watchPromotionNotices({bool openOnly = true}) {
    return createRealtimeRefreshStream(
      load: () => getPromotionNotices(openOnly: openOnly),
      triggers: [
        _tableTrigger('promotion_notices', primaryKey: const ['id']),
        _tableTrigger('lot_promotions', primaryKey: const ['id']),
      ],
    );
  }

  Future<Product> ensureProduct({
    required String categoryId,
    required String name,
    required String productType,
    required double salePrice,
    required double lastPurchaseCost,
    required int lowStockThreshold,
    required int unitsPerPackage,
    required Map<String, dynamic> costDetails,
  }) async {
    final normalizedName = name.trim();
    final normalizedPackageName = _productPackageName(costDetails);
    final normalizedUnitName = _productUnitName(costDetails);
    final normalizedBrand = _productBrand(costDetails);
    final normalizedPresentation = _productPresentation(costDetails);
    if (normalizedName.isEmpty) {
      throw StateError('El producto no puede estar vacio.');
    }

    final rows = await _client
        .from('products')
        .select(_productSelectClause)
        .eq('category_id', categoryId)
        .eq('name', normalizedName)
        .limit(1);
    final data = _mapRows(rows);

    String productId;
    if (data.isNotEmpty) {
      productId = data.first['id'] as String;
      await _client
          .from('products')
          .update({
            'product_type': productType,
            'units_per_package': unitsPerPackage,
            'low_stock_threshold': lowStockThreshold,
            'package_name': normalizedPackageName,
            'unit_name': normalizedUnitName,
            'brand': normalizedBrand,
            'presentation': normalizedPresentation,
          })
          .eq('id', productId);
    } else {
      final inserted =
          await _client
              .from('products')
              .insert({
                'category_id': categoryId,
                'name': normalizedName,
                'product_type': productType,
                'units_per_package': unitsPerPackage,
                'package_name': normalizedPackageName,
                'unit_name': normalizedUnitName,
                'low_stock_threshold': lowStockThreshold,
                'brand': normalizedBrand,
                'presentation': normalizedPresentation,
                'is_active': true,
              })
              .select('id')
              .single();
      productId = inserted['id'] as String;
    }

    final currentPricing = await _loadLatestPricingForProduct(productId);
    await _upsertPriceHistory(
      productId: productId,
      salePrice: salePrice,
      promotionalPrice: currentPricing?.promotionalPrice,
      promotionNote: currentPricing?.promotionNote,
      coldPriceIncrement: currentPricing?.coldPriceIncrement ?? 0.50,
    );

    final products = await getProducts();
    return products.firstWhere((product) => product.id == productId);
  }

  Future<void> updateProductLowStockThreshold({
    required String productId,
    required int lowStockThreshold,
  }) async {
    await _client
        .from('products')
        .update({'low_stock_threshold': lowStockThreshold})
        .eq('id', productId);
  }

  Future<void> updateProductUnitsPerPackage({
    required String productId,
    required int unitsPerPackage,
  }) async {
    await _client
        .from('products')
        .update({'units_per_package': unitsPerPackage})
        .eq('id', productId);
  }

  Future<void> updateProductCatalogData({
    required String productId,
    required String productType,
    required double salePrice,
    required double lastPurchaseCost,
    required int unitsPerPackage,
    required Map<String, dynamic> costDetails,
  }) async {
    final normalizedPackageName = _productPackageName(costDetails);
    final normalizedUnitName = _productUnitName(costDetails);
    final normalizedBrand = _productBrand(costDetails);
    final normalizedPresentation = _productPresentation(costDetails);
    await _client
        .from('products')
        .update({
          'product_type': productType,
          'units_per_package': unitsPerPackage,
          'package_name': normalizedPackageName,
          'unit_name': normalizedUnitName,
          'brand': normalizedBrand,
          'presentation': normalizedPresentation,
        })
        .eq('id', productId);

    final currentPricing = await _loadLatestPricingForProduct(productId);
    await _upsertPriceHistory(
      productId: productId,
      salePrice: salePrice,
      promotionalPrice: currentPricing?.promotionalPrice,
      promotionNote: currentPricing?.promotionNote,
      coldPriceIncrement: currentPricing?.coldPriceIncrement ?? 0.50,
    );
  }

  Future<void> activateLotPromotion({
    required String purchaseItemId,
    required int promotionalQuantity,
    required double promotionalPrice,
    String? promotionNote,
  }) async {
    final currentUserId = _currentUserId();
    final lot = await _loadLotContextByPurchaseItemId(purchaseItemId);
    if (lot == null) {
      throw StateError('El lote seleccionado ya no existe.');
    }
    if (lot.totalAvailableUnits <= 0) {
      throw StateError('El lote ya no tiene stock disponible para promocion.');
    }

    final nextQuantity = promotionalQuantity.clamp(1, lot.totalAvailableUnits);
    final nextStatus =
        lot.storeAvailableUnits > 0 ? 'active_store' : 'pending_transfer';
    final normalizedNote = _normalizeOptionalText(promotionNote);
    final now = _toSupabaseDateTime(DateTime.now());

    final existingRows = await _client
        .from('lot_promotions')
        .select('id')
        .eq('purchase_item_id', purchaseItemId)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false)
        .limit(1);
    final existing = _mapRows(existingRows);

    final payload = <String, dynamic>{
      'purchase_item_id': purchaseItemId,
      'product_id': lot.productId,
      'supplier_id': lot.supplierId,
      'promotional_price': promotionalPrice,
      'promo_quantity_total': nextQuantity,
      'promo_quantity_remaining': nextQuantity,
      'note': normalizedNote,
      'status': nextStatus,
      'updated_at': now,
      'exhausted_at': null,
    };

    if (existing.isEmpty) {
      await _client.from('lot_promotions').insert({
        ...payload,
        'created_by': currentUserId,
        'created_at': now,
      });
      return;
    }

    await _client
        .from('lot_promotions')
        .update(payload)
        .eq('id', existing.first['id'] as String);
  }

  Future<void> cancelLotPromotion({required String promotionId}) async {
    await _client
        .from('lot_promotions')
        .update({
          'status': 'cancelled',
          'updated_at': _toSupabaseDateTime(DateTime.now()),
        })
        .eq('id', promotionId);
  }

  Future<void> updateProductColdState({
    required String productId,
    required int coldStockUnits,
    required double coldPriceIncrement,
  }) async {
    await _syncStoreColdStock(
      productId: productId,
      desiredColdStoreUnits: coldStockUnits,
    );
    final currentPricing = await _loadLatestPricingForProduct(productId);
    await _upsertPriceHistory(
      productId: productId,
      salePrice: currentPricing?.salePrice ?? 0,
      promotionalPrice: currentPricing?.promotionalPrice,
      promotionNote: currentPricing?.promotionNote,
      coldPriceIncrement: coldPriceIncrement,
    );
  }

  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async {
    dynamic query = _client
        .from('price_history')
        .select(
          'id, product_id, sale_price, promotional_price, promotion_note, '
          'cold_price_increment, effective_from, effective_to, '
          'product:products!price_history_product_id_fkey(name), '
          'creator:profiles!price_history_created_by_fkey(full_name)',
        );

    if (productId != null && productId.isNotEmpty) {
      query = query.eq('product_id', productId);
    }

    final rows = await query.order('effective_from', ascending: false);
    return _mapRows(rows).map((row) {
      final product = _mapNullable(row['product']);
      final creator = _mapNullable(row['creator']);
      return PriceHistoryEntry(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        productName: product['name']?.toString() ?? 'Producto',
        salePrice: _toDoubleValue(row['sale_price']),
        promotionalPrice: _toNullableDoubleValue(row['promotional_price']),
        promotionNote: row['promotion_note']?.toString(),
        coldPriceIncrement: _toDoubleValue(
          row['cold_price_increment'],
          fallback: 0.50,
        ),
        effectiveFrom: _parseSupabaseDateTime(row['effective_from'] as String),
        effectiveTo:
            row['effective_to'] == null
                ? null
                : _parseSupabaseDateTime(row['effective_to'] as String),
        createdByName: creator['full_name']?.toString() ?? 'Administrador',
      );
    }).toList();
  }

  Stream<List<PriceHistoryEntry>> watchPriceHistory({String? productId}) {
    return createRealtimeRefreshStream(
      load: () => getPriceHistory(productId: productId),
      triggers: [
        _tableTrigger('price_history', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger('profiles', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<InventoryMovement>> getInventoryMovements() async {
    final rows = await _client
        .from('inventory_movements')
        .select(
          'id, product_id, batch_id, supplier_id, movement_type, quantity, notes, happened_at, '
          'product:products(name), supplier:suppliers(name), actor:profiles(full_name), '
          'from_location:locations!inventory_movements_from_location_id_fkey(name), '
          'to_location:locations!inventory_movements_to_location_id_fkey(name)',
        )
        .order('happened_at', ascending: false);

    return _mapRows(rows).map((row) {
      final product = _mapNullable(row['product']);
      final supplier = _mapNullable(row['supplier']);
      final actor = _mapNullable(row['actor']);
      final fromLocation = _mapNullable(row['from_location']);
      final toLocation = _mapNullable(row['to_location']);

      return InventoryMovement(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        productName: product['name']?.toString() ?? 'Producto',
        batchId: row['batch_id']?.toString(),
        supplierId: row['supplier_id']?.toString(),
        supplierName: supplier['name']?.toString(),
        type: row['movement_type'] as String,
        quantity: (row['quantity'] as num).toInt(),
        fromLocation: fromLocation['name']?.toString() ?? 'Sin origen',
        toLocation: toLocation['name']?.toString() ?? 'Sin destino',
        actorName: actor['full_name']?.toString() ?? 'Usuario',
        occurredAt: _parseSupabaseDateTime(row['happened_at'] as String),
        notes: row['notes']?.toString(),
      );
    }).toList();
  }

  Stream<List<InventoryMovement>> watchInventoryMovements() {
    return createRealtimeRefreshStream(
      load: getInventoryMovements,
      triggers: [
        _tableTrigger('inventory_movements', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<InventoryLotAlert>> getInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    final today = _dateOnly(DateTime.now());
    final limitDate = today.add(Duration(days: daysAhead));
    final lots = await _loadLotContexts();
    final alerts = <InventoryLotAlert>[];

    for (final lot in lots) {
      final expiryDate = lot.expiryDate;
      if (expiryDate == null || lot.totalAvailableUnits <= 0) {
        continue;
      }

      final normalizedExpiry = _dateOnly(expiryDate);
      final isExpired = normalizedExpiry.isBefore(today);
      final isWithinWindow =
          !isExpired &&
          (normalizedExpiry.isAtSameMomentAs(today) ||
              normalizedExpiry.isBefore(limitDate) ||
              normalizedExpiry.isAtSameMomentAs(limitDate));

      if (expiredOnly && !isExpired) {
        continue;
      }
      if (!expiredOnly && !isWithinWindow) {
        continue;
      }

      alerts.add(
        InventoryLotAlert(
          purchaseItemId: lot.purchaseItemId,
          productId: lot.productId,
          productName: lot.productName,
          supplierId: lot.supplierId,
          supplierName: lot.supplierName,
          receivedAt: lot.receivedAt,
          expiryDate: expiryDate,
          availableUnits: lot.totalAvailableUnits,
        ),
      );
    }

    alerts.sort((left, right) {
      final expiryCompare = left.expiryDate.compareTo(right.expiryDate);
      if (expiryCompare != 0) {
        return expiryCompare;
      }
      return left.productName.toLowerCase().compareTo(
        right.productName.toLowerCase(),
      );
    });
    return alerts;
  }

  Stream<List<InventoryLotAlert>> watchInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) {
    return createRealtimeRefreshStream(
      load:
          () => getInventoryLotAlerts(
            daysAhead: daysAhead,
            expiredOnly: expiredOnly,
          ),
      triggers: [
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('purchases', primaryKey: const ['id']),
        _tableTrigger(
          'inventory_stock',
          primaryKey: const [
            'product_id',
            'location_id',
            'batch_id',
            'storage_condition',
          ],
        ),
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger('suppliers', primaryKey: const ['id']),
      ],
    );
  }

  Future<void> registerInventoryLoss({
    required String purchaseItemId,
    required int quantity,
    String? notes,
  }) async {
    final currentUserId = _currentUserId();
    if (quantity <= 0) {
      throw StateError('La cantidad perdida debe ser mayor a cero.');
    }

    final lot = await _loadLotContextByPurchaseItemId(purchaseItemId);
    if (lot == null || lot.totalAvailableUnits <= 0) {
      throw StateError('El lote ya no tiene stock disponible.');
    }
    if (quantity > lot.totalAvailableUnits) {
      throw StateError('La perdida supera el stock disponible del lote.');
    }

    final rows = await _loadStockRows(batchId: purchaseItemId);
    rows.sort(_stockRowLossPriority);
    var remaining = quantity;
    final now = _toSupabaseDateTime(DateTime.now());
    final normalizedNotes = _normalizeOptionalText(notes);

    for (final row in rows) {
      if (remaining <= 0) {
        break;
      }
      if (row.quantity <= 0) {
        continue;
      }

      final removedUnits = remaining < row.quantity ? remaining : row.quantity;
      await _decrementStockRow(row, removedUnits);
      await _client.from('losses').insert({
        'product_id': row.productId,
        'batch_id': purchaseItemId,
        'location_id': row.locationId,
        'quantity': removedUnits,
        'reason': 'other',
        'financial_impact': lot.unitCost * removedUnits,
        'storage_condition': row.storageCondition,
        'notes': normalizedNotes,
        'reported_by': currentUserId,
        'created_at': now,
      });
      await _client.from('inventory_movements').insert({
        'product_id': row.productId,
        'batch_id': purchaseItemId,
        'movement_type': 'loss',
        'from_location_id': row.locationId,
        'to_location_id': null,
        'quantity': removedUnits,
        'reference_table': 'purchase_items',
        'reference_id': purchaseItemId,
        'created_by': currentUserId,
        'supplier_id': lot.supplierId,
        'happened_at': now,
        'notes': normalizedNotes,
        'from_storage_condition': row.storageCondition,
      });
      remaining -= removedUnits;
    }

    await _syncLotPromotionStatusForBatch(purchaseItemId);
  }

  Future<List<WarehouseSupplierLot>> getWarehouseSupplierLots({
    required String productId,
    String? supplierId,
  }) async {
    final lots = await _loadLotContexts(
      productId: productId,
      supplierId: supplierId,
    );
    final activePromotionByPurchaseItemId =
        await _loadActivePromotionByPurchaseItemId();

    final result =
        lots
            .where((lot) => lot.warehouseAvailableUnits > 0)
            .map(
              (lot) {
                final promotion =
                    activePromotionByPurchaseItemId[lot.purchaseItemId];
                return WarehouseSupplierLot(
                  purchaseItemId: lot.purchaseItemId,
                  productId: lot.productId,
                  supplierId: lot.supplierId,
                  supplierName: lot.supplierName,
                  receivedAt: lot.receivedAt,
                  availableUnits: lot.warehouseAvailableUnits,
                  expiryDate: lot.expiryDate,
                  isPromotionPriority: promotion != null,
                  promotionId: promotion?.promotionId,
                  promotionStatus: promotion?.status,
                  promotionalPrice: promotion?.promotionalPrice,
                  promotionNote: promotion?.note,
                );
              },
            )
            .toList()
          ..sort((left, right) {
            final leftRank = _warehouseLotPromotionRank(left);
            final rightRank = _warehouseLotPromotionRank(right);
            if (leftRank != rightRank) {
              return leftRank.compareTo(rightRank);
            }

            final leftExpiry = left.expiryDate;
            final rightExpiry = right.expiryDate;
            if (leftExpiry != null && rightExpiry != null) {
              final expiryCompare = leftExpiry.compareTo(rightExpiry);
              if (expiryCompare != 0) {
                return expiryCompare;
              }
            } else if (leftExpiry != null) {
              return -1;
            } else if (rightExpiry != null) {
              return 1;
            }

            return left.receivedAt.compareTo(right.receivedAt);
          });

    return result;
  }

  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    String? supplierId,
    String? purchaseItemId,
    String? notes,
  }) async {
    final currentUserId = _currentUserId();
    if (quantity <= 0) {
      throw StateError('La cantidad a transferir debe ser mayor a cero.');
    }

    final warehouseId = await _resolveLocationId('warehouse');
    final storeId = await _resolveLocationId('store');
    final allLots = await getWarehouseSupplierLots(
      productId: productId,
      supplierId: supplierId,
    );
    final normalizedPurchaseItemId = purchaseItemId?.trim();
    final lots =
        normalizedPurchaseItemId == null || normalizedPurchaseItemId.isEmpty
            ? allLots
            : allLots
                .where((lot) => lot.purchaseItemId == normalizedPurchaseItemId)
                .toList();
    if (lots.isEmpty) {
      throw StateError(
        normalizedPurchaseItemId == null || normalizedPurchaseItemId.isEmpty
            ? 'No hay lotes disponibles para mover a tienda.'
            : 'El lote seleccionado ya no tiene stock en almacen.',
      );
    }
    final totalWarehouseUnits = lots.fold<int>(
      0,
      (sum, lot) => sum + lot.availableUnits,
    );
    if (quantity > totalWarehouseUnits) {
      throw StateError(
        normalizedPurchaseItemId == null || normalizedPurchaseItemId.isEmpty
            ? 'No hay suficiente stock en almacen para la transferencia.'
            : 'El lote seleccionado solo tiene ${lots.first.availableUnits} unidades disponibles en almacen.',
      );
    }

    var remaining = quantity;
    final now = _toSupabaseDateTime(DateTime.now());
    final normalizedNotes = _normalizeOptionalText(notes);
    for (final lot in lots) {
      if (remaining <= 0) {
        break;
      }
      final lotToMove =
          remaining < lot.availableUnits ? remaining : lot.availableUnits;
      final lotRows = await _loadStockRows(
        batchId: lot.purchaseItemId,
        locationId: warehouseId,
      );
      var lotRemaining = lotToMove;
      for (final row in lotRows) {
        if (lotRemaining <= 0) {
          break;
        }
        if (row.quantity <= 0) {
          continue;
        }
        final movedUnits =
            lotRemaining < row.quantity ? lotRemaining : row.quantity;
        await _decrementStockRow(row, movedUnits);
        await _incrementOrCreateStockRow(
          productId: row.productId,
          locationId: storeId,
          batchId: row.batchId,
          storageCondition: row.storageCondition,
          quantity: movedUnits,
        );
        await _client.from('inventory_movements').insert({
          'product_id': row.productId,
          'batch_id': row.batchId,
          'movement_type': 'transfer',
          'from_location_id': warehouseId,
          'to_location_id': storeId,
          'quantity': movedUnits,
          'reference_table': 'purchase_items',
          'reference_id': row.batchId,
          'created_by': currentUserId,
          'supplier_id': lot.supplierId,
          'happened_at': now,
          'notes': normalizedNotes,
          'from_storage_condition': row.storageCondition,
          'to_storage_condition': row.storageCondition,
        });
        lotRemaining -= movedUnits;
        remaining -= movedUnits;
      }

      if (lotToMove > 0) {
        await _syncLotPromotionStatusForBatch(lot.purchaseItemId);
      }
    }
  }

  Future<Map<String, _ProductInventorySnapshot>> _loadStockByProduct() async {
    final rows = await _client
        .from('inventory_stock')
        .select(
          'product_id, quantity, storage_condition, location:locations!inventory_stock_location_id_fkey(location_type)',
        );

    final stockByProduct = <String, _ProductInventorySnapshot>{};
    for (final row in _mapRows(rows)) {
      final productId = row['product_id'] as String;
      final location = _mapNullable(row['location']);
      final locationType = location['location_type']?.toString();
      final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
      final storageCondition =
          row['storage_condition']?.toString() ?? 'ambiente';
      final current = stockByProduct.putIfAbsent(
        productId,
        _ProductInventorySnapshot.new,
      );

      if (locationType == 'store') {
        current.storeUnits += quantity;
        if (storageCondition == 'frio') {
          current.coldStoreUnits += quantity;
        }
      } else if (locationType == 'warehouse') {
        current.warehouseUnits += quantity;
      }
    }

    return stockByProduct;
  }

  Future<Map<String, DateTime>> _loadNextExpiryByProduct() async {
    final lots = await _loadLotContexts();
    final expiries = <String, DateTime>{};

    for (final lot in lots) {
      final expiryDate = lot.expiryDate;
      if (expiryDate == null || lot.totalAvailableUnits <= 0) {
        continue;
      }
      final current = expiries[lot.productId];
      if (current == null || expiryDate.isBefore(current)) {
        expiries[lot.productId] = expiryDate;
      }
    }

    return expiries;
  }

  Future<Map<String, List<ProductPromotionOffer>>>
  _loadPromotionOffersByProduct() async {
    final grouped = <String, List<ProductPromotionOffer>>{};
    final promotions = await getActiveLotPromotions();

    for (final promotion in promotions) {
      final offer = ProductPromotionOffer(
        promotionId: promotion.promotionId,
        purchaseItemId: promotion.purchaseItemId,
        supplierId: promotion.supplierId,
        supplierName: promotion.supplierName,
        expiryDate: promotion.expiryDate,
        promotionalPrice: promotion.promotionalPrice,
        promoQuantityTotal: promotion.promoQuantityTotal,
        promoQuantityRemaining: promotion.promoQuantityRemaining,
        storeAvailableUnits: promotion.storeAvailableUnits,
        warehouseAvailableUnits: promotion.warehouseAvailableUnits,
        status: promotion.status,
        note: promotion.note,
        createdAt: promotion.createdAt,
      );
      if (!offer.isActiveInStore) {
        continue;
      }
      grouped.putIfAbsent(promotion.productId, () => []).add(offer);
    }

    for (final entry in grouped.entries) {
      entry.value.sort((left, right) {
        final expiryLeft = left.expiryDate;
        final expiryRight = right.expiryDate;
        if (expiryLeft != null && expiryRight != null) {
          final expiryCompare = expiryLeft.compareTo(expiryRight);
          if (expiryCompare != 0) {
            return expiryCompare;
          }
        } else if (expiryLeft != null) {
          return -1;
        } else if (expiryRight != null) {
          return 1;
        }

        final createdCompare = left.createdAt.compareTo(right.createdAt);
        if (createdCompare != 0) {
          return createdCompare;
        }

        return left.purchaseItemId.compareTo(right.purchaseItemId);
      });
    }

    return grouped;
  }

  // ignore: unused_element
  Future<Map<String, _ProductPricingSnapshot>> _loadActivePricingByProduct({
    required List<String> productIds,
  }) async {
    if (productIds.isEmpty) {
      return const {};
    }

    final activeRows = await _client
        .from('price_history')
        .select(
          'id, product_id, sale_price, promotional_price, promotion_note, cold_price_increment, effective_from, effective_to',
        )
        .inFilter('product_id', productIds)
        .isFilter('effective_to', null)
        .order('effective_from', ascending: false);

    final pricingByProduct = <String, _ProductPricingSnapshot>{};
    for (final row in _mapRows(activeRows)) {
      final productId = row['product_id'] as String;
      if (pricingByProduct.containsKey(productId)) {
        continue;
      }

      pricingByProduct[productId] = _ProductPricingSnapshot(
        id: row['id'] as String,
        salePrice: _toDoubleValue(row['sale_price']),
        promotionalPrice: _toNullableDoubleValue(row['promotional_price']),
        promotionNote: row['promotion_note']?.toString(),
        coldPriceIncrement: _toDoubleValue(
          row['cold_price_increment'],
          fallback: 0.50,
        ),
      );
    }

    if (pricingByProduct.length == productIds.length) {
      return pricingByProduct;
    }

    final missingIds =
        productIds.where((id) => !pricingByProduct.containsKey(id)).toList();
    if (missingIds.isEmpty) {
      return pricingByProduct;
    }

    final fallbackRows = await _client
        .from('price_history')
        .select(
          'id, product_id, sale_price, promotional_price, promotion_note, cold_price_increment, effective_from, effective_to',
        )
        .inFilter('product_id', missingIds)
        .order('effective_from', ascending: false);

    for (final row in _mapRows(fallbackRows)) {
      final productId = row['product_id'] as String;
      if (pricingByProduct.containsKey(productId)) {
        continue;
      }

      pricingByProduct[productId] = _ProductPricingSnapshot(
        id: row['id'] as String,
        salePrice: _toDoubleValue(row['sale_price']),
        promotionalPrice: _toNullableDoubleValue(row['promotional_price']),
        promotionNote: row['promotion_note']?.toString(),
        coldPriceIncrement: _toDoubleValue(
          row['cold_price_increment'],
          fallback: 0.50,
        ),
      );
    }

    return pricingByProduct;
  }

  Future<_ProductPricingSnapshot?> _loadLatestPricingForProduct(
    String productId,
  ) async {
    final rows = await _client
        .from('price_history')
        .select(
          'id, sale_price, promotional_price, promotion_note, cold_price_increment',
        )
        .eq('product_id', productId)
        .order('effective_from', ascending: false)
        .limit(1);
    final data = _mapRows(rows);
    if (data.isEmpty) {
      return null;
    }

    final row = data.first;
    return _ProductPricingSnapshot(
      id: row['id'] as String,
      salePrice: _toDoubleValue(row['sale_price']),
      promotionalPrice: _toNullableDoubleValue(row['promotional_price']),
      promotionNote: row['promotion_note']?.toString(),
      coldPriceIncrement: _toDoubleValue(
        row['cold_price_increment'],
        fallback: 0.50,
      ),
    );
  }

  Future<Map<String, double>> _loadLastPurchaseCostByProduct() async {
    final rows = await _client
        .from('purchase_items')
        .select(
          'product_id, unit_cost, purchase:purchases!purchase_items_purchase_id_fkey(received_at)',
        );

    final latestTimestampByProduct = <String, DateTime>{};
    final latestCostByProduct = <String, double>{};

    for (final row in _mapRows(rows)) {
      final purchase = _mapNullable(row['purchase']);
      final receivedAtRaw = purchase['received_at']?.toString();
      if (receivedAtRaw == null || receivedAtRaw.isEmpty) {
        continue;
      }

      final productId = row['product_id'] as String;
      final receivedAt = _parseSupabaseDateTime(receivedAtRaw);
      final currentReceivedAt = latestTimestampByProduct[productId];
      if (currentReceivedAt != null && currentReceivedAt.isAfter(receivedAt)) {
        continue;
      }

      latestTimestampByProduct[productId] = receivedAt;
      latestCostByProduct[productId] =
          (row['unit_cost'] as num?)?.toDouble() ?? 0;
    }

    return latestCostByProduct;
  }

  Future<Map<String, _LatestPurchaseSnapshot>>
  _loadLatestPurchaseSnapshotsByProduct() async {
    final rows = await _client
        .from('purchase_items')
        .select(
          'product_id, cost_notes, '
          'purchase:purchases!purchase_items_purchase_id_fkey(received_at)',
        );

    final latestTimestampByProduct = <String, DateTime>{};
    final latestSnapshotByProduct = <String, _LatestPurchaseSnapshot>{};

    for (final row in _mapRows(rows)) {
      final purchase = _mapNullable(row['purchase']);
      final receivedAtRaw = purchase['received_at']?.toString();
      if (receivedAtRaw == null || receivedAtRaw.isEmpty) {
        continue;
      }

      final productId = row['product_id'] as String;
      final receivedAt = _parseSupabaseDateTime(receivedAtRaw);
      final currentReceivedAt = latestTimestampByProduct[productId];
      if (currentReceivedAt != null && currentReceivedAt.isAfter(receivedAt)) {
        continue;
      }

      latestTimestampByProduct[productId] = receivedAt;
      latestSnapshotByProduct[productId] = _LatestPurchaseSnapshot(
        costNotes: _normalizedText(row['cost_notes']),
      );
    }

    return latestSnapshotByProduct;
  }

  Future<List<_LotContext>> _loadLotContexts({
    String? productId,
    String? supplierId,
  }) async {
    dynamic query = _client
        .from('purchase_items')
        .select(
          'id, product_id, unit_cost, expiry_date, '
          'product:products!purchase_items_product_id_fkey(name), '
          'purchase:purchases!purchase_items_purchase_id_fkey('
          'received_at, supplier_id, '
          'supplier:suppliers!purchases_supplier_id_fkey(id, name))',
        );

    if (productId != null && productId.trim().isNotEmpty) {
      query = query.eq('product_id', productId);
    }

    final rows = _mapRows(await query);
    final stockByBatch = await _loadBatchStockSummaries(productId: productId);
    final lots = <_LotContext>[];

    for (final row in rows) {
      final purchase = _mapNullable(row['purchase']);
      final supplier = _mapNullable(purchase['supplier']);
      final resolvedSupplierId = purchase['supplier_id']?.toString();
      if (supplierId != null &&
          supplierId.trim().isNotEmpty &&
          resolvedSupplierId != supplierId) {
        continue;
      }

      final stock = stockByBatch[row['id'] as String] ?? _BatchStockSummary();
      final product = _mapNullable(row['product']);
      lots.add(
        _LotContext(
          purchaseItemId: row['id'] as String,
          productId: row['product_id'] as String,
          productName: product['name']?.toString() ?? 'Producto',
          unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
          supplierId: resolvedSupplierId,
          supplierName: supplier['name']?.toString() ?? 'Proveedor',
          receivedAt: _parseSupabaseDateTime(purchase['received_at'] as String),
          expiryDate:
              row['expiry_date'] == null
                  ? null
                  : DateTime.parse(row['expiry_date'] as String),
          warehouseAvailableUnits: stock.warehouseUnits,
          storeAvailableUnits: stock.storeUnits,
          totalAvailableUnits: stock.totalUnits,
        ),
      );
    }

    lots.sort((left, right) {
      final leftExpiry = left.expiryDate;
      final rightExpiry = right.expiryDate;
      if (leftExpiry != null && rightExpiry != null) {
        final expiryCompare = leftExpiry.compareTo(rightExpiry);
        if (expiryCompare != 0) {
          return expiryCompare;
        }
      } else if (leftExpiry != null) {
        return -1;
      } else if (rightExpiry != null) {
        return 1;
      }

      return left.receivedAt.compareTo(right.receivedAt);
    });

    return lots;
  }

  Future<Map<String, LotPromotion>> _loadActivePromotionByPurchaseItemId()
      async {
    final promotions = await getActiveLotPromotions();
    final map = <String, LotPromotion>{};
    for (final promotion in promotions) {
      map[promotion.purchaseItemId] = promotion;
    }
    return map;
  }

  Future<void> _syncLotPromotionStatusForBatch(String purchaseItemId) async {
    final rows = await _client
        .from('lot_promotions')
        .select('id, status, promo_quantity_remaining')
        .eq('purchase_item_id', purchaseItemId)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false)
        .limit(1);
    final data = _mapRows(rows);
    if (data.isEmpty) {
      return;
    }

    final promotion = data.first;
    final stock =
        (await _loadBatchStockSummaries())[purchaseItemId] ??
        _BatchStockSummary();
    final remaining =
        (promotion['promo_quantity_remaining'] as num?)?.toInt() ?? 0;
    final nextStatus =
        remaining <= 0 || stock.totalUnits <= 0
            ? 'exhausted'
            : stock.storeUnits > 0
            ? 'active_store'
            : 'pending_transfer';
    final currentStatus =
        promotion['status']?.toString() ?? 'pending_transfer';
    if (currentStatus == nextStatus) {
      return;
    }

    await _client
        .from('lot_promotions')
        .update({
          'status': nextStatus,
          'updated_at': _toSupabaseDateTime(DateTime.now()),
          'exhausted_at':
              nextStatus == 'exhausted'
                  ? _toSupabaseDateTime(DateTime.now())
                  : null,
        })
        .eq('id', promotion['id'] as String);
  }

  Future<_LotContext?> _loadLotContextByPurchaseItemId(
    String purchaseItemId,
  ) async {
    final rows = await _loadLotContexts();
    for (final lot in rows) {
      if (lot.purchaseItemId == purchaseItemId) {
        return lot;
      }
    }
    return null;
  }

  Future<Map<String, _BatchStockSummary>> _loadBatchStockSummaries({
    String? productId,
  }) async {
    dynamic query = _client
        .from('inventory_stock')
        .select(
          'product_id, batch_id, quantity, storage_condition, '
          'location:locations!inventory_stock_location_id_fkey(location_type)',
        );

    if (productId != null && productId.trim().isNotEmpty) {
      query = query.eq('product_id', productId);
    }

    final rows = await query;
    final stockByBatch = <String, _BatchStockSummary>{};
    for (final row in _mapRows(rows)) {
      final batchId = row['batch_id'] as String;
      final location = _mapNullable(row['location']);
      final locationType = location['location_type']?.toString();
      final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
      final current = stockByBatch.putIfAbsent(batchId, _BatchStockSummary.new);

      current.totalUnits += quantity;
      if (locationType == 'warehouse') {
        current.warehouseUnits += quantity;
      } else if (locationType == 'store') {
        current.storeUnits += quantity;
      }
    }

    return stockByBatch;
  }

  Future<void> _syncStoreColdStock({
    required String productId,
    required int desiredColdStoreUnits,
  }) async {
    final storeId = await _resolveLocationId('store');
    final rows = await _loadStockRows(
      productId: productId,
      locationId: storeId,
    );
    final totalStoreUnits = rows.fold<int>(0, (sum, row) => sum + row.quantity);
    final boundedTarget =
        desiredColdStoreUnits < 0
            ? 0
            : desiredColdStoreUnits > totalStoreUnits
            ? totalStoreUnits
            : desiredColdStoreUnits;
    final currentColdUnits = rows
        .where((row) => row.storageCondition == 'frio')
        .fold<int>(0, (sum, row) => sum + row.quantity);

    if (boundedTarget == currentColdUnits) {
      return;
    }

    if (boundedTarget > currentColdUnits) {
      await _moveStorageConditionUnits(
        rows: rows,
        fromCondition: 'ambiente',
        toCondition: 'frio',
        units: boundedTarget - currentColdUnits,
      );
      return;
    }

    await _moveStorageConditionUnits(
      rows: rows,
      fromCondition: 'frio',
      toCondition: 'ambiente',
      units: currentColdUnits - boundedTarget,
    );
  }

  Future<void> _moveStorageConditionUnits({
    required List<_InventoryStockRow> rows,
    required String fromCondition,
    required String toCondition,
    required int units,
  }) async {
    var remaining = units;
    final candidates =
        rows
            .where(
              (row) =>
                  row.storageCondition == fromCondition && row.quantity > 0,
            )
            .toList()
          ..sort((left, right) {
            final updatedCompare = left.updatedAt.compareTo(right.updatedAt);
            if (updatedCompare != 0) {
              return updatedCompare;
            }
            return left.batchId.compareTo(right.batchId);
          });

    for (final row in candidates) {
      if (remaining <= 0) {
        break;
      }

      final movedUnits = remaining < row.quantity ? remaining : row.quantity;
      await _decrementStockRow(row, movedUnits);
      await _incrementOrCreateStockRow(
        productId: row.productId,
        locationId: row.locationId,
        batchId: row.batchId,
        storageCondition: toCondition,
        quantity: movedUnits,
      );
      remaining -= movedUnits;
    }
  }

  Future<List<_InventoryStockRow>> _loadStockRows({
    String? productId,
    String? locationId,
    String? batchId,
  }) async {
    dynamic query = _client
        .from('inventory_stock')
        .select(
          'product_id, location_id, batch_id, storage_condition, quantity, updated_at, '
          'location:locations!inventory_stock_location_id_fkey(location_type)',
        );

    if (productId != null && productId.trim().isNotEmpty) {
      query = query.eq('product_id', productId);
    }
    if (locationId != null && locationId.trim().isNotEmpty) {
      query = query.eq('location_id', locationId);
    }
    if (batchId != null && batchId.trim().isNotEmpty) {
      query = query.eq('batch_id', batchId);
    }

    final rows = await query.order('updated_at');
    return _mapRows(rows).map((row) {
      final location = _mapNullable(row['location']);
      return _InventoryStockRow(
        productId: row['product_id'] as String,
        locationId: row['location_id'] as String,
        locationType: location['location_type']?.toString() ?? '',
        batchId: row['batch_id'] as String,
        storageCondition: row['storage_condition']?.toString() ?? 'ambiente',
        quantity: (row['quantity'] as num?)?.toInt() ?? 0,
        updatedAt:
            row['updated_at'] == null
                ? DateTime.fromMillisecondsSinceEpoch(0)
                : _parseSupabaseDateTime(row['updated_at'] as String),
      );
    }).toList();
  }

  Future<void> _decrementStockRow(_InventoryStockRow row, int quantity) async {
    final nextQuantity = row.quantity - quantity;
    if (nextQuantity > 0) {
      await _client
          .from('inventory_stock')
          .update({
            'quantity': nextQuantity,
            'updated_at': _toSupabaseDateTime(DateTime.now()),
          })
          .eq('product_id', row.productId)
          .eq('location_id', row.locationId)
          .eq('batch_id', row.batchId)
          .eq('storage_condition', row.storageCondition);
      return;
    }

    await _client
        .from('inventory_stock')
        .delete()
        .eq('product_id', row.productId)
        .eq('location_id', row.locationId)
        .eq('batch_id', row.batchId)
        .eq('storage_condition', row.storageCondition);
  }

  Future<void> _incrementOrCreateStockRow({
    required String productId,
    required String locationId,
    required String batchId,
    required String storageCondition,
    required int quantity,
  }) async {
    final rows = await _client
        .from('inventory_stock')
        .select('quantity')
        .eq('product_id', productId)
        .eq('location_id', locationId)
        .eq('batch_id', batchId)
        .eq('storage_condition', storageCondition)
        .limit(1);
    final data = _mapRows(rows);
    if (data.isEmpty) {
      await _client.from('inventory_stock').insert({
        'product_id': productId,
        'location_id': locationId,
        'batch_id': batchId,
        'storage_condition': storageCondition,
        'quantity': quantity,
      });
      return;
    }

    final currentQuantity = (data.first['quantity'] as num?)?.toInt() ?? 0;
    await _client
        .from('inventory_stock')
        .update({
          'quantity': currentQuantity + quantity,
          'updated_at': _toSupabaseDateTime(DateTime.now()),
        })
        .eq('product_id', productId)
        .eq('location_id', locationId)
        .eq('batch_id', batchId)
        .eq('storage_condition', storageCondition);
  }

  Future<void> _upsertPriceHistory({
    required String productId,
    required double salePrice,
    required double coldPriceIncrement,
    double? promotionalPrice,
    String? promotionNote,
  }) async {
    final currentUserId = _currentUserId();
    final rows = await _client
        .from('price_history')
        .select(
          'id, sale_price, promotional_price, promotion_note, cold_price_increment, effective_to',
        )
        .eq('product_id', productId)
        .order('effective_from', ascending: false)
        .limit(1);
    final data = _mapRows(rows);

    if (data.isNotEmpty) {
      final current = data.first;
      final currentSalePrice = (current['sale_price'] as num?)?.toDouble() ?? 0;
      final currentPromotionalPrice =
          (current['promotional_price'] as num?)?.toDouble();
      final currentPromotionNote = current['promotion_note']?.toString();
      final currentColdIncrement =
          (current['cold_price_increment'] as num?)?.toDouble() ?? 0.50;

      if (currentSalePrice == salePrice &&
          currentPromotionalPrice == promotionalPrice &&
          currentPromotionNote == promotionNote &&
          currentColdIncrement == coldPriceIncrement &&
          current['effective_to'] == null) {
        return;
      }

      if (current['effective_to'] == null) {
        await _client
            .from('price_history')
            .update({'effective_to': _toSupabaseDateTime(DateTime.now())})
            .eq('id', current['id'] as String);
      }
    }

    await _client.from('price_history').insert({
      'product_id': productId,
      'sale_price': salePrice,
      'promotional_price': promotionalPrice,
      'promotion_note': promotionNote,
      'cold_price_increment': coldPriceIncrement,
      'effective_from': _toSupabaseDateTime(DateTime.now()),
      'created_by': currentUserId,
    });
  }

  Future<String> _resolveLocationId(String locationType) async {
    final rows = await _client
        .from('locations')
        .select('id')
        .eq('location_type', locationType)
        .limit(1);

    final data = _mapRows(rows);
    if (data.isEmpty) {
      throw StateError(
        'No existe una ubicacion configurada para $locationType.',
      );
    }

    return data.first['id'] as String;
  }

  String _currentUserId() {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError(
        'No hay una sesion activa para completar esta operacion.',
      );
    }
    return currentUserId;
  }

  List<Map<String, dynamic>> _mapRows(dynamic rows) {
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Map<String, dynamic> _mapNullable(dynamic value) {
    if (value == null) {
      return const {};
    }

    return Map<String, dynamic>.from(value as Map);
  }

  double _toDoubleValue(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  double? _toNullableDoubleValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Stream<dynamic> _tableTrigger(
    String table, {
    required List<String> primaryKey,
  }) {
    return _client.from(table).stream(primaryKey: primaryKey).skip(1);
  }
}

const String _productSelectClause =
    'id, sku, category_id, name, product_type, units_per_package, '
    'package_name, unit_name, low_stock_threshold, is_active, brand, presentation';

class _ProductPricingSnapshot {
  const _ProductPricingSnapshot({
    required this.id,
    required this.salePrice,
    required this.promotionalPrice,
    required this.promotionNote,
    required this.coldPriceIncrement,
  });

  const _ProductPricingSnapshot.empty()
    : id = '',
      salePrice = 0,
      promotionalPrice = null,
      promotionNote = null,
      coldPriceIncrement = 0.50;

  final String id;
  final double salePrice;
  final double? promotionalPrice;
  final String? promotionNote;
  final double coldPriceIncrement;
}

class _ProductInventorySnapshot {
  _ProductInventorySnapshot({
    this.storeUnits = 0,
    this.warehouseUnits = 0,
    this.coldStoreUnits = 0,
  });

  int storeUnits;
  int warehouseUnits;
  int coldStoreUnits;
}

class _LatestPurchaseSnapshot {
  const _LatestPurchaseSnapshot({this.costNotes});

  final String? costNotes;
}

class _BatchStockSummary {
  _BatchStockSummary({
    this.warehouseUnits = 0,
    this.storeUnits = 0,
    this.totalUnits = 0,
  });

  int warehouseUnits;
  int storeUnits;
  int totalUnits;
}

class _LotContext {
  const _LotContext({
    required this.purchaseItemId,
    required this.productId,
    required this.productName,
    required this.unitCost,
    required this.supplierId,
    required this.supplierName,
    required this.receivedAt,
    required this.expiryDate,
    required this.warehouseAvailableUnits,
    required this.storeAvailableUnits,
    required this.totalAvailableUnits,
  });

  final String purchaseItemId;
  final String productId;
  final String productName;
  final double unitCost;
  final String? supplierId;
  final String supplierName;
  final DateTime receivedAt;
  final DateTime? expiryDate;
  final int warehouseAvailableUnits;
  final int storeAvailableUnits;
  final int totalAvailableUnits;
}

class _InventoryStockRow {
  const _InventoryStockRow({
    required this.productId,
    required this.locationId,
    required this.locationType,
    required this.batchId,
    required this.storageCondition,
    required this.quantity,
    required this.updatedAt,
  });

  final String productId;
  final String locationId;
  final String locationType;
  final String batchId;
  final String storageCondition;
  final int quantity;
  final DateTime updatedAt;
}

int _stockRowLossPriority(_InventoryStockRow left, _InventoryStockRow right) {
  final leftRank = left.locationType == 'warehouse' ? 0 : 1;
  final rightRank = right.locationType == 'warehouse' ? 0 : 1;
  if (leftRank != rightRank) {
    return leftRank.compareTo(rightRank);
  }

  final updatedCompare = left.updatedAt.compareTo(right.updatedAt);
  if (updatedCompare != 0) {
    return updatedCompare;
  }

  return left.batchId.compareTo(right.batchId);
}

int _warehouseLotPromotionRank(WarehouseSupplierLot lot) {
  if (!lot.isPromotionPriority) {
    return 2;
  }
  if (lot.promotionStatus == 'pending_transfer') {
    return 0;
  }
  if (lot.promotionStatus == 'active_store') {
    return 1;
  }
  return 2;
}

String _warehouseSupplierLotsKey({
  required String productId,
  String? supplierId,
}) {
  final normalizedSupplierId = supplierId?.trim() ?? '';
  return '$productId::$normalizedSupplierId';
}

String _inventoryLotAlertsKey(int daysAhead, bool expiredOnly) {
  return '$daysAhead::$expiredOnly';
}

String _productPackageName(Map<String, dynamic> costDetails) {
  return _normalizedText(costDetails['package_name']) ?? 'caja';
}

String _productUnitName(Map<String, dynamic> costDetails) {
  return _normalizedText(costDetails['unit_name']) ?? 'unid';
}

String? _productBrand(Map<String, dynamic> costDetails) {
  return _normalizedText(costDetails['brand']) ??
      _normalizedText(costDetails['marca']);
}

String? _productPresentation(Map<String, dynamic> costDetails) {
  return _normalizedText(costDetails['presentation']) ??
      _normalizedText(costDetails['presentacion']);
}

String? _normalizedText(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? _normalizeOptionalText(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

DateTime _parseSupabaseDateTime(String rawValue) {
  return DateTime.parse(rawValue).toLocal();
}

String _toSupabaseDateTime(DateTime value) {
  return value.toUtc().toIso8601String();
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
