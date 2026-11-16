import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/data/models/user_profile_model.dart';

/// شاشة إدارة المناديب الميدانيين (Sales Reps Management) - مخصصة للمشرف / مدير النظام (Admin Only)
/// مرتبطة مباشرة بجدولي `users_profiles` و `branches` في قاعدة بيانات Supabase.
class SalesRepsManagementPage extends StatefulWidget {
  final VoidCallback? onRepsChanged;

  const SalesRepsManagementPage({
    super.key,
    this.onRepsChanged,
  });

  @override
  State<SalesRepsManagementPage> createState() =>
      SalesRepsManagementPageState();
}

class SalesRepsManagementPageState extends State<SalesRepsManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  List<UserProfileModel> _salesReps = <UserProfileModel>[];
  Map<int, String> _branchesMap =
      Map<int, String>.from(UserProfileModel.officialBranchesById);

  String _searchQuery = '';
  String _statusFilter = 'الكل'; // 'الكل', 'نشط', 'موقوف'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSalesRepsAndBranches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// توليد معرف UUID v4 قياسي متوافق مع عمود `id` في جدول `users_profiles`
  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  /// جلب قائمة الفروع الـ 7 وبيانات جميع المناديب المسجلين في جدول `users_profiles` من Supabase
  Future<void> _loadSalesRepsAndBranches() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      if (AppConstants.isSupabaseConfigured) {
        final supabase = Supabase.instance.client;

        // 1. جلب الفروع الرسمية من جدول branches
        try {
          final List<dynamic> branchRows = await supabase
              .from(AppConstants.tableBranches)
              .select('id, branch_name')
              .order('id', ascending: true);
          if (branchRows.isNotEmpty) {
            final Map<int, String> loadedBranches = <int, String>{};
            for (final row in branchRows) {
              if (row is Map) {
                final id = int.tryParse(row['id']?.toString() ?? '');
                final name = row['branch_name']?.toString().trim() ?? '';
                if (id != null && name.isNotEmpty) {
                  loadedBranches[id] = name;
                }
              }
            }
            if (loadedBranches.isNotEmpty) {
              _branchesMap = loadedBranches;
            }
          }
        } catch (e) {
          debugPrint('Branches fetch info: $e');
        }

        // 2. جلب المناديب المسجلين من جدول users_profiles
        final List<dynamic> rows = await supabase
            .from(AppConstants.tableUsersProfiles)
            .select(
              'id, username, full_name, phone, role, branch_id, is_active, created_at',
            )
            .eq('role', 'sales_rep')
            .order('created_at', ascending: false);

        final List<UserProfileModel> loadedReps = <UserProfileModel>[];
        for (final raw in rows) {
          if (raw is Map<String, dynamic>) {
            final branchNum =
                UserProfileModel.resolveBranchNumber(raw['branch_id']);
            final branchLabel = branchNum != null &&
                    _branchesMap.containsKey(branchNum)
                ? _branchesMap[branchNum]!
                : UserProfileModel.resolveBranchName(
                    raw['branch_id'],
                    role: 'sales_rep',
                  );

            loadedReps.add(
              UserProfileModel.fromJson(raw).copyWith(
                branchId: branchLabel,
                branchNumber: branchNum ?? 1,
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _salesReps = loadedReps;
            _isLoading = false;
          });
        }
        widget.onRepsChanged?.call();
        return;
      }
    } catch (error) {
      debugPrint('Error loading sales reps from Supabase: $error');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// تبديل حالة تفعيل حساب المندوب (نشط / موقوف) ومزامنتها فوراً مع Supabase
  Future<void> _toggleRepActiveStatus(
    UserProfileModel rep,
    bool newStatus,
  ) async {
    final index = _salesReps.indexWhere((r) => r.id == rep.id);
    if (index == -1) return;

    final updated = rep.copyWith(isActive: newStatus);
    setState(() {
      _salesReps[index] = updated;
    });

    try {
      if (AppConstants.isSupabaseConfigured) {
        await Supabase.instance.client
            .from(AppConstants.tableUsersProfiles)
            .update({'is_active': newStatus}).eq('id', rep.id);
      }
      widget.onRepsChanged?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                newStatus ? Colors.green.shade800 : Colors.orange.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                newStatus
                    ? 'تم تفعيل حساب المندوب "${rep.fullName}" بنجاح'
                    : 'تم إيقاف حساب المندوب "${rep.fullName}" مؤقتاً',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
    } catch (error) {
      // التراجع في حال فشل الاتصال
      if (mounted) {
        setState(() {
          _salesReps[index] = rep;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade700,
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Text('تعذر تحديث حالة المندوب: $error'),
              ),
            ),
          );
      }
    }
  }

  /// فتح نافذة إضافة مندوب جديد أو تعديل بيانات وفرع مندوب حالي
  Future<void> openAddOrEditRepModal({UserProfileModel? existingRep}) async {
    final bool isEditing = existingRep != null;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final TextEditingController fullNameCtrl = TextEditingController(
      text: existingRep?.fullName ?? '',
    );
    final TextEditingController usernameCtrl = TextEditingController(
      text: existingRep?.username.isNotEmpty == true
          ? existingRep!.username
          : (existingRep?.email ?? ''),
    );
    final TextEditingController phoneCtrl = TextEditingController(
      text: existingRep?.phone ?? '',
    );
    final TextEditingController passwordCtrl = TextEditingController();

    int selectedBranchId = existingRep?.branchNumber ?? 1;
    if (!_branchesMap.containsKey(selectedBranchId)) {
      selectedBranchId = _branchesMap.keys.first;
    }
    bool isActive = existingRep?.isActive ?? true;
    bool isSaving = false;
    bool obscurePass = true;

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

            Future<void> saveSalesRep() async {
              if (!formKey.currentState!.validate()) return;

              setSheetState(() => isSaving = true);

              final fullName = fullNameCtrl.text.trim();
              final username = usernameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final password = passwordCtrl.text;
              final branchName =
                  _branchesMap[selectedBranchId] ?? 'فرع صنعاء';

              try {
                final supabase = Supabase.instance.client;

                if (isEditing) {
                  await supabase
                      .from(AppConstants.tableUsersProfiles)
                      .update({
                    'full_name': fullName,
                    'username': username,
                    'phone': phone,
                    'branch_id': selectedBranchId,
                    'is_active': isActive,
                  }).eq('id', existingRep.id);

                  if (password.isNotEmpty) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'jalap_rep_pwd_${username.toLowerCase()}',
                      password,
                    );
                  }
                } else {
                  final String newRepId = _generateUuidV4();

                  // حفظ كلمة المرور المخصصة للمندوب الجديد
                  if (password.isNotEmpty) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'jalap_rep_pwd_${username.toLowerCase()}',
                      password,
                    );
                  }

                  // إدراج المندوب مباشرة في جدول users_profiles في Supabase
                  await supabase
                      .from(AppConstants.tableUsersProfiles)
                      .insert({
                    'id': newRepId,
                    'username': username,
                    'full_name': fullName,
                    'phone': phone,
                    'role': 'sales_rep',
                    'branch_id': selectedBranchId,
                    'is_active': isActive,
                  });
                }

                await _loadSalesRepsAndBranches();

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
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: AppConstants.royalGold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isEditing
                                      ? 'تم تحديث بيانات المندوب "$fullName" ($branchName) بنجاح'
                                      : 'تمت إضافة المندوب "$fullName" ($branchName) وتفعيله على Supabase بنجاح',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                }
              } catch (error) {
                setSheetState(() => isSaving = false);
                if (mounted) {
                  ScaffoldMessenger.of(this.context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red.shade700,
                        content: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            'تعذر حفظ بيانات المندوب: $error',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                }
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
                  child: Form(
                    key: formKey,
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
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.softRoyalGold,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppConstants.royalGold,
                                ),
                              ),
                              child: Icon(
                                isEditing
                                    ? Icons.manage_accounts_rounded
                                    : Icons.person_add_alt_1_rounded,
                                color: AppConstants.deepNavyBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing
                                        ? 'تعديل بيانات المندوب الميداني'
                                        : 'إضافة مندوب مبيعات جديد',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: AppConstants.deepNavyBlue,
                                    ),
                                  ),
                                  const Text(
                                    'مرتبط مباشرة بجدول (users_profiles) والفروع السبعة في Supabase',
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
                          controller: fullNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'الاسم الكامل للمندوب',
                            hintText: 'مثال: أحمد محمد صالح - مندوب مبيعات',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال الاسم الكامل للمندوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: usernameCtrl,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText:
                                'اسم المستخدم أو البريد الإلكتروني للدخول',
                            hintText: 'مثال: rep_ibb أو rep.ibb@jalap.com',
                            prefixIcon:
                                const Icon(Icons.alternate_email_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال اسم المستخدم أو البريد الإلكتروني';
                            }
                            if (val.trim().length < 3) {
                              return 'يجب أن يتكون المعرف من 3 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: obscurePass,
                          decoration: InputDecoration(
                            labelText: isEditing
                                ? 'كلمة مرور جديدة (اختياري)'
                                : 'كلمة المرور لحساب المندوب',
                            hintText: '6 أحرف أو أرقام على الأقل',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setSheetState(() => obscurePass = !obscurePass);
                              },
                              icon: Icon(
                                obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (val) {
                            if (!isEditing &&
                                (val == null || val.trim().length < 6)) {
                              return 'يرجى تعيين كلمة مرور من 6 خانات على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف / الجوال',
                            hintText: '77XXXXXXX',
                            prefixIcon: const Icon(Icons.phone_iphone_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال رقم هاتف المندوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: selectedBranchId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'الفرع المخصص للمندوب (branches)',
                            prefixIcon: const Icon(Icons.storefront_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: _branchesMap.entries.map((entry) {
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedBranchId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppConstants.cleanLightGrey,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'حالة الحساب (نشط ومخول بالدخول)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: Text(
                              isActive
                                  ? 'المندوب مفعل ويمكنه إرسال الجرد والطلبات'
                                  : 'الحساب موقوف مؤقتاً من الدخول للنظام',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            activeColor: AppConstants.deepNavyBlue,
                            value: isActive,
                            onChanged: (val) {
                              setSheetState(() => isActive = val);
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: isSaving ? null : saveSalesRep,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppConstants.deepNavyBlue,
                              foregroundColor: Colors.white,
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
                                    Icons.check_circle_rounded,
                                    color: AppConstants.royalGold,
                                  ),
                            label: Text(
                              isEditing
                                  ? 'حفظ تعديلات المندوب'
                                  : 'حفظ وإضافة المندوب الآن',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
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

  List<UserProfileModel> get _filteredReps {
    final query = _searchQuery.trim().toLowerCase();
    return _salesReps.where((rep) {
      final matchesStatus = _statusFilter == 'الكل' ||
          (_statusFilter == 'نشط' && rep.isActive) ||
          (_statusFilter == 'موقوف' && !rep.isActive);
      final matchesQuery = query.isEmpty ||
          rep.fullName.toLowerCase().contains(query) ||
          rep.username.toLowerCase().contains(query) ||
          rep.phone.toLowerCase().contains(query) ||
          (rep.branchId ?? '').toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final int totalReps = _salesReps.length;
    final int activeReps = _salesReps.where((r) => r.isActive).length;
    final int inactiveReps = totalReps - activeReps;
    final filtered = _filteredReps;

    return Scaffold(
      backgroundColor: AppConstants.cleanLightGrey,
      appBar: AppBar(
        title: const Text(
          'إدارة المناديب وصلاحيات الفروع',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: AppConstants.deepNavyBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث قائمة المناديب',
            onPressed: _loadSalesRepsAndBranches,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sales_reps_fab',
        onPressed: () => openAddOrEditRepModal(),
        backgroundColor: AppConstants.royalGold,
        foregroundColor: AppConstants.deepNavyBlue,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'إضافة مندوب جديد',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // =============================================================
                // 1. بطاقة ملخص المناديب الملكية (إجمالي / نشط / موقوف)
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
                      border: Border.all(
                        color: AppConstants.royalGold,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.royalGold,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.supervisor_account_rounded,
                            color: AppConstants.deepNavyBlue,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'فريق المبيعات الميداني (Supabase)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'إجمالي المناديب: $totalReps • نشط: $activeReps • موقوف: $inactiveReps',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => openAddOrEditRepModal(),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppConstants.royalGold,
                            foregroundColor: AppConstants.deepNavyBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'جديد',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =============================================================
                // 2. شريط البحث والفلترة حسب حالة الحساب
                // =============================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText:
                                'ابحث باسم المندوب أو المعرف أو الفرع أو الهاتف...',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final status in ['الكل', 'نشط', 'موقوف'])
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(
                              status == 'الكل'
                                  ? 'الكل ($totalReps)'
                                  : (status == 'نشط'
                                      ? 'نشط ($activeReps)'
                                      : 'موقوف ($inactiveReps)'),
                            ),
                            selected: _statusFilter == status,
                            selectedColor: AppConstants.softRoyalGold,
                            onSelected: (_) =>
                                setState(() => _statusFilter = status),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: AppConstants.deepNavyBlue,
                              fontWeight: _statusFilter == status
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // =============================================================
                // 3. قائمة المناديب المسجلين في Supabase
                // =============================================================
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 48,
                                color: Colors.black38,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'لا يوجد مناديب مطابقون للبحث الحالي.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => openAddOrEditRepModal(),
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: AppConstants.royalGold,
                                ),
                                label: const Text('إضافة مندوب جديد'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final rep = filtered[index];
                            final bool isActive = rep.isActive;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: isActive
                                      ? AppConstants.royalGold
                                      : Colors.grey.shade300,
                                  width: isActive ? 1.4 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 23,
                                          backgroundColor: isActive
                                              ? AppConstants.deepNavyBlue
                                              : Colors.grey.shade400,
                                          child: Icon(
                                            Icons.badge_rounded,
                                            color: isActive
                                                ? AppConstants.royalGold
                                                : Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                rep.fullName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                  color:
                                                      AppConstants.deepNavyBlue,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .alternate_email_rounded,
                                                    size: 13,
                                                    color: Colors.black54,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      rep.username.isNotEmpty
                                                          ? rep.username
                                                          : rep.email,
                                                      textDirection:
                                                          TextDirection.ltr,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Switch.adaptive(
                                              value: isActive,
                                              activeColor:
                                                  AppConstants.deepNavyBlue,
                                              onChanged: (val) =>
                                                  _toggleRepActiveStatus(
                                                rep,
                                                val,
                                              ),
                                            ),
                                            Text(
                                              isActive ? 'نشط' : 'موقوف',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isActive
                                                    ? Colors.green.shade800
                                                    : Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppConstants.softRoyalGold,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppConstants.royalGold,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.storefront_rounded,
                                                size: 14,
                                                color:
                                                    AppConstants.deepNavyBlue,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                rep.branchId ?? 'فرع صنعاء',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      AppConstants.deepNavyBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        if (rep.phone.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  AppConstants.cleanLightGrey,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.phone_iphone_rounded,
                                                  size: 14,
                                                  color: Colors.black54,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  rep.phone,
                                                  textDirection:
                                                      TextDirection.ltr,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: () =>
                                              openAddOrEditRepModal(
                                            existingRep: rep,
                                          ),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'تعديل',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
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
