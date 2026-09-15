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


  final ScrollController _recentAssignmentsScrollController =
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FD),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopNavigationBar(),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return Center(
        child: _buildErrorState(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth - 48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMetricCardsRow(),
                const SizedBox(height: 24),
                _buildMiddleChartsAndActivityGrid(),
                const SizedBox(height: 24),
                _buildBottomTablesAndDesignsGrid(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline,
          size: 60,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        const Text(
          "Unable to load dashboard",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 500,
          child: Text(
            error ?? "Unknown error",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: loadDashboard,
          icon: const Icon(Icons.refresh),
          label: const Text("Retry"),
        ),
      ],
    );
  }

  // ==========================================================
  // SIDEBAR
  // ==========================================================

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: const Color(0xFF0D2353),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(
                  Icons.diamond_outlined,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Kalpana Enterprises",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Crafting Excellence",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sidebarItem(
            Icons.dashboard,
            "Dashboard",
            AppSection.dashboard,
          ),
          _sidebarItem(
            Icons.layers_outlined,
            "Flax Master",
            AppSection.flaxMaster,
          ),
          _sidebarItem(
            Icons.account_tree_outlined,
            "Create Tree",
            AppSection.treeMaster,
          ),
          _sidebarItem(
            Icons.account_tree_outlined,
            "Flax Assign to Tree",
            AppSection.flaxAssignToTree,
          ),
          _sidebarItem(
            Icons.check_circle_outline,
            "Tree Casting",
            AppSection.flaxRelease,
          ),
          _sidebarReportsGroup(),
          _sidebarItem(
            Icons.settings_outlined,
            "Settings",
            AppSection.settings,
          ),
        ],
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

  Widget _buildTopNavigationBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sectionTitle(_section),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _sectionSubtitle(_section),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                _formattedDate(_now),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 20),
              const Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                _formattedTime(_now),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _refreshCurrentSection,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Account',
                offset: const Offset(0, 44),
                onSelected: (value) {
                  if (value == 'logout') {
                    _logout();
                  }
                },
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                        _userName.isEmpty ? 'User' : _userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Log Out',
                            style: TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE2E8F0),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isEmpty ? "..." : _userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _userRole.isEmpty ? "" : _userRole,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // METRIC CARDS
  // ==========================================================

  Widget _buildMetricCardsRow() {
    final total = _number(
      summary?["total_flax"],
    );

    final assigned = _number(
      summary?["assigned_flax"],
    );

    final available = _number(
      summary?["available_flax"],
    );

    final underMaintenance = _number(
      summary?["under_maintenance_flax"],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _metricCard(
            title: "Total Flax",
            value: total.toString(),
            subtitle: "All Flax",
            icon: Icons.inventory_2_outlined,
            iconBackground: const Color(0xFFE0EDFF),
            iconColor: const Color(0xFF1D5CFF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _metricCard(
            title: "Assigned Flax",
            value: assigned.toString(),
            subtitle: "Assigned to Tree",
            icon: Icons.check_circle_outline,
            iconBackground: const Color(0xFFE1F6EB),
            iconColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _metricCard(
            title: "Available Flax",
            value: available.toString(),
            subtitle: "Not Assigned",
            icon: Icons.inventory_2_outlined,
            iconBackground: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFFA855F7),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _metricCard(
            title: "Under Maintenance",
            value: underMaintenance.toString(),
            subtitle: "Inactive Flax",
            icon: Icons.build_outlined,
            iconBackground: const Color(0xFFFFF7E6),
            iconColor: const Color(0xFFF59E0B),
          ),
        ),
      ],
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
    return Container(
      height: 135,
      padding: const EdgeInsets.all(20),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MIDDLE SECTION
  // ==========================================================

  Widget _buildMiddleChartsAndActivityGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildFlaxOverviewCard(),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: _buildFlaxStatusCard(),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: _buildRecentActivityCard(),
        ),
      ],
    );
  }

  // ==========================================================
  // DONUT CHART
  // ==========================================================

  Widget _buildFlaxOverviewCard() {
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

    return _dashboardCard(
      height: 280,
      title: "Flax Overview",
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
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
                Center(
                  child: Column(
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
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _donutLegendRow(
                  "Assigned",
                  assigned,
                  const Color(0xFF10B981),
                  total,
                ),
                const SizedBox(height: 18),
                _donutLegendRow(
                  "Available",
                  available,
                  const Color(0xFF1D5CFF),
                  total,
                ),
                const SizedBox(height: 18),
                _donutLegendRow(
                  "Under Maintenance",
                  underMaintenance,
                  const Color(0xFFF59E0B),
                  total,
                ),
              ],
            ),
          ),
        ],
      ),
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
      height: 280,
      padding: const EdgeInsets.all(20),
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
                      reservedSize: 40,
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
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: _buildRecentAssignmentsTableCard(),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: _buildTopDesignUsageCard(),
        ),
      ],
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
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
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
  }
}