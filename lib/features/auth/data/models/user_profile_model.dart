/// نموذج بيانات ملف المستخدم المرتبط بجدول `users_profiles` في قاعدة بيانات Supabase.
class UserProfileModel {
  /// المعرف الفريد للمستخدم (UUID)
  final String id;

  /// البريد الإلكتروني أو اسم المستخدم للدخول (`username` / `email`)
  final String email;

  /// اسم المستخدم المسجل في جدول `users_profiles`
  final String username;

  /// الاسم الكامل للمستخدم أو المندوب
  final String fullName;

  /// رقم الهاتف المسجل في جدول `users_profiles`
  final String phone;

  /// الدور الوظيفي والصلاحية ('admin' أو 'sales_rep')
  final String role;

  /// اسم الفرع المرتبط بالمستخدم للعرض في الواجهات
  final String? branchId;

  /// الرقم المعرف للفرع في جدول `branches` (1..7)
  final int? branchNumber;

  /// حالة تفعيل الحساب
  final bool isActive;

  /// تاريخ إنشاء الحساب
  final DateTime? createdAt;

  const UserProfileModel({
    required this.id,
    required this.email,
    this.username = '',
    required this.fullName,
    this.phone = '',
    required this.role,
    this.branchId,
    this.branchNumber,
    this.isActive = true,
    this.createdAt,
  });

  /// الفروع السبعة الرسمية المعتمدة في جدول `branches` بقاعدة بيانات Supabase
  static const Map<int, String> officialBranchesById = {
    1: 'فرع صنعاء',
    2: 'فرع عدن',
    3: 'فرع تعز',
    4: 'فرع إب',
    5: 'فرع الحديدة',
    6: 'فرع المكلا',
    7: 'فرع ذمار',
  };

  static String? resolveBranchName(dynamic rawBranchId, {String? role}) {
    if (rawBranchId == null) {
      return role == 'admin' ? 'الإدارة العامة - جميع الفروع' : 'فرع صنعاء';
    }
    if (rawBranchId is int) {
      return officialBranchesById[rawBranchId] ?? 'فرع رقم $rawBranchId';
    }
    final asInt = int.tryParse(rawBranchId.toString().trim());
    if (asInt != null && officialBranchesById.containsKey(asInt)) {
      return officialBranchesById[asInt];
    }
    final str = rawBranchId.toString().trim();
    return str.isEmpty ? 'فرع صنعاء' : str;
  }

  static int? resolveBranchNumber(dynamic rawBranchId) {
    if (rawBranchId == null) return null;
    if (rawBranchId is int) return rawBranchId;
    final asInt = int.tryParse(rawBranchId.toString().trim());
    if (asInt != null) return asInt;
    final str = rawBranchId.toString().trim();
    for (final entry in officialBranchesById.entries) {
      if (str.contains(entry.value) ||
          entry.value.contains(str.replaceAll('فرع ', ''))) {
        return entry.key;
      }
    }
    return 1;
  }

  // ===========================================================================
  // الخصائص المساعدة للصلاحيات والأدوار (Role Helpers)
  // ===========================================================================

  /// هل المستخدم يمتلك صلاحية مشرف / مدير نظام؟
  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  /// هل المستخدم يمتلك صلاحية مندوب مبيعات ميداني؟
  bool get isSales =>
      role.trim().toLowerCase() == 'sales_rep' ||
      role.trim().toLowerCase() == 'sales';

  /// المسمى الوظيفي باللغة العربية للعرض في الواجهات
  String get roleArabicLabel => isAdmin ? 'مشرف نظام' : 'مندوب مبيعات';

  // ===========================================================================
  // دوال التحويل من وإلى JSON (Serialization) مع التعامل الآمن مع القيم الفارغة
  // ===========================================================================

  /// إنشاء كائن [UserProfileModel] من خريطة بيانات JSON قادمة من Supabase
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString() ?? 'sales_rep';
    final rawUsername =
        (json['username'] ?? json['email'])?.toString().trim() ?? '';
    final rawBranch = json['branch_id'] ?? json['branchId'];

    return UserProfileModel(
      id: json['id']?.toString() ?? '',
      email: (json['email'] ?? json['username'])?.toString() ?? '',
      username: rawUsername,
      fullName: (json['full_name'] ?? json['fullName'])?.toString() ?? 'مستخدم',
      phone: json['phone']?.toString() ?? '',
      role: rawRole,
      branchId: resolveBranchName(rawBranch, role: rawRole),
      branchNumber: resolveBranchNumber(rawBranch),
      isActive: _parseBool(
        json['is_active'] ?? json['isActive'],
        defaultValue: true,
      ),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  /// تحويل كائن [UserProfileModel] إلى خريطة بيانات JSON لإرسالها إلى Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username.isNotEmpty ? username : email,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'branch_id': branchNumber,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// إنشاء نسخة معدلة من الكائن الحالي
  UserProfileModel copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    String? phone,
    String? role,
    String? branchId,
    int? branchNumber,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      branchNumber: branchNumber ?? this.branchNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return defaultValue;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
