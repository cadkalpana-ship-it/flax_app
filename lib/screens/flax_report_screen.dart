
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FlaxReportScreen extends StatefulWidget {
  final String userName;
  const FlaxReportScreen({super.key, required this.userName});

  @override
  State<FlaxReportScreen> createState() => FlaxReportScreenState();
}

class FlaxReportScreenState extends State<FlaxReportScreen> {
  final ApiService _api = ApiService();

  // ============================================================
  // FILTER STATE
  // ============================================================

  String _period = 'monthly';

  DateTime? _startDate;
  DateTime? _endDate;

  // Assignment status filter.
  //
  // Supported values:
  // all
  // assigned
  // released
  // removed
  String _statusFilter = 'all';

  bool _loading = false;
  bool _downloading = false;

  String? _error;

  Map<String, dynamic>? _report;

  // ============================================================
  // RESULTS
  // ============================================================

  List<dynamic> get _results {
    final value = _report?['results'];

    if (value is! List) {
      return [];
    }

    // No status filtering.
    if (_statusFilter == 'all') {
      return value;
    }

    // Filter report records by assignment status.
    return value.where((item) {
      if (item is! Map) {
        return false;
      }

      final status =
          item['status']?.toString().trim().toLowerCase() ?? '';

      return status == _statusFilter;
    }).toList();
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Map<String, dynamic> get _summary {
    final value = _report?['summary'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  @override
  void initState() {
    super.initState();

    _loadReport();
  }

  Future<void> refreshData() async {
    await _refreshCurrentPage();
  }

  // ============================================================
  // REPORT FILTER — REAL BACKEND QUERY PARAMS
  // ============================================================

  Future<void> _refreshCurrentPage() async {
    if (_period == 'selected') {
      if (_startDate == null || _endDate == null) {
        setState(() {
          _error = 'Please select both start and end dates.';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final params = <String, String>{
        'period': _period,
      };

      if (_period == 'selected') {
        String formatDate(DateTime date) {
          final month = date.month.toString().padLeft(2, '0');
          final day = date.day.toString().padLeft(2, '0');

          return '${date.year}-$month-$day';
        }

        params['start_date'] = formatDate(_startDate!);
        params['end_date'] = formatDate(_endDate!);
      }

      final query = params.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}='
                '${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&');

      debugPrint(
        'Loading report: '
        '${ApiService.baseUrl}/reports/flax-assignment/?$query',
      );

      final result = await _api.fetchFlaxAssignmentReport(
        period: _period,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;

      setState(() {
        _report = result;
        _loading = false;
      });

      debugPrint('Report loaded successfully.');
      debugPrint('Results after status filter: ${_results.length}');
      debugPrint('Summary: $_summary');
      debugPrint('Status filter: $_statusFilter');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });

      debugPrint('Report loading error: $e');
    }
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> _loadReport() async {
    if (_period == 'selected') {
      if (_startDate == null || _endDate == null) {
        setState(() {
          _error = 'Please select both start and end dates.';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.fetchFlaxAssignmentReport(
        period: _period,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;

      setState(() {
        _report = result;
        _loading = false;
      });

      debugPrint('Report loaded successfully.');
      debugPrint('Results: ${_results.length}');
      debugPrint('Status filter: $_statusFilter');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });

      debugPrint('Report loading error: $e');
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _pickStartDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _startDate = picked;

      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _endDate = picked;
    });
  }

  // ============================================================
  // XLSX DOWNLOAD
  // ============================================================

  Future<void> _downloadExcel() async {
    if (_report == null || _results.isEmpty) {
      _showMessage(
        'There is no report data to export.',
        isError: true,
      );
      return;
    }

    setState(() {
      _downloading = true;
    });

    try {
      debugPrint('========== XLSX EXPORT ==========');
      debugPrint('Results: ${_results.length}');
      debugPrint('Summary: $_summary');
      debugPrint('Status filter: $_statusFilter');

      final Excel excel = Excel.createExcel();

      // Use the default Sheet1 as the Summary sheet.
      excel.rename(
        'Sheet1',
        'Summary',
      );

      final Sheet summarySheet = excel['Summary'];

      final Sheet detailsSheet = excel['Assignment Details'];

      _buildSummarySheet(summarySheet);
      _buildDetailsSheet(detailsSheet);

      final bool defaultSheetSet = excel.setDefaultSheet(
        'Summary',
      );

      debugPrint(
        'Default Summary sheet set: $defaultSheetSet',
      );

      debugPrint(
        'Workbook sheets: ${excel.sheets.keys.toList()}',
      );

      debugPrint(
        'Summary rows: ${summarySheet.maxRows}',
      );

      debugPrint(
        'Summary columns: ${summarySheet.maxColumns}',
      );

      debugPrint(
        'Details rows: ${detailsSheet.maxRows}',
      );

      debugPrint(
        'Details columns: ${detailsSheet.maxColumns}',
      );

      if (summarySheet.maxRows == 0) {
        throw Exception(
          'Summary sheet was not populated.',
        );
      }

      if (detailsSheet.maxRows <= 1) {
        throw Exception(
          'Assignment Details sheet was not populated.',
        );
      }

      final List<int>? generatedBytes = excel.save();

      if (generatedBytes == null || generatedBytes.isEmpty) {
        throw Exception(
          'Excel file could not be generated.',
        );
      }

      debugPrint(
        'Generated XLSX bytes: ${generatedBytes.length}',
      );

      final Uint8List bytes = Uint8List.fromList(
        generatedBytes,
      );

      final fileName = _buildFileName();

      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;

      _showMessage(
        'Excel report downloaded successfully.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'XLSX EXPORT ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      _showMessage(
        'Failed to download Excel report: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  // ============================================================
  // PDF DOWNLOAD
  // ============================================================

  Future<void> _downloadPdf() async {
    if (_report == null || _results.isEmpty) {
      _showMessage(
        'There is no report data to export.',
        isError: true,
      );
      return;
    }

    setState(() {
      _downloading = true;
    });

    try {
      debugPrint('========== PDF EXPORT ==========');
      debugPrint('Results: ${_results.length}');
      debugPrint('Summary: $_summary');
      debugPrint('Status filter: $_statusFilter');

      final pdf = pw.Document();

      // ----------------------------------------------------------
      // SUMMARY PAGE
      // ----------------------------------------------------------

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          footer: (context) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(
              width: 0.5,
              color: PdfColors.grey400,
            ),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Downloaded by: ${widget.userName.isEmpty ? 'User' : widget.userName}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      );
    },
          build: (context) {
            return [
              pw.Text(
                'FLAX ASSIGNMENT REPORT',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Flax Assignment Report',
                style: const pw.TextStyle(
                  fontSize: 11,
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(2),
                },
                children: [
                  _pdfInfoRow(
                    'Report Period',
                    _periodLabel(),
                  ),
                  _pdfInfoRow(
                    'Assignment Status',
                    _statusLabel(),
                  ),
                  _pdfInfoRow(
                    'Start Date',
                    _displayDate(_report?['start_date']),
                  ),
                  _pdfInfoRow(
                    'End Date',
                    _displayDate(_report?['end_date']),
                  ),
                  _pdfInfoRow(
                    'Generated On',
                    _displayDateTime(DateTime.now()),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'SUMMARY',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  _pdfSummaryRow(
                    'Total Assignments',
                    _number(
                      _summary['total_assignments'],
                    ).toString(),
                  ),
                  _pdfSummaryRow(
                    'Released',
                    _number(
                      _summary['released'],
                    ).toString(),
                  ),
                  _pdfSummaryRow(
                    'Currently Assigned',
                    _number(
                      _summary['currently_assigned'],
                    ).toString(),
                  ),
                  _pdfSummaryRow(
                    'Removed',
                    _number(
                      _summary['removed'],
                    ).toString(),
                  ),
                  _pdfSummaryRow(
                    'Unique Flaxes',
                    _number(
                      _summary['unique_flaxes'],
                    ).toString(),
                  ),
                  _pdfSummaryRow(
                    'Unique Trees',
                    _number(
                      _summary['unique_trees'],
                    ).toString(),
                  ),
                  _pdfSummaryRow(
                    'Average Assignment Days',
                    _double(
                      _summary['average_assignment_days'],
                    ).toStringAsFixed(2),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // ----------------------------------------------------------
      // DETAILS
      // ----------------------------------------------------------

      final headers = [
        '#',
        'Flax No',
        'Size',
        'Design',
        'Tree No',
        'Assigned',
        'Released',
        'Duration',
        'Status',
      ];

      final data = <List<String>>[];

      for (int index = 0; index < _results.length; index++) {
        final item = Map<String, dynamic>.from(
          _results[index] as Map,
        );

        data.add([
          '${index + 1}',
          _text(item['flax_no']),
          _text(item['flax_size']),
          _text(item['design_name']),
          _text(item['tree_no']),
          _displayDateTime(
            item['assigned_on'],
          ),
          _displayDateTime(
            item['released_on'],
          ),
          _text(item['duration']),
          _text(item['status']),
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              pw.Text(
                'ASSIGNMENT DETAILS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Status: ${_statusLabel()}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${_results.length} records',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 7,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 5,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: const {
                  0: pw.FixedColumnWidth(25),
                  1: pw.FixedColumnWidth(60),
                  2: pw.FixedColumnWidth(50),
                  3: pw.FlexColumnWidth(1.5),
                  4: pw.FixedColumnWidth(60),
                  5: pw.FixedColumnWidth(80),
                  6: pw.FixedColumnWidth(80),
                  7: pw.FixedColumnWidth(65),
                  8: pw.FixedColumnWidth(55),
                },
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();

      debugPrint(
        'Generated PDF bytes: ${bytes.length}',
      );

      final fileName = '${_buildFileName()}.pdf';

      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );

      if (!mounted) return;

      _showMessage(
        'PDF report generated successfully.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'PDF EXPORT ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      _showMessage(
        'Failed to generate PDF report: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  // ============================================================
  // FILE NAME
  // ============================================================

  String _buildFileName() {
    final now = DateTime.now();

    String two(int value) {
      return value.toString().padLeft(2, '0');
    }

    final timestamp =
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';

    final statusPart =
        _statusFilter == 'all'
            ? ''
            : '_${_statusFilter[0].toUpperCase()}'
                '${_statusFilter.substring(1)}';

    return 'Flax_Assignment_Report$statusPart'
        '_$timestamp';
  }

  // ============================================================
  // SUMMARY SHEET
  // ============================================================

  void _buildSummarySheet(Sheet sheet) {
    sheet.appendRow([
      TextCellValue('FLAX ASSIGNMENT REPORT'),
    ]);

    sheet.appendRow([
      TextCellValue('Report Period'),
      TextCellValue(_periodLabel()),
    ]);

    sheet.appendRow([
      TextCellValue('Assignment Status'),
      TextCellValue(_statusLabel()),
    ]);

    sheet.appendRow([
      TextCellValue('Start Date'),
      TextCellValue(
        _displayDate(_report?['start_date']),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('End Date'),
      TextCellValue(
        _displayDate(_report?['end_date']),
      ),
    ]);

    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('SUMMARY'),
    ]);

    sheet.appendRow([
      TextCellValue('Total Assignments'),
      IntCellValue(
        _number(_summary['total_assignments']),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Released'),
      IntCellValue(
        _number(_summary['released']),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Currently Assigned'),
      IntCellValue(
        _number(_summary['currently_assigned']),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Removed'),
      IntCellValue(
        _number(_summary['removed']),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Unique Flaxes'),
      IntCellValue(
        _number(_summary['unique_flaxes']),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Unique Trees'),
      IntCellValue(
        _number(_summary['unique_trees']),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Average Assignment Days'),
      DoubleCellValue(
        _double(
          _summary['average_assignment_days'],
        ),
      ),
    ]);

    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('Displayed Records'),
      IntCellValue(
        _results.length,
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Generated On'),
      TextCellValue(
        _displayDateTime(DateTime.now()),
      ),
    ]);
  }

  // ============================================================
  // DETAILS SHEET
  // ============================================================

  void _buildDetailsSheet(Sheet sheet) {
    sheet.appendRow([
      TextCellValue('#'),
      TextCellValue('Flax No'),
      TextCellValue('Flax Size'),
      TextCellValue('Design ID'),
      TextCellValue('Design Name'),
      TextCellValue('Category'),
      TextCellValue('Tree No'),
      TextCellValue('Tree Name'),
      TextCellValue('Assigned On'),
      TextCellValue('Released On'),
      TextCellValue('Removed On'),
      TextCellValue('Duration'),
      TextCellValue('Duration Days'),
      TextCellValue('Status'),
    ]);

    for (int index = 0; index < _results.length; index++) {
      final item = Map<String, dynamic>.from(
        _results[index] as Map,
      );

      sheet.appendRow([
        IntCellValue(index + 1),
        TextCellValue(
          _text(item['flax_no']),
        ),
        TextCellValue(
          _text(item['flax_size']),
        ),
        TextCellValue(
          _text(item['design_id']),
        ),
        TextCellValue(
          _text(item['design_name']),
        ),
        TextCellValue(
          _text(item['category']),
        ),
        TextCellValue(
          _text(item['tree_no']),
        ),
        TextCellValue(
          _text(item['tree_name']),
        ),
        TextCellValue(
          _displayDateTime(item['assigned_on']),
        ),
        TextCellValue(
          _displayDateTime(item['released_on']),
        ),
        TextCellValue(
          _displayDateTime(item['removed_on']),
        ),
        TextCellValue(
          _text(item['duration']),
        ),
        DoubleCellValue(
          _double(item['duration_days']),
        ),
        TextCellValue(
          _text(item['status']),
        ),
      ]);
    }
  }

  // ============================================================
  // PDF HELPERS
  // ============================================================

  pw.TableRow _pdfInfoRow(
    String label,
    String value,
  ) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(7),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(7),
          child: pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _pdfSummaryRow(
    String label,
    String value,
  ) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(7),
          child: pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(7),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VALUE HELPERS
  // ============================================================

  int _number(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  double _double(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }

  String _text(
    dynamic value, {
    String fallback = '-',
  }) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  String _displayDate(dynamic value) {
    if (value == null) return '-';

    final text = value.toString().trim();

    if (text.isEmpty) return '-';

    if (text.length >= 10) {
      return text.substring(0, 10);
    }

    return text;
  }

  String _displayDateTime(dynamic value) {
    if (value == null) return '-';

    final text = value.toString().trim();

    if (text.isEmpty) return '-';

    final parsed = DateTime.tryParse(text);

    if (parsed == null) {
      return text;
    }

    final local = parsed.toLocal();

    String two(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${two(local.day)}-'
        '${two(local.month)}-'
        '${local.year} '
        '${two(local.hour)}:'
        '${two(local.minute)}';
  }

  // ============================================================
  // PERIOD LABEL
  // ============================================================

  String _periodLabel() {
    switch (_period) {
      case 'daily':
        return 'Daily';

      case 'weekly':
        return 'Weekly';

      case 'monthly':
        return 'Monthly';

      case 'yearly':
        return 'Yearly';

      case 'selected':
        return 'Selected Date Range';

      default:
        return _period;
    }
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String _statusLabel() {
    switch (_statusFilter) {
      case 'assigned':
        return 'Assigned';

      case 'released':
        return 'Released';

      case 'removed':
        return 'Removed';

      case 'all':
      default:
        return 'All Statuses';
    }
  }

  // ============================================================
  // DATE RANGE
  // ============================================================

  String _dateRangeText() {
    if (_startDate == null || _endDate == null) {
      return 'Select date range';
    }

    return '${_formatDate(_startDate!)}'
        '  →  '
        '${_formatDate(_endDate!)}';
  }

  String _formatDate(DateTime date) {
    String two(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${two(date.day)}-'
        '${two(date.month)}-'
        '${date.year}';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade700 : null,
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildFilters(),
              const SizedBox(height: 20),

              if (_error != null) ...[
                _buildErrorCard(),
                const SizedBox(height: 20),
              ],

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 80,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_report != null) ...[
                _buildSummaryCards(),
                const SizedBox(height: 20),
                _buildResultsTable(),
              ],
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flax Assignment Report',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Review flax assignments, release history and duration',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed:
                  _downloading ||
                          _report == null ||
                          _results.isEmpty
                      ? null
                      : _downloadExcel,
              icon: _downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.table_view_outlined,
                      size: 18,
                    ),
              label: const Text(
                'Download XLSX',
              ),
            ),

            const SizedBox(width: 10),

            OutlinedButton.icon(
              onPressed:
                  _downloading ||
                          _report == null ||
                          _results.isEmpty
                      ? null
                      : _downloadPdf,
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
              ),
              label: const Text(
                'Download PDF',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return Container(
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 800;

          // ----------------------------------------------------
          // PERIOD
          // ----------------------------------------------------

          final periodField = SizedBox(
            width: compact ? double.infinity : 220,
            child: DropdownButtonFormField<String>(
              value: _period,
              decoration: _inputDecoration(
                'Report Period',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'daily',
                  child: Text('Daily'),
                ),
                DropdownMenuItem(
                  value: 'weekly',
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text('Monthly'),
                ),
                DropdownMenuItem(
                  value: 'yearly',
                  child: Text('Yearly'),
                ),
                DropdownMenuItem(
                  value: 'selected',
                  child: Text('Selected Date Range'),
                ),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _period = value;

                        // Clear dates when switching away
                        // from selected date range.
                        if (value != 'selected') {
                          _startDate = null;
                          _endDate = null;
                        }
                      });
                    },
            ),
          );

          // ----------------------------------------------------
          // STATUS
          // ----------------------------------------------------

          final statusField = SizedBox(
            width: compact ? double.infinity : 190,
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: _inputDecoration(
                'Assignment Status',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Statuses'),
                ),
                DropdownMenuItem(
                  value: 'assigned',
                  child: Text('Assigned'),
                ),
                DropdownMenuItem(
                  value: 'released',
                  child: Text('Released'),
                ),
                DropdownMenuItem(
                  value: 'removed',
                  child: Text('Removed'),
                ),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _statusFilter = value;
                      });
                    },
            ),
          );

          // ----------------------------------------------------
          // DATE FIELDS
          // ----------------------------------------------------

          final dateFields = _period != 'selected'
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        label: 'From',
                        value: _startDate == null
                            ? 'Select date'
                            : _formatDate(
                                _startDate!,
                              ),
                        onPressed: _pickStartDate,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: _dateButton(
                        label: 'To',
                        value: _endDate == null
                            ? 'Select date'
                            : _formatDate(
                                _endDate!,
                              ),
                        onPressed: _pickEndDate,
                      ),
                    ),
                  ],
                );

          // ----------------------------------------------------
          // ACTION BUTTONS
          // ----------------------------------------------------

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : _loadReport,
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                ),
                label: const Text(
                  'Generate',
                ),
              ),
            ],
          );

          // ----------------------------------------------------
          // COMPACT
          // ----------------------------------------------------

          if (compact) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                periodField,

                const SizedBox(height: 14),

                statusField,

                if (_period == 'selected') ...[
                  const SizedBox(height: 14),
                  dateFields,
                ],

                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerRight,
                  child: actionButtons,
                ),
              ],
            );
          }

          // ----------------------------------------------------
          // DESKTOP
          // ----------------------------------------------------

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              periodField,

              const SizedBox(width: 16),

              statusField,

              if (_period == 'selected') ...[
                const SizedBox(width: 16),

                Expanded(
                  child: dateFields,
                ),
              ],

              const Spacer(),

              actionButtons,
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // DATE BUTTON
  // ============================================================

  Widget _dateButton({
    required String label,
    required String value,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration(
    String label,
  ) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF1D5CFF),
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
              ),
            ),
          ),

          TextButton(
            onPressed: _loadReport,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _summaryCard(
            'Total Assignments',
            _number(
              _summary['total_assignments'],
            ).toString(),
            Icons.assignment_outlined,
          ),

          _summaryCard(
            'Released',
            _number(
              _summary['released'],
            ).toString(),
            Icons.check_circle_outline,
          ),

          _summaryCard(
            'Assigned',
            _number(
              _summary['currently_assigned'],
            ).toString(),
            Icons.account_tree_outlined,
          ),

          _summaryCard(
            'Removed',
            _number(
              _summary['removed'],
            ).toString(),
            Icons.remove_circle_outline,
          ),

          _summaryCard(
            'Unique Flaxes',
            _number(
              _summary['unique_flaxes'],
            ).toString(),
            Icons.view_module_outlined,
          ),

          _summaryCard(
            'Unique Trees',
            _number(
              _summary['unique_trees'],
            ).toString(),
            Icons.forest_outlined,
          ),
        ];

        if (constraints.maxWidth < 700) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards,
        );
      },
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF1D5CFF),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
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
  // RESULTS TABLE
  // ============================================================

  Widget _buildResultsTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Assignment Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),

                Text(
                  '${_results.length} records',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Status: ${_statusLabel()}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 16),

            if (_results.isEmpty)
              const SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'No assignment records found for this period and status.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              _buildDataTable(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATA TABLE
  // ============================================================

  Widget _buildDataTable() {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 46,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 58,
          columnSpacing: 28,

          headingTextStyle:
              const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),

          dataTextStyle:
              const TextStyle(
            fontSize: 12,
            color: Color(0xFF0F172A),
          ),

          columns: const [
            DataColumn(
              label: Text('#'),
            ),
            DataColumn(
              label: Text('FLAX NO'),
            ),
            DataColumn(
              label: Text('SIZE'),
            ),
            DataColumn(
              label: Text('DESIGN'),
            ),
            DataColumn(
              label: Text('TREE NO'),
            ),
            DataColumn(
              label: Text('ASSIGNED'),
            ),
            DataColumn(
              label: Text('RELEASED'),
            ),
            DataColumn(
              label: Text('DURATION'),
            ),
            DataColumn(
              label: Text('STATUS'),
            ),
          ],

          rows: List<DataRow>.generate(
            _results.length,
            (index) {
              final item =
                  Map<String, dynamic>.from(
                _results[index] as Map,
              );

              final status = _text(
                item['status'],
                fallback: 'Assigned',
              );

              return DataRow(
                cells: [
                  DataCell(
                    Text('${index + 1}'),
                  ),

                  DataCell(
                    Text(
                      _text(item['flax_no']),
                    ),
                  ),

                  DataCell(
                    Text(
                      _text(item['flax_size']),
                    ),
                  ),

                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        _text(
                          item['design_name'],
                        ),
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  DataCell(
                    Text(
                      _text(item['tree_no']),
                    ),
                  ),

                  DataCell(
                    Text(
                      _displayDateTime(
                        item['assigned_on'],
                      ),
                    ),
                  ),

                  DataCell(
                    Text(
                      _displayDateTime(
                        item['released_on'],
                      ),
                    ),
                  ),

                  DataCell(
                    Text(
                      _text(item['duration']),
                    ),
                  ),

                  DataCell(
                    _statusChip(status),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(String status) {
    final normalized =
        status.toLowerCase().trim();

    Color foreground;
    Color background;

    if (normalized == 'released') {
      foreground = const Color(0xFF059669);
      background = const Color(0xFFE1F6EB);
    } else if (normalized == 'removed') {
      foreground = const Color(0xFFDC2626);
      background = const Color(0xFFFEE2E2);
    } else {
      foreground = const Color(0xFF2563EB);
      background = const Color(0xFFEFF6FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
