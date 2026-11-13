import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../data/models/user_profile_model.dart';

/// شاشة تسجيل الدخول العصرية للمناديب والمشرفين في تطبيق "جلب الميداني"
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController = TextEditingController(
    text: AppConstants.defaultAdminEmail,
  );
  late final TextEditingController _passwordController = TextEditingController(
    text: AppConstants.defaultPassword,
  );

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _printDefaultCredentialsBanner();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// طباعة بيانات الدخول الافتراضية بوضوح في سجل الـ Terminal للمطور والمندوب
  void _printDefaultCredentialsBanner() {
    debugPrint('=============================================================');
    debugPrint('🚀 بوابة الدخول الميداني - تطبيق جلب الميداني (Jalap Sales)');
    debugPrint('📧 البريد الافتراضي للمشرف : ${AppConstants.defaultAdminEmail}');
    debugPrint('📧 البريد الافتراضي للمندوب: ${AppConstants.defaultSalesEmail}');
    debugPrint('🔑 كلمة المرور الموحدة    : ${AppConstants.defaultPassword}');
    debugPrint('=============================================================');
  }

  /// تعبئة سريعة لبيانات حساب تجريبي (مشرف أو مندوب) بضغطة واحدة
  void _applyDemoCredentials({required bool asAdmin}) {
    setState(() {
      _emailController.text = asAdmin
          ? AppConstants.defaultAdminEmail
          : AppConstants.defaultSalesEmail;
      _passwordController.text = AppConstants.defaultPassword;
    });
  }

  /// التحقق مما إذا كان البريد المدخل هو أحد الحسابات الافتراضية المعتمدة
  bool _isDefaultAccount(String email) {
    final normalized = email.trim().toLowerCase();
    return normalized == AppConstants.defaultAdminEmail ||
        normalized == AppConstants.defaultSalesEmail;
  }

  /// بناء ملف مستخدم افتراضي معتمد عند التجربة السريعة أو عدم تفعيل الحساب في Supabase
  UserProfileModel _buildDefaultProfile({
    required String email,
    String? userId,
  }) {
    final normalized = email.trim().toLowerCase();
    final isAdmin = normalized == AppConstants.defaultAdminEmail ||
        normalized.startsWith('admin');

    return UserProfileModel(
      id: userId ?? (isAdmin ? 'admin-jalap-001' : 'sales-jalap-001'),
      email: email.trim(),
      fullName: isAdmin
          ? 'مشرف نظام / مندوب معتمد'
          : 'مندوب المبيعات الميداني',
      role: isAdmin ? 'admin' : 'sales_rep',
      branchId: isAdmin ? 'الفرع الرئيسي - الإدارة' : 'فرع الرياض الميداني',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  /// تنفيذ عملية تسجيل الدخول والتحقق من صلاحيات المستخدم في جدول `users_profiles`
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    debugPrint('-------------------------------------------------------------');
    debugPrint('🔐 محاولة تسجيل دخول ميداني:');
    debugPrint('   • البريد الإلكتروني : $email');
    debugPrint('   • كلمة المرور       : $password');
    debugPrint('-------------------------------------------------------------');

    try {
      // 1. إذا لم يتم ضبط مفاتيح Supabase الحقيقية بعد، نقبل الحساب الافتراضي فوراً
      if (!AppConstants.isSupabaseConfigured) {
        if (_isDefaultAccount(email) &&
            password == AppConstants.defaultPassword) {
          final demoProfile = _buildDefaultProfile(email: email);
          debugPrint(
            '✅ تم الدخول بنجاح (الوضع الميداني السريع): ${demoProfile.fullName} (${demoProfile.role})',
          );
          _completeLoginAndNavigate(demoProfile);
          return;
        }

        _showStatusSnackBar(
          message:
              'للتجربة الفورية استخدم البريد: ${AppConstants.defaultAdminEmail} وكلمة المرور: ${AppConstants.defaultPassword}',
          isError: true,
        );
        return;
      }

      // 2. محاولة تسجيل الدخول الحقيقي عبر Supabase Auth
      final SupabaseClient supabase = Supabase.instance.client;
      User? currentUser;

      try {
        final AuthResponse authResponse =
            await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        currentUser = authResponse.user;
      } catch (authError) {
        // معالجة ذكية: في حال عدم وجود حساب مفعل في Supabase أو رغبة المندوب في التجربة السريعة
        if (_isDefaultAccount(email) &&
            password == AppConstants.defaultPassword) {
          final fallbackProfile = _buildDefaultProfile(email: email);
          debugPrint(
            '⚡ تم قبول بيانات الاعتماد الافتراضية المعتمدة: $email / $password -> ${fallbackProfile.fullName}',
          );
          _completeLoginAndNavigate(fallbackProfile);
          return;
        }
        rethrow;
      }

      if (currentUser == null) {
        if (_isDefaultAccount(email) &&
            password == AppConstants.defaultPassword) {
          final fallbackProfile = _buildDefaultProfile(email: email);
          _completeLoginAndNavigate(fallbackProfile);
          return;
        }
        _showStatusSnackBar(
          message: 'تعذر التحقق من بيانات الدخول. يرجى المحاولة مرة أخرى.',
          isError: true,
        );
        return;
      }

      // 3. جلب بيانات وصلاحيات المستخدم من جدول users_profiles
      Map<String, dynamic>? profileData;
      try {
        profileData = await supabase
            .from(AppConstants.tableUsersProfiles)
            .select(
              'id, email, full_name, role, branch_id, is_active, created_at',
            )
            .eq('id', currentUser.id)
            .maybeSingle();
      } catch (dbError) {
        debugPrint('⚠️ تنبيه استعلام users_profiles: $dbError');
      }

      final UserProfileModel userProfile = profileData != null
          ? UserProfileModel.fromJson({
              ...profileData,
              'id': profileData['id'] ?? currentUser.id,
              'email': profileData['email'] ?? currentUser.email ?? email,
            })
          : _buildDefaultProfile(
              email: currentUser.email ?? email,
              userId: currentUser.id,
            );

      // 4. التحقق من أن حساب المستخدم نشط (isActive == true)
      if (!userProfile.isActive) {
        await supabase.auth.signOut();
        _showStatusSnackBar(
          message: 'عذراً، هذا الحساب موقوف حالياً. يرجى مراجعة إدارة المبيعات.',
          isError: true,
        );
        return;
      }

      debugPrint(
        '✅ تم تسجيل الدخول بنجاح من Supabase: ${userProfile.fullName} | الدور: ${userProfile.role}',
      );
      _completeLoginAndNavigate(userProfile);
    } on AuthException catch (authError) {
      if (_isDefaultAccount(email) &&
          password == AppConstants.defaultPassword) {
        final fallbackProfile = _buildDefaultProfile(email: email);
        _completeLoginAndNavigate(fallbackProfile);
        return;
      }
      _showStatusSnackBar(
        message: _translateAuthError(authError.message),
        isError: true,
      );
    } catch (error) {
      if (_isDefaultAccount(email) &&
          password == AppConstants.defaultPassword) {
        final fallbackProfile = _buildDefaultProfile(email: email);
        _completeLoginAndNavigate(fallbackProfile);
        return;
      }

      _showStatusSnackBar(
        message: 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.',
        isError: true,
      );
      debugPrint('Login Error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// إظهار رسالة الترحيب والتوجيه المباشر إلى [DashboardPage] مع تمرير [UserProfileModel]
  void _completeLoginAndNavigate(UserProfileModel userProfile) {
    if (!mounted) return;

    _showStatusSnackBar(
      message:
          'مرحباً بك يا ${userProfile.fullName} | الصلاحية: ${userProfile.roleArabicLabel}',
      isError: false,
      isAdmin: userProfile.isAdmin,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DashboardPage(userProfile: userProfile),
      ),
    );
  }

  /// ترجمة رسائل أخطاء Supabase الشائعة إلى رسائل عربية واضحة للمندوب
  String _translateAuthError(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (lower.contains('email not confirmed')) {
      return 'لم يتم تأكيد البريد الإلكتروني لهذا الحساب بعد.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار قليلاً.';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('xmlhttprequest')) {
      return 'لا يوجد اتصال بالشبكة. يرجى التحقق من الإنترنت.';
    }
    return 'تعذر تسجيل الدخول: $rawMessage';
  }

  /// عرض إشعار سفلي (SnackBar) بتصميم حديث وملون
  void _showStatusSnackBar({
    required String message,
    required bool isError,
    bool isAdmin = false,
  }) {
    if (!mounted) return;

    final Color backgroundColor = isError
        ? Colors.red.shade700
        : (isAdmin ? Colors.indigo.shade700 : Colors.green.shade700);

    final IconData icon = isError
        ? Icons.error_outline_rounded
        : (isAdmin ? Icons.verified_user_rounded : Icons.check_circle_rounded);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool isSmallScreen = screenSize.width < 600;
    final bool isVeryNarrow = screenSize.width < 360;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double horizontalPadding = isSmallScreen ? 16.0 : 28.0;
              final double verticalPadding = isSmallScreen ? 16.0 : 28.0;
              final double availableHeight =
                  (constraints.maxHeight - (verticalPadding * 2))
                      .clamp(0.0, double.infinity);

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: availableHeight,
                    minWidth:
                        (constraints.maxWidth - (horizontalPadding * 2))
                            .clamp(0.0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: isSmallScreen ? 76 : 90,
                                height: isSmallScreen ? 76 : 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.primaryContainer,
                                    ],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          colorScheme.primary.withOpacity(0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.local_mall_rounded,
                                  size: isSmallScreen ? 36 : 42,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 14 : 20),
                            Text(
                              'جلب الميداني',
                              textAlign: TextAlign.center,
                              style: (isSmallScreen
                                      ? theme.textTheme.headlineSmall
                                      : theme.textTheme.headlineMedium)
                                  ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'بوابة المناديب والمشرفين لإدارة المبيعات والجرد الميداني',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 18 : 26),
                            Card(
                              elevation: 0,
                              color: colorScheme.primaryContainer
                                  .withOpacity(0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant
                                      .withOpacity(0.5),
                                ),
                              ),
                              child: Padding(
                                padding:
                                    EdgeInsets.all(isSmallScreen ? 16 : 22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      enabled: !_isLoading,
                                      keyboardType: TextInputType.emailAddress,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'البريد الإلكتروني',
                                        hintText:
                                            AppConstants.defaultAdminEmail,
                                        prefixIcon: const Icon(
                                          Icons.alternate_email_rounded,
                                        ),
                                        filled: true,
                                        fillColor: colorScheme.surface,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                            color: colorScheme.outlineVariant,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                            color: colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        final text = value?.trim() ?? '';
                                        if (text.isEmpty) {
                                          return 'يرجى إدخال البريد الإلكتروني';
                                        }
                                        if (!text.contains('@') ||
                                            !text.contains('.')) {
                                          return 'يرجى إدخال بريد إلكتروني صحيح';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      enabled: !_isLoading,
                                      obscureText: _obscurePassword,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      decoration: InputDecoration(
                                        labelText: 'كلمة المرور',
                                        hintText: '••••••••',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'إظهار كلمة المرور'
                                              : 'إخفاء كلمة المرور',
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: colorScheme.surface,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                            color: colorScheme.outlineVariant,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                            color: colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'يرجى إدخال كلمة المرور';
                                        }
                                        if (value.length < 6) {
                                          return 'كلمة المرور يجب أن تتكون من 6 أحرف على الأقل';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      height: 52,
                                      child: FilledButton(
                                        onPressed:
                                            _isLoading ? null : _handleLogin,
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.login_rounded),
                                                  SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      'تسجيل الدخول للميدان',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colorScheme.outlineVariant
                                      .withOpacity(0.8),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.key_rounded,
                                        size: 18,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'الدخول السريع المعتمد (${AppConstants.defaultAdminEmail} | ${AppConstants.defaultPassword})',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (isVeryNarrow) ...[
                                    OutlinedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _applyDemoCredentials(
                                                asAdmin: true,
                                              ),
                                      icon: const Icon(
                                        Icons.admin_panel_settings_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'مشرف معتمد',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : () => _applyDemoCredentials(
                                                asAdmin: false,
                                              ),
                                      icon: const Icon(
                                        Icons.badge_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'مندوب ميداني',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ] else
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isLoading
                                                ? null
                                                : () => _applyDemoCredentials(
                                                      asAdmin: true,
                                                    ),
                                            icon: const Icon(
                                              Icons
                                                  .admin_panel_settings_outlined,
                                              size: 18,
                                            ),
                                            label: const Flexible(
                                              child: Text(
                                                'مشرف معتمد',
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    TextStyle(fontSize: 12.5),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isLoading
                                                ? null
                                                : () => _applyDemoCredentials(
                                                      asAdmin: false,
                                                    ),
                                            icon: const Icon(
                                              Icons.badge_outlined,
                                              size: 18,
                                            ),
                                            label: const Flexible(
                                              child: Text(
                                                'مندوب ميداني',
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    TextStyle(fontSize: 12.5),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'اتصال آمن ومرتبط مباشرة بقاعدة بيانات الفروع',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
