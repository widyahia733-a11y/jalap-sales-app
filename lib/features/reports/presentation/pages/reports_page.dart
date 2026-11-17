import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/al_rabie_catalog.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/audit_log_service.dart';
import '../../../../core/utils/offline_sync_service.dart';
import '../../../auth/data/models/user_profile_model.dart';

/// نموذج موحد لسجل حركة داخل تقارير الإدارة الشاملة (جرد ميداني أو طلب مبيعات)
class FieldReportRecord {
  final String id;
  final String recordType; // 'audit' أو 'order'
  final String repId;
  final String repName;
  final String repUsername;
  final int branchId;
  final String branchName;
  final String customerName;
  final String productCode;
  final String productName;
  final String category;
  final String imageAsset;
  final int cartonQty;
  final String status;
  final DateTime timestamp;

  const FieldReportRecord({
    required this.id,
    required this.recordType,
    required this.repId,
    required this.repName,
    required this.repUsername,
    required this.branchId,
    required this.branchName,
    required this.customerName,
    required this.productCode,
    required this.productName,
    required this.category,
    required this.imageAsset,
    required this.cartonQty,
    required this.status,
    required this.timestamp,
  });

  bool get isAudit => recordType == 'audit';
  bool get isOrder => recordType == 'order';

  String get recordTypeArabic => isAudit ? 'جرد ميداني' : 'طلب مبيعات';
}

/// فلاتر الفترات الزمنية السريعة والمخصصة
enum ReportDatePreset {
  all,
  today,
  thisWeek,
  thisMonth,
  custom,
}

/// شاشة التقارير والتحليلات الشاملة للمشرفين والإدارة (`reports_page.dart`)
/// توفر فلترة متعددة الأبعاد (المندوب، الفرع/المخزن، الصنف، التاريخ، ونوع الحركة) مع مؤشرات أداء ديناميكية وتصدير.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final OfflineSyncService _offlineSync = OfflineSyncService.instance;
  final TextEditingController _quickSearchController = TextEditingController();

  List<FieldReportRecord> _allRecords = <FieldReportRecord>[];
  List<AuditLogEntry> _auditLogs = <AuditLogEntry>[];
  List<UserProfileModel> _salesReps = <UserProfileModel>[];
  Map<int, String> _branchesMap =
      Map<int, String>.from(UserProfileModel.officialBranchesById);

  // حالة الفلاتر الخمسة الشاملة + وضع سجل التدقيق (audit_logs)
  String _selectedRecordType = 'all'; // 'all', 'audit', 'order', 'audit_logs'
  String _selectedRepId = 'all'; // 'all' أو معرف المندوب (rep.id)
  String _selectedBranchName = 'الكل'; // 'الكل' أو اسم الفرع
  AlRabieProduct? _selectedProduct; // null = جميع الأصناف الـ 62
  ReportDatePreset _selectedDatePreset = ReportDatePreset.all;
  DateTimeRange? _customDateRange;
  String _quickSearchQuery = '';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportsDataFromSupabase();
  }

  @override
  void dispose() {
    _quickSearchController.dispose();
    super.dispose();
  }

  /// جلب وتوحيد كافة سجلات الجرد (`inventory_audits`) والطلبات (`orders`) والمناديب والفروع من Supabase
  Future<void> _loadReportsDataFromSupabase() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final Map<String, UserProfileModel> repsById = <String, UserProfileModel>{};
    final Map<int, String> customersById = <int, String>{};
    final List<FieldReportRecord> combined = <FieldReportRecord>[];

    try {
      if (AppConstants.isSupabaseConfigured) {
        final supabase = Supabase.instance.client;

        // 1. جلب الفروع الـ 7 الرسمية
        try {
          final List<dynamic> branchRows = await supabase
              .from(AppConstants.tableBranches)
              .select('id, branch_name')
              .order('id', ascending: true);
          if (branchRows.isNotEmpty) {
            final Map<int, String> loadedBranches = <int, String>{};
            for (final row in branchRows) {
              if (row is Map) {
                final bId = int.tryParse(row['id']?.toString() ?? '');
                final bName = row['branch_name']?.toString().trim() ?? '';
                if (bId != null && bName.isNotEmpty) {
                  loadedBranches[bId] = bName;
                }
              }
            }
            if (loadedBranches.isNotEmpty) {
              _branchesMap = loadedBranches;
            }
          }
        } catch (e) {
          debugPrint('Reports branches fetch info: $e');
        }

        // 2. جلب جميع المناديب والمشرفين من جدول users_profiles
        try {
          final List<dynamic> userRows = await supabase
              .from(AppConstants.tableUsersProfiles)
              .select(
                'id, username, full_name, phone, role, branch_id, is_active, created_at',
              )
              .order('created_at', ascending: false);

          final List<UserProfileModel> loadedReps = <UserProfileModel>[];
          for (final raw in userRows) {
            if (raw is Map<String, dynamic>) {
              final bNum =
                  UserProfileModel.resolveBranchNumber(raw['branch_id']);
              final bLabel = (bNum != null && _branchesMap.containsKey(bNum))
                  ? _branchesMap[bNum]!
                  : UserProfileModel.resolveBranchName(
                      raw['branch_id'],
                      role: raw['role']?.toString(),
                    );
              final model = UserProfileModel.fromJson(raw).copyWith(
                branchId: bLabel,
                branchNumber: bNum ?? 1,
              );
              repsById[model.id] = model;
              if (model.isSales) {
                loadedReps.add(model);
              }
            }
          }
          _salesReps = loadedReps;
        } catch (e) {
          debugPrint('Reports users_profiles fetch info: $e');
        }

        // 3. جلب أسماء العملاء المسجلين في جدول customers (إن وجدوا)
        try {
          final List<dynamic> custRows = await supabase
              .from(AppConstants.tableCustomers)
              .select('id, customer_name');
          for (final row in custRows) {
            if (row is Map) {
              final cId = int.tryParse(row['id']?.toString() ?? '');
              final cName = row['customer_name']?.toString().trim() ?? '';
              if (cId != null && cName.isNotEmpty) {
                customersById[cId] = cName;
              }
            }
          }
        } catch (e) {
          debugPrint('Reports customers fetch info: $e');
        }

        // 4. جلب سجلات الجرد الفعلي من جدول inventory_audits
        try {
          final List<dynamic> auditRows = await supabase
              .from(AppConstants.tableInventoryAudits)
              .select()
              .order('audit_date', ascending: false)
              .limit(250);

          for (final raw in auditRows) {
            if (raw is Map<String, dynamic>) {
              final repId = raw['rep_id']?.toString() ?? '';
              final repProfile = repsById[repId];
              final prodKey = raw['product_id']?.toString() ?? '1';
              final product = AlRabieCatalog.findBySkuOrId(prodKey) ??
                  AlRabieCatalog.items.first;
              final custId = int.tryParse(raw['customer_id']?.toString() ?? '');
              final customerLabel = (custId != null &&
                      customersById.containsKey(custId))
                  ? customersById[custId]!
                  : 'عميل ميداني عام';
              final branchNum = repProfile?.branchNumber ?? 1;
              final branchLabel =
                  repProfile?.branchId ?? (_branchesMap[branchNum] ?? 'فرع صنعاء');
              final qty =
                  ((raw['stock_qty'] ?? raw['carton_qty']) as num?)?.toInt() ??
                      0;
              final dt =
                  DateTime.tryParse(raw['audit_date']?.toString() ?? '') ??
                      DateTime.now();

              if (qty > 0) {
                combined.add(
                  FieldReportRecord(
                    id: 'AUD-${raw['id'] ?? dt.millisecondsSinceEpoch}',
                    recordType: 'audit',
                    repId: repId,
                    repName: repProfile?.fullName ?? 'مندوب ميداني',
                    repUsername: repProfile?.username ?? 'sales_rep',
                    branchId: branchNum,
                    branchName: branchLabel,
                    customerName: customerLabel,
                    productCode: product.code,
                    productName: product.name,
                    category: product.category,
                    imageAsset: product.imageAsset,
                    cartonQty: qty,
                    status: 'معتمد',
                    timestamp: dt,
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Reports inventory_audits fetch info: $e');
        }

        // 5. جلب سجلات طلبات التوريد والمبيعات من جدول orders
        try {
          final List<dynamic> orderRows = await supabase
              .from(AppConstants.tableOrders)
              .select()
              .order('order_date', ascending: false)
              .limit(250);

          for (final raw in orderRows) {
            if (raw is Map<String, dynamic>) {
              final repId = raw['rep_id']?.toString() ?? '';
              final repProfile = repsById[repId];
              final prodKey = raw['product_id']?.toString() ?? '1';
              final product = AlRabieCatalog.findBySkuOrId(prodKey) ??
                  AlRabieCatalog.items.first;
              final custId = int.tryParse(raw['customer_id']?.toString() ?? '');
              final customerLabel = (custId != null &&
                      customersById.containsKey(custId))
                  ? customersById[custId]!
                  : 'عميل ميداني عام';
              final branchNum = repProfile?.branchNumber ?? 1;
              final branchLabel =
                  repProfile?.branchId ?? (_branchesMap[branchNum] ?? 'فرع صنعاء');
              final qty =
                  ((raw['order_qty'] ?? raw['items_count']) as num?)?.toInt() ??
                      0;
              final statusRaw =
                  (raw['status']?.toString() ?? 'pending').toLowerCase();
              final statusArabic = statusRaw == 'completed'
                  ? 'مكتمل'
                  : (statusRaw == 'cancelled' ? 'ملغى' : 'قيد المتابعة');
              final dt =
                  DateTime.tryParse(raw['order_date']?.toString() ?? '') ??
                      DateTime.now();

              if (qty > 0) {
                combined.add(
                  FieldReportRecord(
                    id: 'ORD-${raw['id'] ?? dt.millisecondsSinceEpoch}',
                    recordType: 'order',
                    repId: repId,
                    repName: repProfile?.fullName ?? 'مندوب ميداني',
                    repUsername: repProfile?.username ?? 'sales_rep',
                    branchId: branchNum,
                    branchName: branchLabel,
                    customerName: customerLabel,
                    productCode: product.code,
                    productName: product.name,
                    category: product.category,
                    imageAsset: product.imageAsset,
                    cartonQty: qty,
                    status: statusArabic,
                    timestamp: dt,
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Reports orders fetch info: $e');
        }
      }

      // 6. دمج أي سجلات محلية حديثة من الكاش المحلي لمنع فقدان أي حركة ميدانية
      final localRecords = _offlineSync.getCachedReportRecords();
      for (final local in localRecords) {
        final dt = DateTime.tryParse(local['created_at']?.toString() ?? '') ??
            DateTime.now();
        final sku = local['sku']?.toString() ?? '43002001';
        final qty = (local['carton_qty'] as num?)?.toInt() ?? 0;
        final repId = local['rep_id']?.toString() ?? '';

        // تجنب تكرار السجل إذا كان قد تم جلبه من السحابة بنفس المندوب والصنف والكمية خلال دقيقة
        final alreadyInCombined = combined.any(
          (r) =>
              r.productCode == sku &&
              r.cartonQty == qty &&
              r.repId == repId &&
              r.timestamp.difference(dt).inMinutes.abs() < 2,
        );
        if (!alreadyInCombined && qty > 0) {
          final product = AlRabieCatalog.findBySkuOrId(sku) ??
              AlRabieCatalog.items.first;
          combined.add(
            FieldReportRecord(
              id: local['reference_no']?.toString() ??
                  'LOC-${dt.millisecondsSinceEpoch}',
              recordType: local['record_type']?.toString() ?? 'audit',
              repId: repId,
              repName: local['rep_name']?.toString() ?? 'مندوب ميداني',
              repUsername: local['rep_username']?.toString() ?? '',
              branchId: 1,
              branchName: local['branch_name']?.toString() ?? 'فرع صنعاء',
              customerName:
                  local['customer_name']?.toString() ?? 'عميل ميداني عام',
              productCode: product.code,
              productName: product.name,
              category: product.category,
              imageAsset: product.imageAsset,
              cartonQty: qty,
              status: 'محفوظ',
              timestamp: dt,
            ),
          );
        }
      }

      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // 7. جلب وبناء سجل التدقيق الرقابي الشامل (Audit Trail - audit_logs)
      final List<AuditLogEntry> fetchedLogs =
          await AuditLogService.instance.fetchCombinedAuditLogs();
      for (final rec in combined) {
        final alreadyLogged = fetchedLogs.any(
          (l) =>
              l.userId == rec.repId &&
              l.createdAt.difference(rec.timestamp).inMinutes.abs() < 2 &&
              l.details.contains(rec.productCode),
        );
        if (!alreadyLogged) {
          fetchedLogs.add(
            AuditLogEntry(
              id: 'LOG-${rec.id}',
              userId: rec.repId.isNotEmpty ? rec.repId : rec.repUsername,
              userName: rec.repName,
              userRole: 'sales_rep',
              branchName: rec.branchName,
              actionType:
                  rec.isAudit ? 'submit_inventory_audit' : 'create_order',
              targetEntity: '[${rec.productCode}] ${rec.productName}',
              details:
                  '${rec.recordTypeArabic}: ${rec.cartonQty} كرتون • العميل: ${rec.customerName} • الفرع: ${rec.branchName}',
              createdAt: rec.timestamp,
            ),
          );
        }
      }
      fetchedLogs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _auditLogs = fetchedLogs;
    } catch (error) {
      debugPrint('Error loading reports data: $error');
    }

    if (mounted) {
      setState(() {
        _allRecords = combined;
        _isLoading = false;
      });
    }
  }

  /// التحقق من وقوع تاريخ الحركة ضمن نطاق التاريخ المحدد
  bool _matchesDateFilter(DateTime dt) {
    final now = DateTime.now();
    switch (_selectedDatePreset) {
      case ReportDatePreset.all:
        return true;
      case ReportDatePreset.today:
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      case ReportDatePreset.thisWeek:
        final weekAgo = now.subtract(const Duration(days: 7));
        return dt.isAfter(weekAgo) || dt.isAtSameMomentAs(weekAgo);
      case ReportDatePreset.thisMonth:
        return dt.year == now.year && dt.month == now.month;
      case ReportDatePreset.custom:
        if (_customDateRange == null) return true;
        final start = DateTime(
          _customDateRange!.start.year,
          _customDateRange!.start.month,
          _customDateRange!.start.day,
        );
        final end = DateTime(
          _customDateRange!.end.year,
          _customDateRange!.end.month,
          _customDateRange!.end.day,
          23,
          59,
          59,
        );
        return !dt.isBefore(start) && !dt.isAfter(end);
    }
  }

  /// السجلات المفلترة وفق الأبعاد الخمسة (نوع الحركة، المندوب، الفرع، الصنف، والتاريخ)
  List<FieldReportRecord> get _filteredRecords {
    final normalizedSearch =
        AlRabieCatalog.normalizeArabicSearch(_quickSearchQuery);

    return _allRecords.where((rec) {
      // 1. فلتر نوع الحركة (الكل / جرد / طلبات)
      if (_selectedRecordType != 'all' &&
          _selectedRecordType != 'audit_logs' &&
          rec.recordType != _selectedRecordType) {
        return false;
      }

      // 2. فلتر المندوب
      if (_selectedRepId != 'all' && rec.repId != _selectedRepId) {
        return false;
      }

      // 3. فلتر الفرع / المخزن
      if (_selectedBranchName != 'الكل' &&
          !rec.branchName.contains(_selectedBranchName.replaceAll('فرع ', ''))) {
        return false;
      }

      // 4. فلتر الصنف المحدد من الـ 62 صنفاً
      if (_selectedProduct != null &&
          rec.productCode != _selectedProduct!.code) {
        return false;
      }

      // 5. فلتر الفترة الزمنية
      if (!_matchesDateFilter(rec.timestamp)) {
        return false;
      }

      // 6. البحث النصي السريع (باسم الصنف، الكود، المندوب، العميل، أو الفرع)
      if (normalizedSearch.isNotEmpty) {
        final hay = AlRabieCatalog.normalizeArabicSearch(
          '${rec.productName} ${rec.productCode} ${rec.repName} ${rec.repUsername} ${rec.branchName} ${rec.customerName}',
        );
        if (!hay.contains(normalizedSearch)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _selectedRecordType != 'all' ||
      _selectedRepId != 'all' ||
      _selectedBranchName != 'الكل' ||
      _selectedProduct != null ||
      _selectedDatePreset != ReportDatePreset.all ||
      _quickSearchQuery.trim().isNotEmpty;

  void _resetAllFilters() {
    setState(() {
      _selectedRecordType = 'all';
      _selectedRepId = 'all';
      _selectedBranchName = 'الكل';
      _selectedProduct = null;
      _selectedDatePreset = ReportDatePreset.all;
      _customDateRange = null;
      _quickSearchQuery = '';
      _quickSearchController.clear();
    });
  }

  /// اختيار فترة زمنية مخصصة (من تاريخ - إلى تاريخ)
  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      helpText: 'حدد الفترة الزمنية للتقرير (من تاريخ - إلى تاريخ)',
      saveText: 'اعتماد الفترة',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDatePreset = ReportDatePreset.custom;
      });
    }
  }

  /// نافذة البحث والاختيار السريع لصنف محدد من أصناف الربيع الـ 62
  Future<void> _openProductFilterPicker() async {
    String modalSearch = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final normalized =
                AlRabieCatalog.normalizeArabicSearch(modalSearch);
            final matchedItems = AlRabieCatalog.items.where((p) {
              if (normalized.isEmpty) return true;
              return AlRabieCatalog.normalizeArabicSearch(p.name)
                      .contains(normalized) ||
                  p.code.toLowerCase().contains(normalized) ||
                  AlRabieCatalog.normalizeArabicSearch(p.category)
                      .contains(normalized);
            }).toList();

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  right: 16,
                  left: 16,
                  top: 14,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_rounded,
                          color: AppConstants.deepNavyBlue,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'فلترة التقرير حسب الصنف (62 صنفاً)',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppConstants.deepNavyBlue,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedProduct = null);
                            Navigator.of(sheetCtx).pop();
                          },
                          child: const Text('عرض الكل (62)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      onChanged: (val) =>
                          setModalState(() => modalSearch = val),
                      decoration: InputDecoration(
                        hintText:
                            'ابحث باسم الصنف أو الكود (43002001 أو JLP-3001)...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppConstants.cleanLightGrey,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: matchedItems.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = matchedItems[index];
                            final isSelected =
                                _selectedProduct?.code == item.code;
                            return ListTile(
                              dense: true,
                              tileColor: isSelected
                                  ? AppConstants.softRoyalGold
                                  : null,
                              leading: AlRabieProductThumbnail(
                                imageAsset: item.imageAsset,
                                category: item.category,
                                size: 40,
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppConstants.deepNavyBlue,
                                ),
                              ),
                              subtitle: Text(
                                'رقم الصنف: ${item.code} • ${item.category}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppConstants.deepNavyBlue,
                                    )
                                  : null,
                              onTap: () {
                                setState(() => _selectedProduct = item);
                                Navigator.of(sheetCtx).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  /// تصدير ومشاركة التقرير المفلتر بصيغة CSV وجدول ملخص جاهز للمشاركة
  Future<void> _exportOrShareFilteredReport(
    List<FieldReportRecord> records,
    int totalCartons,
    int uniqueItemsCount,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'تقرير نظام جلب الميداني - أصناف الربيع (${_formatDateTime(DateTime.now())})',
    );
    buffer.writeln(
      'إجمالي الكراتين: $totalCartons كرتون | عدد العمليات: ${records.length} | الأصناف المشمولة: $uniqueItemsCount صنفاً',
    );
    buffer.writeln(
      '-------------------------------------------------------------------------',
    );
    buffer.writeln(
      'التاريخ والوقت,نوع الحركة,المندوب,الفرع / المخزن,العميل,رقم الصنف (SKU),اسم الصنف,الكمية (كرتون),الحالة',
    );

    for (final r in records) {
      buffer.writeln(
        '${_formatDateTime(r.timestamp)},${r.recordTypeArabic},${r.repName},${r.branchName},${r.customerName},${r.productCode},${r.productName},${r.cartonQty},${r.status}',
      );
    }

    final csvText = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csvText));
    await AuditLogService.instance.logAction(
      userId: 'admin_master',
      userName: 'مشرف النظام',
      userRole: 'admin',
      branchName: _selectedBranchName,
      actionType: 'export_report',
      targetEntity: 'CSV Report (${records.length} rows)',
      details:
          'تصدير تقرير إداري شامل (${records.length} حركة • $totalCartons كرتون)',
    );

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.softRoyalGold,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppConstants.royalGold),
                      ),
                      child: const Icon(
                        Icons.ios_share_rounded,
                        color: AppConstants.deepNavyBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تم تجهيز ونسخ التقرير الشامل (CSV / نصي)',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppConstants.deepNavyBlue,
                            ),
                          ),
                          Text(
                            'تم نسخ التقرير للحافظة تلقائياً، ويمكنك لصقه في Excel أو WhatsApp',
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
                const SizedBox(height: 14),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.cleanLightGrey,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csvText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        fontFamily: 'monospace',
                        color: AppConstants.deepNavyBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: csvText));
                      Navigator.of(sheetCtx).pop();
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green.shade800,
                            content: const Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                'تم نسخ التقرير الكامل (CSV) إلى الحافظة بنجاح',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppConstants.deepNavyBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.copy_all_rounded,
                      color: AppConstants.royalGold,
                    ),
                    label: const Text(
                      'نسخ التقرير وإغلاق النافذة',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    final int totalCartons =
        filtered.fold<int>(0, (sum, r) => sum + r.cartonQty);
    final int totalTransactions = filtered.length;
    final int uniqueItemsCount =
        filtered.map((r) => r.productCode).toSet().length;

    final List<String> allBranchNames = <String>[
      'الكل',
      ..._branchesMap.values,
    ];

    return Scaffold(
      backgroundColor: AppConstants.cleanLightGrey,
      appBar: AppBar(
        title: const Text(
          'تقارير الجرد والمبيعات الشاملة',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17.5),
        ),
        backgroundColor: AppConstants.deepNavyBlue,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => _exportOrShareFilteredReport(
              filtered,
              totalCartons,
              uniqueItemsCount,
            ),
            icon: const Icon(
              Icons.ios_share_rounded,
              size: 18,
              color: AppConstants.royalGold,
            ),
            label: const Text(
              'تصدير / مشاركة',
              style: TextStyle(
                color: AppConstants.royalGold,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'تحديث البيانات من Supabase',
            onPressed: _loadReportsDataFromSupabase,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // =============================================================
                // 1. مؤشرات الأداء التنفيذية الديناميكية (Executive Summary KPIs)
                // =============================================================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ReportKpiCard(
                              title: 'إجمالي الكراتين',
                              value: '$totalCartons',
                              unit: 'كرتون',
                              icon: Icons.all_inbox_rounded,
                              isPrimaryNavy: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ReportKpiCard(
                              title: 'عدد العمليات',
                              value: '$totalTransactions',
                              unit: 'حركة',
                              icon: Icons.receipt_long_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ReportKpiCard(
                              title: 'الأصناف المشمولة',
                              value: '$uniqueItemsCount / 62',
                              unit: 'صنف',
                              icon: Icons.category_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // =======================================================
                      // 2. فلتر نوع الحركة + سجل التدقيق الرقابي (audit_logs)
                      // =======================================================
                      Row(
                        children: [
                          _RecordTypeTabChip(
                            label: 'الكل (${_allRecords.length})',
                            isSelected: _selectedRecordType == 'all',
                            icon: Icons.layers_rounded,
                            onTap: () =>
                                setState(() => _selectedRecordType = 'all'),
                          ),
                          const SizedBox(width: 5),
                          _RecordTypeTabChip(
                            label: 'الجرد',
                            isSelected: _selectedRecordType == 'audit',
                            icon: Icons.fact_check_rounded,
                            onTap: () =>
                                setState(() => _selectedRecordType = 'audit'),
                          ),
                          const SizedBox(width: 5),
                          _RecordTypeTabChip(
                            label: 'الطلبات',
                            isSelected: _selectedRecordType == 'order',
                            icon: Icons.local_shipping_rounded,
                            onTap: () =>
                                setState(() => _selectedRecordType = 'order'),
                          ),
                          const SizedBox(width: 5),
                          _RecordTypeTabChip(
                            label: 'سجل التدقيق (${_auditLogs.length})',
                            isSelected: _selectedRecordType == 'audit_logs',
                            icon: Icons.policy_rounded,
                            onTap: () => setState(
                              () => _selectedRecordType = 'audit_logs',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // =======================================================
                      // 3. فلتر المندوب + فلتر الفرع / المخزن
                      // =======================================================
                      Row(
                        children: [
                          // فلتر المندوب
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.cleanLightGrey,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedRepId != 'all'
                                      ? AppConstants.royalGold
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRepId,
                                  isExpanded: true,
                                  isDense: true,
                                  icon: const Icon(
                                    Icons.person_search_rounded,
                                    size: 18,
                                    color: AppConstants.deepNavyBlue,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.deepNavyBlue,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: 'all',
                                      child: Text(
                                        'المندوب: الكل',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ..._salesReps.map((rep) {
                                      return DropdownMenuItem<String>(
                                        value: rep.id,
                                        child: Text(
                                          '${rep.fullName} (${rep.username})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedRepId = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // فلتر الفرع / المخزن
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.cleanLightGrey,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedBranchName != 'الكل'
                                      ? AppConstants.royalGold
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: allBranchNames
                                          .contains(_selectedBranchName)
                                      ? _selectedBranchName
                                      : 'الكل',
                                  isExpanded: true,
                                  isDense: true,
                                  icon: const Icon(
                                    Icons.warehouse_rounded,
                                    size: 17,
                                    color: AppConstants.deepNavyBlue,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppConstants.deepNavyBlue,
                                  ),
                                  items: allBranchNames.map((branch) {
                                    return DropdownMenuItem<String>(
                                      value: branch,
                                      child: Text(
                                        branch == 'الكل'
                                            ? 'الفرع / المخزن: الكل'
                                            : branch,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(
                                        () => _selectedBranchName = val,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // =======================================================
                      // 4. فلتر الصنف (62 صنفاً) + البحث النصي المباشر
                      // =======================================================
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: InkWell(
                              onTap: _openProductFilterPicker,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedProduct != null
                                      ? AppConstants.softRoyalGold
                                      : AppConstants.cleanLightGrey,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedProduct != null
                                        ? AppConstants.royalGold
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 16,
                                      color: AppConstants.deepNavyBlue,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _selectedProduct == null
                                            ? 'الصنف: جميع الأصناف (62)'
                                            : '[${_selectedProduct!.code}] ${_selectedProduct!.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppConstants.deepNavyBlue,
                                        ),
                                      ),
                                    ),
                                    if (_selectedProduct != null)
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _selectedProduct = null,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 18,
                                        color: AppConstants.deepNavyBlue,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: _quickSearchController,
                              onChanged: (val) =>
                                  setState(() => _quickSearchQuery = val),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'بحث سريع بالكود أو العميل...',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 17,
                                ),
                                suffixIcon: _quickSearchQuery.isNotEmpty
                                    ? IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.clear_rounded,
                                          size: 15,
                                        ),
                                        onPressed: () {
                                          _quickSearchController.clear();
                                          setState(
                                            () => _quickSearchQuery = '',
                                          );
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppConstants.cleanLightGrey,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // =======================================================
                      // 5. فلتر التاريخ (الكل / اليوم / هذا الأسبوع / هذا الشهر / فترة مخصصة)
                      // =======================================================
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _DatePresetChip(
                              label: 'كل التواريخ',
                              isSelected:
                                  _selectedDatePreset == ReportDatePreset.all,
                              onTap: () => setState(
                                () =>
                                    _selectedDatePreset = ReportDatePreset.all,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _DatePresetChip(
                              label: 'اليوم',
                              isSelected:
                                  _selectedDatePreset == ReportDatePreset.today,
                              onTap: () => setState(
                                () => _selectedDatePreset =
                                    ReportDatePreset.today,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _DatePresetChip(
                              label: 'هذا الأسبوع',
                              isSelected: _selectedDatePreset ==
                                  ReportDatePreset.thisWeek,
                              onTap: () => setState(
                                () => _selectedDatePreset =
                                    ReportDatePreset.thisWeek,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _DatePresetChip(
                              label: 'هذا الشهر',
                              isSelected: _selectedDatePreset ==
                                  ReportDatePreset.thisMonth,
                              onTap: () => setState(
                                () => _selectedDatePreset =
                                    ReportDatePreset.thisMonth,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _DatePresetChip(
                              label: _selectedDatePreset ==
                                          ReportDatePreset.custom &&
                                      _customDateRange != null
                                  ? '${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}'
                                  : 'فترة مخصصة 📅',
                              isSelected: _selectedDatePreset ==
                                  ReportDatePreset.custom,
                              onTap: _pickCustomDateRange,
                            ),
                            if (_hasActiveFilters) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _resetAllFilters,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                ),
                                icon: Icon(
                                  Icons.filter_alt_off_rounded,
                                  size: 15,
                                  color: Colors.red.shade700,
                                ),
                                label: Text(
                                  'إعادة ضبط',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // =============================================================
                // 6. قائمة السجلات والحركات المفلترة أو سجل التدقيق الرقابي (audit_logs)
                // =============================================================
                Expanded(
                  child: _selectedRecordType == 'audit_logs'
                      ? _buildAuditTrailLogsView()
                      : (filtered.isEmpty
                          ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  size: 52,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'لا توجد سجلات مطابقة للفلاتر المحددة حالياً.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppConstants.deepNavyBlue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_hasActiveFilters)
                                  FilledButton.icon(
                                    onPressed: _resetAllFilters,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      color: AppConstants.royalGold,
                                    ),
                                    label: const Text('إظهار جميع السجلات'),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final record = filtered[index];
                            final isAudit = record.isAudit;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: isAudit
                                      ? Colors.teal.shade200
                                      : AppConstants.royalGold,
                                  width: 1.2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // السطر العلوي: نوع الحركة + التاريخ والوقت + الكمية بالكرتون
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isAudit
                                                ? Colors.teal.shade50
                                                : AppConstants.softRoyalGold,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isAudit
                                                  ? Colors.teal.shade400
                                                  : AppConstants.royalGold,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isAudit
                                                    ? Icons.fact_check_rounded
                                                    : Icons
                                                        .local_shipping_rounded,
                                                size: 13,
                                                color: isAudit
                                                    ? Colors.teal.shade900
                                                    : AppConstants.deepNavyBlue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                record.recordTypeArabic,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  color: isAudit
                                                      ? Colors.teal.shade900
                                                      : AppConstants
                                                          .deepNavyBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _formatDateTime(record.timestamp),
                                            textDirection: TextDirection.ltr,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppConstants.deepNavyBlue,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${record.cartonQty} كرتون',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: AppConstants.royalGold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // السطر الأوسط: صورة الصنف + الكود الرسمي + اسم الصنف
                                    Row(
                                      children: [
                                        AlRabieProductThumbnail(
                                          imageAsset: record.imageAsset,
                                          category: record.category,
                                          size: 48,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants
                                                          .deepNavyBlue,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      record.productCode,
                                                      textDirection:
                                                          TextDirection.ltr,
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppConstants
                                                            .royalGold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      record.category,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.black54,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                record.productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  color:
                                                      AppConstants.deepNavyBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),

                                    // السطر السفلي: اسم المندوب + الفرع/المخزن + اسم العميل
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _InfoMetaBadge(
                                          icon: Icons.badge_outlined,
                                          label: record.repName,
                                        ),
                                        _InfoMetaBadge(
                                          icon: Icons.warehouse_outlined,
                                          label: record.branchName,
                                        ),
                                        _InfoMetaBadge(
                                          icon: Icons.storefront_outlined,
                                          label: record.customerName,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
                ),
              ],
            ),
    );
  }

  /// واجهة عرض سجل التدقيق الرقابي الشامل (`audit_logs`) لجميع العمليات الحساسة
  Widget _buildAuditTrailLogsView() {
    final normalizedSearch =
        AlRabieCatalog.normalizeArabicSearch(_quickSearchQuery);
    final filteredLogs = _auditLogs.where((log) {
      if (_selectedRepId != 'all' && log.userId != _selectedRepId) {
        return false;
      }
      if (_selectedBranchName != 'الكل' &&
          !log.branchName
              .contains(_selectedBranchName.replaceAll('فرع ', ''))) {
        return false;
      }
      if (!_matchesDateFilter(log.createdAt)) {
        return false;
      }
      if (normalizedSearch.isNotEmpty) {
        final hay = AlRabieCatalog.normalizeArabicSearch(
          '${log.userName} ${log.userId} ${log.actionArabicLabel} ${log.targetEntity} ${log.details} ${log.branchName}',
        );
        if (!hay.contains(normalizedSearch)) return false;
      }
      return true;
    }).toList();

    if (filteredLogs.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد سجلات تدقيق مطابقة للفلاتر الحالية.',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppConstants.deepNavyBlue,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        final isOrder = log.actionType == 'create_order';
        final isAudit = log.actionType == 'submit_inventory_audit';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isOrder
                  ? AppConstants.royalGold
                  : (isAudit ? Colors.teal.shade300 : Colors.indigo.shade200),
              width: 1.2,
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
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.deepNavyBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            size: 13,
                            color: AppConstants.royalGold,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            log.actionArabicLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppConstants.royalGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatDateTime(log.createdAt),
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  log.details,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppConstants.deepNavyBlue,
                  ),
                ),
                if (log.targetEntity.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'المرجع / الكيان: ${log.targetEntity}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Divider(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoMetaBadge(
                      icon: Icons.person_outline_rounded,
                      label: '${log.userName} (${log.userRole})',
                    ),
                    _InfoMetaBadge(
                      icon: Icons.warehouse_outlined,
                      label: log.branchName,
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
}

class _ReportKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final bool isPrimaryNavy;

  const _ReportKpiCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.isPrimaryNavy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimaryNavy ? AppConstants.deepNavyBlue : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimaryNavy ? AppConstants.royalGold : Colors.grey.shade300,
          width: isPrimaryNavy ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isPrimaryNavy
                    ? AppConstants.royalGold
                    : AppConstants.deepNavyBlue,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isPrimaryNavy ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isPrimaryNavy
                        ? AppConstants.royalGold
                        : AppConstants.deepNavyBlue,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isPrimaryNavy ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordTypeTabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _RecordTypeTabChip({
    required this.label,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.deepNavyBlue
                : AppConstants.cleanLightGrey,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppConstants.royalGold : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppConstants.royalGold
                    : AppConstants.deepNavyBlue,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppConstants.deepNavyBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DatePresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      selectedColor: AppConstants.softRoyalGold,
      backgroundColor: AppConstants.cleanLightGrey,
      side: BorderSide(
        color: isSelected ? AppConstants.royalGold : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        fontSize: 11.5,
        color: AppConstants.deepNavyBlue,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _InfoMetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoMetaBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.cleanLightGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppConstants.deepNavyBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppConstants.deepNavyBlue,
            ),
          ),
        ],
      ),
    );
  }
}
