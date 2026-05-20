import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';

bool isBeverageCategory(Category category) {
  final normalizedName = category.name.trim().toLowerCase();
  final normalizedPrefix = category.prefix.trim().toLowerCase();
  return normalizedName.contains('bebid') || normalizedPrefix.startsWith('beb');
}

bool isBeverageProduct(Product product, List<Category> categories) {
  for (final category in categories) {
    if (category.id == product.categoryId) {
      return isBeverageCategory(category);
    }
  }
  return false;
}

bool hasColdStock(Product product) {
  return product.coldStockUnits > 0;
}

double coldPriceIncrement(Product product) {
  return product.coldPriceIncrement;
}

bool hasActivePromotion(Product product) {
  return availablePromotionUnits(product) > 0;
}

List<ProductPromotionOffer> activePromotionOffers(Product product) {
  return product.promotionOffers.where((offer) => offer.isActiveInStore).toList(
    growable: false,
  );
}

int availablePromotionUnits(Product product) {
  return activePromotionOffers(
    product,
  ).fold(0, (sum, offer) => sum + offer.allocatableUnits);
}

double? bestPromotionalPrice(Product product) {
  final offers = activePromotionOffers(product);
  if (offers.isEmpty) {
    return null;
  }

  var bestPrice = offers.first.promotionalPrice;
  for (final offer in offers.skip(1)) {
    if (offer.promotionalPrice < bestPrice) {
      bestPrice = offer.promotionalPrice;
    }
  }
  return bestPrice;
}

double effectiveBaseSalePrice(Product product) {
  return bestPromotionalPrice(product) ?? product.salePrice;
}

double effectiveSalePrice(Product product, {bool isIced = false}) {
  final basePrice = effectiveBaseSalePrice(product);
  if (!isIced) {
    return basePrice;
  }
  return basePrice + coldPriceIncrement(product);
}
