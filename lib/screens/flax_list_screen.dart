import 'package:flax_app/models/app_user.dart';
import 'package:flax_app/screens/add_flax_dialog.dart';
import 'package:flutter/material.dart';
import '../models/flax.dart';
import '../services/api_service.dart';

// Embeddable content for the "Flax Master" sidebar section — no Scaffold/
// AppBar of its own, so it drops straight into the dashboard's IndexedStack.
//
// Backend:
//   - Flax data is loaded page-by-page from the backend.
//   - The normal table still displays 50 records per page.
//   - ALL backend pages are also loaded into _allFlaxes so that the
//     frontend-only size dropdown can search the complete dataset.
//   - Size filtering is NOT sent to the backend.
//   - Assignment/status actions continue to use the real backend APIs.

class FlaxListView extends StatefulWidget {
  const FlaxListView({super.key});

  @override
  State<FlaxListView> createState() => FlaxListViewState();
}

class FlaxListViewState extends State<FlaxListView> {
  final ApiService _api = ApiService();

  AppUser? _currentUser;

  // ------------------------------------------------------------
  // PAGINATED DATA — currently displayed page
  // ------------------------------------------------------------

  List<Flax> _flaxes = [];

  // ------------------------------------------------------------
  // COMPLETE DATASET — used ONLY for frontend size filtering
  // ------------------------------------------------------------

  List<Flax> _allFlaxes = [];

  String? _nextUrl;
  String? _previousUrl;
  String? _currentUrl;

  int _totalCount = 0;
  int? _pageSize;
  int _currentPage = 1;

  String _statusFilter = 'All';
  String _selectedSize = 'All';

  bool _loading = true;
  bool _loadingAllFlaxes = false;

  String? _error;

  // ------------------------------------------------------------
  // SIZE LIST
  // ------------------------------------------------------------

  static const List<String> _flaxSizes = [
    '5x3',
    '5x3.5',
    '5x4',
    '5x4.5',
    '6x3',
    '6x3.5',
    '6x4',
    '6x4.5',
    '7x3',
    '7x3.5',
    '7x4',
    '7x4.5',
    '8x3',
    '8x3.5',
    '8x4',
    '8x4.5',
    '9x3',
    '9x3.5',
    '9x4',
    '9x4.5',
  ];

  // ------------------------------------------------------------
  // FILTERED DATA
  // ------------------------------------------------------------

  List<Flax> get _filteredFlaxes {
    List<Flax> result = _allFlaxes;

    // Frontend-only size filter.
    if (_selectedSize != 'All') {
      result = result.where((flax) {
        return flax.flaxSize.trim().toLowerCase() ==
            _selectedSize.trim().toLowerCase();
      }).toList();
    }

    // Frontend status filter.
    if (_statusFilter == 'Active') {
      result = result.where((flax) {
        return flax.assignmentStatus.trim().toLowerCase() !=
            'under maintenance';
      }).toList();
    } else if (_statusFilter == 'Inactive') {
      result = result.where((flax) {
        return flax.assignmentStatus.trim().toLowerCase() ==
            'under maintenance';
      }).toList();
    }

    return result;
  }

  // ------------------------------------------------------------
  // PAGINATED VIEW OF FILTERED DATA
  // ------------------------------------------------------------

  List<Flax> get _displayedFlaxes {
    // When no frontend filter is active, simply display the current
    // backend page. This keeps normal pagination exactly as before.
    if (_selectedSize == 'All' && _statusFilter == 'All') {
      return _flaxes;
    }

    // Once a frontend filter is active, paginate the COMPLETE
    // locally-loaded dataset.
    final pageSize = _pageSize ?? 50;

    final start = (_currentPage - 1) * pageSize;

    if (start >= _filteredFlaxes.length) {
      return [];
    }

    final end = (start + pageSize).clamp(0, _filteredFlaxes.length);

    return _filteredFlaxes.sublist(start, end);
  }

  int get _filteredTotalCount => _filteredFlaxes.length;

  int get _filteredPageCount {
    final pageSize = _pageSize ?? 50;

    if (_filteredTotalCount == 0) {
      return 1;
    }

    return ((_filteredTotalCount + pageSize - 1) / pageSize).ceil();
  }

  bool get _hasFrontendFilter =>
      _selectedSize != 'All' || _statusFilter != 'All';

  // ------------------------------------------------------------
  // INITIAL LOAD
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadPage();
  }

  Future<void> _loadCurrentUser() async {
  try {
    final user = await _api.getStoredAppUser();

    if (!mounted) return;

    setState(() {
      _currentUser = user;
    });
  } catch (e) {
    debugPrint('Failed to load current user: $e');
  }
}

bool get _isAdmin => _currentUser?.isAdmin == true;

  // ------------------------------------------------------------
  // PUBLIC REFRESH
  // ------------------------------------------------------------

  Future<void> refreshData() async {
    await _refreshAllData();
  }

  // ------------------------------------------------------------
  // LOAD CURRENT BACKEND PAGE
  // ------------------------------------------------------------

  Future<void> _loadPage({
    String? url,
    int page = 1,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.fetchFlaxesPage(url: url);

      if (!mounted) return;

      setState(() {
        _flaxes = result.results;

        _nextUrl = result.next;
        _previousUrl = result.previous;
        _currentUrl = url;

        _totalCount = result.count;
        _pageSize ??=
            result.results.isNotEmpty ? result.results.length : 50;

        _currentPage = page;
        _loading = false;
      });

      // Load the complete dataset in the background.
      //
      // This is deliberately separate from the current page request.
      // The table can therefore continue using the backend's normal
      // 50-record pagination while the complete dataset is collected
      // for frontend-only size filtering.
      if (_allFlaxes.isEmpty || _allFlaxes.length < result.count) {
        _loadAllFlaxes();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ------------------------------------------------------------
  // LOAD ALL FLAX RECORDS
  // ------------------------------------------------------------

  Future<void> _loadAllFlaxes() async {
    if (_loadingAllFlaxes) {
      return;
    }

    _loadingAllFlaxes = true;

    try {
      final List<Flax> all = [];

      String? nextUrl;

      // First request.
      var result = await _api.fetchFlaxesPage();

      all.addAll(result.results);
      nextUrl = result.next;

      // Continue requesting pages until Django returns no "next".
      while (nextUrl != null) {
        result = await _api.fetchFlaxesPage(url: nextUrl);

        all.addAll(result.results);
        nextUrl = result.next;
      }

      if (!mounted) return;

      setState(() {
        _allFlaxes = all;

        // Keep total count synchronized with the actual dataset
        // returned by the backend.
        _totalCount = all.length;
      });
    } catch (e) {
      // Do not destroy the current page if the background
      // full-dataset loading fails.
      //
      // The current page is still usable.
      debugPrint('Failed to load complete Flax dataset: $e');
    } finally {
      _loadingAllFlaxes = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  // ------------------------------------------------------------
  // NEXT / PREVIOUS
  // ------------------------------------------------------------

  void _goNext() {
    // If frontend filtering is active, paginate the locally
    // filtered complete dataset.
    if (_hasFrontendFilter) {
      final maxPage = _filteredPageCount;

      if (_currentPage < maxPage) {
        setState(() {
          _currentPage++;
        });
      }

      return;
    }

    // Normal backend pagination.
    if (_nextUrl != null) {
      _loadPage(
        url: _nextUrl,
        page: _currentPage + 1,
      );
    }
  }

  void _goPrevious() {
    // If frontend filtering is active, paginate locally.
    if (_hasFrontendFilter) {
      if (_currentPage > 1) {
        setState(() {
          _currentPage--;
        });
      }

      return;
    }

    // Normal backend pagination.
    if (_previousUrl != null) {
      _loadPage(
        url: _previousUrl,
        page: _currentPage - 1,
      );
    }
  }

  // ------------------------------------------------------------
  // ADD FLAX
  // ------------------------------------------------------------

  Future<void> _addFlax() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return const AddFlaxDialog();
      },
    );

    if (result == true) {
      await _refreshAllData();
    }
  }

  // ------------------------------------------------------------
  // EDIT FLAX DETAILS
  // ------------------------------------------------------------

  Future<void> _editFlaxDetails(Flax flax) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AddFlaxDialog(
          flax: flax,
        );
      },
    );

    if (result == true) {
      await _refreshAllData();
    }
  }

  // ------------------------------------------------------------
  // REFRESH CURRENT PAGE
  // ------------------------------------------------------------

  Future<void> _refreshCurrentPage() async {
    // Reload current backend page.
    await _loadPage(
      url: _currentUrl,
      page: _currentPage,
    );

    // Refresh complete dataset as well.
    await _loadAllFlaxes();
  }

  // ------------------------------------------------------------
  // REFRESH EVERYTHING
  // ------------------------------------------------------------

  Future<void> _refreshAllData() async {
    // Clear the local complete dataset first so newly-created,
    // edited or deleted records are reflected.
    setState(() {
      _allFlaxes = [];
    });

    await _loadPage();
  }

  // ------------------------------------------------------------
  // SIZE SELECTION
  // ------------------------------------------------------------

  void _onSizeChanged(String? value) {
    if (value == null) return;

    setState(() {
      _selectedSize = value;

      // Start filtered results from page 1.
      _currentPage = 1;
    });
  }

  // ------------------------------------------------------------
  // RESET
  // ------------------------------------------------------------

  void _onReset() {
    setState(() {
      _statusFilter = 'All';
      _selectedSize = 'All';
      _currentPage = 1;
    });

    _loadPage();
  }

  // ------------------------------------------------------------
  // STATUS FILTER
  // ------------------------------------------------------------

  Future<void> _showFilterMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter by Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            for (final option in const [
              'All',
              'Active',
              'Inactive',
            ])
              ListTile(
                title: Text(option),
                trailing: _statusFilter == option
                    ? const Icon(
                        Icons.check,
                        color: Color(0xFF1D5CFF),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context, option);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _statusFilter = selected;
        _currentPage = 1;
      });
    }
  }

  // ------------------------------------------------------------
  // ACTIONS
  // ------------------------------------------------------------

  Future<void> _setMaintenance(Flax flax) async {
    final controller = TextEditingController(
      text: flax.remarks,
    );

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Set ${flax.flaxNo} Under Maintenance',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (Optional)',
              hintText: 'e.g. Damaged, Old stock, Not in use',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (reason == null) {
      controller.dispose();
      return;
    }

    try {
      await _api.setAssignmentStatus(
        flax.flaxNo,
        FlaxAssignmentStatus.underMaintenance,
        remarks: reason,
      );

      await _refreshAllData();
    } catch (e) {
      _showError(e);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _toggleAssignment(Flax flax) async {
    final isInactive =
        flax.assignmentStatus.trim().toLowerCase() ==
            'under maintenance';

    if (isInactive) {
      try {
        await _api.setAssignmentStatus(
          flax.flaxNo,
          FlaxAssignmentStatus.available,
        );

        await _refreshAllData();
      } catch (e) {
        _showError(e);
      }

      return;
    }

    await _setMaintenance(flax);
  }

  Future<void> _editFlax(Flax flax) async {
    final isAvailable =
        flax.assignmentStatus == FlaxAssignmentStatus.available;

    if (isAvailable) {
      final treeNoController = TextEditingController();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Assign ${flax.flaxNo} to Tree',
          ),
          content: TextField(
            controller: treeNoController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Tree No.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      );

      if (confirmed == true &&
          treeNoController.text.trim().isNotEmpty) {
        try {
          await _api.assignToTree(
            flax.flaxNo,
            treeNo: treeNoController.text.trim(),
          );

          await _refreshAllData();
        } catch (e) {
          _showError(e);
        }
      }

      treeNoController.dispose();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(flax.flaxNo),
          content: Text(
            flax.treeNo != null && flax.treeNo!.isNotEmpty
                ? 'Currently assigned to tree ${flax.treeNo}. Release it?'
                : 'Currently assigned. Release it?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Release'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await _api.releaseFlax(flax.flaxNo);

          await _refreshAllData();
        } catch (e) {
          _showError(e);
        }
      }
    }
  }

  // ------------------------------------------------------------
  // ERROR
  // ------------------------------------------------------------

  void _showError(Object e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToolbar(),
                    const SizedBox(height: 16),
                    _buildResultCount(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildTableArea(),
                    ),
                    const SizedBox(height: 12),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BANNER
  // ------------------------------------------------------------

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 20,
      ),
      color: const Color(0xFF2C4870),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.dns_outlined,
                  color: Color(0xFF2C4870),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Flax Master List',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage all flax entries with size and status',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Complete dataset loading indicator.
          if (_loadingAllFlaxes)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading all flaxes...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

          // _buildBannerCount(),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text(
                'Kalpana Enterprises',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Better Process  |  Better Production',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  

  // ------------------------------------------------------------
  // RESULT COUNT
  // ------------------------------------------------------------

  Widget _buildResultCount() {
    final text = _hasFrontendFilter
        ? '${_filteredTotalCount} matching entries'
        : '${_totalCount} total entries';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          if (_loadingAllFlaxes) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TOOLBAR
  // ------------------------------------------------------------

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedSize,
            decoration: InputDecoration(
              labelText: 'Flax Size',
              hintText: 'Select size',
              prefixIcon: const Icon(
                Icons.straighten_outlined,
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: 'All',
                child: Text('All Sizes'),
              ),
              ..._flaxSizes.map(
                (size) => DropdownMenuItem<String>(
                  value: size,
                  child: Text(size),
                ),
              ),
            ],
            onChanged: _loadingAllFlaxes
                ? null
                : _onSizeChanged,
          ),
        ),
        const SizedBox(width: 12),
        if (_isAdmin)
        FilledButton.icon(
          onPressed: _addFlax,
          icon: const Icon(
            Icons.add,
            size: 18,
          ),
          label: const Text('Add New Flax'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1D5CFF),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _showFilterMenu,
          icon: const Icon(
            Icons.filter_alt_outlined,
            size: 18,
          ),
          label: const Text('Filter'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(
              color: Color(0xFFE2E8F0),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _onReset,
          icon: const Icon(
            Icons.refresh,
            size: 18,
          ),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(
              color: Color(0xFFE2E8F0),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // TABLE
  // ------------------------------------------------------------

  static const List<int> _flexes = [
    1, // Sl
    2, // Flax
    2, // Size
    2, // Condition
    2, // Created
    3, // Remarks
    2, // Action
  ];

  Widget _buildTableArea() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _loadPage(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final displayed = _displayedFlaxes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableHeaderRow(),
        const Divider(height: 1),
        Expanded(
          child: displayed.isEmpty
              ? Center(
                  child: Text(
                    _loadingAllFlaxes
                        ? 'Loading all flaxes...'
                        : 'No matching flaxes',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: displayed.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final pageSize = _pageSize ?? 50;

                    final slNo = _hasFrontendFilter
                        ? ((_currentPage - 1) * pageSize) +
                            index +
                            1
                        : ((_currentPage - 1) * pageSize) +
                            index +
                            1;

                    return _buildTableDataRow(
                      displayed[index],
                      slNo,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderRow() {
    const headers = [
      'Sl. No.',
      'Flax No.',
      'Size',
      'Condition',
      'Created Date',
      'Remarks',
      'Action',
    ];

    return Container(
      color: const Color(0xFFF1F5FE),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 8,
      ),
      child: Row(
        children: List.generate(
          headers.length,
          (i) {
            return Expanded(
              flex: _flexes[i],
              child: Text(
                headers[i],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTableDataRow(
    Flax flax,
    int slNo,
  ) {
    final isActive =
        flax.assignmentStatus.trim().toLowerCase() !=
            'under maintenance';

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 8,
      ),
      child: Row(
        children: [
          Expanded(
            flex: _flexes[0],
            child: Text('$slNo'),
          ),
          Expanded(
            flex: _flexes[1],
            child: Text(
              flax.flaxNo,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: _flexes[2],
            child: Text(flax.flaxSize),
          ),
          Expanded(
            flex: _flexes[3],
            child: _conditionPill(
              flax.condition,
            ),
          ),
          Expanded(
            flex: _flexes[4],
            child: Text(
              flax.createdDateDisplay,
            ),
          ),
          Expanded(
            flex: _flexes[5],
            child: Text(
              flax.remarks.isEmpty
                  ? '-'
                  : flax.remarks,
              style: TextStyle(
                fontSize: 12,
                color: flax.remarks.isEmpty
                    ? Colors.grey
                    : const Color(0xFF334155),
              ),
            ),
          ),
          Expanded(
            flex: _flexes[6],
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      _editFlaxDetails(flax),
                  icon: const Icon(
                    Icons.edit_square,
                    size: 18,
                    color: Color(0xFF1D5CFF),
                  ),
                  visualDensity:
                      VisualDensity.compact,
                ),
                Switch(
                  value: isActive,
                  onChanged: (_) =>
                      _toggleAssignment(flax),
                  activeThumbColor: Colors.white,
                  activeTrackColor:
                      const Color.fromARGB(
                    255,
                    71,
                    177,
                    0,
                  ),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor:
                      const Color.fromARGB(
                    255,
                    255,
                    29,
                    29,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CONDITION PILL
  // ------------------------------------------------------------

  Widget _conditionPill(
    String condition,
  ) {
    final isActive = condition == 'Active';

    final bg = isActive
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);

    final fg = isActive
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          condition,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FOOTER
  // ------------------------------------------------------------

  Widget _buildFooter() {
    if (_loading || _error != null) {
      return const SizedBox.shrink();
    }

    final pageSize = _pageSize ?? 50;

    final total = _hasFrontendFilter
        ? _filteredTotalCount
        : _totalCount;

    final maxPage = _hasFrontendFilter
        ? _filteredPageCount
        : (_totalCount == 0
            ? 1
            : ((_totalCount + pageSize - 1) / pageSize)
                .ceil());

    final displayedCount = _displayedFlaxes.length;

    final start = total == 0
        ? 0
        : ((_currentPage - 1) * pageSize) + 1;

    final end = total == 0
        ? 0
        : (start + displayedCount - 1)
            .clamp(0, total);

    final canGoPrevious = _hasFrontendFilter
        ? _currentPage > 1
        : _previousUrl != null;

    final canGoNext = _hasFrontendFilter
        ? _currentPage < maxPage
        : _nextUrl != null;

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _hasFrontendFilter
              ? 'Showing $start to $end of $total filtered entries'
              : 'Showing $start to $end of $_totalCount entries',
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.grey,
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed:
                  canGoPrevious ? _goPrevious : null,
              icon: const Icon(
                Icons.chevron_left,
              ),
            ),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1D5CFF),
                borderRadius:
                    BorderRadius.circular(6),
              ),
              child: Text(
                '$_currentPage',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed:
                  canGoNext ? _goNext : null,
              icon: const Icon(
                Icons.chevron_right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}