import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late AnimationController _animController;
  late Animation<double> _laserAnimation;

  final List<Map<String, String>> _sampleBarcodes = [
    {'code': 'BAR-GPU-4070', 'label': 'RTX 4070 Ti', 'sub': 'GPU - LKR 245,000'},
    {'code': 'BAR-CPU-7800X', 'label': 'Ryzen 7 7800X3D', 'sub': 'CPU - LKR 145,000'},
    {'code': 'BAR-MB-B650', 'label': 'ASUS ROG B650', 'sub': 'Motherboard - LKR 72,000'},
    {'code': 'BAR-RAM-32GB', 'label': 'Corsair 32GB DDR5', 'sub': 'RAM - LKR 39,000'},
  ];

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
  }

  @override
  void dispose() {
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
            icon: const Icon(Icons.flash_on),
            tooltip: 'Flashlight',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Flashlight toggled'),
                  duration: Duration(milliseconds: 600),
                ),
              );
            },
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
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Viewfinder background
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 2),
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

            // 2. Quick Barcode Simulator Chips (For headless testing & instant simulation)
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Simulate Barcode Scan (Tap any component):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sampleBarcodes.map((item) {
                          return ActionChip(
                            avatar: const Icon(Icons.qr_code, size: 16, color: Color(0xFF0F172A)),
                            label: Text('${item['label']} (${item['sub']})'),
                            onPressed: () => _lookupBarcode(item['code']!),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

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
            ),
          ],
        ),
      ),
    );
  }
}
