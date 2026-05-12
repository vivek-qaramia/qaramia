import 'dart:convert';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../models/product_info.dart';
import '../providers/ad_providers.dart';
import '../providers/providers.dart';
import '../theme/brand.dart';

/// Host-side scan button shown on the live broadcast.
///
/// Snapshots the current Agora frame, attempts a barcode decode, falls back to
/// Claude Vision if no barcode is found, matches an ad, and publishes the
/// detected products + featured ad to all viewers via Firestore.
class BroadcastScanButton extends ConsumerStatefulWidget {
  final RtcEngine engine;
  final String streamId;
  const BroadcastScanButton({super.key, required this.engine, required this.streamId});

  @override
  ConsumerState<BroadcastScanButton> createState() => _BroadcastScanButtonState();
}

class _BroadcastScanButtonState extends ConsumerState<BroadcastScanButton> {
  bool _scanning = false;
  String? _lastBarcode;
  String? _statusMsg;

  Future<String?> _captureFrame() async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/qaramia_scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await widget.engine.takeSnapshot(uid: 0, filePath: path);
      // The native side writes the file asynchronously even though the call
      // returns. A short wait avoids racing the file existence check.
      for (var i = 0; i < 10; i++) {
        if (await File(path).exists()) return path;
        await Future.delayed(const Duration(milliseconds: 80));
      }
      return null;
    } catch (e) {
      debugPrint('Snapshot failed: $e');
      return null;
    }
  }

  Future<List<ProductInfo>> _tryBarcode(String filePath) async {
    final controller = MobileScannerController();
    try {
      final capture = await controller.analyzeImage(filePath);
      final raw = capture?.barcodes
          .map((b) => b.rawValue)
          .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
      if (raw == null || raw == _lastBarcode) return const [];
      _lastBarcode = raw;
      final scanner = ref.read(productScannerServiceProvider);
      final product = await scanner.lookupBarcode(raw);
      return [product];
    } catch (e) {
      debugPrint('Barcode decode failed: $e');
      return const [];
    } finally {
      await controller.dispose();
    }
  }

  Future<List<ProductInfo>> _tryVision(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final b64 = base64Encode(bytes);
      final scanner = ref.read(productScannerServiceProvider);
      return await scanner.scanViaVision(b64);
    } catch (e) {
      debugPrint('Vision scan failed: $e');
      return const [];
    }
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() { _scanning = true; _statusMsg = 'Scanning…'; });
    try {
      final filePath = await _captureFrame();
      if (filePath == null) {
        _showStatus('Couldn\'t capture frame');
        return;
      }

      // 1. Barcode path (fast, free, deterministic)
      var products = await _tryBarcode(filePath);

      // 2. Vision fallback
      if (products.isEmpty) {
        products = await _tryVision(filePath);
      }

      // Clean up temp file regardless of outcome
      try { await File(filePath).delete(); } catch (_) {}

      if (products.isEmpty) {
        _showStatus('No products found');
        return;
      }

      // 3. Match ad + publish
      final ad = await ref.read(adServiceProvider).matchAd(products);
      await ref.read(streamServiceProvider).publishProducts(widget.streamId, products, ad);

      _showStatus(
        products.length == 1
          ? 'Spotted: ${products.first.name ?? products.first.brand ?? "product"}'
          : 'Spotted ${products.length} products',
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _dismiss() async {
    _lastBarcode = null;
    await ref.read(streamServiceProvider).dismissProducts(widget.streamId);
    _showStatus('Cleared');
  }

  void _showStatus(String msg) {
    if (!mounted) return;
    setState(() => _statusMsg = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _statusMsg == msg) setState(() => _statusMsg = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_statusMsg != null)
          AnimatedOpacity(
            opacity: _statusMsg != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_statusMsg!,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dismiss (only useful if products are already published)
            GestureDetector(
              onTap: _scanning ? null : _dismiss,
              child: Container(
                width: 36, height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.cleaning_services_outlined, color: Colors.white70, size: 16),
              ),
            ),
            // Primary scan button
            GestureDetector(
              onTap: _scanning ? null : _scan,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: QBrand.ringGradient,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                child: _scanning
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.center_focus_strong, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
