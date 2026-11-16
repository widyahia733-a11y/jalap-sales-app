import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/al_rabie_catalog.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';
import '../../../auth/data/models/user_profile_model.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../../inventory/presentation/pages/inventory_page.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../sales_rep/presentation/pages/sales_rep_field_page.dart';
import '../../../sales_reps/presentation/pages/sales_reps_management_page.dart';

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
  final GlobalKey<SalesRepsManagementPageState> _salesRepsKey =
      GlobalKey<SalesRepsManagementPageState>();

  int _selectedIndex = 0;
  bool _isSigningOut = false;

  UserProfileModel? _currentUser;
  bool _useSalesRepQuickMode = false;

  // إحصائيات حية وحقيقية من Supabase (بدون أي أرقام مالية وهمية)
  int _liveOrdersCount = 0;
  int _livePendingOrdersCount = 0;
  int _liveActiveRepsCount = 0;
  int _liveTotalRepsCount = 0;
  int _liveBranchesCount = 7;

  @override
  void initState() {
    super.initState();
    final authUser = Supabase.instance.client.auth.currentUser;
    if (widget.userProfile != null) {
      _currentUser = widget.userProfile;
      _useSalesRepQuickMode = _currentUser!.isSales;
      _refreshLiveDashboardMetrics();
    } else if (authUser != null) {
      _currentUser = UserProfileModel(
        id: authUser.id,
        email: authUser.email ?? '',
        username: authUser.email ?? '',
        fullName: 'مستخدم معتمد',
        role: 'sales_rep',
        branchId: 'فرع صنعاء',
        isActive: true,
      );
      _useSalesRepQuickMode = true;
      _refreshLiveDashboardMetrics();
    } else {
      // حماية المسارات الداخلية من الوصول المباشر بدون تسجيل دخول
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const LoginPage(),
            ),
          );
        }
      });
    }
  }

  /// جلب الأعداد الحقيقية المباشرة من جداول Supabase (الطلبات، المناديب النشطين، والفروع)
  Future<void> _refreshLiveDashboardMetrics() async {
    try {
      final cachedOrders = OfflineSyncService.instance
          .getCachedOrders()
          .where((o) => !(o['id']?.toString().startsWith('ORD-10') ?? false))
          .toList();
      int ordersTotal = cachedOrders.length;
      int ordersPending = cachedOrders
          .where((o) => (o['status']?.toString() ?? 'pending') == 'pending')
          .length;

      int activeReps = 0;
      int totalReps = 0;
      int branchesCount = 7;

      if (AppConstants.isSupabaseConfigured) {
        final supabase = Supabase.instance.client;

        // 1. العدد الفعلي للمناديب في جدول users_profiles
        try {
          final List<dynamic> repRows = await supabase
              .from(AppConstants.tableUsersProfiles)
              .select('id, is_active')
              .eq('role', 'sales_rep');
          totalReps = repRows.length;
          activeReps = repRows
              .where((r) => r is Map && (r['is_active'] == true))
              .length;
        } catch (e) {
          debugPrint('Live reps count info: $e');
        }

        // 2. العدد الفعلي للطلبات في جدول orders
        try {
          final List<dynamic> orderRows = await supabase
              .from(AppConstants.tableOrders)
              .select('id, status');
          if (orderRows.isNotEmpty || cachedOrders.isEmpty) {
            ordersTotal = orderRows.length;
            ordersPending = orderRows
                .where(
                  (o) =>
                      o is Map &&
                      (o['status']?.toString() ?? 'pending') == 'pending',
                )
                .length;
          }
        } catch (e) {
          debugPrint('Live orders count info: $e');
        }

        // 3. العدد الفعلي للفروع في جدول branches
        try {
          final List<dynamic> branchRows = await supabase
              .from(AppConstants.tableBranches)
              .select('id');
          if (branchRows.isNotEmpty) {
            branchesCount = branchRows.length;
          }
        } catch (e) {
          debugPrint('Live branches count info: $e');
        }
      }

      if (mounted) {
        setState(() {
          _liveOrdersCount = ordersTotal;
          _livePendingOrdersCount = ordersPending;
          _liveActiveRepsCount = activeReps;
          _liveTotalRepsCount = totalReps;
          _liveBranchesCount = branchesCount;
        });
      }
    } catch (error) {
      debugPrint('Dashboard metrics refresh warning: $error');
    }
  }

  /// الانتقال السريع إلى قسم محدد عبر شريط التنقل السفلي
  void _navigateToTab(
    int index, {
    String? actionLabel,
    bool openAddRepModal = false,
  }) {
    setState(() {
      _selectedIndex = index;
    });

    _refreshLiveDashboardMetrics();

    if (openAddRepModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _salesRepsKey.currentState?.openAddOrEditRepModal();
      });
    } else if (actionLabel != null && mounted) {
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
    final user = _currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_useSalesRepQuickMode) {
      return SalesRepFieldPage(
        userProfile: user,
        isSigningOut: _isSigningOut,
        onSignOut: _handleSignOut,
        onSwitchToFullDashboard: user.isAdmin
            ? () {
                setState(() => _useSalesRepQuickMode = false);
              }
            : null,
      );
    }

    final bool isAdmin = user.isAdmin;

    final List<Widget> pages = [
      _HomeTabView(
        userProfile: user,
        isSigningOut: _isSigningOut,
        onSignOut: _handleSignOut,
        onQuickActionSelect: _navigateToTab,
        liveOrdersCount: _liveOrdersCount,
        livePendingOrdersCount: _livePendingOrdersCount,
        liveActiveRepsCount: _liveActiveRepsCount,
        liveTotalRepsCount: _liveTotalRepsCount,
        liveBranchesCount: _liveBranchesCount,
      ),
      InventoryPage(
        currentUserId: user.id,
        currentBranchId: user.branchId,
      ),
      OrdersPage(
        currentUserId: user.id,
        currentBranchId: user.branchId,
      ),
      CustomersPage(
        currentBranchId: user.branchId,
      ),
      if (isAdmin)
        SalesRepsManagementPage(
          key: _salesRepsKey,
          onRepsChanged: _refreshLiveDashboardMetrics,
        ),
      ProfilePage(
        userProfile: user,
        isSigningOut: _isSigningOut,
        onSignOut: _handleSignOut,
      ),
    ];

    final List<NavigationDestination> destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(
          Icons.dashboard_rounded,
          color: AppConstants.deepNavyBlue,
        ),
        label: 'الرئيسية',
      ),
      const NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(
          Icons.inventory_2_rounded,
          color: AppConstants.deepNavyBlue,
        ),
        label: 'الأصناف والجرد',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(
          Icons.receipt_long_rounded,
          color: AppConstants.deepNavyBlue,
        ),
        label: 'الطلبات',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_alt_outlined),
        selectedIcon: Icon(
          Icons.people_alt_rounded,
          color: AppConstants.deepNavyBlue,
        ),
        label: 'العملاء',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.supervisor_account_outlined),
          selectedIcon: Icon(
            Icons.supervisor_account_rounded,
            color: AppConstants.deepNavyBlue,
          ),
          label: 'المناديب',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(
          Icons.person_rounded,
          color: AppConstants.deepNavyBlue,
        ),
        label: 'الحساب',
      ),
    ];

    final int safeIndex = _selectedIndex.clamp(0, pages.length - 1);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.cleanLightGrey,
        body: IndexedStack(
          index: safeIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (int index) {
            setState(() => _selectedIndex = index);
            _refreshLiveDashboardMetrics();
          },
          height: 72,
          elevation: 4,
          backgroundColor: Colors.white,
          indicatorColor: AppConstants.softRoyalGold,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: destinations,
        ),
      ),
    );
  }
}

// =============================================================================
// شاشة التبويب الرئيسي (Home Tab View) - إحصائيات حية من Supabase بدون أرقام وهمية
// =============================================================================

class _HomeTabView extends StatelessWidget {
  final UserProfileModel userProfile;
  final bool isSigningOut;
  final VoidCallback onSignOut;
  final void Function(
    int tabIndex, {
    String? actionLabel,
    bool openAddRepModal,
  }) onQuickActionSelect;
  final int liveOrdersCount;
  final int livePendingOrdersCount;
  final int liveActiveRepsCount;
  final int liveTotalRepsCount;
  final int liveBranchesCount;

  const _HomeTabView({
    required this.userProfile,
    required this.isSigningOut,
    required this.onSignOut,
    required this.onQuickActionSelect,
    required this.liveOrdersCount,
    required this.livePendingOrdersCount,
    required this.liveActiveRepsCount,
    required this.liveTotalRepsCount,
    required this.liveBranchesCount,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OfflineSyncService offlineSync = OfflineSyncService.instance;
    final int catalogCount = AlRabieCatalog.items.length;

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
                                      ? userProfile.branchId!
                                      : 'الفرع الرئيسي',
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
                                : 'نمط Offline-First نشط • جميع أصناف كتالوج الربيع ($catalogCount صنفاً) والعملاء والمناديب مرتبطة مباشرة بـ Supabase',
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
                      'المؤشرات التشغيلية المباشرة (Supabase Live)',
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
                      '$liveBranchesCount فروع معتمدة',
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
              _PrimaryOperationalStatCard(
                catalogCount: '$catalogCount / $catalogCount',
                activeRepsText:
                    '$liveActiveRepsCount / $liveTotalRepsCount مندوب نشط',
                badgeText: 'ORDER',
                onTap: () => onQuickActionSelect(
                  userProfile.isAdmin ? 4 : 1,
                  actionLabel: userProfile.isAdmin
                      ? 'إدارة المناديب وصلاحيات الفروع'
                      : 'كتالوج وجرد أصناف الربيع',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryStatCard(
                      title: 'إجمالي الطلبات المسجلة',
                      value: '$liveOrdersCount طلب',
                      subtitle: livePendingOrdersCount > 0
                          ? 'منها $livePendingOrdersCount قيد المتابعة'
                          : 'مرتبطة مباشرة بقاعدة البيانات',
                      icon: Icons.receipt_long_rounded,
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
                      title: 'كتالوج أصناف الربيع',
                      value: '$catalogCount / $catalogCount',
                      subtitle: 'الأصناف الرسمية المعتمدة',
                      icon: Icons.fact_check_rounded,
                      accentColor: Colors.teal.shade800,
                      backgroundColor: Colors.white,
                      borderColor: Colors.teal.shade300,
                      onTap: () => onQuickActionSelect(
                        1,
                        actionLabel: 'كتالوج وجرد أصناف الربيع',
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
                'إجراءات سريعة ومباشرة لإدارة الجرد والطلبات والمناديب والعملاء',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              _QuickActionTile(
                title: 'جرد جديد',
                subtitle:
                    'تسجيل الجرد الأسبوعي السريع (+ / -) لكتالوج أصناف الربيع بالصور والأكواد الرسمية',
                icon: Icons.qr_code_scanner_rounded,
                onTap: () => onQuickActionSelect(
                  1,
                  actionLabel: 'كتالوج وجرد أصناف الربيع',
                ),
              ),
              const SizedBox(height: 12),
              _QuickActionTile(
                title: 'طلب جديد',
                subtitle:
                    'إرسال طلب توريد بضاعة لأصناف الربيع المعتمدة للفرع وحفظه فوراً',
                icon: Icons.add_shopping_cart_rounded,
                onTap: () => onQuickActionSelect(
                  2,
                  actionLabel: 'إدارة الطلبات والمبيعات',
                ),
              ),
              if (userProfile.isAdmin) ...[
                const SizedBox(height: 12),
                _QuickActionTile(
                  title: 'إضافة مندوب',
                  subtitle:
                      'إنشاء حساب مندوب مبيعات جديد وتخصيص فرعه وصلاحياته في (users_profiles)',
                  icon: Icons.supervisor_account_rounded,
                  onTap: () => onQuickActionSelect(
                    4,
                    actionLabel: 'إدارة المناديب وصلاحيات الفروع',
                    openAddRepModal: true,
                  ),
                ),
              ],
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

class _PrimaryOperationalStatCard extends StatelessWidget {
  final String catalogCount;
  final String activeRepsText;
  final String badgeText;
  final VoidCallback onTap;

  const _PrimaryOperationalStatCard({
    required this.catalogCount,
    required this.activeRepsText,
    required this.badgeText,
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
                      Icons.analytics_rounded,
                      color: AppConstants.deepNavyBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'حالة الكتالوج وفريق المبيعات',
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
                      badgeText,
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
                          'أصناف الربيع المعتمدة',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          catalogCount,
                          textDirection: TextDirection.ltr,
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
                          'المناديب المسجلون',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeRepsText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
