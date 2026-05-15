import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_info.dart';
import '../utils/affiliate.dart';

/// A single line item in the local viewer-side bag.
///
/// Identity is derived from brand+name so re-adding an already-present product
/// bumps its quantity instead of inserting a duplicate row.
class CartItem {
  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double? price;
  final String? size;
  final int quantity;
  final String? affiliateQuery;

  const CartItem({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    this.price,
    this.size,
    this.quantity = 1,
    this.affiliateQuery,
  });

  CartItem copyWith({String? size, int? quantity}) => CartItem(
        id: id,
        name: name,
        brand: brand,
        imageUrl: imageUrl,
        price: price,
        size: size ?? this.size,
        quantity: quantity ?? this.quantity,
        affiliateQuery: affiliateQuery,
      );

  static String idFor(ProductInfo p) =>
      '${(p.brand ?? '').toLowerCase()}|${(p.name ?? '').toLowerCase()}';

  factory CartItem.fromProduct(ProductInfo p) {
    final query = [p.brand, p.name].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    return CartItem(
      id: idFor(p),
      name: p.name ?? p.brand ?? 'Unknown product',
      brand: p.brand,
      imageUrl: p.imageUrl,
      price: p.price,
      affiliateQuery: query.isEmpty ? null : query,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(const []);

  void addProduct(ProductInfo p) {
    final id = CartItem.idFor(p);
    final existing = state.indexWhere((c) => c.id == id);
    if (existing >= 0) {
      final item = state[existing];
      state = [
        ...state.sublist(0, existing),
        item.copyWith(quantity: item.quantity + 1),
        ...state.sublist(existing + 1),
      ];
    } else {
      state = [...state, CartItem.fromProduct(p)];
    }
  }

  void remove(String id) {
    state = state.where((c) => c.id != id).toList();
  }

  void setQuantity(String id, int qty) {
    if (qty <= 0) {
      remove(id);
      return;
    }
    state = [
      for (final item in state) if (item.id == id) item.copyWith(quantity: qty) else item,
    ];
  }

  void setSize(String id, String size) {
    state = [
      for (final item in state) if (item.id == id) item.copyWith(size: size) else item,
    ];
  }

  void clear() => state = const [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(),
);

/// Item count for the bag badge.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold<int>(0, (acc, c) => acc + c.quantity);
});

/// Total $ value for the checkout pill. Items without a price contribute 0.
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold<double>(
        0,
        (acc, c) => acc + ((c.price ?? 0) * c.quantity),
      );
});

/// Aggregated affiliate query — used by the Checkout-now pill to launch a
/// single Amazon search covering all items.
String cartAffiliateUrl(List<CartItem> items) {
  final query = items
      .map((c) => c.affiliateQuery)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ');
  return query.isEmpty ? '' : affiliateUrl(query);
}
