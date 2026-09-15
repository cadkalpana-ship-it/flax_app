import 'package:flutter/material.dart';

import '../models/assignment_history_entry.dart';
import '../models/flax.dart';
import '../services/api_service.dart';

class FlaxAssignment extends StatefulWidget {
  const FlaxAssignment({super.key});

  @override
  State<FlaxAssignment> createState() => FlaxAssignmentState();
}

class FlaxAssignmentState extends State<FlaxAssignment> {
  final ApiService _api = ApiService();

  final TextEditingController _treeNoController = TextEditingController();

  final TextEditingController _tableSearchController =
      TextEditingController();

  // ============================================================
  // AVAILABLE TREE MODULE DATA
  // ============================================================

  List<Map<String, dynamic>> _availableTrees = [];

  bool _loadingTreeNumbers = false;

  Map<String, dynamic>? _selectedTree;

  // ============================================================
  // AVAILABLE FLAX
  // ============================================================

  List<Flax> _availableFlaxes = [];

  bool _loading = true;

  String? _error;

  String? _selectedSize;

  String? _selectedFlaxNo;

  // ============================================================
  // HISTORY (real backend status: Assigned / Released / Removed)
  // ============================================================

  List<AssignmentHistoryEntry> _recentAssignments = [];

  bool _loadingHistory = true;

  bool _assigning = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadAvailable();
    _loadHistory();
    _fetchAvailableTrees();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _treeNoController.dispose();
    _tableSearchController.dispose();

    super.dispose();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refreshData() async {
    await Future.wait([
      _loadAvailable(),
      _loadHistory(),
      _fetchAvailableTrees(),
    ]);
  }

  // ============================================================
  // LOAD AVAILABLE TREE NUMBERS
  // ============================================================

  Future<void> _fetchAvailableTrees() async {
    if (!mounted) return;

    setState(() {
      _loadingTreeNumbers = true;
    });

    try {
      final trees = await _api.fetchAvailableTreeDetails();

      if (!mounted) return;

      setState(() {
        _availableTrees = trees;

        _loadingTreeNumbers = false;

        // If currently selected tree is no longer available,
        // clear it.
        final selectedTreeNo = _treeNoController.text.trim();

        final stillAvailable = _availableTrees.any(
          (tree) => tree['tree_no']?.toString().trim() == selectedTreeNo,
        );

        if (!stillAvailable) {
          _treeNoController.clear();
          _selectedTree = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _availableTrees = [];

        _loadingTreeNumbers = false;
      });

      _showError(
        'Failed to load available trees: $e',
      );
    }
  }

  // ============================================================
  // LOAD AVAILABLE FLAX
  // ============================================================

  Future<void> _loadAvailable() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final flaxes = await _api.fetchAllFlaxes(
        assignmentStatus: 'Available',
      );

      if (!mounted) return;

      setState(() {
        _availableFlaxes = flaxes;

        _loading = false;

        _sanitizeSelection();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;

        _error = e.toString();
      });
    }
  }

  // ============================================================
  // LOAD HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _loadingHistory = true;
    });

    try {
      final entries = await _api.fetchRecentAssignmentHistory();

      if (!mounted) return;

      setState(() {
        _recentAssignments = entries;

        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingHistory = false;
      });
    }
  }

  // ============================================================
  // REMOVE ASSIGNMENT
  // ============================================================

  Future<void> _removeAssignment(
    String flaxNo,
    String treeNo,
  ) async {
    final codeController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.link_off,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 10),
              Text('Remove Assignment'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remove the assignment of '
                  '$flaxNo from tree $treeNo?',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will make the FLX Available again. '
                  'It will NOT release the casting work.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Confirmation Code',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: codeController,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter confirmation code',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(
                  0xFFDC2626,
                ),
              ),
              onPressed: () {
                if (codeController.text.trim().isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(Icons.link_off),
              label: const Text(
                'Remove Assignment',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      codeController.dispose();
      return;
    }

    final code = codeController.text.trim();

    codeController.dispose();

    try {
      await _api.removeAssignment(
        flaxNo,
        code,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$flaxNo assignment removed '
            'from tree $treeNo',
          ),
        ),
      );

      // IMPORTANT:
      //
      // Released Tree Number must become
      // available again.
      await _loadAvailable();
      await _loadHistory();
      await _fetchAvailableTrees();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SANITIZE SELECTION
  // ============================================================

  void _sanitizeSelection() {
    if (_selectedSize != null && !_sizes.contains(_selectedSize)) {
      _selectedSize = null;
    }

    if (_selectedFlaxNo != null &&
        !_availableFlaxes.any(
          (f) => f.flaxNo == _selectedFlaxNo,
        )) {
      _selectedFlaxNo = null;
    }
  }

  // ============================================================
  // DERIVED STATE
  // ============================================================

  List<String> get _sizes {
    final sizes = _availableFlaxes.map((f) => f.flaxSize).toSet().toList();

    sizes.sort();

    return sizes;
  }

  List<Flax> get _namesForSelectedSize {
    if (_selectedSize == null) {
      return _availableFlaxes;
    }

    return _availableFlaxes
        .where(
          (f) => f.flaxSize == _selectedSize,
        )
        .toList();
  }

  Flax? get _selectedFlax {
    if (_selectedFlaxNo == null) {
      return null;
    }

    for (final f in _availableFlaxes) {
      if (f.flaxNo == _selectedFlaxNo) {
        return f;
      }
    }

    return null;
  }

  List<Flax> get _tableRows {
    final query = _tableSearchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _availableFlaxes;
    }

    return _availableFlaxes
        .where(
          (f) => f.flaxNo.toLowerCase().contains(query),
        )
        .toList();
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  void _onSizeChanged(
    String? size,
  ) {
    setState(() {
      _selectedSize = size;

      _selectedFlaxNo = null;
    });
  }

  void _onNameChanged(
    String? flaxNo,
  ) {
    setState(() {
      _selectedFlaxNo = flaxNo;
    });
  }

  void _selectRowIntoForm(
    Flax flax,
  ) {
    setState(() {
      _selectedSize = flax.flaxSize;

      _selectedFlaxNo = flax.flaxNo;
    });
  }

  // ============================================================
  // SELECT TREE
  // ============================================================

  void _selectTree(
    String treeNo,
  ) {
    Map<String, dynamic>? selected;

    for (final tree in _availableTrees) {
      final currentTreeNo = tree['tree_no']?.toString().trim() ?? '';

      if (currentTreeNo == treeNo) {
        selected = tree;
        break;
      }
    }

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedTree = selected;

      _treeNoController.text = selected!['tree_no']?.toString() ?? '';
    });
  }

  // ============================================================
  // CAN ASSIGN
  // ============================================================

  bool get _canAssign =>
      _selectedFlaxNo != null &&
      _treeNoController.text.trim().isNotEmpty &&
      !_assigning;

  // ============================================================
  // ASSIGN
  // ============================================================

  Future<void> _assign() async {
    if (!_canAssign) return;

    final treeNo = _treeNoController.text.trim();

    final flaxNo = _selectedFlaxNo!;

    // ----------------------------------------------------------
    // Extra frontend safety check.
    //
    // Even though backend also validates availability,
    // don't allow a Tree Number that isn't currently returned
    // by available-trees.
    // ----------------------------------------------------------

    final treeIsAvailable = _availableTrees.any(
      (tree) => tree['tree_no']?.toString().trim() == treeNo,
    );

    if (!treeIsAvailable) {
      _showError(
        'Tree $treeNo is no longer available.',
      );

      await _fetchAvailableTrees();

      return;
    }

    setState(() {
      _assigning = true;
    });

    try {
      await _api.assignToTree(
        flaxNo,
        treeNo: treeNo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$flaxNo assigned to $treeNo',
          ),
        ),
      );

      setState(() {
        _selectedFlaxNo = null;

        _selectedSize = null;

        _treeNoController.clear();

        _selectedTree = null;

        _assigning = false;
      });

      // --------------------------------------------------------
      // VERY IMPORTANT
      //
      // Assignment has now happened in DB.
      //
      // Reload available Tree Numbers.
      //
      // The assigned Tree Number will disappear from dropdown.
      // --------------------------------------------------------

      await _fetchAvailableTrees();

      await _loadAvailable();

      await _loadHistory();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _assigning = false;
      });

      _showError(e);
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    Object e,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString(),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                0.03,
              ),
              blurRadius: 10,
              offset: const Offset(
                0,
                3,
              ),
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
                padding: const EdgeInsets.all(
                  20,
                ),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _error != null
                        ? _buildErrorState()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildToolbar(),
                              const SizedBox(
                                height: 16,
                              ),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _buildAvailableTable(),
                                    ),
                                    const SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: _buildAssignmentDetails(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Error: $_error',
          ),
          const SizedBox(
            height: 12,
          ),
          ElevatedButton.icon(
            onPressed: _loadAvailable,
            icon: const Icon(
              Icons.refresh,
            ),
            label: const Text(
              'Retry',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BANNER
  // ============================================================

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 18,
      ),
      color: const Color(0xFFF5F8FF),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(
              8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                8,
              ),
              border: Border.all(
                color: const Color(
                  0xFFE2E8F0,
                ),
              ),
            ),
            child: const Icon(
              Icons.link,
              color: Color(0xFF1D5CFF),
              size: 20,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'FLX Assignment – Tree Casting',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(
                height: 2,
              ),
              Text(
                'Assign available FLX to a tree for casting. '
                '(Select FLX size, FLX name and Tree number)',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOOLBAR
  // ============================================================

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color: const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _buildSizeDropdown(),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: _buildNameDropdown(),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: _buildTreeNumberField(),
          ),
          const SizedBox(
            width: 12,
          ),
          FilledButton.icon(
            onPressed: _canAssign ? _assign : null,
            icon: _assigning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.link,
                    size: 18,
                  ),
            label: Text(
              _assigning ? 'Assigning...' : 'Assign FLX',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(
                0xFF1D5CFF,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LABELED FIELD
  // ============================================================

  Widget _labeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        child,
      ],
    );
  }

  // ============================================================
  // FIELD DECORATION
  // ============================================================

  InputDecoration _fieldDecoration(
    String hint,
  ) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          8,
        ),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          8,
        ),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  // ============================================================
  // SIZE DROPDOWN
  // ============================================================

  Widget _buildSizeDropdown() {
    final validSize = _sizes.contains(
      _selectedSize,
    )
        ? _selectedSize
        : null;

    return _labeledField(
      label: 'FLX Size',
      child: DropdownButtonFormField<String?>(
        value: validSize,
        decoration: _fieldDecoration(
          'All Sizes',
        ),
        hint: const Text(
          'All Sizes',
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text(
              'All Sizes',
            ),
          ),
          ..._sizes.map(
            (size) => DropdownMenuItem<String?>(
              value: size,
              child: Text(size),
            ),
          ),
        ],
        onChanged: _onSizeChanged,
      ),
    );
  }

  // ============================================================
  // FLX NAME DROPDOWN
  // ============================================================

  Widget _buildNameDropdown() {
    final names = _namesForSelectedSize;

    final validValue = names.any(
      (f) => f.flaxNo == _selectedFlaxNo,
    )
        ? _selectedFlaxNo
        : null;

    return _labeledField(
      label: 'FLX Name',
      child: DropdownButtonFormField<String?>(
        value: validValue,
        decoration: _fieldDecoration(
          'Select FLX Name',
        ),
        hint: const Text(
          'Select FLX Name',
        ),
        items: names
            .map(
              (f) => DropdownMenuItem<String?>(
                value: f.flaxNo,
                child: Text(f.flaxNo),
              ),
            )
            .toList(),
        onChanged: _onNameChanged,
      ),
    );
  }

  // ============================================================
  // TREE NUMBER DROPDOWN
  // ============================================================

  Widget _buildTreeNumberField() {
    final selectedTreeNo = _treeNoController.text.trim();

    final validSelectedValue = _availableTrees.any(
      (tree) => tree['tree_no']?.toString().trim() == selectedTreeNo,
    )
        ? selectedTreeNo
        : null;

    return _labeledField(
      label: 'Tree Number',
      child: DropdownButtonFormField<String>(
        value: validSelectedValue,
        isExpanded: true,
        decoration: _fieldDecoration(
          _loadingTreeNumbers
              ? 'Loading available trees...'
              : 'Select tree number',
        ),
        items: _availableTrees.map(
          (tree) {
            final treeNo = tree['tree_no']?.toString().trim() ?? '';

            return DropdownMenuItem<String>(
              value: treeNo,
              child: Text(treeNo),
            );
          },
        ).toList(),
        onChanged: _loadingTreeNumbers
            ? null
            : (value) {
                if (value == null) {
                  return;
                }

                _selectTree(
                  value,
                );
              },
      ),
    );
  }

  // ============================================================
  // AVAILABLE FLX TABLE
  // ============================================================

  Widget _buildAvailableTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color: const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      padding: const EdgeInsets.all(
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storage,
                size: 16,
                color: Color(0xFF1D5CFF),
              ),
              const SizedBox(
                width: 8,
              ),
              const Text(
                'Available FLX',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _tableSearchController,
                  onChanged: (_) => setState(
                    () {},
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search FLX Name...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 16,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        8,
                      ),
                      borderSide: const BorderSide(
                        color: Color(
                          0xFFE2E8F0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          _buildTableHeaderRow(),
          const Divider(
            height: 1,
          ),
          Expanded(
            child: _tableRows.isEmpty
                ? const Center(
                    child: Text(
                      'No available flax',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _tableRows.length,
                    separatorBuilder: (
                      context,
                      index,
                    ) =>
                        const Divider(
                      height: 1,
                    ),
                    itemBuilder: (
                      context,
                      index,
                    ) =>
                        _buildTableDataRow(
                      _tableRows[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static const List<int> _tableFlexes = [
    3,
    2,
    2,
    1,
  ];

  Widget _buildTableHeaderRow() {
    const headers = [
      'FLX Name',
      'FLX Size',
      'Tree Number',
      'Action',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: List.generate(
          headers.length,
          (i) {
            return Expanded(
              flex: _tableFlexes[i],
              child: Text(
                headers[i],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF475569),
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
  ) {
    final isSelected = flax.flaxNo == _selectedFlaxNo;

    return Container(
      color: isSelected ? const Color(0xFFEFF6FF) : null,
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            flex: _tableFlexes[0],
            child: Text(
              flax.flaxNo,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: _tableFlexes[1],
            child: Text(
              flax.flaxSize,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: _tableFlexes[2],
            child: const Text(
              '-',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: _tableFlexes[3],
            child: IconButton(
              onPressed: () => _selectRowIntoForm(
                flax,
              ),
              icon: const Icon(
                Icons.arrow_circle_right_outlined,
                size: 20,
                color: Color(
                  0xFF1D5CFF,
                ),
              ),
              tooltip: 'Select this FLX',
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ASSIGNMENT DETAILS
  // ============================================================

  Widget _buildAssignmentDetails() {
    final flax = _selectedFlax;

    final treeNo = _treeNoController.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color: const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      padding: const EdgeInsets.all(
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.link,
                size: 16,
                color: Color(0xFF1D5CFF),
              ),
              SizedBox(
                width: 8,
              ),
              Text(
                'Assignment Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          if (flax != null) ...[
            _detailRow(
              'FLX Size',
              flax.flaxSize,
            ),
            const Divider(
              height: 20,
            ),
            _detailRow(
              'FLX Name',
              flax.flaxNo,
            ),
            const Divider(
              height: 20,
            ),
            _detailRow(
              'Tree Number',
              treeNo.isEmpty ? '-' : treeNo,
            ),
            const SizedBox(
              height: 20,
            ),
          ],
          const Row(
            children: [
              Icon(
                Icons.history,
                size: 15,
                color: Color(0xFF1D5CFF),
              ),
              SizedBox(
                width: 6,
              ),
              Text(
                'Recently Assigned',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          Expanded(
            child: _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Widget _buildHistoryList() {
    if (_loadingHistory) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      );
    }

    if (_recentAssignments.isEmpty) {
      return const Center(
        child: Text(
          'No assignments yet',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _recentAssignments.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
      ),
      itemBuilder: (context, index) {
        final entry = _recentAssignments[index];

        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(
                        0xFF0F172A,
                      ),
                    ),
                    children: [
                      TextSpan(
                        text: entry.flaxNo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: '  →  ',
                        style: TextStyle(
                          color: Color(
                            0xFF1D5CFF,
                          ),
                        ),
                      ),
                      TextSpan(
                        text: entry.treeNo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _historyStatusChip(entry.status),
              const SizedBox(
                width: 8,
              ),
              Text(
                entry.timeDisplay,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              // Only an ACTIVE (still "Assigned") entry can be removed.
              // Released/Removed entries are history — no action on them.
              if (entry.isActive)
                IconButton(
                  tooltip: 'Remove Assignment',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.link_off,
                    size: 18,
                    color: Color(
                      0xFFDC2626,
                    ),
                  ),
                  onPressed: () {
                    _removeAssignment(
                      entry.flaxNo,
                      entry.treeNo,
                    );
                  },
                )
              else
                const SizedBox(
                  width: 40,
                  height: 32,
                ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // HISTORY STATUS CHIP
  // ============================================================

  Widget _historyStatusChip(String status) {
    Color foreground;
    Color background;

    switch (status) {
      case 'Released':
        foreground = const Color(0xFF059669);
        background = const Color(0xFFE1F6EB);
        break;

      case 'Removed':
        foreground = const Color(0xFFDC2626);
        background = const Color(0xFFFEE2E2);
        break;

      case 'Assigned':
      default:
        foreground = const Color(0xFF2563EB);
        background = const Color(0xFFEFF6FF);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}