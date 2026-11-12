import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';

/// نموذج بيانات العميل المرتبط بجدول `customers` و `channels` و `branches`
class FieldCustomerModel {
  final String id;
  final String storeName;
  final String branchName;
  final String region;
  final String phone;
  final String channel;
  final double latitude;
  final double longitude;
  final bool isActive;

  const FieldCustomerModel({
    required this.id,
    required this.storeName,
    required this.branchName,
    required this.region,
    required this.phone,
    required this.channel,
    this.latitude = 15.3694,
    this.longitude = 44.1910,
    this.isActive = true,
  });

  factory FieldCustomerModel.fromJson(Map<String, dynamic> json, int index) {
    return FieldCustomerModel(
      id: json['id']?.toString() ?? 'CUST-${100 + index}',
      storeName: (json['name'] ?? json['store_name'] ?? 'عميل جلب ${index + 1}')
          .toString(),
      branchName:
          (json['branch_name'] ?? json['branch'] ?? 'الفرع الرئيسي - صنعاء')
              .toString(),
      region: (json['region'] ?? json['address'] ?? 'صنعاء - شارع حدة')
          .toString(),
      phone: (json['phone'] ?? json['mobile'] ?? '771234567').toString(),
      channel: (json['channel'] ?? json['channel_name'] ?? 'سوبرماركت وتجزئة')
          .toString(),
      latitude: _toDouble(json['latitude'] ?? json['lat'], 15.3694),
      longitude: _toDouble(json['longitude'] ?? json['lng'], 44.1910),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': storeName,
      'branch_name': branchName,
      'region': region,
      'phone': phone,
      'channel': channel,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    };
  }

  static double _toDouble(dynamic val, double fallback) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }
}

/// شاشة دليل العملاء والفروع وقنوات التوزيع (`customers`, `channels`, `branches`)
/// تدعم التخزين المحلي (Offline-First) وطابور المزامنة.
class CustomersPage extends StatefulWidget {
  final String? currentBranchId;

  const CustomersPage({
    super.key,
    this.currentBranchId,
  });

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineSyncService _offlineSync = OfflineSyncService.instance;

  List<FieldCustomerModel> _customers = [];
  String _selectedChannel = 'الكل';
  String _searchQuery = '';
  bool _isLoading = false;

  /// قنوات البيع المعتمدة في جدول `channels`
  static const List<String> _salesChannels = [
    'الكل',
    'هايبرماركت وأسواق كبرى',
    'تجار جملة وموزعين',
    'سوبرماركت وتجزئة',
    'بقالات وتموينات',
    'الفنادق والمطاعم (HORECA)',
  ];

  /// الفروع الفعلية المعتمدة في جدول `branches`
  static const List<String> _approvedBranches = [
    'الفرع الرئيسي - صنعاء',
    'فرع عدن - المعلا',
    'فرع تعز الميداني',
    'فرع الحديدة التجاري',
    'فرع إب والمنطقة الوسطى',
    'فرع حضرموت - المكلا',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    // 1. استرجاع العملاء من الذاكرة المحلية (Offline Cache)
    final cachedCustomersJson = _offlineSync.getCachedCustomers();
    if (cachedCustomersJson.isNotEmpty) {
      _customers = List<FieldCustomerModel>.generate(
        cachedCustomersJson.length,
        (i) => FieldCustomerModel.fromJson(cachedCustomersJson[i], i),
      );
    } else {
      _customers = _defaultCustomers();
      await _persistCustomersLocally();
    }

    // 2. محاولة المزامنة مع Supabase في حال توفر اتصال
    if (AppConstants.isSupabaseConfigured) {
      try {
        final rows = await Supabase.instance.client
            .from(AppConstants.tableCustomers)
            .select()
            .limit(40);

        if (rows.isNotEmpty) {
          final fetched = <FieldCustomerModel>[];
          for (int i = 0; i < rows.length; i++) {
            fetched.add(FieldCustomerModel.fromJson(rows[i], i));
          }
          if (fetched.isNotEmpty) {
            _customers = fetched;
            await _persistCustomersLocally();
          }
        }
      } catch (error) {
        debugPrint('Customers offline cache active: $error');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _persistCustomersLocally() async {
    await _offlineSync.cacheCustomers(
      _customers.map((c) => c.toJson()).toList(),
    );
  }

  /// بيانات العملاء التجريبية المطابقة للفروع وقنوات البيع الفعلية في `channels` و `customers`
  List<FieldCustomerModel> _defaultCustomers() {
    return const [
      FieldCustomerModel(
        id: 'CUST-101',
        storeName: 'هائل سعيد أنعم وشركاه - المركز التجاري',
        branchName: 'الفرع الرئيسي - صنعاء',
        region: 'صنعاء - شارع الستين الجنوبي',
        phone: '777441122',
        channel: 'هايبرماركت وأسواق كبرى',
        latitude: 15.3324,
        longitude: 44.1782,
      ),
      FieldCustomerModel(
        id: 'CUST-102',
        storeName: 'سوبرماركت الجند الحديث - فرع حدة',
        branchName: 'الفرع الرئيسي - صنعاء',
        region: 'صنعاء - شارع حدة الرئيسي',
        phone: '771889977',
        channel: 'سوبرماركت وتجزئة',
        latitude: 15.3241,
        longitude: 44.1912,
      ),
      FieldCustomerModel(
        id: 'CUST-103',
        storeName: 'مؤسسة الخير لتجارة الجملة والتوريدات',
        branchName: 'فرع الحديدة التجاري',
        region: 'الحديدة - شارع صنعاء التجاري',
        phone: '733112233',
        channel: 'تجار جملة وموزعين',
        latitude: 14.7979,
        longitude: 42.9540,
      ),
      FieldCustomerModel(
        id: 'CUST-104',
        storeName: 'بقالة وتموينات السعيدة',
        branchName: 'فرع تعز الميداني',
        region: 'تعز - شارع جمال عبدالناصر',
        phone: '711778899',
        channel: 'بقالات وتموينات',
        latitude: 13.5776,
        longitude: 44.0178,
      ),
      FieldCustomerModel(
        id: 'CUST-105',
        storeName: 'هايبر شملان ستار - المركز الرئيسي',
        branchName: 'فرع عدن - المعلا',
        region: 'عدن - المنصورة شارع التسعين',
        phone: '774332211',
        channel: 'هايبرماركت وأسواق كبرى',
        latitude: 12.8492,
        longitude: 44.9765,
      ),
      FieldCustomerModel(
        id: 'CUST-106',
        storeName: 'مجموعة مطاعم وفنادق التاج الملكي',
        branchName: 'فرع حضرموت - المكلا',
        region: 'المكلا - خور المكلا السياحي',
        phone: '779998877',
        channel: 'الفنادق والمطاعم (HORECA)',
        latitude: 14.5404,
        longitude: 49.1272,
      ),
    ];
  }

  List<FieldCustomerModel> get _filteredCustomers {
    return _customers.where((customer) {
      final matchesChannel = _selectedChannel == 'الكل' ||
          customer.channel == _selectedChannel;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          customer.storeName.toLowerCase().contains(q) ||
          customer.branchName.toLowerCase().contains(q) ||
          customer.region.toLowerCase().contains(q) ||
          customer.phone.contains(q);
      return matchesChannel && matchesSearch;
    }).toList();
  }

  /// الاتصال السريع بالعميل عبر الهاتف
  Future<void> _callCustomer(FieldCustomerModel customer) async {
    final uri = Uri(scheme: 'tel', path: customer.phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        _showInfoSnackBar(
          'جاري الاتصال بـ ${customer.storeName} على الرقم: ${customer.phone}',
          icon: Icons.phone_in_talk_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        _showInfoSnackBar(
          'رقم الاتصال بـ "${customer.storeName}": ${customer.phone}',
          icon: Icons.phone_in_talk_rounded,
        );
      }
    }
  }

  /// فتح الموقع الجغرافي للعميل على الخرائط (Google Maps)
  Future<void> _openCustomerLocation(FieldCustomerModel customer) async {
    final mapUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${customer.latitude},${customer.longitude}',
    );
    try {
      final launched = await launchUrl(
        mapUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showInfoSnackBar(
          'الموقع الجغرافي لـ "${customer.storeName}": ${customer.region}',
          icon: Icons.map_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        _showInfoSnackBar(
          'الموقع الجغرافي لـ "${customer.storeName}": ${customer.region}',
          icon: Icons.map_rounded,
        );
      }
    }
  }

  void _showInfoSnackBar(
    String message, {
    required IconData icon,
  }) {
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
                Icon(icon, color: AppConstants.royalGold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  /// فتح نموذج إضافة عميل ميداني جديد مع حفظ محلي فوري وإضافة لطابور المزامنة
  Future<void> _openAddCustomerSheet() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final regionCtrl = TextEditingController(text: 'صنعاء - شارع حدة');
    final phoneCtrl = TextEditingController();
    String selectedBranch = _approvedBranches.first;
    String selectedChannel = _salesChannels[3]; // سوبرماركت وتجزئة
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

            Future<void> saveNewCustomer() async {
              if (!formKey.currentState!.validate()) return;

              setSheetState(() => isSaving = true);

              final newCustomer = FieldCustomerModel(
                id: 'CUST-${DateTime.now().millisecondsSinceEpoch}',
                storeName: nameCtrl.text.trim(),
                branchName: selectedBranch,
                region: regionCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                channel: selectedChannel,
              );

              setState(() {
                _customers.insert(0, newCustomer);
              });

              await _persistCustomersLocally();
              final syncedOnline = await _offlineSync.enqueueOrSyncOperation(
                table: AppConstants.tableCustomers,
                action: 'insert',
                payload: newCustomer.toJson(),
              );

              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }

              if (mounted) {
                _showInfoSnackBar(
                  syncedOnline
                      ? 'تمت إضافة ومزامنة العميل "${newCustomer.storeName}" بنجاح'
                      : 'تم حفظ العميل "${newCustomer.storeName}" محلياً وإضافته لطابور المزامنة',
                  icon: Icons.person_add_alt_1_rounded,
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
                child: Form(
                  key: formKey,
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
                        const Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppConstants.softRoyalGold,
                              foregroundColor: AppConstants.deepNavyBlue,
                              child: Icon(Icons.person_add_alt_1_rounded),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إضافة عميل / منفذ بيع جديد',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'ربط العميل بجدول العملاء (customers) والفرع وقناة البيع (channels)',
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
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'اسم المحل / المنشأة التجارية',
                            hintText: 'مثال: سوبرماركت الجند الحديث',
                            prefixIcon: const Icon(Icons.storefront_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'يرجى إدخال اسم المحل أو العميل'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedBranch,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'الفرع التابع (branches)',
                            prefixIcon: const Icon(
                              Icons.store_mall_directory_outlined,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          items: _approvedBranches.map((branch) {
                            return DropdownMenuItem<String>(
                              value: branch,
                              child: Text(branch),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedBranch = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: regionCtrl,
                          decoration: InputDecoration(
                            labelText: 'المنطقة / الشارع والعنوان الميداني',
                            hintText: 'مثال: صنعاء - شارع حدة',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'يرجى تحديد المنطقة أو العنوان'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف / الجوال للتواصل',
                            hintText: '77XXXXXXX',
                            prefixIcon: const Icon(Icons.phone_iphone_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().length < 7)
                              ? 'يرجى إدخال رقم هاتف صحيح'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedChannel,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'قناة التوزيع والبيع (channels)',
                            prefixIcon: const Icon(Icons.hub_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          items: _salesChannels
                              .where((c) => c != 'الكل')
                              .map((channel) {
                            return DropdownMenuItem<String>(
                              value: channel,
                              child: Text(channel),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedChannel = val);
                            }
                          },
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: isSaving ? null : saveNewCustomer,
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
                              'حفظ واعتماد بيانات العميل',
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredCustomers;

    return Scaffold(
      backgroundColor: AppConstants.cleanLightGrey,
      appBar: AppBar(
        title: const Text(
          'دليل العملاء والفروع وقنوات البيع',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: AppConstants.deepNavyBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث العملاء',
            onPressed: _loadCustomers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_fab',
        onPressed: _openAddCustomerSheet,
        backgroundColor: AppConstants.royalGold,
        foregroundColor: AppConstants.deepNavyBlue,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'إضافة عميل',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // شريط البحث
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم المحل، الفرع، المنطقة، أو الجوال...',
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

                // شريط فلترة قنوات البيع (channels)
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _salesChannels.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final channel = _salesChannels[index];
                      final isSelected = _selectedChannel == channel;
                      return ChoiceChip(
                        label: Text(channel),
                        selected: isSelected,
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
                        onSelected: (_) {
                          setState(() => _selectedChannel = channel);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // قائمة العملاء
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('لا يوجد عملاء مطابقون لمعايير البحث.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final customer = filtered[index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 22,
                                          backgroundColor:
                                              AppConstants.deepNavyBlue,
                                          foregroundColor:
                                              AppConstants.royalGold,
                                          child: Icon(
                                            Icons.storefront_rounded,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                customer.storeName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                  color:
                                                      AppConstants.deepNavyBlue,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants
                                                          .softRoyalGold,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        8,
                                                      ),
                                                      border: Border.all(
                                                        color: AppConstants
                                                            .royalGold,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      customer.channel,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppConstants
                                                            .deepNavyBlue,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants
                                                          .cleanLightGrey,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        8,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      customer.branchName,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            customer.region,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone_outlined,
                                          size: 16,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          customer.phone,
                                          textDirection: TextDirection.ltr,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 22),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.tonalIcon(
                                            onPressed: () =>
                                                _callCustomer(customer),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppConstants.softRoyalGold,
                                              foregroundColor:
                                                  AppConstants.deepNavyBlue,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.call_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'اتصال سريع',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _openCustomerLocation(customer),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppConstants.deepNavyBlue,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.location_searching_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'الموقع الجغرافي',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
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
                        ),
                ),
              ],
            ),
    );
  }
}
