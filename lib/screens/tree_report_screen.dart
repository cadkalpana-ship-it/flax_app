import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';

import '../models/assignment_history_entry.dart';
import '../services/api_service.dart';

/// ============================================================
/// TREE REPORT
/// ============================================================
///
/// Aggregates the per-tree rows already captured by the Tree Module
/// (Casting Master) batches — style_no, bag_no, tree_no, tree_wt,
/// purity, require_metal, req_pure_metal, require_alloy — and rolls
/// them up into:
///
///   Top of screen : distinct Style / Bag / Tree counts for the
///                   currently assigned trees (the ones with FLX on
///                   them right now).
///   Bottom of screen : Total Metal / Total Pure Metal / Total Alloy
///                      across those same rows.
///
/// NOTE: this screen currently computes everything on-device from
/// GET /tree-module-batches/ and GET /flaxes/?assignment_status=Assigned
/// — there is no dedicated backend report endpoint for this yet (unlike
/// Flax Report, which has one). See the accompanying backend notes for
/// a proposed /api/tree-report/ endpoint if this needs to be moved
/// server-side (pagination, heavier date filtering, etc).
/// ============================================================

class TreeReportScreen extends StatefulWidget {
  final String userName;
  const TreeReportScreen({super.key, required this.userName});

  @override
  State<TreeReportScreen> createState() => TreeReportScreenState();
}

class _TreeRow {
  final String styleNo;
  final String bagNo;
  final String treeNo;
  final double? treeWt;
  final String purity;
  final String colour;
  final double? requireMetal;
  final double? reqPureMetal;
  final double? requireAlloy;
  final DateTime? submittedOn;

  _TreeRow({
    required this.styleNo,
    required this.bagNo,
    required this.treeNo,
    required this.treeWt,
    required this.purity,
    required this.colour,
    required this.requireMetal,
    required this.reqPureMetal,
    required this.requireAlloy,
    required this.submittedOn,
  });
}

/// Which trees to show, based on their FLX assignment status:
///  - currentlyAssigned : has FLX assigned right now
///  - previouslyAssigned: had FLX assigned/released at some point in the
///                        past, but nothing on it right now
///  - notYetAssigned    : has a casting entry but has never had FLX
///                        assigned to it
enum TreeAssignmentFilter {
  all,
  currentlyAssigned,
  previouslyAssigned,
  notYetAssigned,
}

class TreeReportScreenState extends State<TreeReportScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;

  List<_TreeRow> _allRows = [];
  Set<String> _assignedTreeNumbers = {};

  // Tree numbers that show up anywhere in assignment history (i.e. have
  // been assigned to FLX at least once, whether still assigned or since
  // released). Built from the "recent assignment history" endpoint — see
  // the caveat in _load() below.
  Set<String> _everAssignedTreeNumbers = {};

  TreeAssignmentFilter _assignmentFilter = TreeAssignmentFilter.all;

  String? _selectedPurity;
  String? _selectedColour;

  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> refreshData() async {
    await _load();
  }

  Future<void> _exportPdf() async {
    final rows = _filteredRows;

    if (rows.isEmpty) {
      // _showMessage('No data available for PDF export.');
      return;
    }

    try {
      final pdf = pw.Document();

      final generatedOn = DateTime.now();

      final assignmentLabel = switch (_assignmentFilter) {
        TreeAssignmentFilter.all => 'All Trees',
        TreeAssignmentFilter.currentlyAssigned => 'Currently Assigned',
        TreeAssignmentFilter.previouslyAssigned => 'Previously Assigned',
        TreeAssignmentFilter.notYetAssigned => 'Not Yet Assigned',
      };

      final fromText = _fromDateController.text.trim().isEmpty
          ? 'All'
          : _fromDateController.text.trim();

      final toText = _toDateController.text.trim().isEmpty
          ? 'All'
          : _toDateController.text.trim();

      final purityText = _selectedPurity ?? 'All';
      final colourText = _selectedColour ?? 'All';
      // final username = currentUsername;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TREE REPORT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Kalpana Enterprises',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Better Process  |  Better Production',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
              ],
            );
          },
          footer: (context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 5),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(
                    width: 0.5,
                    color: PdfColors.grey,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Downloaded by: ${widget.userName.isEmpty ? 'User' : widget.userName}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(
                  color: PdfColors.grey300,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Applied Filters',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      _pdfFilterItem(
                        'From',
                        fromText,
                      ),
                      _pdfFilterItem(
                        'To',
                        toText,
                      ),
                      _pdfFilterItem(
                        'Purity',
                        purityText,
                      ),
                      _pdfFilterItem(
                        'Colour',
                        colourText,
                      ),
                      _pdfFilterItem(
                        'Assignment',
                        assignmentLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // SUMMARY
            pw.Row(
              children: [
                _pdfSummaryCard(
                  'Total Trees',
                  _distinctTreeCount.toString(),
                ),
                _pdfSummaryCard(
                  'Total Styles',
                  _distinctStyleCount.toString(),
                ),
                _pdfSummaryCard(
                  'Total Bags',
                  _distinctBagCount.toString(),
                ),
                _pdfSummaryCard(
                  'Total Metal',
                  _totalMetal.toStringAsFixed(2),
                ),
                _pdfSummaryCard(
                  'Pure Metal',
                  _totalPureMetal.toStringAsFixed(2),
                ),
                _pdfSummaryCard(
                  'Total Alloy',
                  _totalAlloy.toStringAsFixed(2),
                ),
              ],
            ),

            pw.SizedBox(height: 16),

            pw.Text(
              'Tree Details',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              headers: [
                'Tree No',
                'Style No',
                'Bag No',
                'Tree Wt',
                'Purity',
                'Colour',
                'Metal',
                'Pure Metal',
                'Alloy',
              ],
              data: rows.map((row) {
                return [
                  _pdfValue(row.treeNo),
                  _pdfValue(row.styleNo),
                  _pdfValue(row.bagNo),
                  row.treeWt?.toStringAsFixed(2) ?? '-',
                  _pdfValue(row.purity),
                  _pdfValue(row.colour),
                  row.requireMetal?.toStringAsFixed(2) ?? '-',
                  row.reqPureMetal?.toStringAsFixed(2) ?? '-',
                  row.requireAlloy?.toStringAsFixed(2) ?? '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 7.5,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
            ),

            pw.SizedBox(height: 8),

            // TOTAL ROW
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Metal: ${_totalMetal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Text(
                    'Pure Metal: ${_totalPureMetal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Text(
                    'Alloy: ${_totalAlloy.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final Uint8List bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'tree_report_${_fileDate(generatedOn)}.pdf',
      );
    } catch (e) {
      _showMessage(
        'Failed to generate PDF: $e',
      );
    }
  }

  pw.Widget _pdfFilterItem(
    String label,
    String value,
  ) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryCard(
    String label,
    String value,
  ) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(
            color: PdfColors.grey300,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pdfValue(String value) {
    return value.trim().isEmpty ? '-' : value.trim();
  }

  String _formatDateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.day)}-${two(date.month)}-'
        '${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  String _fileDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${date.year}${two(date.month)}${two(date.day)}_'
        '${two(date.hour)}${two(date.minute)}';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final batches = await _api.fetchTreeModuleBatches();

      final assignedFlaxes = await _api.fetchAllFlaxes(
        assignmentStatus: 'Assigned',
      );

      // Best-effort: this is the "recent" assignment history endpoint —
      // it's what the app currently has, but if it's capped to a limited
      // number of entries, trees assigned/released further back than that
      // window won't be picked up as "previously assigned". Ask backend
      // for a non-capped /assignment-history/ endpoint if this needs to
      // be exact.
      List<AssignmentHistoryEntry> history = [];
      try {
        history = await _api.fetchRecentAssignmentHistory();
      } catch (_) {
        // Non-fatal — assignment filter just falls back to only
        // "currently assigned" vs "everything else" if this fails.
      }

      final assignedTrees = assignedFlaxes
          .map((flax) => (flax.treeNo ?? '').trim())
          .where((treeNo) => treeNo.isNotEmpty)
          .toSet();

      final everAssignedTrees = history
          .map((entry) => entry.treeNo.trim())
          .where((treeNo) => treeNo.isNotEmpty)
          .toSet()
        ..addAll(assignedTrees);

      final rows = <_TreeRow>[];

      for (final raw in batches) {
        if (raw is! Map) continue;

        final batch = Map<String, dynamic>.from(raw);

        final submittedOn = batch['submitted_on'] != null
            ? DateTime.tryParse(batch['submitted_on'].toString())
            : null;

        final details = batch['details'];

        if (details is! List) continue;

        for (final rawDetail in details) {
          if (rawDetail is! Map) continue;

          final detail = Map<String, dynamic>.from(rawDetail);

          rows.add(
            _TreeRow(
              styleNo: (detail['style_no'] ?? '').toString().trim(),
              bagNo: (detail['bag_no'] ?? '').toString().trim(),
              treeNo: (detail['tree_no'] ?? '').toString().trim(),
              treeWt: _toDouble(detail['tree_wt']),
              purity: (detail['purity'] ?? '').toString().trim(),
              colour: (detail['colour'] ?? '').toString().trim(),
              requireMetal: _toDouble(detail['require_metal']),
              reqPureMetal: _toDouble(detail['req_pure_metal']),
              requireAlloy: _toDouble(detail['require_alloy']),
              submittedOn: submittedOn,
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _allRows = rows;
        _assignedTreeNumbers = assignedTrees;
        _everAssignedTreeNumbers = everAssignedTrees;
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

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // ============================================================
  // FILTERED ROWS
  // ============================================================

  List<_TreeRow> get _filteredRows {
    final from = _parseDate(_fromDateController.text);
    final to = _parseDate(_toDateController.text);

    return _allRows.where((row) {
      if (!_matchesAssignmentFilter(row.treeNo)) {
        return false;
      }

      if (_selectedPurity != null && row.purity != _selectedPurity) {
        return false;
      }

      if (_selectedColour != null && row.colour != _selectedColour) {
        return false;
      }

      if (from != null) {
        if (row.submittedOn == null || row.submittedOn!.isBefore(from)) {
          return false;
        }
      }

      if (to != null) {
        final endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
        if (row.submittedOn == null || row.submittedOn!.isAfter(endOfDay)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool _matchesAssignmentFilter(String treeNo) {
    switch (_assignmentFilter) {
      case TreeAssignmentFilter.all:
        return true;

      case TreeAssignmentFilter.currentlyAssigned:
        return _assignedTreeNumbers.contains(treeNo);

      case TreeAssignmentFilter.previouslyAssigned:
        // Has assignment history, but nothing on it right now.
        return _everAssignedTreeNumbers.contains(treeNo) &&
            !_assignedTreeNumbers.contains(treeNo);

      case TreeAssignmentFilter.notYetAssigned:
        // Has a casting entry, but no assignment history at all.
        return !_everAssignedTreeNumbers.contains(treeNo);
    }
  }

  /// Purity / Colour values actually present in the loaded data, so the
  /// filter dropdowns only ever offer choices that can return results.
  List<String> get _purityOptions {
    final values = _allRows
        .map((r) => r.purity)
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<String> get _colourOptions {
    final values = _allRows
        .map((r) => r.colour)
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  DateTime? _parseDate(String value) {
    final parts = value.trim().split('-');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;

    return DateTime.tryParse(
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}-${two(date.month)}-${date.year}';
  }

  // ============================================================
  // TOTALS
  // ============================================================

  int get _distinctStyleCount => _filteredRows
      .map((r) => r.styleNo)
      .where((v) => v.isNotEmpty)
      .toSet()
      .length;

  int get _distinctBagCount => _filteredRows
      .map((r) => r.bagNo)
      .where((v) => v.isNotEmpty)
      .toSet()
      .length;

  int get _distinctTreeCount => _filteredRows
      .map((r) => r.treeNo)
      .where((v) => v.isNotEmpty)
      .toSet()
      .length;

  double get _totalMetal =>
      _filteredRows.fold(0.0, (sum, r) => sum + (r.requireMetal ?? 0));

  double get _totalPureMetal =>
      _filteredRows.fold(0.0, (sum, r) => sum + (r.reqPureMetal ?? 0));

  double get _totalAlloy =>
      _filteredRows.fold(0.0, (sum, r) => sum + (r.requireAlloy ?? 0));

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final rows = _filteredRows;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildFilterBar(),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _filteredRows.isEmpty ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Export PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTopCountCards(),
          const SizedBox(height: 12),
          Expanded(child: _buildTable(rows)),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _buildFilterBar() {
    final purityOptions = _purityOptions;
    final colourOptions = _colourOptions;

    final validPurity =
        purityOptions.contains(_selectedPurity) ? _selectedPurity : null;
    final validColour =
        colourOptions.contains(_selectedColour) ? _selectedColour : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF3)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 160,
            child: _dateField('From Date', _fromDateController),
          ),
          SizedBox(
            width: 160,
            child: _dateField('To Date', _toDateController),
          ),
          SizedBox(
            width: 140,
            child: _dropdownFilter(
              label: 'Purity',
              value: validPurity,
              options: purityOptions,
              onChanged: (value) {
                setState(() {
                  _selectedPurity = value;
                });
              },
            ),
          ),
          SizedBox(
            width: 140,
            child: _dropdownFilter(
              label: 'Colour',
              value: validColour,
              options: colourOptions,
              onChanged: (value) {
                setState(() {
                  _selectedColour = value;
                });
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: _assignmentDropdown(),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_fromDateController.text.isNotEmpty ||
              _toDateController.text.isNotEmpty ||
              _selectedPurity != null ||
              _selectedColour != null ||
              _assignmentFilter != TreeAssignmentFilter.all)
            TextButton(
              onPressed: () {
                setState(() {
                  _fromDateController.clear();
                  _toDateController.clear();
                  _selectedPurity = null;
                  _selectedColour = null;
                  _assignmentFilter = TreeAssignmentFilter.all;
                });
              },
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  Widget _dropdownFilter({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF29496D),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            hintText: 'All',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All'),
            ),
            ...options.map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF29496D),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'dd-mm-yyyy',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            suffixIcon: const Icon(Icons.calendar_month_outlined, size: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _parseDate(controller.text) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );

            if (picked == null) return;

            setState(() {
              controller.text = _formatDate(picked);
            });
          },
        ),
      ],
    );
  }

  // ============================================================
  // TOP COUNT CARDS
  // ============================================================

  Widget _buildTopCountCards() {
    return Row(
      children: [
        Expanded(
          child: _countCard(
            'Total Trees',
            _distinctTreeCount,
            Icons.account_tree_outlined,
            const Color(0xFF1D5CFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _countCard(
            'Total Styles',
            _distinctStyleCount,
            Icons.style_outlined,
            const Color(0xFF20A464),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _countCard(
            'Total Bags',
            _distinctBagCount,
            Icons.inventory_2_outlined,
            const Color(0xFFE8A93A),
          ),
        ),
      ],
    );
  }

  Widget _countCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF193E68),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF657A90),
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
  // TABLE
  // ============================================================

  Widget _buildTable(List<_TreeRow> rows) {
    if (rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1EAF3)),
        ),
        child: const Center(
          child: Text(
            'No tree data found for the selected filters.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    const headers = [
      'Tree No',
      'Style No',
      'Bag No',
      'Tree Wt',
      'Purity',
      'Colour',
      'Metal',
      'Pure Metal',
      'Alloy',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFFF0F6FC),
            child: Row(
              children: headers
                  .map(
                    (h) => Expanded(
                      child: Text(
                        h,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF24476C),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE6EDF4)),
          Expanded(
            child: ListView.separated(
              primary: false,
               controller: _tableScrollController,
               physics: const ClampingScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE8EEF5)),
              itemBuilder: (context, index) {
                final row = rows[index];

                Widget cell(String value) => Expanded(
                      child: Text(
                        value.isEmpty ? '-' : value,
                        style: const TextStyle(fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      cell(row.treeNo),
                      cell(row.styleNo),
                      cell(row.bagNo),
                      cell(row.treeWt?.toStringAsFixed(2) ?? '-'),
                      cell(row.purity),
                      cell(row.colour),
                      cell(row.requireMetal?.toStringAsFixed(2) ?? '-'),
                      cell(row.reqPureMetal?.toStringAsFixed(2) ?? '-'),
                      cell(row.requireAlloy?.toStringAsFixed(2) ?? '-'),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildTotalsRow(),
        ],
      ),
    );
  }

  // ============================================================
  // TOTALS ROW — same 9-column layout as the table above, so each
  // total sits directly under its own column (Metal / Pure Metal /
  // Alloy) instead of in a separate summary bar.
  // ============================================================

  Widget _buildTotalsRow() {
    Widget cell(String value, {Color? color}) => Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color ?? const Color(0xFF193E68),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF3F9FF),
        border: Border(
          top: BorderSide(color: Color(0xFFD6E8FA), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          cell('Total'),
          cell(''),
          cell(''),
          cell(''),
          cell(''),
          cell(''),
          cell(
            _totalMetal.toStringAsFixed(2),
            color: const Color(0xFF174A8B),
          ),
          cell(
            _totalPureMetal.toStringAsFixed(2),
            color: const Color(0xFF20A464),
          ),
          cell(
            _totalAlloy.toStringAsFixed(2),
            color: const Color(0xFFB3541E),
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
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 12),
          const Text(
            'Unable to load tree report',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 500,
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _assignmentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tree Assignment',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF29496D),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<TreeAssignmentFilter>(
          value: _assignmentFilter,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: TreeAssignmentFilter.all,
              child: Text('All Trees'),
            ),
            DropdownMenuItem(
              value: TreeAssignmentFilter.currentlyAssigned,
              child: Text('Currently Assigned'),
            ),
            DropdownMenuItem(
              value: TreeAssignmentFilter.previouslyAssigned,
              child: Text('Previously Assigned'),
            ),
            DropdownMenuItem(
              value: TreeAssignmentFilter.notYetAssigned,
              child: Text('Not Yet Assigned'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _assignmentFilter = value;
            });
          },
        ),
      ],
    );
  }
}
