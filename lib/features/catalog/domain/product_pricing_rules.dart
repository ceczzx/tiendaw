import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';

bool isBeverageCategory(Category category) {
  return category.prefix.trim().toUpperCase() == 'BEBI';
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
  return generalPromotionalPrice(product) != null ||
      availablePromotionUnits(product) > 0;
}

double? generalPromotionalPrice(Product product) {
  final promotionalPrice = product.promotionalPrice;
  if (promotionalPrice == null ||
      promotionalPrice <= 0 ||
      promotionalPrice >= product.salePrice) {
    return null;
  }
  return promotionalPrice;
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
  var bestPrice = generalPromotionalPrice(product);
  final offers = activePromotionOffers(product);
  if (offers.isEmpty) {
    return bestPrice;
  }

  for (final offer in offers) {
    final offerPrice = promotionalUnitPriceForOffer(product, offer);
    if (bestPrice == null || offerPrice < bestPrice) {
      bestPrice = offerPrice;
    }
  }
  return bestPrice;
}

double promotionalUnitPriceForOffer(Product product, ProductPromotionOffer offer) {
  final generalPrice = generalPromotionalPrice(product);
  if (generalPrice == null || offer.promotionalPrice < generalPrice) {
    return offer.promotionalPrice;
  }
  return generalPrice;
}

double effectiveBaseSalePrice(Product product) {
  var bestPrice = product.salePrice;
  final generalPrice = generalPromotionalPrice(product);
  final lotPrice = bestPromotionalPrice(product);

  if (generalPrice != null && generalPrice < bestPrice) {
    bestPrice = generalPrice;
  }
  if (lotPrice != null && lotPrice < bestPrice) {
    bestPrice = lotPrice;
  }

  return bestPrice;
}

double effectiveSalePrice(Product product, {bool isIced = false}) {
  final basePrice = effectiveBaseSalePrice(product);
  if (!isIced) {
    return basePrice;
  }
  return basePrice + coldPriceIncrement(product);
}
