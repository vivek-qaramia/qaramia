/// A product identified during a live stream by one of three detection paths.
enum ProductSource { barcode, vision, speech }

const productCategories = ['beauty', 'food', 'tech', 'fitness', 'fashion', 'home', 'other'];

class ProductInfo {
  final String? name;
  final String? brand;
  final String? description;
  final String? imageUrl;
  final String? barcode;
  final ProductSource source;
  final String? category;
  final double? price;
  final double? rating;
  final int? reviewCount;

  const ProductInfo({
    this.name,
    this.brand,
    this.description,
    this.imageUrl,
    this.barcode,
    required this.source,
    this.category,
    this.price,
    this.rating,
    this.reviewCount,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) => ProductInfo(
        name: json['name'] as String?,
        brand: json['brand'] as String?,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        barcode: json['barcode'] as String?,
        source: ProductSource.values.firstWhere(
          (s) => s.name == json['source'],
          orElse: () => ProductSource.vision,
        ),
        category: json['category'] as String?,
        price: (json['price'] as num?)?.toDouble(),
        rating: (json['rating'] as num?)?.toDouble(),
        reviewCount: (json['reviewCount'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (brand != null) 'brand': brand,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (barcode != null) 'barcode': barcode,
        'source': source.name,
        if (category != null) 'category': category,
        if (price != null) 'price': price,
        if (rating != null) 'rating': rating,
        if (reviewCount != null) 'reviewCount': reviewCount,
      };

  String get sourceLabel => switch (source) {
        ProductSource.barcode => '📷 Barcode',
        ProductSource.vision  => '🤖 AI Vision',
        ProductSource.speech  => '🎙 Spoken',
      };
}
