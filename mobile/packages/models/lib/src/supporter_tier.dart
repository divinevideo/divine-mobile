// ABOUTME: Typed model describing a Divine supporter subscription tier.
// ABOUTME: Maps an in-app purchase product to a human-readable support offer.

import 'package:meta/meta.dart';

/// How often a supporter subscription renews.
enum SupporterBillingPeriod {
  /// Renews every month.
  monthly,

  /// Renews every year.
  annual,
}

/// A purchasable supporter tier, backed by a StoreKit / Play Billing product.
///
/// The [productId] is the platform-specific SKU configured in App Store
/// Connect and the Google Play Console. [price] and [currencyCode] come from
/// the store's localized price for that product so we never hard-code amounts.
@immutable
class SupporterTier {
  const SupporterTier({
    required this.productId,
    required this.title,
    required this.price,
    this.currencyCode,
    this.description,
    this.billingPeriod,
  });

  /// Platform-specific product identifier (SKU) from the store console.
  final String productId;

  /// Human-readable title shown to the user (from the store product).
  final String title;

  /// Localized display price as returned by the store (e.g. "$4.99").
  final String price;

  /// ISO 4217 currency code for the localized price, when known.
  final String? currencyCode;

  /// Optional marketing description of the tier.
  final String? description;

  /// How often the tier renews, or `null` when the period is not known.
  ///
  /// The UI only names a billing period when this is set, so an unknown
  /// product is never shown with a period it does not have.
  final SupporterBillingPeriod? billingPeriod;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'title': title,
    'price': price,
    if (currencyCode != null) 'currencyCode': currencyCode,
    if (description != null) 'description': description,
    if (billingPeriod != null) 'billingPeriod': billingPeriod!.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupporterTier &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          title == other.title &&
          price == other.price &&
          currencyCode == other.currencyCode &&
          description == other.description &&
          billingPeriod == other.billingPeriod;

  @override
  int get hashCode => Object.hash(
    productId,
    title,
    price,
    currencyCode,
    description,
    billingPeriod,
  );

  @override
  String toString() =>
      'SupporterTier(productId: $productId, title: $title, price: $price, '
      'billingPeriod: ${billingPeriod?.name})';
}
