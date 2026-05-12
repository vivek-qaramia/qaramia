import 'package:dio/dio.dart';
import '../models/product_info.dart';

/// Identifies products from images via two paths:
///   1. Barcode — fast, free, deterministic (handled by mobile_scanner in the
///      UI layer; this service receives the decoded barcode string).
///   2. Claude Vision fallback — POSTs a base64 JPEG to the web app's
///      /api/scan-product route which proxies to Anthropic.
///
/// The base URL of the web API is read from --dart-define=API_BASE_URL=…
/// (e.g. https://qaramia.com). For local dev: --dart-define=API_BASE_URL=http://10.0.2.2:3000
/// (Android emulator) or http://localhost:3000 (iOS simulator).
const _apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');

class ProductScannerService {
  final Dio _dio;

  ProductScannerService({Dio? dio}) : _dio = dio ?? Dio();

  /// Look up a product by barcode value. Hits the same Open Food Facts +
  /// UPC Item DB chain the web app uses, exposed via the /api/lookup-barcode
  /// route (to be added in a follow-up; falls back to a stub for now).
  Future<ProductInfo> lookupBarcode(String barcode) async {
    if (_apiBase.isEmpty) {
      return ProductInfo(barcode: barcode, name: barcode, source: ProductSource.barcode);
    }
    try {
      final res = await _dio.get('$_apiBase/api/lookup-barcode',
          queryParameters: {'barcode': barcode});
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return ProductInfo(barcode: barcode, name: barcode, source: ProductSource.barcode);
      }
      return ProductInfo.fromJson({...data, 'source': 'barcode'});
    } catch (_) {
      return ProductInfo(barcode: barcode, name: barcode, source: ProductSource.barcode);
    }
  }

  /// Identify up to three products in a JPEG image via Claude Vision.
  ///
  /// [imageBytesBase64] should be the JPEG payload encoded as base64 (no
  /// data URI prefix). Returns an empty list on failure or no recognition.
  Future<List<ProductInfo>> scanViaVision(String imageBytesBase64) async {
    if (_apiBase.isEmpty) return const [];
    try {
      final res = await _dio.post(
        '$_apiBase/api/scan-product',
        data: {'image': imageBytesBase64},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final products = (res.data as Map<String, dynamic>)['products'] as List?;
      if (products == null) return const [];
      return products
          .map((p) => ProductInfo.fromJson({
                ...(p as Map<String, dynamic>),
                'source': 'vision',
              }))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
