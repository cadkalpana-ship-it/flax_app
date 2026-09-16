import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flax_app/screens/flax_assignment.dart';
import 'package:flax_app/screens/flax_list_screen.dart';
import 'package:flax_app/screens/flax_report_screen.dart';
import 'package:flax_app/screens/tree_report_screen.dart';
import 'package:flax_app/screens/settings.dart';
import 'package:flax_app/screens/tree_module_screen.dart';
import 'package:flutter/material.dart';
import 'package:flax_app/services/dashboard_service.dart';
import 'package:flax_app/services/auth_service.dart';
import 'package:flax_app/screens/flax_release.dart';
import 'package:flax_app/screens/login_screen.dart';

// ============================================================
// SECTIONS
// ============================================================

enum AppSection {
  dashboard,
  flaxMaster,
  treeMaster,
  flaxAssignToTree,
  flaxRelease,
  castingMaster,
  reports,
  treeReport,
  settings,
}

// ============================================================
// DASHBOARD SCREEN
// ============================================================

class DashboardScreen extends StatefulWidget {
   
  const DashboardScreen({super.key, });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

final GlobalKey<FlaxListViewState> _flaxMasterKey =
    GlobalKey<FlaxListViewState>();

final GlobalKey<TreeModuleScreenState> _treemasterKey =
    GlobalKey<TreeModuleScreenState>();

final GlobalKey<FlaxAssignmentState> _flaxAssignmentKey =
    GlobalKey<FlaxAssignmentState>();

final GlobalKey<FlaxReleaseState> _flaxReleaseKey =
    GlobalKey<FlaxReleaseState>();

final GlobalKey<FlaxReportScreenState> _flaxReportKey =
    GlobalKey<FlaxReportScreenState>();

final GlobalKey<TreeReportScreenState> _treeReportKey =
    GlobalKey<TreeReportScreenState>();

final GlobalKey<SettingsScreenState> _settingsKey =
    GlobalKey<SettingsScreenState>();

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService service = DashboardService();
  final AuthService _auth = AuthService();

  // Responsive breakpoints.
  // Phones / narrow tablets: < 700
  // Tablets / small laptops: 700 - 1099
  // Desktop: >= 1100
  static const double _phoneBreakpoint = 700;
  static const double _desktopBreakpoint = 1100;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  final ScrollController _recentAssignmentsScrollController =
    ScrollController();

    final ScrollController _dashboardScrollController =
    ScrollController();

  Map<String, dynamic>? summary;
  Map<String, dynamic>? overview;

  List<dynamic> recentAssignments = [];
  List<dynamic> recentActivity = [];
  List<dynamic> designUsage = [];

  bool loading = true;
  String? error;

  AppSection _section = AppSection.dashboard;

  // Whether the "Reports" sidebar group is expanded to show its
  // sub-items (Flax Report / Tree Report).
  bool _reportsExpanded = false;

  String _userName = '';
  String _userRole = '';

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    loadDashboard();
    _loadCurrentUser();
    print('Hii');

    // Tick every second so the date/time in the top bar stays live.
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
        });
      },
    );
  }

  @override
void dispose() {
  _clockTimer?.cancel();
  _recentAssignmentsScrollController.dispose();
  _dashboardScrollController.dispose();
  super.dispose();
}

  // ==========================================================
  // DATE / TIME FORMATTING
  // ==========================================================

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formattedDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = _monthNames[dt.month - 1];
    return '$day $month ${dt.year}';
  }

  String _formattedTime(DateTime dt) {
    final hour24 = dt.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;

    final hour = hour12.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }

  // ==========================================================
  // CURRENT USER
  // ==========================================================

  Future<void> _loadCurrentUser() async {
    final name = await _auth.getUserName();
    final role = await _auth.getRole();

    if (!mounted) return;

    setState(() {
      _userName = name.isNotEmpty ? name : 'User';
      _userRole = role == 'admin' ? 'Administrator' : 'User';
    });
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'You will need to sign in again to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _auth.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ==========================================================
  // LOAD DASHBOARD
  // ==========================================================

  Future<void> loadDashboard() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        service.getSummary(),
        service.getOverview(),
        service.getRecentAssignments(),
        service.getRecentActivity(),
        service.getTopDesignUsage(),
      ]);

      if (!mounted) return;

      setState(() {
        summary = results[0] as Map<String, dynamic>;
        overview = results[1] as Map<String, dynamic>;

        recentAssignments = results[2] as List<dynamic>;
        recentActivity = results[3] as List<dynamic>;
        designUsage = results[4] as List<dynamic>;

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _refreshCurrentSection() async {
    switch (_section) {
      case AppSection.dashboard:
        await loadDashboard();
        break;

      case AppSection.flaxMaster:
        await _flaxMasterKey.currentState?.refreshData();
        break;

      case AppSection.treeMaster:
        await _treemasterKey.currentState?.refreshData();
        break;

      case AppSection.flaxAssignToTree:
        await _flaxAssignmentKey.currentState?.refreshData();
        break;

      case AppSection.flaxRelease:
        await _flaxReleaseKey.currentState?.refreshData();
        break;

      case AppSection.reports:
        await _flaxReportKey.currentState?.refreshData();
        break;

      case AppSection.treeReport:
        await _treeReportKey.currentState?.refreshData();
        break;

      case AppSection.settings:
        await _settingsKey.currentState?.refreshData();
        break;

      case AppSection.castingMaster:
        break;
    }
  }
  // ==========================================================
  // HELPERS
  // ==========================================================

  int _number(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _text(
    dynamic value, {
    String fallback = "-",
  }) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  // ==========================================================
  // SECTION TITLE
  // ==========================================================

  String _sectionTitle(AppSection section) {
    switch (section) {
      case AppSection.dashboard:
        return "Dashboard";

      case AppSection.flaxMaster:
        return "Flax Master";

      case AppSection.treeMaster:
        return "Tree Master";
      case AppSection.flaxAssignToTree:
        return "Flax Assign to Tree";

      case AppSection.flaxRelease:
        return "Tree Casting";

      case AppSection.castingMaster:
        return "Casting Master";

      case AppSection.reports:
        return "Flax Report";

      case AppSection.treeReport:
        return "Tree Report";

      case AppSection.settings:
        return "Settings";
    }
  }

  // ==========================================================
  // SECTION SUBTITLE
  // ==========================================================

  String _sectionSubtitle(AppSection section) {
    switch (section) {
      case AppSection.dashboard:
        return "Flax Management - Casting";

      case AppSection.flaxMaster:
        return "Manage all flax records";
      case AppSection.treeMaster:
        return "Manage tree records";

      case AppSection.flaxAssignToTree:
        return "Assign flax to trees";

      case AppSection.flaxRelease:
        return "View released FLX after casting";

      case AppSection.castingMaster:
        return "Manage casting records";

      case AppSection.reports:
        return "View FLX-wise reports";

      case AppSection.treeReport:
        return "Tree-wise style, bag & metal totals";

      case AppSection.settings:
        return "Application settings";
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    // Use the actual viewport width rather than ancestor constraints.
    // This is important on Flutter Web/device emulation: a constrained
    // parent must never make a phone look like a desktop layout.
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = viewportWidth >= _desktopBreakpoint;
    final isPhone = viewportWidth < _phoneBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F6FD),
      // Drawer overlays the page on phones/tablets. It NEVER participates
      // in the Row that lays out the dashboard content.
      drawer: !isDesktop
          ? Drawer(
              width: isPhone ? viewportWidth.clamp(280.0, 320.0) : 340.0,
              elevation: 16,
              child: SafeArea(
                child: _buildSidebar(inDrawer: true),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDesktop)
              SizedBox(
                width: 240,
                child: _buildSidebar(),
              ),
            Expanded(
              child: Column(
                children: [
                  _buildTopNavigationBar(
                    isMobile: !isDesktop,
                    isPhone: isPhone,
                  ),
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // CONTENT SWITCHER
  // ==========================================================

  Widget _buildContent() {
    return IndexedStack(
      index: _section.index,
      children: [
        _buildDashboardBody(),
        FlaxListView(
          key: _flaxMasterKey,
        ),
        TreeModuleScreen(
          key: _treemasterKey,
        ),
        FlaxAssignment(
          key: _flaxAssignmentKey,
        ),
        FlaxRelease(
          key: _flaxReleaseKey,
        ),
        _buildPlaceholder("Casting Master"),
        FlaxReportScreen(
  key: _flaxReportKey,
  userName: _userName,
),
       TreeReportScreen(
  key: _treeReportKey,
  userName: _userName,
),
        SettingsScreen(key: _settingsKey),
      ],
    );
  }

  // ==========================================================
  // PLACEHOLDER
  // ==========================================================

  Widget _buildPlaceholder(String label) {
    return Center(
      child: Text(
        "$label — coming soon",
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
    );
  }

  // ==========================================================
  // DASHBOARD BODY
  // ==========================================================

  Widget _buildDashboardBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildErrorState(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width < _phoneBreakpoint
            ? 12.0
            : width < _desktopBreakpoint
                ? 18.0
                : 24.0;

        return Scrollbar(
          controller: _dashboardScrollController,
          thumbVisibility: width >= _desktopBreakpoint,
          child: SingleChildScrollView(
            controller: _dashboardScrollController,
            primary: false,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              width < _phoneBreakpoint ? 12 : 20,
              horizontalPadding,
              width < _phoneBreakpoint ? 20 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (width < _phoneBreakpoint) ...[
                      _buildMobileDashboardIntro(),
                      const SizedBox(height: 12),
                    ],
                    _buildMetricCardsRow(),
                    SizedBox(height: width < _phoneBreakpoint ? 14 : 20),
                    _buildMiddleChartsAndActivityGrid(),
                    SizedBox(height: width < _phoneBreakpoint ? 14 : 20),
                    _buildBottomTablesAndDesignsGrid(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDashboardIntro() {
    final displayName = _userName.trim().isEmpty ? "Admin" : _userName.trim();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Good day, $displayName",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "Here is your Flax Tracker overview.",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                _formattedDate(_now),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  Widget _buildErrorState() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            "Unable to load dashboard",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error ?? "Unknown error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SIDEBAR
  // ==========================================================

  Widget _buildSidebar({bool inDrawer = false}) {
    return Container(
      width: inDrawer ? null : 240,
      color: const Color(0xFF0D2353),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Row(
                children: [
                  const Icon(Icons.diamond_outlined, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Kalpana Enterprises",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Crafting Excellence",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _sidebarItem(Icons.dashboard, "Dashboard", AppSection.dashboard),
            _sidebarItem(Icons.layers_outlined, "Flax Master", AppSection.flaxMaster),
            _sidebarItem(Icons.account_tree_outlined, "Create Tree", AppSection.treeMaster),
            _sidebarItem(Icons.account_tree_outlined, "Flax Assign to Tree", AppSection.flaxAssignToTree),
            _sidebarItem(Icons.check_circle_outline, "Tree Casting", AppSection.flaxRelease),
            _sidebarReportsGroup(),
            _sidebarItem(Icons.settings_outlined, "Settings", AppSection.settings),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // SIDEBAR ITEM
  // ==========================================================

  Widget _sidebarItem(
    IconData icon,
    String title,
    AppSection section, {
    bool hasDropdown = false,
  }) {
    final isSelected = _section == section;

    return GestureDetector(
      onTap: () {
        setState(() {
          _section = section;
        });

        // Refresh data whenever a section is opened
        if (section == AppSection.dashboard) {
          loadDashboard();
        }

        _scaffoldKey.currentState?.closeDrawer();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1D5CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: hasDropdown
              ? const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white70,
                  size: 16,
                )
              : null,
        ),
      ),
    );
  }

  // ==========================================================
  // REPORTS SIDEBAR GROUP (Flax Report / Tree Report)
  // ==========================================================

  Widget _sidebarReportsGroup() {
    final isChildSelected =
        _section == AppSection.reports || _section == AppSection.treeReport;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _reportsExpanded = !_reportsExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isChildSelected
                  ? const Color(0xFF1D5CFF)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.bar_chart_outlined,
                color: isChildSelected ? Colors.white : Colors.white70,
                size: 20,
              ),
              title: Text(
                "Reports",
                style: TextStyle(
                  color: isChildSelected ? Colors.white : Colors.white70,
                  fontWeight:
                      isChildSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: Icon(
                _reportsExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ),
        ),
        if (_reportsExpanded) ...[
          _sidebarSubItem(
            "Flax Report",
            AppSection.reports,
          ),
          _sidebarSubItem(
            "Tree Report",
            AppSection.treeReport,
          ),
        ],
      ],
    );
  }

  Widget _sidebarSubItem(
    String title,
    AppSection section,
  ) {
    final isSelected = _section == section;

    return GestureDetector(
      onTap: () {
        setState(() {
          _section = section;
        });
        _scaffoldKey.currentState?.closeDrawer();
      },
      child: Container(
        margin: const EdgeInsets.only(
          left: 28,
          right: 12,
          bottom: 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1D5CFF).withOpacity(0.55)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          leading: const Icon(
            Icons.circle,
            color: Colors.white38,
            size: 6,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // TOP NAVIGATION
  // ==========================================================

  Widget _buildTopNavigationBar({
    bool isMobile = false,
    bool isPhone = false,
  }) {
    return Material(
      color: Colors.white,
      elevation: 0.5,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 8 : isMobile ? 12 : 20,
          vertical: isPhone ? 7 : 10,
        ),
        child: Row(
          children: [
            if (isMobile)
              IconButton(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _sectionTitle(_section),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isPhone ? 16 : isMobile ? 18 : 21,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(height: 2),
                    Text(
                      _sectionSubtitle(_section),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            if (isMobile && !isPhone)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: _buildCompactDateTime(),
              ),
            if (!isMobile) _buildDesktopDateTime(),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refreshCurrentSection,
              icon: const Icon(Icons.refresh, color: Colors.grey),
            ),
            PopupMenuButton<String>(
              tooltip: 'Account',
              offset: const Offset(0, 44),
              onSelected: (value) {
                if (value == 'logout') _logout();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    _userName.isEmpty ? 'User' : _userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Log Out', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: isPhone ? 18 : 20,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: const Icon(Icons.person, color: Color(0xFF64748B)),
                  ),
                  if (!isPhone) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName.isEmpty ? "..." : _userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            _userRole,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopDateTime() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey),
        const SizedBox(width: 5),
        Text(_formattedDate(_now), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
        const SizedBox(width: 14),
        const Icon(Icons.access_time, size: 15, color: Colors.grey),
        const SizedBox(width: 5),
        Text(_formattedTime(_now), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCompactDateTime() {
    return Text(
      _formattedTime(_now),
      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
    );
  }

  // ==========================================================
  // METRIC CARDS
  // ==========================================================

  Widget _buildMetricCardsRow() {
    final total = _number(summary?["total_flax"]);
    final assigned = _number(summary?["assigned_flax"]);
    final available = _number(summary?["available_flax"]);
    final underMaintenance = _number(summary?["under_maintenance_flax"]);

    final cards = <Widget>[
      _metricCard(
        title: "Total Flax",
        value: total.toString(),
        subtitle: "All Flax",
        icon: Icons.inventory_2_outlined,
        iconBackground: const Color(0xFFE0EDFF),
        iconColor: const Color(0xFF1D5CFF),
      ),
      _metricCard(
        title: "Assigned Flax",
        value: assigned.toString(),
        subtitle: "Assigned to Tree",
        icon: Icons.check_circle_outline,
        iconBackground: const Color(0xFFE1F6EB),
        iconColor: const Color(0xFF10B981),
      ),
      _metricCard(
        title: "Available Flax",
        value: available.toString(),
        subtitle: "Not Assigned",
        icon: Icons.inventory_2_outlined,
        iconBackground: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFFA855F7),
      ),
      _metricCard(
        title: "Under Maintenance",
        value: underMaintenance.toString(),
        subtitle: "Inactive Flax",
        icon: Icons.build_outlined,
        iconBackground: const Color(0xFFFFF7E6),
        iconColor: const Color(0xFFF59E0B),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isPhone = width < _phoneBreakpoint;
        final gap = isPhone ? 10.0 : 14.0;

        // A phone gets a compact 2 x 2 dashboard grid. This keeps all four
        // KPIs visible near the top without turning each card into a large
        // full-width block.
        final columns = isPhone
            ? 2
            : width < _desktopBreakpoint
                ? 2
                : 4;

        final cardWidth =
            (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // METRIC CARD
  // ==========================================================

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 230;
        final height = compact ? 112.0 : 135.0;
        final padding = compact ? 14.0 : 20.0;
        final iconSize = compact ? 20.0 : 24.0;
        final iconPadding = compact ? 10.0 : 12.0;

        return Container(
          height: height,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 16 : 12),
            border: Border.all(
              color: const Color(0xFFE8EDF5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: compact ? 11 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: compact ? 25 : 28,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: compact ? 9.5 : 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: iconSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // MIDDLE SECTION
  // ==========================================================

  Widget _buildMiddleChartsAndActivityGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = width < _phoneBreakpoint ? 12.0 : 16.0;

        if (width < 760) {
          return Column(
            children: [
              _buildFlaxOverviewCard(),
              SizedBox(height: gap),
              _buildFlaxStatusCard(),
              SizedBox(height: gap),
              _buildRecentActivityCard(),
            ],
          );
        }

        final columns = width < _desktopBreakpoint ? 2 : 3;
        final itemWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(width: itemWidth, child: _buildFlaxOverviewCard()),
            SizedBox(width: itemWidth, child: _buildFlaxStatusCard()),
            SizedBox(width: itemWidth, child: _buildRecentActivityCard()),
          ],
        );
      },
    );
  }

  // ==========================================================
  // DONUT CHART
  // ==========================================================

  Widget _buildFlaxOverviewCard() {
    final assigned = _number(overview?["assigned"]);
    final available = _number(overview?["available"]);
    final underMaintenance = _number(overview?["under_maintenance"]);
    final total = assigned + available + underMaintenance;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isSmallPhone = width < 380;
        final isPhone = width < 600;

        // Mobile uses a vertical composition: the donut gets the full
        // visual focus and the three states become compact status tiles.
        // This avoids squeezing the legend beside the donut at 320px.
        final height = isSmallPhone
            ? 235.0
            : isPhone
                ? 250.0
                : 280.0;

        return _dashboardCard(
          height: height,
          title: "Flax Overview",
          child: isPhone
              ? _buildMobileFlaxOverview(
                  assigned: assigned,
                  available: available,
                  underMaintenance: underMaintenance,
                  total: total,
                  compact: isSmallPhone,
                )
              : _buildDesktopFlaxOverview(
                  assigned: assigned,
                  available: available,
                  underMaintenance: underMaintenance,
                  total: total,
                ),
        );
      },
    );
  }

  Widget _buildMobileFlaxOverview({
    required int assigned,
    required int available,
    required int underMaintenance,
    required int total,
    required bool compact,
  }) {
    final chartSize = compact ? 86.0 : 98.0;

    return Column(
      children: [
        SizedBox(
          width: chartSize,
          height: chartSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: compact ? 32 : 36,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      color: const Color(0xFF10B981),
                      value: assigned.toDouble(),
                      radius: compact ? 15 : 17,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      color: const Color(0xFF1D5CFF),
                      value: available.toDouble(),
                      radius: compact ? 15 : 17,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      color: const Color(0xFFF59E0B),
                      value: underMaintenance.toDouble(),
                      radius: compact ? 15 : 17,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total.toString(),
                    style: TextStyle(
                      fontSize: compact ? 20 : 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    "Total",
                    style: TextStyle(
                      fontSize: 8.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 5 : 7),
        Row(
          children: [
              Expanded(
                child: _mobileOverviewTile(
                  label: "Assigned",
                  value: assigned,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _mobileOverviewTile(
                  label: "Available",
                  value: available,
                  color: const Color(0xFF1D5CFF),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _mobileOverviewTile(
                  label: "Maintenance",
                  value: underMaintenance,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _mobileOverviewTile({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFlaxOverview({
    required int assigned,
    required int available,
    required int underMaintenance,
    required int total,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      color: const Color(0xFF10B981),
                      value: assigned.toDouble(),
                      radius: 18,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      color: const Color(0xFF1D5CFF),
                      value: available.toDouble(),
                      radius: 18,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      color: const Color(0xFFF59E0B),
                      value: underMaintenance.toDouble(),
                      radius: 18,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Total",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _donutLegendRow("Assigned", assigned, const Color(0xFF10B981), total),
              const SizedBox(height: 18),
              _donutLegendRow("Available", available, const Color(0xFF1D5CFF), total),
              const SizedBox(height: 18),
              _donutLegendRow("Under Maintenance", underMaintenance, const Color(0xFFF59E0B), total),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // DONUT LEGEND
  // ==========================================================

  Widget _donutLegendRow(
    String label,
    int value,
    Color color,
    int total,
  ) {
    final percentage =
        total > 0 ? ((value / total) * 100).toStringAsFixed(0) : "0";

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
            ),
          ),
        ),
        Text(
          "$value",
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "($percentage%)",
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // BAR CHART
  // ==========================================================

  Widget _buildFlaxStatusCard() {
    final assigned = _number(
      overview?["assigned"],
    );

    final available = _number(
      overview?["available"],
    );

    final underMaintenance = _number(
      overview?["under_maintenance"],
    );

    final total = assigned + available + underMaintenance;

    final maxY = total > 0 ? (total * 1.2).ceilToDouble() : 10.0;

    return Container(
      height: MediaQuery.sizeOf(context).width < 380
          ? 235
          : MediaQuery.sizeOf(context).width < 600
              ? 250
              : 280,
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Flax Condition",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      total > 0 ? (total / 5).clamp(1, double.infinity) : 2,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0xFFE2E8F0),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        String label;

                        switch (value.toInt()) {
                          case 0:
                            label = "Total";
                            break;

                          case 1:
                            label = "Assigned";
                            break;

                          case 2:
                            label = "Available";
                            break;

                          case 3:
                            label = "Maintenance";
                            break;

                          default:
                            label = "";
                        }

                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: MediaQuery.sizeOf(context).width < 600 ? 8 : 10,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: total.toDouble(),
                        width: 30,
                        color: const Color(0xFF10B981),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: assigned.toDouble(),
                        width: 30,
                        color: const Color(0xFF3B82F6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: available.toDouble(),
                        width: 30,
                        color: const Color(0xFF9333EA),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(
                        toY: underMaintenance.toDouble(),
                        width: 30,
                        color: const Color(0xFFF59E0B),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RECENT ACTIVITY
  // ==========================================================

  Widget _buildRecentActivityCard() {
    final activities = recentActivity.take(4).toList();

    return _dashboardCard(
      height: 280,
      title: "Recent Activity",
      trailing: TextButton(
        onPressed: () {},
        child: const Text("View All"),
      ),
      child: activities.isEmpty
          ? const Center(
              child: Text(
                "No recent activity",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: activities.length,
              separatorBuilder: (context, index) {
                return const Divider(
                  height: 18,
                );
              },
              itemBuilder: (context, index) {
                final activity = activities[index];

                final message = _text(
                  activity["message"],
                  fallback: "Activity",
                );

                final type = _text(
                  activity["activity_type"],
                  fallback: "System",
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0EDFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: Color(0xFF1D5CFF),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            type,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ==========================================================
  // BOTTOM SECTION
  // ==========================================================

  Widget _buildBottomTablesAndDesignsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = width < _phoneBreakpoint ? 12.0 : 16.0;

        if (width < 900) {
          return Column(
            children: [
              _buildRecentAssignmentsTableCard(),
              SizedBox(height: gap),
              _buildTopDesignUsageCard(),
            ],
          );
        }

        final leftWidth = (width - gap) * 0.64;
        final rightWidth = width - gap - leftWidth;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: leftWidth, child: _buildRecentAssignmentsTableCard()),
            SizedBox(width: gap),
            SizedBox(width: rightWidth, child: _buildTopDesignUsageCard()),
          ],
        );
      },
    );
  }

  // ==========================================================
  // RECENT ASSIGNMENTS
  // ==========================================================

  // ==========================================================
// RECENT ASSIGNMENTS
// ==========================================================

  Widget _buildRecentAssignmentsTableCard() {
  final assignments = recentAssignments.take(5).toList();

  return _dashboardCard(
    height: 330,
    title: "Recent Flax Assignments",
    child: assignments.isEmpty
        ? const Center(
            child: Text(
              "No recent assignments",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          )
        : Scrollbar(
            controller: _recentAssignmentsScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _recentAssignmentsScrollController,
              primary: false,
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFF8FAFC),
                  ),
                  columnSpacing: 32,
                  columns: const [
                    DataColumn(
                      label: Text("Sl. No"),
                    ),
                    DataColumn(
                      label: Text("Flax No"),
                    ),
                    DataColumn(
                      label: Text("Flax Size"),
                    ),
                    DataColumn(
                      label: Text("Design"),
                    ),
                    DataColumn(
                      label: Text("Tree No"),
                    ),
                    DataColumn(
                      label: Text("Condition"),
                    ),
                  ],
                  rows: List.generate(
                    assignments.length,
                    (index) {
                      final item = assignments[index];

                      final status = _text(
                        item["process_status"],
                        fallback: "Released",
                      );

                      final statusLower =
                          status.trim().toLowerCase();

                      final isActive =
                          statusLower == "released" ||
                          statusLower == "not_released";

                      final condition =
                          isActive ? "Released" : "Not Released";

                      return DataRow(
                        cells: [
                          DataCell(
                            Text("${index + 1}"),
                          ),
                          DataCell(
                            Text(
                              _text(item["flax_no"]),
                            ),
                          ),
                          DataCell(
                            Text(
                              _text(item["flax_size"]),
                            ),
                          ),
                          DataCell(
                            Text(
                              _text(item["design_name"]),
                            ),
                          ),
                          DataCell(
                            Text(
                              _text(item["tree_no"]),
                            ),
                          ),
                          DataCell(
                            _conditionChip(
                              condition,
                              isActive,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
  );
}

  // ==========================================================
  // CONDITION CHIP
  // ==========================================================

  Widget _conditionChip(
    String condition,
    bool isActive,
  ) {
    final color = isActive ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    final background =
        isActive ? const Color(0xFFE1F6EB) : const Color(0xFFFFF7E6);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        condition,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================================
  // TOP DESIGN USAGE
  // ==========================================================

  Widget _buildTopDesignUsageCard() {
    final designs = designUsage.take(5).toList();

    int maximum = 0;

    for (final design in designs) {
      final count = _number(design["count"]);

      if (count > maximum) {
        maximum = count;
      }
    }

    if (maximum == 0) {
      maximum = 1;
    }

    return _dashboardCard(
      height: 330,
      title: "Top Design by Flax Usage",
      trailing: TextButton(
        onPressed: () {},
        child: const Text("View Report"),
      ),
      child: designs.isEmpty
          ? const Center(
              child: Text(
                "No design usage information",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: designs.map(
                (design) {
                  final name = _text(
                    design["design_name"],
                    fallback: "Design",
                  );

                  final count = _number(design["count"]);

                  final progress = count / maximum;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              count.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: const Color(
                              0xFFF1F5F9,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF06B6D4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
    );
  }

  // ==========================================================
  // COMMON DASHBOARD CARD
  // ==========================================================
  //
  // IMPORTANT:
  // This version always provides a finite height.
  // This prevents the unbounded-height RenderFlex error.
  //
  // ==========================================================

  Widget _dashboardCard({
    String? title,
    Widget? trailing,
    Widget? child,
    double height = 280,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 420 ? 14.0 : 20.0;

        return Container(
          height: height,
          padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          if (title != null) const SizedBox(height: 16),
          if (child != null)
            Expanded(
              child: child,
            ),
        ],
      ),
        );
      },
    );
  }
}