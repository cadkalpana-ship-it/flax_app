import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/api_service.dart';

class FlaxReportScreen extends StatefulWidget {
  final String userName;

  const FlaxReportScreen({
    super.key,
    required this.userName,
  });

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

    if (_statusFilter == 'all') {
      return value;
    }

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

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> refreshData() async {
    await _loadReport();
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

      if (_endDate!.isBefore(_startDate!)) {
        setState(() {
          _error = 'End date cannot be before start date.';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      debugPrint(
        'Loading Flax Assignment Report',
      );

      debugPrint(
        'Period: $_period',
      );

      debugPrint(
        'Status: $_statusFilter',
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

      debugPrint(
        'Report loaded successfully.',
      );

      debugPrint(
        'Results: ${_results.length}',
      );

      debugPrint(
        'Summary: $_summary',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'REPORT ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // DATE PICKERS
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

      if (_endDate != null &&
          _endDate!.isBefore(picked)) {
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
  // EXCEL EXPORT
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
      final excel = Excel.createExcel();

      excel.rename(
        'Sheet1',
        'Summary',
      );

      final summarySheet = excel['Summary'];

      final detailsSheet =
          excel['Assignment Details'];

      _buildSummarySheet(summarySheet);
      _buildDetailsSheet(detailsSheet);

      excel.setDefaultSheet('Summary');

      final generatedBytes = excel.save();

      if (generatedBytes == null ||
          generatedBytes.isEmpty) {
        throw Exception(
          'Excel file could not be generated.',
        );
      }

      final bytes = Uint8List.fromList(
        generatedBytes,
      );

      await FileSaver.instance.saveAs(
        name: _buildFileName(),
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
  // PDF EXPORT
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
      final pdf = pw.Document();

      // --------------------------------------------------------
      // SUMMARY PAGE
      // --------------------------------------------------------

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
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Downloaded by: '
                    '${widget.userName.isEmpty ? 'User' : widget.userName}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} '
                    'of ${context.pagesCount}',
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
                    _displayDate(
                      _report?['start_date'],
                    ),
                  ),
                  _pdfInfoRow(
                    'End Date',
                    _displayDate(
                      _report?['end_date'],
                    ),
                  ),
                  _pdfInfoRow(
                    'Generated On',
                    _displayDateTime(
                      DateTime.now(),
                    ),
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
                      _summary[
                          'average_assignment_days'],
                    ).toStringAsFixed(2),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // --------------------------------------------------------
      // DETAILS
      // --------------------------------------------------------

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

      for (
        int index = 0;
        index < _results.length;
        index++
      ) {
        final item =
            Map<String, dynamic>.from(
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
                headerDecoration:
                    const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 7,
                ),
                cellPadding:
                    const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 5,
                ),
                cellAlignment:
                    pw.Alignment.centerLeft,
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

      await Printing.sharePdf(
        bytes: bytes,
        filename: '${_buildFileName()}.pdf',
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

    String two(int value) =>
        value.toString().padLeft(2, '0');

    final timestamp =
        '${now.year}'
        '${two(now.month)}'
        '${two(now.day)}_'
        '${two(now.hour)}'
        '${two(now.minute)}';

    final statusPart =
        _statusFilter == 'all'
            ? ''
            : '_${_statusFilter[0].toUpperCase()}'
                '${_statusFilter.substring(1)}';

    return 'Flax_Assignment_Report'
        '$statusPart'
        '_$timestamp';
  }

  // ============================================================
  // EXCEL SUMMARY
  // ============================================================

  void _buildSummarySheet(Sheet sheet) {
    sheet.appendRow([
      TextCellValue(
        'FLAX ASSIGNMENT REPORT',
      ),
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
        _displayDate(
          _report?['start_date'],
        ),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('End Date'),
      TextCellValue(
        _displayDate(
          _report?['end_date'],
        ),
      ),
    ]);

    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('SUMMARY'),
    ]);

    sheet.appendRow([
      TextCellValue('Total Assignments'),
      IntCellValue(
        _number(
          _summary['total_assignments'],
        ),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Released'),
      IntCellValue(
        _number(
          _summary['released'],
        ),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Currently Assigned'),
      IntCellValue(
        _number(
          _summary['currently_assigned'],
        ),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Removed'),
      IntCellValue(
        _number(
          _summary['removed'],
        ),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Unique Flaxes'),
      IntCellValue(
        _number(
          _summary['unique_flaxes'],
        ),
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Unique Trees'),
      IntCellValue(
        _number(
          _summary['unique_trees'],
        ),
      ),
    ]);

    sheet.appendRow([
      TextCellValue(
        'Average Assignment Days',
      ),
      DoubleCellValue(
        _double(
          _summary[
              'average_assignment_days'],
        ),
      ),
    ]);

    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('Displayed Records'),
      IntCellValue(_results.length),
    ]);

    sheet.appendRow([
      TextCellValue('Generated On'),
      TextCellValue(
        _displayDateTime(
          DateTime.now(),
        ),
      ),
    ]);
  }

  // ============================================================
  // EXCEL DETAILS
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

    for (
      int index = 0;
      index < _results.length;
      index++
    ) {
      final item =
          Map<String, dynamic>.from(
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
          _displayDateTime(
            item['assigned_on'],
          ),
        ),
        TextCellValue(
          _displayDateTime(
            item['released_on'],
          ),
        ),
        TextCellValue(
          _displayDateTime(
            item['removed_on'],
          ),
        ),
        TextCellValue(
          _text(item['duration']),
        ),
        DoubleCellValue(
          _double(
            item['duration_days'],
          ),
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
    if (value == null) {
      return 0;
    }

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
    if (value == null) {
      return 0;
    }

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
    if (value == null) {
      return fallback;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  String _displayDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    if (text.length >= 10) {
      return text.substring(0, 10);
    }

    return text;
  }

  String _displayDateTime(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    final parsed =
        DateTime.tryParse(text);

    if (parsed == null) {
      return text;
    }

    final local =
        parsed.toLocal();

    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(local.day)}-'
        '${two(local.month)}-'
        '${local.year} '
        '${two(local.hour)}:'
        '${two(local.minute)}';
  }

  // ============================================================
  // PERIOD
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
  // STATUS
  // ============================================================

  String _statusLabel() {
    switch (_statusFilter) {
      case 'assigned':
        return 'Assigned';

      case 'released':
        return 'Released';

      case 'removed':
        return 'Removed';

      default:
        return 'All Statuses';
    }
  }

  // ============================================================
  // DATE DISPLAY
  // ============================================================

  String _formatDate(DateTime date) {
    String two(int value) =>
        value.toString().padLeft(2, '0');

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
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError
                  ? Colors.red.shade700
                  : null,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal:
                constraints.maxWidth < 600
                    ? 12
                    : 24,
            vertical:
                constraints.maxWidth < 600
                    ? 16
                    : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1600,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildFilters(),

                  const SizedBox(
                    height: 20,
                  ),

                  if (_error != null) ...[
                    _buildErrorCard(),
                    const SizedBox(
                      height: 20,
                    ),
                  ],

                  if (_loading)
                    _buildLoading()
                  else if (_report != null) ...[
                    _buildSummaryCards(),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildResultsTable(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 80,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child:
                CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading report...',
            style: TextStyle(
              fontSize: 13,
              color:
                  Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final compact =
            constraints.maxWidth < 800;

        final title = Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Flax Assignment Report',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Review flax assignments, release history and duration',
              style: const TextStyle(
                fontSize: 13,
                color:
                    Color(0xFF64748B),
              ),
            ),
          ],
        );

        final buttons = Wrap(
          spacing: 10,
          runSpacing: 10,
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
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .table_view_outlined,
                      size: 18,
                    ),
              label: const Text(
                'Download XLSX',
              ),
            ),
            OutlinedButton.icon(
              onPressed:
                  _downloading ||
                          _report == null ||
                          _results.isEmpty
                      ? null
                      : _downloadPdf,
              icon: const Icon(
                Icons
                    .picture_as_pdf_outlined,
                size: 18,
              ),
              label: const Text(
                'Download PDF',
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 14),
              buttons,
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            Expanded(
              child: title,
            ),
            const SizedBox(width: 20),
            buttons,
          ],
        );
      },
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.025,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final compact =
              constraints.maxWidth < 900;

          final periodField =
              _buildPeriodField();

          final statusField =
              _buildStatusField();

          final dateFields =
              _buildDateFields();

          final generateButton =
              OutlinedButton.icon(
            onPressed:
                _loading
                    ? null
                    : _loadReport,
            icon: const Icon(
              Icons.refresh,
              size: 18,
            ),
            label: const Text(
              'Generate Report',
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                periodField,

                const SizedBox(
                  height: 14,
                ),

                statusField,

                if (_period ==
                    'selected') ...[
                  const SizedBox(
                    height: 14,
                  ),
                  dateFields,
                ],

                const SizedBox(
                  height: 14,
                ),

                Align(
                  alignment:
                      Alignment.centerRight,
                  child:
                      generateButton,
                ),
              ],
            );
          }

          return Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment:
                WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 220,
                child: periodField,
              ),

              SizedBox(
                width: 210,
                child: statusField,
              ),

              if (_period ==
                  'selected')
                SizedBox(
                  width: 420,
                  child: dateFields,
                ),

              generateButton,
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // PERIOD FIELD
  // ============================================================

  Widget _buildPeriodField() {
    return DropdownButtonFormField<String>(
      value: _period,
      isExpanded: true,
      decoration:
          _inputDecoration(
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
          child: Text(
            'Selected Date Range',
          ),
        ),
      ],
      onChanged: _loading
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _period = value;

                if (value !=
                    'selected') {
                  _startDate = null;
                  _endDate = null;
                }
              });
            },
    );
  }

  // ============================================================
  // STATUS FIELD
  // ============================================================

  Widget _buildStatusField() {
    return DropdownButtonFormField<String>(
      value: _statusFilter,
      isExpanded: true,
      decoration:
          _inputDecoration(
        'Assignment Status',
      ),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text(
            'All Statuses',
          ),
        ),
        DropdownMenuItem(
          value: 'assigned',
          child: Text(
            'Assigned',
          ),
        ),
        DropdownMenuItem(
          value: 'released',
          child: Text(
            'Released',
          ),
        ),
        DropdownMenuItem(
          value: 'removed',
          child: Text(
            'Removed',
          ),
        ),
      ],
      onChanged: _loading
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _statusFilter =
                    value;
              });
            },
    );
  }

  // ============================================================
  // DATE FIELDS
  // ============================================================

  Widget _buildDateFields() {
    return Row(
      children: [
        Expanded(
          child: _dateButton(
            label: 'From',
            value:
                _startDate == null
                    ? 'Select date'
                    : _formatDate(
                        _startDate!,
                      ),
            onPressed:
                _loading
                    ? () {}
                    : _pickStartDate,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: _dateButton(
            label: 'To',
            value:
                _endDate == null
                    ? 'Select date'
                    : _formatDate(
                        _endDate!,
                      ),
            onPressed:
                _loading
                    ? () {}
                    : _pickEndDate,
          ),
        ),
      ],
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
      style:
          OutlinedButton.styleFrom(
        alignment:
            Alignment.centerLeft,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        minimumSize:
            const Size(0, 58),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            8,
          ),
        ),
        side: const BorderSide(
          color:
              Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color:
                  Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color:
                  Color(0xFF0F172A),
              fontWeight:
                  FontWeight.w500,
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
      fillColor:
          const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(8),
        borderSide:
            const BorderSide(
          color:
              Color(0xFF1D5CFF),
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
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color:
                    Color(0xFF991B1B),
                fontSize: 13,
              ),
            ),
          ),

          TextButton(
            onPressed:
                _loading
                    ? null
                    : _loadReport,
            child:
                const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARDS
  // ============================================================

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final width =
            constraints.maxWidth;

        int columns;

        if (width < 550) {
          columns = 1;
        } else if (width < 850) {
          columns = 2;
        } else if (width < 1200) {
          columns = 3;
        } else {
          columns = 6;
        }

        const spacing = 12.0;

        final cardWidth =
            columns == 1
                ? width
                : (width -
                        (spacing *
                            (columns - 1))) /
                    columns;

        final cards = [
          _summaryCard(
            'Total Assignments',
            _number(
              _summary[
                  'total_assignments'],
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
              _summary[
                  'currently_assigned'],
            ).toString(),
            Icons
                .account_tree_outlined,
          ),
          _summaryCard(
            'Removed',
            _number(
              _summary['removed'],
            ).toString(),
            Icons
                .remove_circle_outline,
          ),
          _summaryCard(
            'Unique Flaxes',
            _number(
              _summary[
                  'unique_flaxes'],
            ).toString(),
            Icons
                .view_module_outlined,
          ),
          _summaryCard(
            'Unique Trees',
            _number(
              _summary[
                  'unique_trees'],
            ).toString(),
            Icons.forest_outlined,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: cardWidth,
                  child: card,
                ),
              )
              .toList(),
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
      width: double.infinity,
      constraints:
          const BoxConstraints(
        minHeight: 100,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.025,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFEFF6FF),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color:
                  const Color(0xFF1D5CFF),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        Color(0xFF64748B),
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF0F172A),
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
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.025,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                if (constraints.maxWidth <
                    500) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Assignment Details',
                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Color(
                            0xFF0F172A,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      _tableMeta(),
                    ],
                  );
                }

                return Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Assignment Details',
                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Color(
                            0xFF0F172A,
                          ),
                        ),
                      ),
                    ),
                    _tableMeta(),
                  ],
                );
              },
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Status: ${_statusLabel()}',
              style: const TextStyle(
                fontSize: 11,
                color:
                    Color(0xFF64748B),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            if (_results.isEmpty)
              _buildEmptyState()
            else
              _buildDataTable(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TABLE META
  // ============================================================

  Widget _tableMeta() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF1F5F9),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        '${_results.length} records',
        style: const TextStyle(
          fontSize: 11,
          fontWeight:
              FontWeight.w600,
          color:
              Color(0xFF475569),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      constraints:
          const BoxConstraints(
        minHeight: 220,
      ),
      padding:
          const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons
                  .assignment_outlined,
              size: 28,
              color:
                  Color(0xFF94A3B8),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'No assignment records found',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w600,
              color:
                  Color(0xFF334155),
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'Try changing the report period or assignment status.',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 12,
              color:
                  Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA TABLE
  // ============================================================

  Widget _buildDataTable() {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(8),
      child: Container(
        decoration:
            BoxDecoration(
          border: Border.all(
            color:
                const Color(
              0xFFE2E8F0,
            ),
          ),
          borderRadius:
              BorderRadius.circular(
            8,
          ),
        ),
        child:
            SingleChildScrollView(
          scrollDirection:
              Axis.horizontal,
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 50,
            dataRowMaxHeight: 62,
            columnSpacing: 28,
            horizontalMargin: 16,

            headingTextStyle:
                const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF475569),
            ),

            dataTextStyle:
                const TextStyle(
              fontSize: 12,
              color:
                  Color(0xFF0F172A),
            ),

            headingRowColor:
                WidgetStateProperty
                    .all(
              const Color(
                0xFFF8FAFC,
              ),
            ),

            columns: const [
              DataColumn(
                label: Text('#'),
              ),
              DataColumn(
                label:
                    Text('FLAX NO'),
              ),
              DataColumn(
                label:
                    Text('SIZE'),
              ),
              DataColumn(
                label:
                    Text('DESIGN'),
              ),
              DataColumn(
                label:
                    Text('TREE NO'),
              ),
              DataColumn(
                label:
                    Text('ASSIGNED'),
              ),
              DataColumn(
                label:
                    Text('RELEASED'),
              ),
              DataColumn(
                label:
                    Text('DURATION'),
              ),
              DataColumn(
                label:
                    Text('STATUS'),
              ),
            ],

            rows: List<
                DataRow>.generate(
              _results.length,
              (index) {
                final item =
                    Map<String,
                        dynamic>.from(
                  _results[index]
                      as Map,
                );

                final status =
                    _text(
                  item['status'],
                  fallback:
                      'Assigned',
                );

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '${index + 1}',
                      ),
                    ),

                    DataCell(
                      Text(
                        _text(
                          item[
                              'flax_no'],
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        _text(
                          item[
                              'flax_size'],
                        ),
                      ),
                    ),

                    DataCell(
                      SizedBox(
                        width: 160,
                        child: Text(
                          _text(
                            item[
                                'design_name'],
                          ),
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        _text(
                          item[
                              'tree_no'],
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        _displayDateTime(
                          item[
                              'assigned_on'],
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        _displayDateTime(
                          item[
                              'released_on'],
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        _text(
                          item[
                              'duration'],
                        ),
                      ),
                    ),

                    DataCell(
                      _statusChip(
                        status,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(
    String status,
  ) {
    final normalized =
        status.toLowerCase().trim();

    Color foreground;
    Color background;

    if (normalized ==
        'released') {
      foreground =
          const Color(0xFF059669);
      background =
          const Color(0xFFE1F6EB);
    } else if (normalized ==
        'removed') {
      foreground =
          const Color(0xFFDC2626);
      background =
          const Color(0xFFFEE2E2);
    } else {
      foreground =
          const Color(0xFF2563EB);
      background =
          const Color(0xFFEFF6FF);
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}