import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';
import '../../../auth/data/models/user_profile_model.dart';

/// نموذج مبسط لصنف ضمن واجهة المندوب الميدانية السريعة (الأصناف الـ 27 المعتمدة)
class _SalesRepProductItem {
  final String id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final double cartonPrice;

  const _SalesRepProductItem({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.cartonPrice,
  });
}

/// واجهة مندوب المبيعات الميدانية السريعة والخفيفة (Sales Rep Field Interface)
/// مصممة خصيصاً لزيارة التاجر وتحتوي على خيارين رئيسيين فقط:
/// 1. جرد المخزون (الأصناف الـ 27 مع أزرار + / - وإدخال رقمي مباشر + زر إرسال الجرد للمشرف)
/// 2. طلب بضاعة (شاشة سريعة لإرسال طلبات الأصناف للفرع)
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

  /// 0 = جرد المخزون (27 صنفاً) | 1 = طلب بضاعة للفرع
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

  /// القائمة المعتمدة للأصناف الـ 27
  static const List<_SalesRepProductItem> _products27 = [
    _SalesRepProductItem(id: 'prod-01', code: 'JLP-1001', name: 'عصير جلب مانجو طبيعي 250 مل', category: 'مشروبات وعصائر', unit: 'كرتون (24 عبوة)', cartonPrice: 4800),
    _SalesRepProductItem(id: 'prod-02', code: 'JLP-1002', name: 'عصير جلب جوافة فاخر 250 مل', category: 'مشروبات وعصائر', unit: 'كرتون (24 عبوة)', cartonPrice: 4800),
    _SalesRepProductItem(id: 'prod-03', code: 'JLP-1003', name: 'عصير جلب كوكتيل فواكه 250 مل', category: 'مشروبات وعصائر', unit: 'كرتون (24 عبوة)', cartonPrice: 5000),
    _SalesRepProductItem(id: 'prod-04', code: 'JLP-1004', name: 'عصير جلب برتقال طازج 1 لتر', category: 'مشروبات وعصائر', unit: 'كرتون (12 عبوة)', cartonPrice: 7200),
    _SalesRepProductItem(id: 'prod-05', code: 'JLP-1005', name: 'عصير جلب تفاح أحمر 1 لتر', category: 'مشروبات وعصائر', unit: 'كرتون (12 عبوة)', cartonPrice: 7200),
    _SalesRepProductItem(id: 'prod-06', code: 'JLP-1006', name: 'مياه جلب النقية 330 مل', category: 'مياه معدنية', unit: 'كرتون (40 قارورة)', cartonPrice: 2200),
    _SalesRepProductItem(id: 'prod-07', code: 'JLP-1007', name: 'مياه جلب النقية 600 مل', category: 'مياه معدنية', unit: 'كرتون (30 قارورة)', cartonPrice: 2400),
    _SalesRepProductItem(id: 'prod-08', code: 'JLP-1008', name: 'مياه جلب العائلية 1.5 لتر', category: 'مياه معدنية', unit: 'كرتون (12 قارورة)', cartonPrice: 2100),
    _SalesRepProductItem(id: 'prod-09', code: 'JLP-1009', name: 'حليب جلب كامل الدسم 1 لتر', category: 'ألبان ومنتجاتها', unit: 'كرتون (12 عبوة)', cartonPrice: 9600),
    _SalesRepProductItem(id: 'prod-10', code: 'JLP-1010', name: 'حليب جلب قليل الدسم 1 لتر', category: 'ألبان ومنتجاتها', unit: 'كرتون (12 عبوة)', cartonPrice: 9600),
    _SalesRepProductItem(id: 'prod-11', code: 'JLP-1011', name: 'حليب جلب بالموز للأطفال 200 مل', category: 'ألبان ومنتجاتها', unit: 'كرتون (27 عبوة)', cartonPrice: 6500),
    _SalesRepProductItem(id: 'prod-12', code: 'JLP-1012', name: 'حليب جلب بالفراولة 200 مل', category: 'ألبان ومنتجاتها', unit: 'كرتون (27 عبوة)', cartonPrice: 6500),
    _SalesRepProductItem(id: 'prod-13', code: 'JLP-1013', name: 'حليب جلب بالشوكولاتة 200 مل', category: 'ألبان ومنتجاتها', unit: 'كرتون (27 عبوة)', cartonPrice: 6500),
    _SalesRepProductItem(id: 'prod-14', code: 'JLP-1014', name: 'زبادي جلب طازج كامل الدسم 170 جم', category: 'ألبان ومنتجاتها', unit: 'كرتون (24 علبة)', cartonPrice: 4200),
    _SalesRepProductItem(id: 'prod-15', code: 'JLP-1015', name: 'لبن رائب جلب المراعي 500 مل', category: 'ألبان ومنتجاتها', unit: 'كرتون (20 عبوة)', cartonPrice: 5400),
    _SalesRepProductItem(id: 'prod-16', code: 'JLP-1016', name: 'جبنة مثلثات جلب الكريمية 8 قطع', category: 'أجبان ومعلبات', unit: 'كرتون (36 علبة)', cartonPrice: 14400),
    _SalesRepProductItem(id: 'prod-17', code: 'JLP-1017', name: 'جبنة كاسات جلب الذهبية 500 جم', category: 'أجبان ومعلبات', unit: 'كرتون (12 برطمان)', cartonPrice: 18000),
    _SalesRepProductItem(id: 'prod-18', code: 'JLP-1018', name: 'قشطة جلب التاج الفاخرة 170 جم', category: 'أجبان ومعلبات', unit: 'كرتون (48 علبة)', cartonPrice: 19200),
    _SalesRepProductItem(id: 'prod-19', code: 'JLP-1019', name: 'تونة جلب لحم أبيض بالزيت 185 جم', category: 'أجبان ومعلبات', unit: 'كرتون (48 علبة)', cartonPrice: 28800),
    _SalesRepProductItem(id: 'prod-20', code: 'JLP-1020', name: 'فول مدمس جلب بالخلطة السرية 400 جم', category: 'بقوليات ومعلبات', unit: 'كرتون (24 علبة)', cartonPrice: 7800),
    _SalesRepProductItem(id: 'prod-21', code: 'JLP-1021', name: 'فاصوليا بيضاء جلب بصلصة الطماطم 400 جم', category: 'بقوليات ومعلبات', unit: 'كرتون (24 علبة)', cartonPrice: 8400),
    _SalesRepProductItem(id: 'prod-22', code: 'JLP-1022', name: 'بازلاء خضراء جلب طازجة 400 جم', category: 'بقوليات ومعلبات', unit: 'كرتون (24 علبة)', cartonPrice: 7600),
    _SalesRepProductItem(id: 'prod-23', code: 'JLP-1023', name: 'معجون طماطم جلب المركز 135 جم', category: 'زيوت وصلصات', unit: 'كرتون (48 علبة)', cartonPrice: 9200),
    _SalesRepProductItem(id: 'prod-24', code: 'JLP-1024', name: 'زيت دوار الشمس جلب النقي 1.5 لتر', category: 'زيوت وصلصات', unit: 'كرتون (12 قارورة)', cartonPrice: 16800),
    _SalesRepProductItem(id: 'prod-25', code: 'JLP-1025', name: 'أرز بسمتي جلب حبة طويلة 5 كجم', category: 'بقوليات وحبوب', unit: 'كرتون (4 أكياس)', cartonPrice: 22000),
    _SalesRepProductItem(id: 'prod-26', code: 'JLP-1026', name: 'شاي جلب الأسود الكيني الفاخر 400 جم', category: 'مشروبات ساخنة', unit: 'كرتون (24 عبوة)', cartonPrice: 24000),
    _SalesRepProductItem(id: 'prod-27', code: 'JLP-1027', name: 'بسكويت جلب بالزبدة والقمح 100 جم', category: 'بسكويت وخفايف', unit: 'كرتون (48 باكت)', cartonPrice: 6800),
  ];

  String _selectedMerchant = _merchants.first;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _orderNotesController = TextEditingController();

  // بيانات جرد المخزون (كرتون + عبوة لكل صنف من الـ 27)
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
    for (final item in _products27) {
      _auditCartons[item.id] = 0;
      _auditPacks[item.id] = 0;
      _auditCartonControllers[item.id] = TextEditingController(text: '0');
      _auditPackControllers[item.id] = TextEditingController(text: '0');

      _orderCartons[item.id] = 0;
      _orderCartonControllers[item.id] = TextEditingController(text: '0');
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

  List<_SalesRepProductItem> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _products27;
    return _products27.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.code.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
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
    for (final p in _products27) {
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
    for (final p in _products27) {
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

      // حفظ الكاش المحلي وتجهيز الإرسال للمشرف
      final Map<String, Map<String, dynamic>> localAuditCache =
          _offlineSync.getCachedInventoryAudits();

      for (final product in _products27) {
        final cartons = _auditCartons[product.id] ?? 0;
        final packs = _auditPacks[product.id] ?? 0;
        if (cartons > 0 || packs > 0) {
          final entryMap = <String, dynamic>{
            'product_id': product.id,
            'carton_count': cartons,
            'pack_count': packs,
            'damaged_count': 0,
            'returned_count': 0,
            'notes':
                'جرد ميداني مرسل للمشرف ($batchRef) - التاجر: $_selectedMerchant',
            'audited_at': now.toIso8601String(),
          };
          localAuditCache[product.id] = entryMap;

          syncedOnline = await _offlineSync.enqueueOrSyncOperation(
            table: AppConstants.tableInventoryAudits,
            action: 'upsert',
            payload: <String, dynamic>{
              'product_id': product.id,
              'carton_count': cartons,
              'pack_count': packs,
              'damaged_count': 0,
              'returned_count': 0,
              'notes':
                  'مُرسل للمشرف ($batchRef) | التاجر: $_selectedMerchant | المندوب: ${widget.userProfile.fullName}',
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
          'تم إرسال الجرد ($batchRef) للمشرف بنجاح • التاجر: $_selectedMerchant • الأصناف المجرودة: $_auditedItemsCount / 27 ($_totalAuditCartons كرتون و $_totalAuditPacks عبوة)';

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
                            ? 'تم إرسال الجرد للمشرف ومزامنته مباشرة ($batchRef)'
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
      for (final p in _products27) {
        final qty = _orderCartons[p.id] ?? 0;
        if (qty > 0) {
          summaryItems.add('${p.name} ($qty كرتون)');
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
          for (final p in _products27) {
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
                            ? 'تم إرسال طلب البضاعة ($orderNumber) للفرع بنجاح ($formattedTotal)'
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
      for (final p in _products27) {
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
                      'بوابة المندوب الميداني • ${widget.userProfile.branchId ?? "الفرع الرئيسي"}',
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
              // 1. شريط اختيار التاجر + الخيارين الرئيسيين عند زيارة التاجر
              // ===============================================================
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                    const SizedBox(height: 10),

                    // الخياران الرئيسيان للمندوب عند زيارة التاجر:
                    // 1) جرد المخزون (27 صنفاً)  |  2) طلب بضاعة للفرع
                    Row(
                      children: [
                        Expanded(
                          child: _MainRepOptionButton(
                            isSelected: _activeSection == 0,
                            icon: Icons.fact_check_rounded,
                            title: 'جرد المخزون',
                            subtitle: 'الأصناف الـ 27 + إرسال للمشرف',
                            badgeText: '$_auditedItemsCount/27',
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
                                : 'سريع',
                            onTap: () => setState(() => _activeSection = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // شريط البحث السريع في الأصناف الـ 27
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText:
                            'ابحث في الأصناف الـ 27 بالاسم أو الكود (JLP-1001)...',
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
              // 2. قائمة الأصناف الـ 27 (جرد المخزون أو طلب البضاعة)
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

  /// قائمة جرد الأصناف الـ 27 (بأزرار + / - أو الإدخال الرقمي المباشر)
  Widget _buildInventoryAuditList(List<_SalesRepProductItem> products) {
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
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.deepNavyBlue,
                        borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppConstants.deepNavyBlue,
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
                  '${product.category} • ${product.unit}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black54,
                  ),
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
                        label: 'عبوة',
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

  /// قائمة طلب البضاعة السريع للفرع
  Widget _buildQuickOrderList(List<_SalesRepProductItem> products) {
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
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppConstants.deepNavyBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppConstants.formatCurrency(product.cartonPrice, branch: widget.userProfile.branchId)} / كرتون',
                        style: const TextStyle(
                          fontSize: 12,
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
                const SizedBox(width: 10),
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
                  'الأصناف المجرودة: $_auditedItemsCount / 27',
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
