import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';

class SystemWStore {
  SystemWStore.seeded()
    : categories = [
        const Category(id: 'cat-bebidas', name: 'Bebidas'),
        const Category(id: 'cat-snacks', name: 'Snacks'),
        const Category(id: 'cat-limpieza', name: 'Limpieza'),
        const Category(id: 'cat-lacteos', name: 'Lacteos'),
      ],
      products = [
        Product(
          id: 'prod-coca-600',
          categoryId: 'cat-bebidas',
          name: 'Coca Cola 600ml',
          salePrice: 4.50,
          lastPurchaseCost: 2.80,
          stockStore: 18,
          stockWarehouse: 72,
          lowStockThreshold: 20,
          nextExpiryDate: DateTime.now().add(const Duration(days: 10)),
        ),
        Product(
          id: 'prod-agua',
          categoryId: 'cat-bebidas',
          name: 'Agua 625ml',
          salePrice: 2.00,
          lastPurchaseCost: 1.10,
          stockStore: 44,
          stockWarehouse: 120,
          lowStockThreshold: 20,
        ),
        Product(
          id: 'prod-papas',
          categoryId: 'cat-snacks',
          name: 'Papas Clasicas',
          salePrice: 3.20,
          lastPurchaseCost: 1.70,
          stockStore: 15,
          stockWarehouse: 80,
          lowStockThreshold: 20,
        ),
        Product(
          id: 'prod-galleta',
          categoryId: 'cat-snacks',
          name: 'Galleta Integral',
          salePrice: 1.80,
          lastPurchaseCost: 0.95,
          stockStore: 33,
          stockWarehouse: 64,
          lowStockThreshold: 20,
        ),
        Product(
          id: 'prod-detergente',
          categoryId: 'cat-limpieza',
          name: 'Detergente 500g',
          salePrice: 7.50,
          lastPurchaseCost: 4.30,
          stockStore: 22,
          stockWarehouse: 45,
          lowStockThreshold: 20,
        ),
        Product(
          id: 'prod-yogurt',
          categoryId: 'cat-lacteos',
          name: 'Yogurt Fresa 1L',
          salePrice: 8.90,
          lastPurchaseCost: 5.20,
          stockStore: 12,
          stockWarehouse: 30,
          lowStockThreshold: 20,
          nextExpiryDate: DateTime.now().add(const Duration(days: 12)),
        ),
      ],
      priceHistory = [
        PriceHistoryEntry(
          id: 'ph-1',
          productId: 'prod-coca-600',
          productName: 'Coca Cola 600ml',
          supplier: 'Distribuidora Lima Norte',
          unitCost: 2.70,
          registeredAt: DateTime.now().subtract(const Duration(days: 18)),
        ),
        PriceHistoryEntry(
          id: 'ph-2',
          productId: 'prod-coca-600',
          productName: 'Coca Cola 600ml',
          supplier: 'Distribuidora Lima Norte',
          unitCost: 2.80,
          registeredAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
        PriceHistoryEntry(
          id: 'ph-3',
          productId: 'prod-yogurt',
          productName: 'Yogurt Fresa 1L',
          supplier: 'Lacteos Andinos',
          unitCost: 5.20,
          registeredAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
      sales = [
        Sale(
          id: 'sale-1',
          sellerId: 'seller-1',
          sellerName: 'Luis Vega',
          items: const [
            SaleLine(
              productId: 'prod-agua',
              productName: 'Agua 625ml',
              quantity: 4,
              unitPrice: 2.00,
            ),
          ],
          paymentMethod: PaymentMethod.cash,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          syncStatus: SyncStatus.synced,
          syncAttempts: 1,
        ),
        Sale(
          id: 'sale-2',
          sellerId: 'seller-2',
          sellerName: 'Carla Soto',
          items: const [
            SaleLine(
              productId: 'prod-coca-600',
              productName: 'Coca Cola 600ml',
              quantity: 6,
              unitPrice: 4.50,
            ),
          ],
          paymentMethod: PaymentMethod.yape,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          syncStatus: SyncStatus.synced,
          syncAttempts: 1,
        ),
      ],
      purchases = [
        Purchase(
          id: 'pur-1',
          supplier: 'Distribuidora Lima Norte',
          registeredBy: 'Mariana Ruiz',
          items: [
            PurchaseLine(
              productId: 'prod-coca-600',
              productName: 'Coca Cola 600ml',
              quantity: 24,
              unitCost: 2.80,
              expiryDate: DateTime.now().add(const Duration(days: 45)),
            ),
          ],
          receivedAt: DateTime.now().subtract(const Duration(days: 4)),
          syncStatus: SyncStatus.synced,
          syncAttempts: 1,
        ),
      ],
      movements = [
        InventoryMovement(
          id: 'mov-1',
          productId: 'prod-coca-600',
          productName: 'Coca Cola 600ml',
          type: 'transferencia',
          quantity: 24,
          fromLocation: 'almacen',
          toLocation: 'tienda',
          actorName: 'Mariana Ruiz',
          occurredAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
      openShift = CashShift(
        id: 'shift-1',
        sellerId: 'seller-1',
        openedAt: DateTime.now().subtract(const Duration(hours: 8)),
        cashSales: 8.00,
        yapeSales: 27.00,
      );

  bool isOnline = true;
  final List<Category> categories;
  final List<Product> products;
  final List<PriceHistoryEntry> priceHistory;
  final List<Sale> sales;
  final List<Purchase> purchases;
  final List<InventoryMovement> movements;
  CashShift openShift;

  int get pendingTransactionsCount =>
      pendingSales.length + pendingPurchases.length;

  List<Sale> get pendingSales =>
      sales.where((sale) => sale.syncStatus != SyncStatus.synced).toList();

  List<Purchase> get pendingPurchases =>
      purchases
          .where((purchase) => purchase.syncStatus != SyncStatus.synced)
          .toList();

  List<Category> listCategories() => List.unmodifiable(categories);
  List<Product> listProducts() => List.unmodifiable(products);
  List<Sale> listSales() => List.unmodifiable(
    sales..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
  List<Purchase> listPurchases() => List.unmodifiable(
    purchases..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)),
  );
  List<InventoryMovement> listInventoryMovements() => List.unmodifiable(
    movements..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
  );
  List<PriceHistoryEntry> listPriceHistory({String? productId}) {
    final entries =
        productId == null
            ? priceHistory
            : priceHistory
                .where((entry) => entry.productId == productId)
                .toList();
    return List.unmodifiable(
      entries..sort((a, b) => b.registeredAt.compareTo(a.registeredAt)),
    );
  }

  Product findProduct(String productId) {
    return products.firstWhere((product) => product.id == productId);
  }

  void saveSale(Sale sale) {
    sales.add(sale);
    _applySale(sale);
  }

  void savePurchase(Purchase purchase) {
    purchases.add(purchase);
    _applyPurchase(purchase);
  }

  void transferWarehouseToStore({
    required String productId,
    required int quantity,
    required String actorName,
  }) {
    final index = products.indexWhere((product) => product.id == productId);
    final currentProduct = products[index];
    final transferable =
        quantity > currentProduct.stockWarehouse
            ? currentProduct.stockWarehouse
            : quantity;

    products[index] = currentProduct.copyWith(
      stockWarehouse: currentProduct.stockWarehouse - transferable,
      stockStore: currentProduct.stockStore + transferable,
    );

    movements.add(
      InventoryMovement(
        id: 'mov-${movements.length + 1}',
        productId: productId,
        productName: currentProduct.name,
        type: 'transferencia',
        quantity: transferable,
        fromLocation: 'almacen',
        toLocation: 'tienda',
        actorName: actorName,
        occurredAt: DateTime.now(),
      ),
    );
  }

  void closeShift() {
    openShift = openShift.copyWith(closedAt: DateTime.now());
  }

  void reopenShiftForSeller(String sellerId) {
    openShift = CashShift(
      id: 'shift-${DateTime.now().millisecondsSinceEpoch}',
      sellerId: sellerId,
      openedAt: DateTime.now(),
      cashSales: 0,
      yapeSales: 0,
    );
  }

  void markSaleSynced(String saleId) {
    final index = sales.indexWhere((sale) => sale.id == saleId);
    if (index == -1) {
      return;
    }

    sales[index] = sales[index].copyWith(
      syncStatus: SyncStatus.synced,
      syncAttempts: sales[index].syncAttempts + 1,
    );
  }

  void markPurchaseSynced(String purchaseId) {
    final index = purchases.indexWhere((purchase) => purchase.id == purchaseId);
    if (index == -1) {
      return;
    }

    purchases[index] = purchases[index].copyWith(
      syncStatus: SyncStatus.synced,
      syncAttempts: purchases[index].syncAttempts + 1,
    );
  }

  void increaseSaleSyncAttempts(String saleId) {
    final index = sales.indexWhere((sale) => sale.id == saleId);
    if (index == -1) {
      return;
    }

    sales[index] = sales[index].copyWith(
      syncStatus: SyncStatus.failed,
      syncAttempts: sales[index].syncAttempts + 1,
    );
  }

  void increasePurchaseSyncAttempts(String purchaseId) {
    final index = purchases.indexWhere((purchase) => purchase.id == purchaseId);
    if (index == -1) {
      return;
    }

    purchases[index] = purchases[index].copyWith(
      syncStatus: SyncStatus.failed,
      syncAttempts: purchases[index].syncAttempts + 1,
    );
  }

  List<Product> lowStockProducts() {
    return products
        .where((product) => product.stockStore < product.lowStockThreshold)
        .toList();
  }

  List<Product> expiringProducts() {
    final today = DateTime.now();
    return products.where((product) {
      final expiryDate = product.nextExpiryDate;
      if (expiryDate == null) {
        return false;
      }

      final remainingDays = expiryDate.difference(today).inDays;
      return remainingDays <= 14;
    }).toList();
  }

  void cleanupSyncedTransactions() {
    final threshold = DateTime.now().subtract(const Duration(days: 7));
    sales.removeWhere(
      (sale) =>
          sale.syncStatus == SyncStatus.synced &&
          sale.createdAt.isBefore(threshold),
    );
    purchases.removeWhere(
      (purchase) =>
          purchase.syncStatus == SyncStatus.synced &&
          purchase.receivedAt.isBefore(threshold),
    );
  }

  void _applySale(Sale sale) {
    for (final item in sale.items) {
      final index = products.indexWhere(
        (product) => product.id == item.productId,
      );
      final product = products[index];
      products[index] = product.copyWith(
        stockStore: (product.stockStore - item.quantity).clamp(0, 1000000),
      );

      movements.add(
        InventoryMovement(
          id: 'mov-${movements.length + 1}',
          productId: item.productId,
          productName: item.productName,
          type: 'venta',
          quantity: item.quantity,
          fromLocation: 'tienda',
          toLocation: 'cliente',
          actorName: sale.sellerName,
          occurredAt: sale.createdAt,
        ),
      );
    }

    openShift = openShift.copyWith(
      cashSales:
          sale.paymentMethod == PaymentMethod.cash
              ? openShift.cashSales + sale.total
              : openShift.cashSales,
      yapeSales:
          sale.paymentMethod == PaymentMethod.yape
              ? openShift.yapeSales + sale.total
              : openShift.yapeSales,
    );
  }

  void _applyPurchase(Purchase purchase) {
    for (final item in purchase.items) {
      final index = products.indexWhere(
        (product) => product.id == item.productId,
      );
      final product = products[index];
      final bestExpiry =
          product.nextExpiryDate == null
              ? item.expiryDate
              : item.expiryDate != null &&
                  item.expiryDate!.isBefore(product.nextExpiryDate!)
              ? item.expiryDate
              : product.nextExpiryDate;

      products[index] = product.copyWith(
        stockWarehouse: product.stockWarehouse + item.quantity,
        lastPurchaseCost: item.unitCost,
        nextExpiryDate: bestExpiry,
      );

      priceHistory.add(
        PriceHistoryEntry(
          id: 'ph-${priceHistory.length + 1}',
          productId: item.productId,
          productName: item.productName,
          supplier: purchase.supplier,
          unitCost: item.unitCost,
          registeredAt: purchase.receivedAt,
        ),
      );

      movements.add(
        InventoryMovement(
          id: 'mov-${movements.length + 1}',
          productId: item.productId,
          productName: item.productName,
          type: 'compra',
          quantity: item.quantity,
          fromLocation: 'proveedor',
          toLocation: 'almacen',
          actorName: purchase.registeredBy,
          occurredAt: purchase.receivedAt,
        ),
      );
    }
  }
}
