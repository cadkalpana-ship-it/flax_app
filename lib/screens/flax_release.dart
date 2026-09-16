import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/flax.dart';
import '../services/api_service.dart';

/// ============================================================
/// TREE CASTING / FLX RELEASE
/// ============================================================
///
/// Workflow:
///
/// 1. Load all currently ASSIGNED FLX.
/// 2. Tree Number dropdown shows only trees having assigned FLX.
/// 3. Select Tree Number.
/// 4. FLX Name dropdown automatically shows only FLX assigned
///    to that selected tree.
/// 5. Select FLX Name.
/// 6. Click RELEASE.
/// 7. Backend:
///
///    PATCH /api/flaxes/<flax_no>/release/
///
///    This releases the FLX from the tree and changes:
///
///      assignment_status = Available
///      process_status    = Released
///      tree_no           = ""
///      tree_id           = ""
///      released_on       = now
///
/// IMPORTANT (bug fix): the "Assigned FLX List" table below is a browse
/// view of ALL currently assigned flax — it must NOT collapse down to just
/// the one flax picked in the Tree Number / FLX Name dropdowns above. Those
/// dropdowns only decide what gets released when you hit the button (or
/// get populated when you tap a row); they must never hide the rest of the
/// list. Only the From/To date range is a real filter on this table.
/// ============================================================

class FlaxRelease extends StatefulWidget {
  const FlaxRelease({super.key});

  @override
  State<FlaxRelease> createState() => FlaxReleaseState();
}

class FlaxReleaseState extends State<FlaxRelease> {
  final ApiService _api = ApiService();

  final TextEditingController _fromDateController = TextEditingController();

  final TextEditingController _toDateController = TextEditingController();

  // ------------------------------------------------------------
  // TUNCH REPORT + IMAGE (captured at release time)
  // ------------------------------------------------------------

  final TextEditingController _topTunchController = TextEditingController();

  final TextEditingController _bottomTunchController =
      TextEditingController();

  final List<_PickedReleaseImage> _releaseImages = [];

  // ------------------------------------------------------------
  // DATA
  // ------------------------------------------------------------

  List<Flax> _allAssigned = [];

  List<Flax> _filteredAssigned = [];

  String? _selectedTreeNo;
  String? _selectedFlaxNo;

  Flax? _selectedFlax;

  bool _loading = true;
  bool _releasing = false;

  String? _error;

  int _currentPage = 1;

  static const int _pageSize = 10;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    final firstDay = DateTime(
      now.year,
      now.month,
      1,
    );

    _fromDateController.text = _formatDate(firstDay);
    _toDateController.text = _formatDate(now);

    _loadAssigned();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();

    _topTunchController.dispose();
    _bottomTunchController.dispose();

    super.dispose();
  }

  // ============================================================
  // TUNCH REPORT IMAGE PICKING
  // ============================================================

  Future<void> _pickReleaseImages() async {
    try {
      final picker = ImagePicker();

      final picked = await picker.pickMultiImage(
        imageQuality: 85,
      );

      if (picked.isEmpty) {
        return;
      }

      final newImages = <_PickedReleaseImage>[];

      for (final file in picked) {
        final bytes = await file.readAsBytes();

        if (bytes.isEmpty) {
          continue;
        }

        newImages.add(
          _PickedReleaseImage(
            file: file,
            bytes: bytes,
          ),
        );
      }

      if (!mounted || newImages.isEmpty) {
        return;
      }

      setState(() {
        _releaseImages.addAll(newImages);
      });
    } catch (e) {
      _showMessage(
        'Unable to select images: $e',
      );
    }
  }

  void _removeReleaseImage(int index) {
    setState(() {
      _releaseImages.removeAt(index);
    });
  }

  void _clearReleaseReportFields() {
    _topTunchController.clear();
    _bottomTunchController.clear();
    _releaseImages.clear();
  }

  // ============================================================
  // LOAD ASSIGNED FLX
  // ============================================================

  Future<void> _loadAssigned() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final List<Flax> rows = [];

      // IMPORTANT:
      // We need ASSIGNED records here, NOT Released records.
      //
      // These are the FLX records currently attached to trees.
      String? url = '${ApiService.baseUrl}/flaxes/?assignment_status=Assigned';

      // Follow DRF pagination.
      while (url != null) {
        final page = await _api.fetchFlaxesPage(
          url: url,
        );

        rows.addAll(
          page.results.where(
            (flax) {
              final status = flax.assignmentStatus.trim().toLowerCase();

              final treeNo = flax.treeNo?.trim() ?? '';

              return status == 'assigned' && treeNo.isNotEmpty;
            },
          ),
        );

        url = page.next;
      }

      // Sort:
      // Tree Number first
      // FLX Number second
      rows.sort(
        (a, b) {
          final treeCompare = (a.treeNo ?? '').compareTo(
            b.treeNo ?? '',
          );

          if (treeCompare != 0) {
            return treeCompare;
          }

          return a.flaxNo.compareTo(
            b.flaxNo,
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _allAssigned = rows;

        // Validate current tree selection.
        if (_selectedTreeNo != null &&
            !_treeNumbers.contains(
              _selectedTreeNo,
            )) {
          _selectedTreeNo = null;
          _selectedFlaxNo = null;
          _selectedFlax = null;
        }

        // Validate current FLX selection.
        if (_selectedTreeNo != null) {
          final validFlaxes = _flaxNumbersForTree(
            _selectedTreeNo!,
          );

          if (_selectedFlaxNo != null &&
              !validFlaxes.contains(
                _selectedFlaxNo,
              )) {
            _selectedFlaxNo = null;
            _selectedFlax = null;
          }
        } else {
          _selectedFlaxNo = null;
          _selectedFlax = null;
        }

        _currentPage = 1;

        _applyFilters(
          updateState: false,
        );

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> refreshData() async {
    await _loadAssigned();
  }
  // ============================================================
  // TREE NUMBERS
  // ============================================================

  List<String> get _treeNumbers {
    final values = _allAssigned
        .map(
          (flax) => flax.treeNo?.trim() ?? '',
        )
        .where(
          (treeNo) => treeNo.isNotEmpty,
        )
        .toSet()
        .toList();

    values.sort();

    return values;
  }

  // ============================================================
  // FLX NUMBERS FOR SELECTED TREE
  // ============================================================

  List<String> _flaxNumbersForTree(
    String treeNo,
  ) {
    final values = _allAssigned
        .where(
          (flax) {
            final status = flax.assignmentStatus.trim().toLowerCase();

            return status == 'assigned' && (flax.treeNo ?? '').trim() == treeNo;
          },
        )
        .map(
          (flax) => flax.flaxNo,
        )
        .toSet()
        .toList();

    values.sort();

    return values;
  }

  // ============================================================
  // FILTER
  // ============================================================
  //
  // BUG FIX: this used to also filter by _selectedTreeNo and
  // _selectedFlaxNo, which made the whole "Assigned FLX List" table
  // collapse down to a single row the moment you picked a Tree Number
  // above — hiding every other currently-assigned flax. The Tree/FLX
  // pickers are for choosing what to release, not for controlling what
  // this browse table displays. Only the date range is a real filter here.

  void _applyFilters({
    bool updateState = true,
  }) {
    final from = _parseDate(
      _fromDateController.text,
    );

    final to = _parseDate(
      _toDateController.text,
    );

    final fromDate = from == null
        ? null
        : DateTime(
            from.year,
            from.month,
            from.day,
          );

    final toDate = to == null
        ? null
        : DateTime(
            to.year,
            to.month,
            to.day,
            23,
            59,
            59,
            999,
          );

    final rows = _allAssigned.where(
      (flax) {
        // -------------------------
        // CASTING DATE
        // -------------------------
        //
        // Current backend doesn't have
        // casting_date.
        //
        // assigned_on is therefore used
        // as the casting/assignment date.

        final castingDate = _dateOnly(
          flax.assignedOn,
        );

        if (fromDate != null) {
          if (castingDate == null ||
              castingDate.isBefore(
                fromDate,
              )) {
            return false;
          }
        }

        if (toDate != null) {
          if (castingDate == null ||
              castingDate.isAfter(
                toDate,
              )) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    // Newest first.
    rows.sort(
      (a, b) {
        final aDate = a.assignedOn ??
            DateTime.fromMillisecondsSinceEpoch(
              0,
            );

        final bDate = b.assignedOn ??
            DateTime.fromMillisecondsSinceEpoch(
              0,
            );

        return bDate.compareTo(
          aDate,
        );
      },
    );

    if (updateState) {
      setState(() {
        _filteredAssigned = rows;
        _currentPage = 1;
      });
    } else {
      _filteredAssigned = rows;
    }
  }

  // ============================================================
  // TREE DROPDOWN
  // ============================================================

  void _onTreeChanged(
    String? value,
  ) {
    setState(() {
      _selectedTreeNo = value;

      // IMPORTANT:
      // Changing Tree must clear previous FLX.
      _selectedFlaxNo = null;
      _selectedFlax = null;

      _currentPage = 1;
    });

    // Note: no longer calls _applyFilters() to re-filter the table by
    // tree — the table isn't tree-filtered anymore. See _applyFilters()'s
    // doc comment above.
  }

  // ============================================================
  // FLX DROPDOWN
  // ============================================================

  void _onFlaxChanged(
    String? value,
  ) {
    Flax? selected;

    if (value != null) {
      for (final flax in _allAssigned) {
        if (flax.flaxNo == value) {
          selected = flax;
          break;
        }
      }
    }

    setState(() {
      _selectedFlaxNo = value;
      _selectedFlax = selected;
    });
  }

  // ============================================================
  // SELECT TABLE ROW
  // ============================================================

  void _selectRow(
    Flax flax,
  ) {
    final treeNo = flax.treeNo?.trim();

    setState(() {
      _selectedTreeNo = treeNo;
      _selectedFlaxNo = flax.flaxNo;
      _selectedFlax = flax;
    });

    // Table stays showing everything (within the date range) — tapping a
    // row only highlights it and populates the pickers/details panel.
  }

  // ============================================================
  // RELEASE
  // ============================================================

  Future<void> _releaseSelectedFlax() async {
    final flax = _selectedFlax;

    if (flax == null) {
      _showMessage(
        'Please select a Tree Number and FLX Name.',
      );

      return;
    }

    final treeNo = flax.treeNo?.trim() ?? '';

    final topTunch = _topTunchController.text.trim();
    final bottomTunch = _bottomTunchController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Release FLX',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                treeNo.isEmpty
                    ? 'Release ${flax.flaxNo}?'
                    : 'Release ${flax.flaxNo} from Tree $treeNo?',
              ),
              const SizedBox(height: 10),
              Text('Top Tunch Report: $topTunch'),
              Text('Bottom Tunch Report: $bottomTunch'),
              Text('Images attached: ${_releaseImages.length}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              icon: const Icon(
                Icons.check,
              ),
              label: const Text(
                'Release',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _releasing = true;
      _error = null;
    });

    try {
      // Release now also carries the Top/Bottom Tunch Report readings
      // and at least one image, sent as multipart/form-data in the
      // same request. See ApiService.releaseFlaxWithReport.
      await _api.releaseFlaxWithReport(
        flax.flaxNo,
        topTunchReport: topTunch,
        bottomTunchReport: bottomTunch,
        images: _releaseImages.map((image) => image.file).toList(),
      );

      if (!mounted) return;

      setState(() {
        _selectedTreeNo = null;
        _selectedFlaxNo = null;
        _selectedFlax = null;
        _releasing = false;
        _clearReleaseReportFields();
      });

      _showMessage(
        '${flax.flaxNo} released successfully.',
      );

      // Reload assigned FLX.
      //
      // The released FLX will automatically disappear
      // from the Tree/FLX dropdowns AND the table because it is now
      // Available (not Assigned), which is the correct behavior — this
      // is different from the earlier bug, since a released flax should
      // genuinely leave this "currently assigned" list.
      await _loadAssigned();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _releasing = false;
      });

      _showMessage(
        'Release failed: $e',
      );
    }
  }

  // ============================================================
  // BUTTON ACTION
  // ============================================================

  void _onReleaseButtonPressed() {
    final from = _parseDate(
      _fromDateController.text,
    );

    final to = _parseDate(
      _toDateController.text,
    );

    if (from != null && to != null && from.isAfter(to)) {
      _showMessage(
        'From Date cannot be after To Date.',
      );

      return;
    }

    if (_selectedTreeNo == null || _selectedTreeNo!.isEmpty) {
      _showMessage(
        'Please select a Tree Number.',
      );

      return;
    }

    if (_selectedFlaxNo == null || _selectedFlaxNo!.isEmpty) {
      _showMessage(
        'Please select an FLX Name.',
      );

      return;
    }

    if (_topTunchController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the Top Tunch Report.',
      );

      return;
    }

    if (_bottomTunchController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the Bottom Tunch Report.',
      );

      return;
    }

    if (_releaseImages.isEmpty) {
      _showMessage(
        'Please attach at least one image before releasing.',
      );

      return;
    }

    _releaseSelectedFlax();
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _pickDate(
    TextEditingController controller,
  ) async {
    final initial = _parseDate(
          controller.text,
        ) ??
        DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (
        context,
        child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(
                0xFF1976E8,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    controller.text = _formatDate(picked);

    _applyFilters();
  }

  // ============================================================
  // RESET
  // ============================================================

  void _resetFilters() {
    final now = DateTime.now();

    final firstDay = DateTime(
      now.year,
      now.month,
      1,
    );

    setState(() {
      _fromDateController.text = _formatDate(firstDay);

      _toDateController.text = _formatDate(now);

      _selectedTreeNo = null;
      _selectedFlaxNo = null;
      _selectedFlax = null;

      _currentPage = 1;
    });

    _applyFilters(
      updateState: false,
    );

    setState(() {});
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    String two(
      int value,
    ) {
      return value.toString().padLeft(2, '0');
    }

    return '${two(date.day)}-${two(date.month)}-${date.year}';
  }

  DateTime? _parseDate(
    String value,
  ) {
    final parts = value.trim().split('-');

    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);

    final month = int.tryParse(parts[1]);

    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) {
      return null;
    }

    return DateTime.tryParse(
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
  }

  DateTime? _dateOnly(
    DateTime? date,
  ) {
    if (date == null) {
      return null;
    }

    final local = date.toLocal();

    return DateTime(
      local.year,
      local.month,
      local.day,
    );
  }

  String _dateDisplay(
    DateTime? date,
  ) {
    if (date == null) {
      return '-';
    }

    return _formatDate(
      date.toLocal(),
    );
  }

  String _text(
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    return value.trim();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
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
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildPageHeader(),
          const SizedBox(
            height: 8,
          ),
          _buildFilterPanel(),
          const SizedBox(
            height: 12,
          ),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildMainContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // On phones and tablets the details area should have natural height
        // instead of being squeezed into a fixed fraction of the viewport.
        // That was the source of the clipped Tunch Report shown on screen.
        if (width < 900) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: width < 600 ? 390 : 450,
                  child: _buildAssignedListCard(),
                ),
                const SizedBox(height: 14),
                _buildDetailsCard(compact: width < 600),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: _buildAssignedListCard(),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: _buildDetailsCard(),
            ),
          ],
        );
      },
    );
  }



  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF3F9FF),
            Color(0xFFEAF4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD6E8FA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE0EDFF),
              borderRadius: BorderRadius.circular(
                9,
              ),
            ),
            child: const Icon(
              Icons.account_tree_outlined,
              color: Color(0xFF174A8B),
              size: 24,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FLX Release – After Casting',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF174A8B),
                  ),
                ),
                SizedBox(
                  height: 3,
                ),
                Text(
                  'Select an assigned tree and its FLX, then release it after casting.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF52708F),
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
  // FILTER PANEL
  // ============================================================

  Widget _buildFilterPanel() {
    final treeNumbers = _treeNumbers;

    final flaxNumbers = _selectedTreeNo == null
        ? <String>[]
        : _flaxNumbersForTree(
            _selectedTreeNo!,
          );

    final validTree = treeNumbers.contains(
      _selectedTreeNo,
    )
        ? _selectedTreeNo
        : null;

    final validFlax = flaxNumbers.contains(
      _selectedFlaxNo,
    )
        ? _selectedFlaxNo
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        15,
        18,
        15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE1EAF3),
        ),
      ),
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final compact = constraints.maxWidth < 900;

          final fromDateField = _dateField(
            label: 'From Date',
            controller: _fromDateController,
          );

          final toDateField = _dateField(
            label: 'To Date',
            controller: _toDateController,
          );

          final treeField = _dropdownField(
            label: 'Tree Number',
            hint: 'Select Tree Number',
            value: validTree,
            items: treeNumbers,
            onChanged: _onTreeChanged,
          );

          final flaxField = _dropdownField(
            label: 'FLX Name',
            hint: validTree == null
                ? 'Select Tree Number first'
                : flaxNumbers.isEmpty
                    ? 'No FLX assigned'
                    : 'Select FLX Name',
            value: validFlax,
            items: flaxNumbers,
            enabled: validTree != null && flaxNumbers.isNotEmpty,
            onChanged: _onFlaxChanged,
          );

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: fromDateField,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: toDateField,
                    ),
                  ],
                ),
                const SizedBox(
                  height: 12,
                ),
                Row(
                  children: [
                    Expanded(
                      child: treeField,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: flaxField,
                    ),
                  ],
                ),
                const SizedBox(
                  height: 12,
                ),
                _releaseButton(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: fromDateField,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: toDateField,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: treeField,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: flaxField,
              ),
              const SizedBox(
                width: 12,
              ),
              _releaseButton(),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // RELEASE BUTTON
  // ============================================================

  Widget _releaseButton() {
    final canRelease = !_loading &&
        !_releasing &&
        _selectedTreeNo != null &&
        _selectedFlaxNo != null &&
        _selectedFlax != null &&
        _topTunchController.text.trim().isNotEmpty &&
        _bottomTunchController.text.trim().isNotEmpty &&
        _releaseImages.isNotEmpty;

    return SizedBox(
      height: 42,
      width: 135,
      child: FilledButton.icon(
        onPressed: canRelease ? _onReleaseButtonPressed : null,
        icon: _releasing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.check_circle_outline,
                size: 18,
              ),
        label: Text(
          _releasing ? 'Releasing...' : 'Release',
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1976E8),
          disabledBackgroundColor: const Color(0xFFB8C7D9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DATE FIELD
  // ============================================================

  Widget _dateField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF29496D),
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: () => _pickDate(controller),
          decoration: _fieldDecoration(
            controller.text,
            suffixIcon: const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: Color(0xFF466A90),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _dropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    final validValue = value != null && items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF29496D),
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        DropdownButtonFormField<String>(
          value: validValue,
          isExpanded: true,
          isDense: true,
          decoration: _fieldDecoration(hint),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  // ============================================================
  // FIELD DECORATION
  // ============================================================

  InputDecoration _fieldDecoration(
    String text, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: text,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: Color(0xFFDCE6F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: Color(0xFFDCE6F0),
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: Color(0xFFE5EAF0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: Color(0xFF1976E8),
          width: 1.4,
        ),
      ),
    );
  }

  // ============================================================
  // ASSIGNED FLX LIST
  // ============================================================

  Widget _buildAssignedListCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssignedHeader(),
          const SizedBox(
            height: 10,
          ),
          Expanded(
            child: _buildAssignedTable(),
          ),
          const SizedBox(
            height: 8,
          ),
          _buildPaginationFooter(),
        ],
      ),
    );
  }

  // ============================================================
  // LIST HEADER
  // ============================================================

  Widget _buildAssignedHeader() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE1F7EA),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF20A464),
            size: 22,
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        const Flexible(
          child: Text(
            'Assigned FLX List',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF193E68),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F6EA),
            borderRadius: BorderRadius.circular(
              18,
            ),
          ),
          child: Text(
            '${_filteredAssigned.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF238A5A),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget _buildAssignedTable() {
    final rows = _currentRows;

    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No assigned FLX found for the selected date range.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildTableHeader(),
        const Divider(
          height: 1,
          color: Color(0xFFE6EDF4),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: Color(0xFFE8EEF5),
            ),
            itemBuilder: (context, index) {
              final flax = rows[index];

              final slNo = ((_currentPage - 1) * _pageSize) + index + 1;

              return _buildTableRow(
                flax,
                slNo,
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _buildTableHeader() {
    const headers = [
      'No.',
      'FLX Name',
      'FLX Size',
      'Tree Number',
      'Casting Date',
      'Status',
    ];

    const flexes = [
      1,
      3,
      2,
      3,
      2,
      2,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 11,
      ),
      color: const Color(0xFFF0F6FC),
      child: Row(
        children: List.generate(
          headers.length,
          (index) {
            return Expanded(
              flex: flexes[index],
              child: Text(
                headers[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF24476C),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // TABLE ROW
  // ============================================================

  Widget _buildTableRow(
    Flax flax,
    int slNo,
  ) {
    const flexes = [
      1,
      3,
      2,
      3,
      2,
      2,
    ];

    final selected = _selectedFlax?.flaxNo == flax.flaxNo;

    return InkWell(
      onTap: () => _selectRow(flax),
      child: Container(
        color: selected
            ? const Color(
                0xFFF1F7FF,
              )
            : Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        child: Row(
          children: [
            Expanded(
              flex: flexes[0],
              child: Text(
                '$slNo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                ),
              ),
            ),
            Expanded(
              flex: flexes[1],
              child: Text(
                flax.flaxNo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF294B70),
                ),
              ),
            ),
            Expanded(
              flex: flexes[2],
              child: Text(
                flax.flaxSize,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                ),
              ),
            ),
            Expanded(
              flex: flexes[3],
              child: Text(
                _text(
                  flax.treeNo,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                ),
              ),
            ),
            Expanded(
              flex: flexes[4],
              child: Text(
                _castingDate(flax),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                ),
              ),
            ),
            Expanded(
              flex: flexes[5],
              child: _assignedChip(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ASSIGNED CHIP
  // ============================================================

  Widget _assignedChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFE2F6EA),
          borderRadius: BorderRadius.circular(
            16,
          ),
        ),
        child: const Text(
          'Assigned',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF238A5A),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CASTING DATE
  // ============================================================

  String _castingDate(
    Flax flax,
  ) {
    return _dateDisplay(
      flax.assignedOn,
    );
  }

  // ============================================================
  // PAGINATION
  // ============================================================

  List<Flax> get _currentRows {
    final start = (_currentPage - 1) * _pageSize;

    if (start >= _filteredAssigned.length) {
      return const [];
    }

    final end = (start + _pageSize).clamp(
      0,
      _filteredAssigned.length,
    );

    return _filteredAssigned.sublist(
      start,
      end,
    );
  }

  int get _totalPages {
    if (_filteredAssigned.isEmpty) {
      return 1;
    }

    return ((_filteredAssigned.length - 1) ~/ _pageSize) + 1;
  }

  Widget _buildPaginationFooter() {
    if (_filteredAssigned.isEmpty) {
      return const SizedBox(
        height: 32,
      );
    }

    final start = ((_currentPage - 1) * _pageSize) + 1;

    final end = ((_currentPage - 1) * _pageSize) + _currentRows.length;

    return Row(
      children: [
        Text(
          'Showing $start - $end of ${_filteredAssigned.length}',
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF657A90),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Previous page',
          visualDensity: VisualDensity.compact,
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
              : null,
          icon: const Icon(
            Icons.chevron_left,
            size: 20,
          ),
        ),
        _pageNumber(
          _currentPage,
        ),
        IconButton(
          tooltip: 'Next page',
          visualDensity: VisualDensity.compact,
          onPressed: _currentPage < _totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
          icon: const Icon(
            Icons.chevron_right,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _pageNumber(
    int page,
  ) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1976E8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$page',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // DETAILS CARD
  // ============================================================

  Widget _buildDetailsCard({
    bool compact = false,
  }) {
    final selected = _selectedFlax;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailsHeader(
            compact: compact,
            hasSelection: selected != null,
          ),
          const SizedBox(height: 14),
          if (selected == null)
            _buildDetailsEmptyState()
          else ...[
            _buildSelectedSummary(compact: compact),
            const SizedBox(height: 12),
            _buildSelectedFlaxBox(compact: compact),
            const SizedBox(height: 12),
            _buildTunchReportSection(compact: compact),
            const SizedBox(height: 12),
            _buildReleaseNote(compact: compact),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsHeader({
    required bool compact,
    required bool hasSelection,
  }) {
    return Row(
      children: [
        Container(
          width: compact ? 36 : 40,
          height: compact ? 36 : 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE4F0FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.account_tree_outlined,
            color: Color(0xFF174A8B),
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tree Casting Details',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF193E68),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasSelection
                    ? 'Review the selected FLX before release'
                    : 'Select an assigned FLX to continue',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF71859A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: hasSelection
                ? const Color(0xFFEAF7EF)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            hasSelection ? 'SELECTED' : 'WAITING',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: hasSelection
                  ? const Color(0xFF198754)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE1EAF3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_outlined,
              color: Color(0xFF1D5CFF),
              size: 25,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No FLX selected',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF29496D),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select an assigned FLX from the list to view its tree, casting information and release report.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Color(0xFF71859A),
            ),
          ),
        ],
      ),
    );
  }



  // ============================================================
  // SELECTED SUMMARY
  // ============================================================

  Widget _buildSelectedSummary({bool compact = false}) {
    final flax = _selectedFlax;

    final treeNo = _selectedTreeNo ?? flax?.treeNo ?? '-';

    final flaxNo = _selectedFlaxNo ?? flax?.flaxNo ?? '-';

    final castingDate = flax == null ? '-' : _castingDate(flax);

    final fields = [
      _detailField(label: 'Tree Number', value: treeNo),
      _detailField(label: 'FLX Name', value: flaxNo),
      _detailField(label: 'Casting Date', value: castingDate),
      _detailField(
        label: 'Status',
        value: flax == null ? '-' : 'Assigned',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= (compact ? 430 : 380);

        if (!twoColumns) {
          return Column(
            children: [
              fields[0],
              const SizedBox(height: 8),
              fields[1],
              const SizedBox(height: 8),
              fields[2],
              const SizedBox(height: 8),
              fields[3],
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: (constraints.maxWidth - 8) / 2,
              child: fields[0],
            ),
            SizedBox(
              width: (constraints.maxWidth - 8) / 2,
              child: fields[1],
            ),
            SizedBox(
              width: (constraints.maxWidth - 8) / 2,
              child: fields[2],
            ),
            SizedBox(
              width: (constraints.maxWidth - 8) / 2,
              child: fields[3],
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DETAIL FIELD
  // ============================================================

  Widget _detailField({
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE0E8F1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .3,
              color: Color(0xFF71859A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF29496D),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED FLX
  // ============================================================

  Widget _buildSelectedFlaxBox({
    bool compact = false,
  }) {
    final flax = _selectedFlax!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF8FBFF),
            Color(0xFFF2F7FF),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFD8E7F7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 17,
                color: Color(0xFF1D5CFF),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Selected FLX',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24476C),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'READY',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D5CFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 360;
              final items = [
                _miniDetail('FLX Name', flax.flaxNo),
                _miniDetail('FLX Size', flax.flaxSize),
                _miniDetail('Tree Number', _text(flax.treeNo)),
                _miniDetail('Design', _text(flax.designName)),
              ];

              if (!twoColumns) {
                return Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      items[i],
                      if (i != items.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: (constraints.maxWidth - 8) / 2,
                      child: item,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _miniDetail(
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFFE1EAF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              color: Color(0xFF73879A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF29496D),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TUNCH REPORT + IMAGE (required before release)
  // ============================================================

  Widget _buildTunchReportSection({
    bool compact = false,
  }) {
    final complete = _topTunchController.text.trim().isNotEmpty &&
        _bottomTunchController.text.trim().isNotEmpty &&
        _releaseImages.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFF1DFC0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBC8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 17,
                  color: Color(0xFF9A6410),
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tunch Report',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6D4B16),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Required before releasing this FLX',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF8A6A36),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: complete
                      ? const Color(0xFFE7F6EC)
                      : const Color(0xFFFFF1D9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  complete ? 'COMPLETE' : 'REQUIRED',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: complete
                        ? const Color(0xFF198754)
                        : const Color(0xFF9A6410),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 380;

              final top = _tunchField(
                label: 'Top Tunch',
                controller: _topTunchController,
              );
              final bottom = _tunchField(
                label: 'Bottom Tunch',
                controller: _bottomTunchController,
              );

              if (!twoColumns) {
                return Column(
                  children: [
                    top,
                    const SizedBox(height: 9),
                    bottom,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: top),
                  const SizedBox(width: 9),
                  Expanded(child: bottom),
                ],
              );
            },
          ),
          const SizedBox(height: 11),
          OutlinedButton.icon(
            onPressed: _pickReleaseImages,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              side: const BorderSide(
                color: Color(0xFFE1C991),
              ),
              foregroundColor: const Color(0xFF805711),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 18,
            ),
            label: Text(
              _releaseImages.isEmpty
                  ? 'Attach Tunch Image(s)'
                  : 'Add More Images',
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                _releaseImages.isEmpty
                    ? Icons.info_outline
                    : Icons.check_circle_outline,
                size: 14,
                color: _releaseImages.isEmpty
                    ? const Color(0xFF9A6410)
                    : const Color(0xFF198754),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _releaseImages.isEmpty
                      ? 'At least one image is required.'
                      : '${_releaseImages.length} image(s) attached',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: _releaseImages.isEmpty
                        ? const Color(0xFF8A6A36)
                        : const Color(0xFF3E7552),
                  ),
                ),
              ),
            ],
          ),
          if (_releaseImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _releaseImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = _releaseImages[index];

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          image.bytes,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _removeReleaseImage(index),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFF334155),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tunchField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF29496D),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'e.g. 91.60',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFDCE6F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFDCE6F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Color(0xFF1976E8),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NOTE
  // ============================================================

  Widget _buildReleaseNote({
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 11 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFD7E8FA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: Color(0xFF174A8B),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Release checklist',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF174A8B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Confirm the Tree, FLX, Tunch readings and attached image(s) before releasing.',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.35,
                    color: Color(0xFF52708F),
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
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 50,
            color: Colors.red,
          ),
          const SizedBox(
            height: 12,
          ),
          const Text(
            'Unable to load assigned FLX',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          SizedBox(
            width: 600,
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          FilledButton.icon(
            onPressed: _loadAssigned,
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
  // CARD
  // ============================================================

  Widget _card({
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 420 ? 13.0 : 18.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color: const Color(0xFFE1EAF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.025,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
          child: child,
        );
      },
    );
  }
}

// ================================================================
// WEB-SAFE PICKED IMAGE HOLDER (release-time tunch report images)
// ================================================================

class _PickedReleaseImage {
  final XFile file;
  final Uint8List bytes;

  const _PickedReleaseImage({
    required this.file,
    required this.bytes,
  });
}