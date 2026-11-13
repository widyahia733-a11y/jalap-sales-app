import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';
import '../../../auth/data/models/user_profile_model.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../../inventory/presentation/pages/inventory_page.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

/// الهيكل الرئيسي للتطبيق (Main Dashboard & Navigation Shell)
/// مصمم بالهوية البصرية الملكية (Deep Navy Blue & Royal Gold) ويدعم العمل بدون إنترنت (Offline-First).
class DashboardPage extends StatefulWidget {
  final UserProfileModel? userProfile;

  const DashboardPage({
    super.key,
    this.userProfile,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _isSigningOut = false;

  late final UserProfileModel _currentUser;

  @override
  void initState() {
    super.initState();
    final authUser = Supabase.instance.client.auth.currentUser;
    _currentUser = widget.userProfile ??
        UserProfileModel(
          id: authUser?.id ?? 'admin-jalap-001',
          email: authUser?.email ?? 'admin@jalap.com',
          fullName: 'مشرف نظام / مندوب معتمد',
          role: 'admin',
          branchId: 'الفرع الرئيسي - صنعاء',
          isActive: true,
        );
  }

  /// الانتقال السريع إلى قسم محدد عبر شريط التنقل السفلي
  void _navigateToTab(int index, {String? actionLabel}) {
    setState(() {
      _selectedIndex = index;
    });

    if (actionLabel != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppConstants.deepNavyBlue,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  const Icon(
                    Icons.flash_on_rounded,
                    color: AppConstants.royalGold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم الانتقال إلى: $actionLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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

  /// تسجيل الخروج الآمن والعودة إلى شاشة الدخول
  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      debugPrint('Sign out error: $error');
    } finally {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const LoginPage(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _HomeTabView(
        userProfile: _currentUser,
        isSigningOut: _isSigningOut,
        onSignOut: _handleSignOut,
        onQuickActionSelect: _navigateToTab,
      ),
      InventoryPage(
        currentUserId: _currentUser.id,
        currentBranchId: _currentUser.branchId,
      ),
      OrdersPage(
        currentUserId: _currentUser.id,
        currentBranchId: _currentUser.branchId,
      ),
      CustomersPage(
        currentBranchId: _currentUser.branchId,
      ),
      ProfilePage(
        userProfile: _currentUser,
        isSigningOut: _isSigningOut,
        onSignOut: _handleSignOut,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.cleanLightGrey,
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() => _selectedIndex = index);
          },
          height: 72,
          elevation: 4,
          backgroundColor: Colors.white,
          indicatorColor: AppConstants.softRoyalGold,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(
                Icons.dashboard_rounded,
                color: AppConstants.deepNavyBlue,
              ),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(
                Icons.inventory_2_rounded,
                color: AppConstants.deepNavyBlue,
              ),
              label: 'الأصناف والجرد',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(
                Icons.receipt_long_rounded,
                color: AppConstants.deepNavyBlue,
              ),
              label: 'الطلبات',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_alt_outlined),
              selectedIcon: Icon(
                Icons.people_alt_rounded,
                color: AppConstants.deepNavyBlue,
              ),
              label: 'العملاء',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: AppConstants.deepNavyBlue,
              ),
              label: 'الحساب',
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// شاشة التبويب الرئيسي (Home Tab View) - الهوية الملكية + دعم Offline-First
// =============================================================================

class _HomeTabView extends StatelessWidget {
  final UserProfileModel userProfile;
  final bool isSigningOut;
  final VoidCallback onSignOut;
  final void Function(int tabIndex, {String? actionLabel}) onQuickActionSelect;

  const _HomeTabView({
    required this.userProfile,
    required this.isSigningOut,
    required this.onSignOut,
    required this.onQuickActionSelect,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OfflineSyncService offlineSync = OfflineSyncService.instance;
    final String branchCurrency =
        AppConstants.currencyForBranch(userProfile.branchId);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 170,
          pinned: true,
          stretch: true,
          backgroundColor: AppConstants.deepNavyBlue,
          foregroundColor: Colors.white,
          title: const Text(
            'جلب الميداني',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          actions: [
            // شارة الاتصال التفاعلية (متصل / يعمل محلياً Offline) مع إمكانية التبديل للتجربة
            ValueListenableBuilder<bool>(
              valueListenable: offlineSync.isOnlineNotifier,
              builder: (context, isOnline, _) {
                return GestureDetector(
                  onTap: () {
                    offlineSync.setOfflineMode(isOnline);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 11),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.green.shade600
                          : AppConstants.royalGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline
                              ? Icons.cloud_done_rounded
                              : Icons.offline_bolt_rounded,
                          size: 15,
                          color: isOnline
                              ? Colors.white
                              : AppConstants.deepNavyBlue,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOnline ? 'متصل' : 'يعمل محلياً (Offline)',
                          style: TextStyle(
                            color: isOnline
                                ? Colors.white
                                : AppConstants.deepNavyBlue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: isSigningOut ? null : onSignOut,
              icon: isSigningOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 6),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppConstants.deepNavyBlue,
                    AppConstants.royalNavySecondary,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppConstants.royalGold,
                        child: Icon(
                          userProfile.isAdmin
                              ? Icons.admin_panel_settings_rounded
                              : Icons.badge_rounded,
                          color: AppConstants.deepNavyBlue,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مرحباً، ${userProfile.fullName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _HeaderChip(
                                  icon: Icons.verified_user_outlined,
                                  label: userProfile.roleArabicLabel,
                                  isGold: true,
                                ),
                                _HeaderChip(
                                  icon: Icons.storefront_outlined,
                                  label: userProfile.branchId != null &&
                                          userProfile.branchId!.isNotEmpty
                                      ? '${userProfile.branchId!} ($branchCurrency)'
                                      : 'الفرع الرئيسي ($branchCurrency)',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // شريط حالة التخزين المحلي وطابور المزامنة (Offline-First & Sync Queue)
              ValueListenableBuilder<int>(
                valueListenable: offlineSync.pendingSyncCountNotifier,
                builder: (context, pendingCount, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.softRoyalGold,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppConstants.royalGold),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storage_rounded,
                          color: AppConstants.deepNavyBlue,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pendingCount > 0
                                ? 'نمط Offline-First نشط • توجد ($pendingCount) عمليات محفوظة في طابور المزامنة (Sync Queue) جاهزة للرفع'
                                : 'نمط Offline-First نشط • جميع الأصناف الـ 27 والعملاء والطلبات محفوظة محلياً للعمل بدون إنترنت',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppConstants.deepNavyBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'ملخص الأداء الميداني ($branchCurrency)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppConstants.deepNavyBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.softRoyalGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'العملة: ${AppConstants.defaultCurrencyName} ($branchCurrency)',
                      style: const TextStyle(
                        color: AppConstants.deepNavyBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PrimarySalesStatCard(
                todaySales: AppConstants.formatCurrency(
                  485000,
                  branch: userProfile.branchId,
                ),
                monthSales: AppConstants.formatCurrency(
                  11240000,
                  branch: userProfile.branchId,
                ),
                growthPercentage: '+14.2%',
                onTap: () => onQuickActionSelect(2, actionLabel: 'الطلبات'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryStatCard(
                      title: 'طلبات قيد الانتظار',
                      value: '6 طلبات',
                      subtitle: 'محفوظة وجاهزة للتسليم',
                      icon: Icons.pending_actions_rounded,
                      accentColor: AppConstants.deepNavyBlue,
                      backgroundColor: Colors.white,
                      borderColor: AppConstants.royalGold,
                      onTap: () =>
                          onQuickActionSelect(2, actionLabel: 'الطلبات'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SecondaryStatCard(
                      title: 'حالة الجرد الأسبوعي',
                      value: '27 / 27',
                      subtitle: 'الأصناف المعتمدة',
                      icon: Icons.fact_check_rounded,
                      accentColor: Colors.teal.shade800,
                      backgroundColor: Colors.white,
                      borderColor: Colors.teal.shade300,
                      onTap: () => onQuickActionSelect(
                        1,
                        actionLabel: 'الأصناف والجرد الأسبوعي',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'الاختصارات السريعة (Quick Actions)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppConstants.deepNavyBlue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'تعمل بكفاءة تامة بيد واحدة وحتى في حال انقطاع الاتصال بالإنترنت',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              _QuickActionTile(
                title: 'جرد جديد',
                subtitle:
                    'تسجيل الجرد الأسبوعي السريع (+ / -) للأصناف الـ 27 المعتمدة',
                icon: Icons.qr_code_scanner_rounded,
                onTap: () => onQuickActionSelect(
                  1,
                  actionLabel: 'الأصناف والجرد الأسبوعي (27 صنفاً)',
                ),
              ),
              const SizedBox(height: 12),
              _QuickActionTile(
                title: 'طلب جديد',
                subtitle:
                    'إصدار فاتورة مبيعات جديدة بالعملة المعتمدة ($branchCurrency) وحفظها فوراً',
                icon: Icons.add_shopping_cart_rounded,
                onTap: () => onQuickActionSelect(
                  2,
                  actionLabel: 'إدارة الطلبات والمبيعات',
                ),
              ),
              const SizedBox(height: 12),
              _QuickActionTile(
                title: 'إضافة عميل',
                subtitle:
                    'تسجيل عميل جديد وربطه بالفرع وقناة التوزيع المعتمدة (channels)',
                icon: Icons.person_add_alt_1_rounded,
                onTap: () => onQuickActionSelect(
                  3,
                  actionLabel: 'دليل العملاء وقنوات التوزيع',
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isGold;

  const _HeaderChip({
    required this.icon,
    required this.label,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGold
            ? AppConstants.royalGold
            : Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isGold ? AppConstants.deepNavyBlue : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isGold ? AppConstants.deepNavyBlue : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimarySalesStatCard extends StatelessWidget {
  final String todaySales;
  final String monthSales;
  final String growthPercentage;
  final VoidCallback onTap;

  const _PrimarySalesStatCard({
    required this.todaySales,
    required this.monthSales,
    required this.growthPercentage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppConstants.royalGold, width: 1.4),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.deepNavyBlue,
                AppConstants.royalNavySecondary,
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.royalGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: AppConstants.deepNavyBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'مبيعات اليوم / الشهر',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.royalGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      growthPercentage,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppConstants.deepNavyBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مبيعات اليوم',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todaySales,
                          style: const TextStyle(
                            color: AppConstants.royalGold,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إجمالي الشهر',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          monthSales,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _SecondaryStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: backgroundColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.softRoyalGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppConstants.deepNavyBlue, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppConstants.deepNavyBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppConstants.deepNavyBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: AppConstants.royalGold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.deepNavyBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppConstants.softRoyalGold,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppConstants.deepNavyBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
