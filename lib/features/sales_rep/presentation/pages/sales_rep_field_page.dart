import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/al_rabie_catalog.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';
import '../../../auth/data/models/user_profile_model.dart';

/// واجهة مندوب المبيعات الميدانية السريعة والخفيفة (Sales Rep Field Interface)
/// مرتبطة بالكامل بكتالوج أصناف الربيع الرسمي (اصناف الربيع.xlsx - ورقة ORDER) مع الصور والأكواد الرسمية.
class SalesRepFieldPage extends StatefulWidget {
  final UserProfileModel userProfile;
  final bool isSigningOut;
  final VoidCallback onSignOut;
  final VoidCallback? onSwitchToFullDashboard;

  const SalesRepFieldPage({
    super.key,
    required this.userProfile,
    required this.isSigningOut,
    required this.onSignOut,
    this.onSwitchToFullDashboard,
  });

  @override
  State<SalesRepFieldPage> createState() => _SalesRepFieldPageState();
}

class _SalesRepFieldPageState extends State<SalesRepFieldPage> {
  final OfflineSyncService _offlineSync = OfflineSyncService.instance;

  /// 0 = جرد المخزون | 1 = طلب بضاعة للفرع
  int _activeSection = 0;

  /// قائمة التجار / نقاط البيع الميدانية
  static const List<String> _merchants = [
    'أسواق السعيد المركزية - صنعاء',
    'مؤسسة الخير للتجارة والجملة - الحديدة',
    'تموينات النخبة الحديثة - تعز',
    'سوبرماركت الهدايا الكبرى - عدن',
    'مجموعة فنادق ومطاعم التاج (HORECA) - صنعاء',
    'أسواق الجزيرة الاستهلاكية - إب',
    'مؤسسة باوزير التجارية - المكلا',
    'بقالة وميني ماركت الأمانة - صنعاء',
  ];

  /// القائمة الرسمية الكاملة لأصناف الربيع المستخرجة مباشرة من `AlRabieCatalog.items` (62 صنفاً)
  final List<AlRabieProduct> _catalogProducts =
      List<AlRabieProduct>.unmodifiable(AlRabieCatalog.items);

  String _selectedMerchant = _merchants.first;
  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _orderNotesController = TextEditingController();

  // بيانات جرد المخزون (كرتون + عبوة لكل صنف)
  final Map<String, int> _auditCartons = <String, int>{};
  final Map<String, int> _auditPacks = <String, int>{};
  final Map<String, TextEditingController> _auditCartonControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _auditPackControllers =
      <String, TextEditingController>{};

  // بيانات طلب البضاعة السريع للفرع (كمية الكراتين المطلوبة لكل صنف)
  final Map<String, int> _orderCartons = <String, int>{};
  final Map<String, TextEditingController> _orderCartonControllers =
      <String, TextEditingController>{};

  bool _isSubmittingAudit = false;
  bool _isSubmittingOrder = false;
  String? _lastAuditSubmissionBanner;
  String? _lastOrderSubmissionBanner;

  @override
  void initState() {
    super.initState();
    // 1. تحميل فوري ومضمون (Local-First) لجميع الأصناف الـ 62 من AlRabieCatalog.items بكميات افتراضية (0)
    for (final item in _catalogProducts) {
      _auditCartons[item.id] = 0;
      _auditPacks[item.id] = 0;
      _auditCartonControllers[item.id] = TextEditingController(text: '0');
      _auditPackControllers[item.id] = TextEditingController(text: '0');

      _orderCartons[item.id] = 0;
      _orderCartonControllers[item.id] = TextEditingController(text: '0');
    }

    // 2. دمج أي كميات مخزنة محلياً أو في Supabase حسب رقم الصنف (SKU) دون حجب أو مسح القائمة أبداً
    _mergeStockQuantitiesBySku();
  }

  Future<void> _mergeStockQuantitiesBySku() async {
    try {
      final cachedAudits = _offlineSync.getCachedInventoryAudits();
      if (cachedAudits.isNotEmpty) {
        cachedAudits.forEach((key, data) {
          final matched = AlRabieCatalog.findBySkuOrId(
            data['sku']?.toString() ?? data['product_id']?.toString() ?? key,
          );
          if (matched != null) {
            final cartons =
                ((data['carton_qty'] ?? data['carton_count']) as num?)
                        ?.toInt() ??
                    0;
            final packs =
                ((data['pack_qty'] ?? data['pack_count']) as num?)?.toInt() ??
                    0;
            if (cartons > 0 || packs > 0) {
              _setAuditCarton(matched.id, cartons);
              _setAuditPack(matched.id, packs);
            }
          }
        });
      }

      if (AppConstants.isSupabaseConfigured) {
        final rows = await Supabase.instance.client
            .from(AppConstants.tableInventoryAudits)
            .select()
            .limit(100);
        if (!mounted) return;
        for (final raw in rows) {
          if (raw is Map) {
            final matched = AlRabieCatalog.findBySkuOrId(
              raw['sku']?.toString() ??
                  raw['item_code']?.toString() ??
                  raw['product_id']?.toString(),
            );
            if (matched != null) {
              final cartons =
                  ((raw['carton_qty'] ?? raw['carton_count']) as num?)
                          ?.toInt() ??
                      0;
              final packs =
                  ((raw['pack_qty'] ?? raw['pack_count']) as num?)?.toInt() ??
                      0;
              if (cartons > 0 || packs > 0) {
                _setAuditCarton(matched.id, cartons);
                _setAuditPack(matched.id, packs);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Local-first catalog active (remote merge skipped): $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderNotesController.dispose();
    for (final c in _auditCartonControllers.values) {
      c.dispose();
    }
    for (final c in _auditPackControllers.values) {
      c.dispose();
    }
    for (final c in _orderCartonControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<AlRabieProduct> get _filteredProducts {
    final normalizedQuery = AlRabieCatalog.normalizeArabicSearch(_searchQuery);
    return _catalogProducts.where((p) {
      final matchesCategory =
          _selectedCategory == 'الكل' || p.category == _selectedCategory;
      if (normalizedQuery.isEmpty) return matchesCategory;
      final normalizedName = AlRabieCatalog.normalizeArabicSearch(p.name);
      final normalizedCode = p.code.toLowerCase();
      final normalizedCat = AlRabieCatalog.normalizeArabicSearch(p.category);
      final matchesQuery = normalizedName.contains(normalizedQuery) ||
          normalizedCode.contains(normalizedQuery) ||
          normalizedCat.contains(normalizedQuery);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _setAuditCarton(String productId, int newValue) {
    final clamped = newValue.clamp(0, 99999);
    setState(() {
      _auditCartons[productId] = clamped;
    });
    final ctrl = _auditCartonControllers[productId];
    if (ctrl != null && ctrl.text != '$clamped') {
      ctrl.text = '$clamped';
      ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: ctrl.text.length),
      );
    }
  }

  void _setAuditPack(String productId, int newValue) {
    final clamped = newValue.clamp(0, 99999);
    setState(() {
      _auditPacks[productId] = clamped;
    });
    final ctrl = _auditPackControllers[productId];
    if (ctrl != null && ctrl.text != '$clamped') {
      ctrl.text = '$clamped';
      ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: ctrl.text.length),
      );
    }
  }

  void _setOrderCarton(String productId, int newValue) {
    final clamped = newValue.clamp(0, 99999);
    setState(() {
      _orderCartons[productId] = clamped;
    });
    final ctrl = _orderCartonControllers[productId];
    if (ctrl != null && ctrl.text != '$clamped') {
      ctrl.text = '$clamped';
      ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: ctrl.text.length),
      );
    }
  }

  int get _auditedItemsCount {
    int count = 0;
    for (final p in _catalogProducts) {
      if ((_auditCartons[p.id] ?? 0) > 0 || (_auditPacks[p.id] ?? 0) > 0) {
        count++;
      }
    }
    return count;
  }

  int get _totalAuditCartons =>
      _auditCartons.values.fold<int>(0, (sum, v) => sum + v);

  int get _totalAuditPacks =>
      _auditPacks.values.fold<int>(0, (sum, v) => sum + v);

  int get _totalOrderCartons =>
      _orderCartons.values.fold<int>(0, (sum, v) => sum + v);

  int get _orderedDistinctProductsCount =>
      _orderCartons.values.where((v) => v > 0).length;

  double get _totalOrderAmount {
    double total = 0;
    for (final p in _catalogProducts) {
      final qty = _orderCartons[p.id] ?? 0;
      if (qty > 0) {
        total += qty * p.cartonPrice;
      }
    }
    return total;
  }

  /// إرسال الجرد الأسبوعي للمشرف (يحفظ محلياً ويرفع لـ Supabase / Sync Queue)
  Future<void> _submitInventoryToSupervisor() async {
    FocusScope.of(context).unfocus();

    if (_auditedItemsCount == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            content: const Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'يرجى إدخال كمية صنف واحد على الأقل قبل إرسال الجرد للمشرف.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      return;
    }

    setState(() => _isSubmittingAudit = true);

    try {
      final now = DateTime.now();
      final batchRef =
          'AUD-${now.month}${now.day}-${now.millisecondsSinceEpoch.toString().substring(9)}';
      bool syncedOnline = false;

      final Map<String, Map<String, dynamic>> localAuditCache =
          _offlineSync.getCachedInventoryAudits();

      for (final product in _catalogProducts) {
        final cartons = _auditCartons[product.id] ?? 0;
        final packs = _auditPacks[product.id] ?? 0;
        if (cartons > 0 || packs > 0) {
          final entryMap = <String, dynamic>{
            'product_id': product.id,
            'sku': product.code,
            'product_name': product.name,
            'category': product.category,
            'carton_qty': cartons,
            'pack_qty': packs,
            'carton_count': cartons,
            'pack_count': packs,
            'damaged_qty': 0,
            'returned_qty': 0,
            'notes':
                'جرد ميداني مرسل للمشرف ($batchRef) - التاجر: $_selectedMerchant - [${product.code}] ${product.name}',
            'audited_at': now.toIso8601String(),
          };
          localAuditCache[product.id] = entryMap;

          syncedOnline = await _offlineSync.enqueueOrSyncOperation(
            table: AppConstants.tableInventoryAudits,
            action: 'upsert',
            payload: <String, dynamic>{
              'product_id': product.id,
              'carton_qty': cartons,
              'pack_qty': packs,
              'damaged_qty': 0,
              'returned_qty': 0,
              'notes':
                  'مُرسل للمشرف ($batchRef) | الصنف: [${product.code}] ${product.name} | التاجر: $_selectedMerchant | المندوب: ${widget.userProfile.fullName}',
              'branch_id':
                  widget.userProfile.branchId ?? 'الفرع الرئيسي - صنعاء',
              'audited_by': widget.userProfile.id,
              'audited_at': now.toIso8601String(),
            },
          );
        }
      }

      await _offlineSync.cacheInventoryAudits(localAuditCache);

      final summaryText =
          'تم إرسال الجرد ($batchRef) للمشرف بنجاح • التاجر: $_selectedMerchant • الأصناف المجرودة: $_auditedItemsCount / ${_catalogProducts.length} ($_totalAuditCartons كرتون و $_totalAuditPacks عبوة)';

      if (mounted) {
        setState(() {
          _lastAuditSubmissionBanner = summaryText;
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        syncedOnline
                            ? 'تم إرسال جرد أصناف الربيع للمشرف ومزامنته مباشرة ($batchRef)'
                            : 'تم اعتماد الجرد ($batchRef) وحفظه للإرسال للمشرف فور توفر الشبكة',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingAudit = false);
      }
    }
  }

  /// إرسال طلب البضاعة السريع للفرع
  Future<void> _submitOrderToBranch() async {
    FocusScope.of(context).unfocus();

    if (_totalOrderCartons <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            content: const Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'يرجى تحديد كمية صنف واحد على الأقل لإرسال طلب البضاعة للفرع.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      return;
    }

    setState(() => _isSubmittingOrder = true);

    try {
      final now = DateTime.now();
      final orderNumber =
          'ORD-${now.month}${now.day}-${now.millisecondsSinceEpoch.toString().substring(9)}';
      final branchName =
          widget.userProfile.branchId ?? 'الفرع الرئيسي - صنعاء';
      final totalAmount = _totalOrderAmount;
      final totalCartons = _totalOrderCartons;

      final List<String> summaryItems = <String>[];
      for (final p in _catalogProducts) {
        final qty = _orderCartons[p.id] ?? 0;
        if (qty > 0) {
          summaryItems.add('[${p.code}] ${p.name} ($qty كرتون)');
        }
      }

      // تحديث الكاش المحلي للطلبات
      final cachedOrders = _offlineSync.getCachedOrders();
      final newOrderJson = <String, dynamic>{
        'id': orderNumber,
        'order_number': orderNumber,
        'customer_name': _selectedMerchant,
        'branch_name': branchName,
        'status': 'pending',
        'items_count': totalCartons,
        'total_amount': totalAmount,
        'created_at': now.toIso8601String(),
        'summary_items': summaryItems,
      };
      cachedOrders.insert(0, newOrderJson);
      await _offlineSync.cacheOrders(cachedOrders);

      final syncedOnline = await _offlineSync.enqueueOrSyncOperation(
        table: AppConstants.tableOrders,
        action: 'insert',
        payload: <String, dynamic>{
          'order_number': orderNumber,
          'customer_name': _selectedMerchant,
          'status': 'pending',
          'items_count': totalCartons,
          'total_amount': totalAmount,
          'created_by': widget.userProfile.id,
          'created_at': now.toIso8601String(),
        },
      );

      final formattedTotal = AppConstants.formatCurrency(
        totalAmount,
        branch: branchName,
      );

      if (mounted) {
        setState(() {
          _lastOrderSubmissionBanner =
              'تم إرسال الطلب ($orderNumber) للفرع • التاجر: $_selectedMerchant • $totalCartons كرتون • الإجمالي: $formattedTotal';
          for (final p in _catalogProducts) {
            _orderCartons[p.id] = 0;
            _orderCartonControllers[p.id]?.text = '0';
          }
          _orderNotesController.clear();
        });

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
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: AppConstants.royalGold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        syncedOnline
                            ? 'تم إرسال طلب أصناف الربيع ($orderNumber) للفرع بنجاح ($formattedTotal)'
                            : 'تم حفظ طلب البضاعة ($orderNumber) محلياً وسيتم إرساله للفرع فور توفر الشبكة ($formattedTotal)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingOrder = false);
      }
    }
  }

  void _resetCurrentAuditQuantities() {
    setState(() {
      for (final p in _catalogProducts) {
        _auditCartons[p.id] = 0;
        _auditPacks[p.id] = 0;
        _auditCartonControllers[p.id]?.text = '0';
        _auditPackControllers[p.id]?.text = '0';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final filtered = _filteredProducts;
    final totalCatalogCount = _catalogProducts.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.cleanLightGrey,
        appBar: AppBar(
          backgroundColor: AppConstants.deepNavyBlue,
          foregroundColor: Colors.white,
          titleSpacing: 12,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppConstants.royalGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppConstants.deepNavyBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userProfile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'مندوب مبيعات الربيع • ${widget.userProfile.branchId ?? "الفرع الرئيسي"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _offlineSync.isOnlineNotifier,
              builder: (context, isOnline, _) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Colors.green.shade600
                        : AppConstants.royalGold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnline
                            ? Icons.cloud_done_rounded
                            : Icons.offline_bolt_rounded,
                        size: 13,
                        color: isOnline
                            ? Colors.white
                            : AppConstants.deepNavyBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? 'متصل' : 'محلي',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOnline
                              ? Colors.white
                              : AppConstants.deepNavyBlue,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (widget.onSwitchToFullDashboard != null)
              IconButton(
                tooltip: 'اللوحة الكاملة',
                onPressed: widget.onSwitchToFullDashboard,
                icon: const Icon(
                  Icons.dashboard_customize_outlined,
                  color: AppConstants.royalGold,
                ),
              ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: widget.isSigningOut ? null : widget.onSignOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ===============================================================
              // 1. شريط اختيار التاجر + الخيارين الرئيسيين + البحث والفئات
              // ===============================================================
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // اختيار التاجر / نقطة البيع الحالية
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.cleanLightGrey,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.handshake_rounded,
                            size: 18,
                            color: AppConstants.deepNavyBlue,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'التاجر:',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppConstants.deepNavyBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedMerchant,
                                isExpanded: true,
                                isDense: true,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: AppConstants.deepNavyBlue,
                                ),
                                items: _merchants.map((m) {
                                  return DropdownMenuItem<String>(
                                    value: m,
                                    child: Text(
                                      m,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedMerchant = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // الخياران الرئيسيان للمندوب عند زيارة التاجر:
                    // 1) جرد المخزون  |  2) طلب بضاعة للفرع
                    Row(
                      children: [
                        Expanded(
                          child: _MainRepOptionButton(
                            isSelected: _activeSection == 0,
                            icon: Icons.fact_check_rounded,
                            title: 'جرد المخزون',
                            subtitle: 'كتالوج الربيع + إرسال للمشرف',
                            badgeText: '$_auditedItemsCount/$totalCatalogCount',
                            onTap: () => setState(() => _activeSection = 0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MainRepOptionButton(
                            isSelected: _activeSection == 1,
                            icon: Icons.add_shopping_cart_rounded,
                            title: 'طلب بضاعة',
                            subtitle: 'إرسال طلب سريع للفرع',
                            badgeText: _totalOrderCartons > 0
                                ? '$_totalOrderCartons كرتون'
                                : 'ORDER',
                            onTap: () => setState(() => _activeSection = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // شريط البحث السريع بالاسم أو رقم الصنف الرسمي (43002001 / JLP-3001)
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText:
                            'ابحث بالاسم أو رقم الصنف (43002001 أو JLP-3001)...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : (_activeSection == 0 && _auditedItemsCount > 0
                                ? TextButton(
                                    onPressed: _resetCurrentAuditQuantities,
                                    child: const Text(
                                      'تصفير',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  )
                                : null),
                        filled: true,
                        fillColor: AppConstants.cleanLightGrey,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // شريط تصنيفات أصناف الربيع (عصير 185، 330، 1 لتر، برازما، حليب، شراب...)
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: AlRabieCatalog.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final cat = AlRabieCatalog.categories[index];
                          final isSelected = _selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) {
                              setState(() => _selectedCategory = cat);
                            },
                            selectedColor: AppConstants.softRoyalGold,
                            backgroundColor: AppConstants.cleanLightGrey,
                            side: BorderSide(
                              color: isSelected
                                  ? AppConstants.royalGold
                                  : Colors.grey.shade300,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              color: AppConstants.deepNavyBlue,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // شريط تأكيد آخر عملية إرسال (إن وجد)
              if (_activeSection == 0 &&
                  _lastAuditSubmissionBanner != null) ...[
                Container(
                  width: double.infinity,
                  color: Colors.green.shade50,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: Colors.green.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastAuditSubmissionBanner!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_activeSection == 1 &&
                  _lastOrderSubmissionBanner != null) ...[
                Container(
                  width: double.infinity,
                  color: AppConstants.softRoyalGold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_rounded,
                        size: 18,
                        color: AppConstants.deepNavyBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastOrderSubmissionBanner!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.deepNavyBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ===============================================================
              // 2. قائمة أصناف الربيع (جرد المخزون أو طلب البضاعة) مع الصور الرسمية
              // ===============================================================
              Expanded(
                child: _activeSection == 0
                    ? _buildInventoryAuditList(filtered)
                    : _buildQuickOrderList(filtered),
              ),

              // ===============================================================
              // 3. الشريط السفلي الثابت للإرسال الفوري (للمشرف أو للفرع)
              // ===============================================================
              _activeSection == 0
                  ? _buildAuditBottomActionBar()
                  : _buildOrderBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// قائمة جرد أصناف الربيع مع الصورة الرسمية وأزرار (+ / -) أو الإدخال الرقمي المباشر
  Widget _buildInventoryAuditList(List<AlRabieProduct> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text('لا توجد أصناف مطابقة لبحثك.'),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final cartons = _auditCartons[product.id] ?? 0;
        final packs = _auditPacks[product.id] ?? 0;
        final isEntered = cartons > 0 || packs > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isEntered ? AppConstants.royalGold : Colors.grey.shade300,
              width: isEntered ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AlRabieProductThumbnail(
                      imageAsset: product.imageAsset,
                      category: product.category,
                      size: 54,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppConstants.deepNavyBlue,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  product.code,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.royalGold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  product.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              if (isEntered)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppConstants.softRoyalGold,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'مجرود',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.deepNavyBlue,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppConstants.deepNavyBlue,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product.unit,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DirectNumericStepper(
                        label: 'كرتون',
                        controller: _auditCartonControllers[product.id]!,
                        primaryColor: AppConstants.deepNavyBlue,
                        onDecrement: () =>
                            _setAuditCarton(product.id, cartons - 1),
                        onIncrement: () =>
                            _setAuditCarton(product.id, cartons + 1),
                        onChanged: (val) => _setAuditCarton(
                          product.id,
                          int.tryParse(val) ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DirectNumericStepper(
                        label: 'عبوة (فرط)',
                        controller: _auditPackControllers[product.id]!,
                        primaryColor: Colors.blueGrey.shade800,
                        onDecrement: () => _setAuditPack(product.id, packs - 1),
                        onIncrement: () => _setAuditPack(product.id, packs + 1),
                        onChanged: (val) => _setAuditPack(
                          product.id,
                          int.tryParse(val) ?? 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// قائمة طلب البضاعة السريع للفرع مع الصور الرسمية
  Widget _buildQuickOrderList(List<AlRabieProduct> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text('لا توجد أصناف مطابقة لبحثك.'),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: products.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _orderNotesController,
              decoration: InputDecoration(
                hintText: 'ملاحظات سريعة للفرع (مثل: توصيل مستعجل للتاجر)...',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          );
        }

        final product = products[index - 1];
        final qty = _orderCartons[product.id] ?? 0;
        final isSelected = qty > 0;
        final lineTotal = qty * product.cartonPrice;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? AppConstants.royalGold : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AlRabieProductThumbnail(
                  imageAsset: product.imageAsset,
                  category: product.category,
                  size: 52,
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.deepNavyBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.code,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.royalGold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              product.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: AppConstants.deepNavyBlue,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${AppConstants.formatCurrency(product.cartonPrice, branch: widget.userProfile.branchId)} / كرتون',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 2),
                        Text(
                          'الإجمالي: ${AppConstants.formatCurrency(lineTotal, branch: widget.userProfile.branchId)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: _DirectNumericStepper(
                    label: 'كرتون مطلوب',
                    controller: _orderCartonControllers[product.id]!,
                    primaryColor: AppConstants.deepNavyBlue,
                    onDecrement: () => _setOrderCarton(product.id, qty - 1),
                    onIncrement: () => _setOrderCarton(product.id, qty + 1),
                    onChanged: (val) => _setOrderCarton(
                      product.id,
                      int.tryParse(val) ?? 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// الشريط السفلي لإرسال الجرد للمشرف
  Widget _buildAuditBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المجرود: $_auditedItemsCount / ${_catalogProducts.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppConstants.deepNavyBlue,
                  ),
                ),
                Text(
                  '$_totalAuditCartons كرتون • $_totalAuditPacks عبوة',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed:
                    _isSubmittingAudit ? null : _submitInventoryToSupervisor,
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.deepNavyBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSubmittingAudit
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: AppConstants.royalGold,
                        size: 18,
                      ),
                label: const Text(
                  'إرسال الجرد للمشرف',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// الشريط السفلي لإرسال طلب البضاعة للفرع
  Widget _buildOrderBottomActionBar() {
    final formattedTotal = AppConstants.formatCurrency(
      _totalOrderAmount,
      branch: widget.userProfile.branchId,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_orderedDistinctProductsCount أصناف ($_totalOrderCartons كرتون)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  formattedTotal,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppConstants.deepNavyBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSubmittingOrder ? null : _submitOrderToBranch,
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.royalGold,
                  foregroundColor: AppConstants.deepNavyBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSubmittingOrder
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppConstants.deepNavyBlue,
                        ),
                      )
                    : const Icon(
                        Icons.local_shipping_rounded,
                        color: AppConstants.deepNavyBlue,
                        size: 19,
                      ),
                label: const Text(
                  'إرسال الطلب للفرع',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// زر الخيار الرئيسي للمندوب (جرد المخزون / طلب بضاعة)
class _MainRepOptionButton extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback onTap;

  const _MainRepOptionButton({
    required this.isSelected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.deepNavyBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppConstants.royalGold : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppConstants.royalGold
                      : AppConstants.deepNavyBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color:
                          isSelected ? Colors.white : AppConstants.deepNavyBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppConstants.royalGold
                        : AppConstants.softRoyalGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppConstants.deepNavyBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// أداة إدخال كميات مزدوجة: تدعم أزرار (+ / -) والإدخال الرقمي المباشر بالكيبورد معاً
class _DirectNumericStepper extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color primaryColor;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<String> onChanged;

  const _DirectNumericStepper({
    required this.label,
    required this.controller,
    required this.primaryColor,
    required this.onDecrement,
    required this.onIncrement,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.cleanLightGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onDecrement,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.remove_rounded, size: 18, color: primaryColor),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 24,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: onChanged,
                    onTap: () {
                      controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controller.text.length,
                      );
                    },
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: primaryColor,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onIncrement,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(8),
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
