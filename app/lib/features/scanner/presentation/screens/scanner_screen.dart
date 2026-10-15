import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/app_routes.dart';
import '../../../cart/data/cart_service.dart';
import '../../../catalog/data/catalog_repository.dart';
import '../../../catalog/data/models/product_model.dart';
import '../../../../services/api_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final _barcodeController = TextEditingController();
  final _apiService = ApiService();
  final _cartService = CartService.instance;
  final _repository = CatalogRepository();

  bool _isSearching = false;
  bool _isProcessingScan = false;
  bool _isTorchOn = false;

  late AnimationController _animController;
  late Animation<double> _laserAnimation;
  late MobileScannerController _scannerController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      if (mounted) {
        setState(() => _isTorchOn = !_isTorchOn);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flashlight is not supported or camera is unavailable'),
            duration: Duration(milliseconds: 700),
          ),
        );
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessingScan || _isSearching) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _isProcessingScan = true;
        _barcodeController.text = raw;
        _lookupBarcode(raw).then((_) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _isProcessingScan = false);
            }
          });
        });
        break;
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _animController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _barcodeController.text = text;
      _lookupBarcode(text);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty. Copy a QR code text or barcode first.')),
        );
      }
    }
  }

  static final Map<String, ProductModel> _demoSampleProducts = {
    'BAR-GPU-4070': const ProductModel(
      productId: 1,
      name: 'GeForce RTX 4070 Ti 12GB',
      brand: 'NVIDIA',
      model: 'RTX 4070 Ti',
      price: 749.00,
      stockQuantity: 5,
      categoryName: 'GPU',
      description: 'Ada Lovelace architecture, 12GB GDDR6X, DLSS 3 support.',
    ),
    'BAR-CPU-7800X': const ProductModel(
      productId: 2,
      name: 'AMD Ryzen 7 7800X3D',
      brand: 'AMD',
      model: '7800X3D',
      price: 449.99,
      stockQuantity: 8,
      categoryName: 'CPU',
      description: '8-core, 16-thread desktop processor with AMD 3D V-Cache technology.',
    ),
    'BAR-MB-B650': const ProductModel(
      productId: 3,
      name: 'ASUS ROG STRIX B650-A GAMING WIFI',
      brand: 'ASUS',
      model: 'ROG B650',
      price: 219.99,
      stockQuantity: 12,
      categoryName: 'Motherboard',
      description: 'AMD AM5 socket, DDR5, PCIe 5.0 M.2, WiFi 6E, 2.5G LAN.',
    ),
    'BAR-RAM-32GB': const ProductModel(
      productId: 4,
      name: 'Corsair Vengeance RGB 32GB (2x16GB) DDR5 6000MHz',
      brand: 'Corsair',
      model: '32GB DDR5',
      price: 119.99,
      stockQuantity: 15,
      categoryName: 'RAM',
      description: 'High-performance DDR5 memory with dynamic RGB lighting and Intel XMP / AMD EXPO.',
    ),
  };

  Future<void> _lookupBarcode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      ProductModel? matchedProduct;

      // 1. Check if QR code contains JSON payload (e.g. {"productId": 2} or {"id": 2})
      int? extractedProductId;
      String cleanCode = code;

      if (code.startsWith('{') && code.endsWith('}')) {
        try {
          final decoded = jsonDecode(code);
          if (decoded is Map) {
            extractedProductId = (decoded['productId'] ?? decoded['id'] ?? decoded['product_id']) as int?;
            if (decoded['code'] != null) cleanCode = decoded['code'].toString();
            if (decoded['barcode'] != null) cleanCode = decoded['barcode'].toString();
            if (decoded['name'] != null) cleanCode = decoded['name'].toString();
          }
        } catch (_) {}
      }

      // 2. Check for URL deep link patterns (e.g. "https://pcforge.com/products/2" or "pcforge://product/2")
      if (extractedProductId == null) {
        final uriMatch = RegExp(r'(?:products|product)\/(\d+)').firstMatch(cleanCode);
        if (uriMatch != null) {
          extractedProductId = int.tryParse(uriMatch.group(1)!);
        }
      }

      // 3. Check for prefixed ID patterns (e.g. "PROD-2", "QR-2", "#2", "ID:2")
      if (extractedProductId == null) {
        final prefixMatch = RegExp(r'^(?:PROD|PRODUCT|QR|ITEM|SKU|#)[-:]?(\d+)$', caseSensitive: false).firstMatch(cleanCode);
        if (prefixMatch != null) {
          extractedProductId = int.tryParse(prefixMatch.group(1)!);
        } else {
          // Pure numeric barcode or product ID
          extractedProductId = int.tryParse(cleanCode);
        }
      }

      // 4. If a numeric product ID is resolved, fetch directly
      if (extractedProductId != null && extractedProductId > 0) {
        try {
          matchedProduct = await _repository.getProductById(extractedProductId);
        } catch (_) {}
      }

      // 5. Query local catalog repository with clean non-empty string matching
      if (matchedProduct == null) {
        try {
          final allProducts = await _repository.getProducts();
          final lowerCode = cleanCode.toLowerCase();

          // Exact matches
          for (final p in allProducts) {
            if (p.productId.toString() == cleanCode) {
              matchedProduct = p;
              break;
            }
            if (cleanCode == 'BAR-GPU-4070' && p.name.contains('4070')) {
              matchedProduct = p;
              break;
            }
            if (cleanCode == 'BAR-CPU-7800X' && p.name.contains('7800X3D')) {
              matchedProduct = p;
              break;
            }
            if (cleanCode == 'BAR-MB-B650' && p.name.contains('B650')) {
              matchedProduct = p;
              break;
            }
            if (cleanCode == 'BAR-RAM-32GB' && p.name.contains('Vengeance')) {
              matchedProduct = p;
              break;
            }
            if (p.model != null && p.model!.trim().isNotEmpty && p.model!.toLowerCase() == lowerCode) {
              matchedProduct = p;
              break;
            }
          }

          // Substring matches (guarded against empty models)
          if (matchedProduct == null) {
            for (final p in allProducts) {
              final model = p.model?.trim().toLowerCase();
              if (model != null && model.isNotEmpty && (lowerCode.contains(model) || model.contains(lowerCode))) {
                matchedProduct = p;
                break;
              }
              if (p.name.toLowerCase().contains(lowerCode)) {
                matchedProduct = p;
                break;
              }
            }
          }
        } catch (_) {}
      }

      // 6. Check demo sample barcodes (in-store demo hardware)
      if (matchedProduct == null) {
        final upper = cleanCode.toUpperCase();
        if (_demoSampleProducts.containsKey(upper)) {
          matchedProduct = _demoSampleProducts[upper];
        }
      }

      // 7. Fallback to API barcode service
      if (matchedProduct == null) {
        try {
          final apiResult = await _apiService.lookupProductByBarcode(cleanCode);
          if (apiResult != null) {
            matchedProduct = ProductModel.fromJson(apiResult);
          }
        } catch (_) {}
      }

      // 8. Fallback to search query
      if (matchedProduct == null) {
        try {
          final searchResults = await _repository.getProducts(
            filter: CatalogFilter(searchQuery: cleanCode),
          );
          if (searchResults.isNotEmpty) {
            matchedProduct = searchResults.first;
          }
        } catch (_) {}
      }

      if (matchedProduct != null) {
        if (mounted) {
          _showProductBottomSheet(matchedProduct);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No PC component found matching barcode/QR "$cleanCode".'),
              backgroundColor: Colors.amber.shade900,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Browse Catalog',
                textColor: Colors.white,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.catalog),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error looking up component for "$code": $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showProductBottomSheet(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final inCart = _cartService.getProductQuantity(product.productId);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            24.0,
            24.0,
            24.0,
            24.0 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Component Verified!',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          product.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('In-Store Price', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        'LKR ${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.isInStock ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: product.isInStock ? Colors.green.shade300 : Colors.red.shade300,
                      ),
                    ),
                    child: Text(
                      product.isInStock ? 'In Stock (${product.stockQuantity})' : 'Out of Stock',
                      style: TextStyle(
                        color: product.isInStock ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (product.description != null && product.description!.isNotEmpty) ...[
                Text(
                  product.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.productDetail,
                          arguments: product,
                        );
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('View Specs'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: product.isInStock
                          ? () {
                              final err = _cartService.addItem(product);
                              Navigator.pop(ctx);
                              if (err == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added ${product.name} to Cart!'),
                                    backgroundColor: Colors.green,
                                    action: SnackBarAction(
                                      label: 'View Cart',
                                      textColor: Colors.white,
                                      onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err), backgroundColor: Colors.red),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: Text(inCart > 0 ? 'Add Another' : 'Add to Cart'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('In-Store Scanner (Device Feature)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: 'Paste QR or Barcode from Clipboard',
            onPressed: _pasteFromClipboard,
          ),
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amberAccent : Colors.white,
            ),
            tooltip: 'Toggle Flashlight',
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Align component barcode / QR inside the frame',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

            // 1. Camera Viewfinder Frame
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Viewfinder background & Live Camera Preview
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildCameraContent(),
                      ),
                    ),

                    // Corner reticle accents
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.tealAccent, width: 4),
                            left: BorderSide(color: Colors.tealAccent, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.tealAccent, width: 4),
                            right: BorderSide(color: Colors.tealAccent, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.tealAccent, width: 4),
                            left: BorderSide(color: Colors.tealAccent, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.tealAccent, width: 4),
                            right: BorderSide(color: Colors.tealAccent, width: 4),
                          ),
                        ),
                      ),
                    ),

                    // Animated laser scanning line
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, _) {
                        return Align(
                          alignment: Alignment(0, (_laserAnimation.value * 2) - 1),
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.tealAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.tealAccent.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    if (_isSearching)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.tealAccent),
                      ),
                  ],
                ),
              ),
            ),

            // 2. Barcode & QR Input Panel
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2, size: 20, color: Color(0xFF0F172A)),
                        const SizedBox(width: 8),
                        const Text(
                          'QR & Barcode Lookup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Manual Barcode / QR Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _barcodeController,
                            decoration: InputDecoration(
                              hintText: 'Enter barcode, SKU or QR code...',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              prefixIcon: const Icon(Icons.qr_code),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.content_paste, size: 20),
                                tooltip: 'Paste from clipboard',
                                onPressed: _pasteFromClipboard,
                              ),
                            ),
                            onSubmitted: (val) => _lookupBarcode(val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          key: const Key('scan_lookup_btn'),
                          onPressed: () => _lookupBarcode(_barcodeController.text),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Scan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraContent() {
    return MobileScanner(
      controller: _scannerController,
      onDetect: _onBarcodeDetected,
      errorBuilder: (context, error) {
        if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined, size: 48, color: Colors.amberAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'Camera Permission Required',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Camera permission is required to scan barcodes live. Please allow camera access.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry / Grant Camera'),
                    onPressed: () {
                      _scannerController.start();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Headless test, desktop, or camera not ready fallback
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner, size: 48, color: Colors.tealAccent.withValues(alpha: 0.7)),
                const SizedBox(height: 10),
                const Text(
                  'Scanner Viewfinder',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Align component barcode / QR inside the frame, or use paste/manual lookup below.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
