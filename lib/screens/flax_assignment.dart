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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isPhone = width < 700;
        final isDesktop = width >= 1100;
        final outerPadding = isPhone ? 10.0 : isDesktop ? 24.0 : 16.0;

        return Padding(
          padding: EdgeInsets.all(outerPadding),
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
                    padding: EdgeInsets.all(isPhone ? 10 : 20),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? _buildErrorState()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildToolbar(),
                                  SizedBox(height: isPhone ? 10 : 16),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, contentConstraints) {
                                        final contentWidth =
                                            contentConstraints.maxWidth;
                                        final stacked = contentWidth < 900;

                                        if (stacked) {
                                          return SingleChildScrollView(
                                            padding: EdgeInsets.only(
                                              bottom: isPhone ? 12 : 16,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _buildAvailableTable(
                                                  compactHeight: true,
                                                ),
                                                SizedBox(
                                                  height: isPhone ? 10 : 16,
                                                ),
                                                _buildAssignmentDetails(
                                                  compactHeight: true,
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _buildAvailableTable(),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              flex: 2,
                                              child: _buildAssignmentDetails(),
                                            ),
                                          ],
                                        );
                                      },
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
      },
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load assignment data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAvailable,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BANNER
  // ============================================================

  Widget _buildBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 560;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 12 : 24,
            vertical: isPhone ? 12 : 18,
          ),
          color: const Color(0xFFF5F8FF),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isPhone ? 7 : 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  Icons.link,
                  color: const Color(0xFF1D5CFF),
                  size: isPhone ? 18 : 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'FLX Assignment – Tree Casting',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: isPhone ? 14 : 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Assign available FLX to a tree for casting. '
                      '(Select FLX size, FLX name and Tree number)',
                      maxLines: isPhone ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: isPhone ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // TOOLBAR
  // ============================================================

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isPhone = width < 600;
        final isTablet = width >= 600 && width < 1000;
        final gap = isPhone ? 10.0 : 12.0;

        return Container(
          padding: EdgeInsets.all(isPhone ? 12 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: isPhone
                    ? width - 24
                    : isTablet
                        ? (width - 12) / 2
                        : (width - 36 - 130) / 3,
                child: _buildSizeDropdown(),
              ),
              SizedBox(
                width: isPhone
                    ? width - 24
                    : isTablet
                        ? (width - 12) / 2
                        : (width - 36 - 130) / 3,
                child: _buildNameDropdown(),
              ),
              SizedBox(
                width: isPhone
                    ? width - 24
                    : isTablet
                        ? (width - 12) / 2
                        : (width - 36 - 130) / 3,
                child: _buildTreeNumberField(),
              ),
              SizedBox(
                width: isPhone ? width - 24 : null,
                child: FilledButton.icon(
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
                      : const Icon(Icons.link, size: 18),
                  label: Text(_assigning ? 'Assigning...' : 'Assign FLX'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D5CFF),
                    minimumSize: Size(isPhone ? width - 24 : 130, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  List<Flax> get _filteredTableRows {
    final query = _tableSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _tableRows;

    return _tableRows.where((flax) {
      return flax.flaxNo.toLowerCase().contains(query) ||
          flax.flaxSize.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildAvailableTable({bool compactHeight = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final filteredCount = _filteredTableRows.length;

          return Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 19,
                        color: Color(0xFF1D5CFF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available FLX',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$filteredCount item${filteredCount == 1 ? '' : 's'} available for assignment',
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
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 250,
                        child: _buildTableSearchField(),
                      ),
                    ],
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 12),
                  _buildTableSearchField(),
                ],
                const SizedBox(height: 14),
                if (compactHeight)
                  SizedBox(
                    height: filteredCount == 0
                        ? 150
                        : (compact ? (filteredCount * 64.0).clamp(64.0, 260.0) : 190.0),
                    child: filteredCount == 0
                        ? _buildEmptyAvailableState()
                        : compact
                            ? ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: filteredCount,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _buildMobileAvailableCard(
                                    _filteredTableRows[index],
                                  );
                                },
                              )
                            : _buildDesktopAvailableTable(),
                  )
                else
                  Expanded(
                    child: filteredCount == 0
                        ? _buildEmptyAvailableState()
                        : compact
                            ? ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: filteredCount,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _buildMobileAvailableCard(
                                    _filteredTableRows[index],
                                  );
                                },
                              )
                            : _buildDesktopAvailableTable(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyAvailableState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF94A3B8),
              size: 25,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No FLX found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try another search or size filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAvailableCard(Flax flax) {
    final isSelected = flax.flaxNo == _selectedFlaxNo;

    return Material(
      color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectRowIntoForm(flax),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFDCEBFF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.inventory_2_outlined,
                  size: 18,
                  color: const Color(0xFF1D5CFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flax.flaxNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _infoChip(Icons.straighten_outlined, flax.flaxSize),
                        _infoChip(Icons.account_tree_outlined, 'Unassigned'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Select this FLX',
                onPressed: () => _selectRowIntoForm(flax),
                icon: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.arrow_circle_right_outlined,
                  color: const Color(0xFF1D5CFF),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAvailableTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: _buildTableHeaderRow(),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _filteredTableRows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _buildTableDataRow(_filteredTableRows[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSearchField() {
    final hasSearch = _tableSearchController.text.trim().isNotEmpty;

    return TextField(
      controller: _tableSearchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search FLX name...',
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
          color: Color(0xFF64748B),
        ),
        suffixIcon: hasSearch
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, size: 17),
                onPressed: () {
                  _tableSearchController.clear();
                  setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF93C5FD),
            width: 1.3,
          ),
        ),
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
      'FLX NAME',
      'FLX SIZE',
      'TREE',
      'ACTION',
    ];

    return Row(
      children: List.generate(
        headers.length,
        (i) => Expanded(
          flex: _tableFlexes[i],
          child: Text(
            headers[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: .4,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableDataRow(Flax flax) {
    final isSelected = flax.flaxNo == _selectedFlaxNo;

    return Material(
      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
      child: InkWell(
        onTap: () => _selectRowIntoForm(flax),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Expanded(
                flex: _tableFlexes[0],
                child: Text(
                  flax.flaxNo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Expanded(
                flex: _tableFlexes[1],
                child: Text(
                  flax.flaxSize,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              Expanded(
                flex: _tableFlexes[2],
                child: const Text(
                  'Unassigned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              Expanded(
                flex: _tableFlexes[3],
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => _selectRowIntoForm(flax),
                    icon: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.arrow_circle_right_outlined,
                      size: 21,
                      color: const Color(0xFF1D5CFF),
                    ),
                    tooltip: 'Select this FLX',
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ASSIGNMENT DETAILS
  // ============================================================

  Widget _buildAssignmentDetails({bool compactHeight = false}) {
    final flax = _selectedFlax;
    final treeNo = _treeNoController.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.link,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assignment Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Current FLX → Tree connection',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (flax != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (flax != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFEFF6FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCE6F4)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 390;

                  final flaxBox = _assignmentEntity(
                    icon: Icons.inventory_2_outlined,
                    label: 'FLX',
                    value: flax.flaxNo,
                    subtitle: flax.flaxSize,
                  );
                  final arrow = Icon(
                    compact ? Icons.keyboard_arrow_down : Icons.arrow_forward,
                    color: const Color(0xFF1D5CFF),
                    size: 22,
                  );
                  final treeBox = _assignmentEntity(
                    icon: Icons.account_tree_outlined,
                    label: 'TREE',
                    value: treeNo.isEmpty ? 'Not selected' : treeNo,
                    subtitle: treeNo.isEmpty
                        ? 'Choose a tree above'
                        : 'Ready for assignment',
                  );

                  if (compact) {
                    return Column(
                      children: [
                        flaxBox,
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF1D5CFF),
                            size: 20,
                          ),
                        ),
                        treeBox,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: flaxBox),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: arrow,
                      ),
                      Expanded(child: treeBox),
                    ],
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    color: Color(0xFF94A3B8),
                    size: 21,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select a FLX above to view its assignment details.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.history,
                size: 17,
                color: Color(0xFF1D5CFF),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Recently Assigned',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (_recentAssignments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_recentAssignments.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D5CFF),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (compactHeight)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: _buildHistoryList(shrinkWrap: true),
            )
          else
            Expanded(child: _buildHistoryList()),
        ],
      ),
    );
  }

  Widget _assignmentEntity({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF1D5CFF)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Widget _buildHistoryList({bool shrinkWrap = false}) {
    if (_loadingHistory) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_recentAssignments.isEmpty) {
      return const Center(
        child: Text(
          'No assignments yet',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;

        return ListView.separated(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: _recentAssignments.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = _recentAssignments[index];

            if (compact) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF0F172A),
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
                                    color: Color(0xFF1D5CFF),
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
                        if (entry.isActive)
                          IconButton(
                            tooltip: 'Remove Assignment',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.link_off,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            onPressed: () => _removeAssignment(
                              entry.flaxNo,
                              entry.treeNo,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _historyStatusChip(entry.status),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            entry.timeDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                        ),
                        children: [
                          TextSpan(
                            text: entry.flaxNo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text: '  →  ',
                            style: TextStyle(color: Color(0xFF1D5CFF)),
                          ),
                          TextSpan(
                            text: entry.treeNo,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _historyStatusChip(entry.status),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 0,
                    child: Text(
                      entry.timeDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (entry.isActive)
                    IconButton(
                      tooltip: 'Remove Assignment',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.link_off,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                      onPressed: () => _removeAssignment(
                        entry.flaxNo,
                        entry.treeNo,
                      ),
                    )
                  else
                    const SizedBox(width: 40, height: 32),
                ],
              ),
            );
          },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

