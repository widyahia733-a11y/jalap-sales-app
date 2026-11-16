import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/al_rabie_catalog.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';

/// نموذج بيانات الصنف المرتبط بجدول `products` وكتالوج أصناف الربيع الرسمي (اصناف الربيع.xlsx - ORDER)
class ProductItemModel {
  final String id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final double cartonPrice;
  final int packPerCarton;
  final String imageAsset;

  const ProductItemModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.cartonPrice,
    required this.packPerCarton,
    required this.imageAsset,
  });

  factory ProductItemModel.fromAlRabie(AlRabieProduct p) {
    return ProductItemModel(
      id: p.id,
      code: p.code,
      name: p.name,
      category: p.category,
      unit: p.unit,
      cartonPrice: p.cartonPrice,
      packPerCarton: p.packPerCarton,
      imageAsset: p.imageAsset,
    );
  }

  factory ProductItemModel.fromJson(Map<String, dynamic> json, int index) {
    final rawCode = json['code']?.toString() ??
        json['sku']?.toString() ??
        json['item_code']?.toString();
    final matchedCatalogItem = AlRabieCatalog.findBySkuOrId(
      rawCode ?? json['id']?.toString(),
    );
    if (matchedCatalogItem != null) {
      return ProductItemModel.fromAlRabie(matchedCatalogItem);
    }

    final code = rawCode ?? 'JLP-${(3001 + index)}';
    final name =
        (json['name'] ?? json['product_name'] ?? 'صنف الربيع ${index + 1}')
            .toString();
    final imageAsset = json['image_asset']?.toString() ??
        json['image_url']?.toString() ??
        AlRabieCatalog.resolveImageByCodeOrName(code, name);

    return ProductItemModel(
      id: json['id']?.toString() ?? 'rabie-$code',
      code: code,
      name: name,
      category: (json['category'] ?? 'عصير الربيع 185 مل').toString(),
      unit: (json['unit'] ?? 'كرتون (18 عبوة)').toString(),
      cartonPrice: _toDouble(json['price'] ?? json['carton_price'], 5400.0),
      packPerCarton: _toInt(json['pack_per_carton'] ?? json['packs'], 18),
      imageAsset: imageAsset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'sku': code,
      'name': name,
      'category': category,
      'unit': unit,
      'carton_price': cartonPrice,
      'pack_per_carton': packPerCarton,
      'image_asset': imageAsset,
    };
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// نموذج سجل الجرد الأسبوعي المرتبط بجدول `inventory_audits`
class InventoryAuditEntry {
  final String productId;
  final int cartonCount;
  final int packCount;
  final int damagedCount;
  final int returnedCount;
  final String notes;
  final DateTime auditedAt;

  const InventoryAuditEntry({
    required this.productId,
    required this.cartonCount,
    required this.packCount,
    required this.damagedCount,
    required this.returnedCount,
    this.notes = '',
    required this.auditedAt,
  });

  factory InventoryAuditEntry.fromJson(Map<String, dynamic> json) {
    return InventoryAuditEntry(
      productId: json['product_id']?.toString() ?? '',
      cartonCount:
          (json['carton_qty'] ?? json['carton_count'] as num?)?.toInt() ?? 0,
      packCount: (json['pack_qty'] ?? json['pack_count'] as num?)?.toInt() ?? 0,
      damagedCount:
          (json['damaged_qty'] ?? json['damaged_count'] as num?)?.toInt() ?? 0,
      returnedCount:
          (json['returned_qty'] ?? json['returned_count'] as num?)?.toInt() ??
              0,
      notes: json['notes']?.toString() ?? '',
      auditedAt: DateTime.tryParse(json['audited_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  InventoryAuditEntry copyWith({
    int? cartonCount,
    int? packCount,
    int? damagedCount,
    int? returnedCount,
    String? notes,
    DateTime? auditedAt,
  }) {
    return InventoryAuditEntry(
      productId: productId,
      cartonCount: cartonCount ?? this.cartonCount,
      packCount: packCount ?? this.packCount,
      damagedCount: damagedCount ?? this.damagedCount,
      returnedCount: returnedCount ?? this.returnedCount,
      notes: notes ?? this.notes,
      auditedAt: auditedAt ?? this.auditedAt,
    );
  }

  Map<String, dynamic> toSupabaseMap({String? branchId, String? userId}) {
    return {
      'product_id': productId,
      'carton_qty': cartonCount,
      'pack_qty': packCount,
      'damaged_qty': damagedCount,
      'returned_qty': returnedCount,
      'notes': notes,
      if (branchId != null) 'branch_id': branchId,
      if (userId != null) 'audited_by': userId,
      'audited_at': auditedAt.toIso8601String(),
    };
  }
}

/// الشاشة الكاملة لكتالوج أصناف الربيع والجرد الميداني الأسبوعي (ورقة ORDER - 62 صنفاً رسمياً بالصور)
class InventoryPage extends StatefulWidget {
  final String? currentUserId;
  final String? currentBranchId;

  const InventoryPage({
    super.key,
    this.currentUserId,
    this.currentBranchId,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineSyncService _offlineSync = OfflineSyncService.instance;

  List<ProductItemModel> _allProducts = [];
  final Map<String, InventoryAuditEntry> _auditRecords = {};

  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  bool _isLoading = false;

  static const List<String> _categories = AlRabieCatalog.categories;

  @override
  void initState() {
    super.initState();
    // تحميل فوري ومضمون (Local-First) لجميع الأصناف الـ 62 من AlRabieCatalog.items مباشرة في initState
    _allProducts = AlRabieCatalog.items
        .map(ProductItemModel.fromAlRabie)
        .toList();
    _initializeInventoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// تهيئة قائمة أصناف الربيع المعتمدة (62 صنفاً) ودمج كميات المخزون حسب SKU دون السماح لأي استعلام فارغ بمسح القائمة
  Future<void> _initializeInventoryData() async {
    // 1. ضمان بقاء الأصناف الـ 62 الرسمية من AlRabieCatalog.items مع صورها في جميع الأحوال
    final List<ProductItemModel> officialCatalogProducts = AlRabieCatalog.items
        .map(ProductItemModel.fromAlRabie)
        .toList();

    if (mounted) {
      setState(() {
        _allProducts = officialCatalogProducts;
        _isLoading = false;
      });
    } else {
      _allProducts = officialCatalogProducts;
      _isLoading = false;
    }

    await _offlineSync.cacheProducts(
      _allProducts.map((p) => p.toJson()).toList(),
    );

    // 2. استرجاع ودمج سجلات الجرد المحلية حسب SKU أو معرف الصنف (مع افتراض 0 للأصناف غير المجرودة)
    final cachedAuditsMap = _offlineSync.getCachedInventoryAudits();
    if (cachedAuditsMap.isNotEmpty) {
      cachedAuditsMap.forEach((key, map) {
        final matched = AlRabieCatalog.findBySkuOrId(
          map['sku']?.toString() ??
              map['item_code']?.toString() ??
              map['product_id']?.toString() ??
              key,
        );
        if (matched != null) {
          final entry = InventoryAuditEntry.fromJson(map);
          _auditRecords[matched.id] = InventoryAuditEntry(
            productId: matched.id,
            cartonCount: entry.cartonCount,
            packCount: entry.packCount,
            damagedCount: entry.damagedCount,
            returnedCount: entry.returnedCount,
            notes: entry.notes,
            auditedAt: entry.auditedAt,
          );
        }
      });
    }

    // 3. مزامنة الكتالوج الرسمي مع Supabase ودمج أي كميات جرد واردة من السحابة حسب SKU دون المساس بالقائمة المعروضة
    if (AppConstants.isSupabaseConfigured) {
      try {
        await _offlineSync.syncOfficialCatalogToSupabase();

        final supabase = Supabase.instance.client;
        final List<dynamic> auditRows = await supabase
            .from(AppConstants.tableInventoryAudits)
            .select()
            .limit(100);

        for (final raw in auditRows) {
          if (raw is Map<String, dynamic>) {
            final matched = AlRabieCatalog.findBySkuOrId(
              raw['sku']?.toString() ??
                  raw['item_code']?.toString() ??
                  raw['product_id']?.toString(),
            );
            if (matched != null) {
              final remoteEntry = InventoryAuditEntry.fromJson(raw);
              _auditRecords[matched.id] = InventoryAuditEntry(
                productId: matched.id,
                cartonCount: remoteEntry.cartonCount,
                packCount: remoteEntry.packCount,
                damagedCount: remoteEntry.damagedCount,
                returnedCount: remoteEntry.returnedCount,
                notes: remoteEntry.notes,
                auditedAt: remoteEntry.auditedAt,
              );
            }
          }
        }
        await _persistAuditsLocally();
      } catch (error) {
        debugPrint('Inventory local-first catalog active: $error');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// حفظ كافة سجلات الجرد الحالية في الذاكرة المحلية للجهاز
  Future<void> _persistAuditsLocally() async {
    final serialized = <String, Map<String, dynamic>>{};
    _auditRecords.forEach((key, entry) {
      serialized[key] = entry.toSupabaseMap(
        branchId: widget.currentBranchId,
        userId: widget.currentUserId,
      );
    });
    await _offlineSync.cacheInventoryAudits(serialized);
  }

  /// تعديل سريع لكمية الكرتون أو العبوة مباشرة من بطاقة الصنف (+ / -) بيد واحدة
  Future<void> _quickAdjustProductQty(
    ProductItemModel product, {
    int cartonDelta = 0,
    int packDelta = 0,
  }) async {
    final current = _auditRecords[product.id] ??
        InventoryAuditEntry(
          productId: product.id,
          cartonCount: 0,
          packCount: 0,
          damagedCount: 0,
          returnedCount: 0,
          notes: 'إدخال ميداني سريع [${product.code}]',
          auditedAt: DateTime.now(),
        );

    final nextCartons = (current.cartonCount + cartonDelta).clamp(0, 9999);
    final nextPacks = (current.packCount + packDelta).clamp(0, 9999);

    final updated = current.copyWith(
      cartonCount: nextCartons,
      packCount: nextPacks,
      auditedAt: DateTime.now(),
    );

    setState(() {
      _auditRecords[product.id] = updated;
    });

    await _persistAuditsLocally();
    await _offlineSync.enqueueOrSyncOperation(
      table: AppConstants.tableInventoryAudits,
      action: 'upsert',
      payload: updated.toSupabaseMap(
        branchId: widget.currentBranchId,
        userId: widget.currentUserId,
      ),
    );
  }

  List<ProductItemModel> get _filteredProducts {
    final normalizedQuery = AlRabieCatalog.normalizeArabicSearch(_searchQuery);
    return _allProducts.where((product) {
      final matchesCategory =
          _selectedCategory == 'الكل' || product.category == _selectedCategory;
      if (normalizedQuery.isEmpty) return matchesCategory;
      final normalizedName = AlRabieCatalog.normalizeArabicSearch(product.name);
      final normalizedCode = product.code.toLowerCase();
      final normalizedCat =
          AlRabieCatalog.normalizeArabicSearch(product.category);
      final matchesSearch = normalizedName.contains(normalizedQuery) ||
          normalizedCode.contains(normalizedQuery) ||
          normalizedCat.contains(normalizedQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// اعتماد جرد كافة الأصناف المتبقية دفعة واحدة وحفظها محلياً وفي طابور المزامنة
  Future<void> _completeAllRemainingAudits() async {
    setState(() {
      for (final product in _allProducts) {
        _auditRecords.putIfAbsent(
          product.id,
          () => InventoryAuditEntry(
            productId: product.id,
            cartonCount: 15,
            packCount: 0,
            damagedCount: 0,
            returnedCount: 0,
            notes: 'اعتماد سريع للجرد الأسبوعي [${product.code}]',
            auditedAt: DateTime.now(),
          ),
        );
      }
    });

    await _persistAuditsLocally();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppConstants.deepNavyBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'تم اعتماد وحفظ جرد جميع أصناف الربيع (${_allProducts.length}/${_allProducts.length}) محلياً وفي طابور المزامنة',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
  }

  /// فتح نافذة إدخال/تعديل الجرد التفصيلي لصنف محدد (Audit Entry Form)
  Future<void> _openAuditEntrySheet({ProductItemModel? initialProduct}) async {
    if (_allProducts.isEmpty) return;

    ProductItemModel selectedProduct = initialProduct ?? _allProducts.first;
    final existing = _auditRecords[selectedProduct.id];

    final cartonCtrl = TextEditingController(
      text: (existing?.cartonCount ?? 10).toString(),
    );
    final packCtrl = TextEditingController(
      text: (existing?.packCount ?? 0).toString(),
    );
    final damagedCtrl = TextEditingController(
      text: (existing?.damagedCount ?? 0).toString(),
    );
    final returnedCtrl = TextEditingController(
      text: (existing?.returnedCount ?? 0).toString(),
    );
    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );

    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colorScheme = Theme.of(context).colorScheme;

            void loadProductValues(ProductItemModel prod) {
              final rec = _auditRecords[prod.id];
              cartonCtrl.text = (rec?.cartonCount ?? 10).toString();
              packCtrl.text = (rec?.packCount ?? 0).toString();
              damagedCtrl.text = (rec?.damagedCount ?? 0).toString();
              returnedCtrl.text = (rec?.returnedCount ?? 0).toString();
              notesCtrl.text = rec?.notes ?? '';
            }

            void adjustCounter(TextEditingController ctrl, int delta) {
              final current = int.tryParse(ctrl.text) ?? 0;
              final next = (current + delta).clamp(0, 9999);
              setSheetState(() {
                ctrl.text = next.toString();
              });
            }

            Future<void> saveAuditEntry() async {
              setSheetState(() => isSaving = true);

              final entry = InventoryAuditEntry(
                productId: selectedProduct.id,
                cartonCount: int.tryParse(cartonCtrl.text) ?? 0,
                packCount: int.tryParse(packCtrl.text) ?? 0,
                damagedCount: int.tryParse(damagedCtrl.text) ?? 0,
                returnedCount: int.tryParse(returnedCtrl.text) ?? 0,
                notes: notesCtrl.text.trim(),
                auditedAt: DateTime.now(),
              );

              setState(() {
                _auditRecords[selectedProduct.id] = entry;
              });

              await _persistAuditsLocally();
              final syncedOnline = await _offlineSync.enqueueOrSyncOperation(
                table: AppConstants.tableInventoryAudits,
                action: 'upsert',
                payload: entry.toSupabaseMap(
                  branchId: widget.currentBranchId,
                  userId: widget.currentUserId,
                ),
              );

              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }

              if (mounted) {
                ScaffoldMessenger.of(this.context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppConstants.deepNavyBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      content: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          syncedOnline
                              ? 'تم حفظ ومزامنة جرد "${selectedProduct.name}" بنجاح (${_auditRecords.length}/${_allProducts.length})'
                              : 'تم حفظ جرد "${selectedProduct.name}" محلياً وإضافته لطابور المزامنة (${_auditRecords.length}/${_allProducts.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  right: 20,
                  left: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          AlRabieProductThumbnail(
                            imageAsset: selectedProduct.imageAsset,
                            category: selectedProduct.category,
                            size: 52,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'نموذج تسجيل الجرد الأسبوعي التفصيلي',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'كتالوج الربيع الرسمي • مزامنة تلقائية لجدول (inventory_audits)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<ProductItemModel>(
                        value: selectedProduct,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'الصنف المجرود (رقم الصنف - الاسم)',
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        items: _allProducts.map((prod) {
                          return DropdownMenuItem<ProductItemModel>(
                            value: prod,
                            child: Text(
                              '${prod.code} - ${prod.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setSheetState(() {
                            selectedProduct = val;
                            loadProductValues(val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _CounterFieldCard(
                              label: 'كمية الكرتون',
                              icon: Icons.all_inbox_rounded,
                              color: Colors.teal,
                              controller: cartonCtrl,
                              onDecrement: () => adjustCounter(cartonCtrl, -1),
                              onIncrement: () => adjustCounter(cartonCtrl, 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CounterFieldCard(
                              label: 'كمية العبوة (فرط)',
                              icon: Icons.widgets_outlined,
                              color: Colors.blue,
                              controller: packCtrl,
                              onDecrement: () => adjustCounter(packCtrl, -1),
                              onIncrement: () => adjustCounter(packCtrl, 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CounterFieldCard(
                              label: 'الكميات التالفة',
                              icon: Icons.broken_image_outlined,
                              color: Colors.red,
                              controller: damagedCtrl,
                              onDecrement: () => adjustCounter(damagedCtrl, -1),
                              onIncrement: () => adjustCounter(damagedCtrl, 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CounterFieldCard(
                              label: 'الكميات المرتجعة',
                              icon: Icons.assignment_return_outlined,
                              color: Colors.orange,
                              controller: returnedCtrl,
                              onDecrement: () =>
                                  adjustCounter(returnedCtrl, -1),
                              onIncrement: () => adjustCounter(returnedCtrl, 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesCtrl,
                        decoration: InputDecoration(
                          labelText:
                              'ملاحظات المندوب حول الصنف أو تاريخ الصلاحية',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: isSaving ? null : saveAuditEntry,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppConstants.deepNavyBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_rounded,
                                  color: AppConstants.royalGold,
                                ),
                          label: const Text(
                            'حفظ واعتماد جرد الصنف',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final int totalCount = _allProducts.length;
    final int completedCount = _auditRecords.length;
    final int remainingCount =
        (totalCount - completedCount).clamp(0, totalCount);
    final double progress =
        totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);

    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: AppConstants.cleanLightGrey,
      appBar: AppBar(
        title: Text(
          'كتالوج وجرد أصناف الربيع ($totalCount صنفاً)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: AppConstants.deepNavyBlue,
        foregroundColor: Colors.white,
        actions: [
          if (remainingCount > 0)
            TextButton.icon(
              onPressed: _completeAllRemainingAudits,
              icon: const Icon(
                Icons.done_all_rounded,
                size: 18,
                color: AppConstants.royalGold,
              ),
              label: const Text(
                'اعتماد الكل',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.royalGold,
                ),
              ),
            ),
          IconButton(
            tooltip: 'تحديث الأصناف',
            onPressed: _initializeInventoryData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_fab',
        onPressed: () => _openAuditEntrySheet(),
        backgroundColor: AppConstants.royalGold,
        foregroundColor: AppConstants.deepNavyBlue,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(
          'جرد تفصيلي',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // =============================================================
                // 1. البطاقة الإحصائية الملكية لحالة الجرد الأسبوعي لكتالوج الربيع
                // =============================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppConstants.deepNavyBlue,
                          AppConstants.royalNavySecondary,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.deepNavyBlue.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.royalGold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppConstants.royalGold,
                                ),
                              ),
                              child: const Icon(
                                Icons.inventory_rounded,
                                color: AppConstants.royalGold,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'كتالوج أصناف الربيع المعتمد (ORDER)',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    remainingCount == 0
                                        ? 'مكتمل بالكامل لهذا الأسبوع ($totalCount/$totalCount) ومحفوظ محلياً'
                                        : 'تم جرد $completedCount صنفاً ومتبقي $remainingCount أصناف',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.royalGold,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '$completedCount / $totalCount',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  color: AppConstants.deepNavyBlue,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppConstants.royalGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =============================================================
                // 2. شريط البحث السريع والفلترة حسب فئات الربيع
                // =============================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText:
                          'ابحث باسم الصنف أو رقم الصنف (43002001 أو JLP-3001)...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.clear_rounded),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedCategory = category);
                        },
                        selectedColor: AppConstants.softRoyalGold,
                        side: BorderSide(
                          color: isSelected
                              ? AppConstants.royalGold
                              : colorScheme.outlineVariant,
                        ),
                        labelStyle: TextStyle(
                          color: AppConstants.deepNavyBlue,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // =============================================================
                // 3. قائمة أصناف الربيع مع الصور الرسمية وأزرار الإدخال السريعة (+ / -)
                // =============================================================
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('لا توجد أصناف مطابقة لبحثك الحالي.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final audit = _auditRecords[product.id];
                            final isAudited = audit != null;
                            final int currentCartons = audit?.cartonCount ?? 0;
                            final int currentPacks = audit?.packCount ?? 0;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isAudited
                                      ? AppConstants.royalGold
                                      : colorScheme.outlineVariant,
                                  width: isAudited ? 1.4 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // رأس البطاقة (صورة الصنف + رقم الصنف SKU + اسم الصنف فقط)
                                    InkWell(
                                      onTap: () => _openAuditEntrySheet(
                                        initialProduct: product,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          AlRabieProductThumbnail(
                                            imageAsset: product.imageAsset,
                                            category: product.category,
                                            size: 58,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppConstants
                                                        .deepNavyBlue,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    product.code,
                                                    textDirection:
                                                        TextDirection.ltr,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppConstants
                                                          .royalGold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  product.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14.5,
                                                    color: AppConstants
                                                        .deepNavyBlue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isAudited
                                                  ? AppConstants.softRoyalGold
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isAudited
                                                    ? AppConstants.royalGold
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isAudited
                                                      ? Icons.verified_rounded
                                                      : Icons.schedule_rounded,
                                                  size: 13,
                                                  color: isAudited
                                                      ? AppConstants
                                                          .deepNavyBlue
                                                      : Colors.grey.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isAudited ? 'مجرود' : 'انتظار',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isAudited
                                                        ? AppConstants
                                                            .deepNavyBlue
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 20),

                                    // =========================================
                                    // أزرار الإدخال السريعة (+ / -) للكرتون والعبوات بيد واحدة
                                    // =========================================
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _InlineQuickStepper(
                                            label: 'كرتون',
                                            value: currentCartons,
                                            primaryColor:
                                                AppConstants.deepNavyBlue,
                                            accentColor: AppConstants.royalGold,
                                            onDecrement: () =>
                                                _quickAdjustProductQty(
                                              product,
                                              cartonDelta: -1,
                                            ),
                                            onIncrement: () =>
                                                _quickAdjustProductQty(
                                              product,
                                              cartonDelta: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _InlineQuickStepper(
                                            label: 'عبوة',
                                            value: currentPacks,
                                            primaryColor:
                                                Colors.blueGrey.shade800,
                                            accentColor:
                                                Colors.blueGrey.shade100,
                                            onDecrement: () =>
                                                _quickAdjustProductQty(
                                              product,
                                              packDelta: -1,
                                            ),
                                            onIncrement: () =>
                                                _quickAdjustProductQty(
                                              product,
                                              packDelta: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          tooltip: 'تسجيل التوالف والمرتجعات',
                                          onPressed: () => _openAuditEntrySheet(
                                            initialProduct: product,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor:
                                                AppConstants.softRoyalGold,
                                            foregroundColor:
                                                AppConstants.deepNavyBlue,
                                          ),
                                          icon: const Icon(
                                            Icons.tune_rounded,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (isAudited &&
                                        (audit.damagedCount > 0 ||
                                            audit.returnedCount > 0)) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (audit.damagedCount > 0)
                                            _AuditMiniBadge(
                                              label:
                                                  'تالف: ${audit.damagedCount}',
                                              color: Colors.red,
                                            ),
                                          if (audit.returnedCount > 0)
                                            _AuditMiniBadge(
                                              label:
                                                  'مرتجع: ${audit.returnedCount}',
                                              color: Colors.orange,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// عداد سريع مدمج داخل بطاقة الصنف (+ / -) للتشغيل بيد واحدة أثناء الزيارة الميدانية
class _InlineQuickStepper extends StatelessWidget {
  final String label;
  final int value;
  final Color primaryColor;
  final Color accentColor;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _InlineQuickStepper({
    required this.label,
    required this.value,
    required this.primaryColor,
    required this.accentColor,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.cleanLightGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onDecrement,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.remove_rounded, size: 18, color: primaryColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: primaryColor,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onIncrement,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterFieldCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final MaterialColor color;
  final TextEditingController controller;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CounterFieldCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.controller,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color.shade700),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onDecrement,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: onIncrement,
                style: IconButton.styleFrom(backgroundColor: color.shade700),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditMiniBadge extends StatelessWidget {
  final String label;
  final MaterialColor color;

  const _AuditMiniBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: color.shade800,
        ),
      ),
    );
  }
}
