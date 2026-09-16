import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/tree_module_row.dart';
import '../services/api_service.dart';

class TreeModuleScreen extends StatefulWidget {
  const TreeModuleScreen({super.key});

  @override
  State<TreeModuleScreen> createState() => TreeModuleScreenState();
}

class TreeModuleScreenState extends State<TreeModuleScreen> {
  final ApiService _api = ApiService();

  

  // ============================================================
  // DROPDOWN VALUES
  // ============================================================

  static const List<String> _purityOptions = [
    '58.50',
    '58.60',
    '58.65',
    '59.00',
    '59.60',
    '75.10',
    '75.15',
    '75.25',
    '75.50',
    '76.00',
    '37.70',
    '920',
    '850',
  ];

  static const List<String> _colourOptions = [
    'Yellow',
    'White',
    'Rose',
    'Silver',
  ];

  // ============================================================
  // FORM CONTROLLERS
  // ============================================================

  final TextEditingController _treeNoController =
      TextEditingController();

  final TextEditingController _treeWtController =
      TextEditingController();

  final TextEditingController _requireMetalController =
      TextEditingController();

  final TextEditingController _reqPureMetalController =
      TextEditingController();

  final TextEditingController _requireAlloyController =
      TextEditingController();

  final TextEditingController _styleNoController =
      TextEditingController();

  final TextEditingController _bagNoController =
      TextEditingController();

  String? _selectedPurity;
  String? _selectedColour;

  // ============================================================
  // PENDING ROWS
  // ============================================================

  final List<TreeModuleRow> _rows = [];

  // ============================================================
  // IMAGES
  // ============================================================

  final List<_PickedTreeImage> _images = [];

  bool _submitting = false;

  // ============================================================
  // SUBMITTED BATCHES
  // ============================================================

  List<Map<String, dynamic>> _submittedBatches = [];

  Map<String, dynamic>? _selectedBatch;

  bool _loadingBatches = true;

  String? _batchError;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
print('in initstate');
    _loadSubmittedBatches();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refreshData() async {
    await _loadSubmittedBatches();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _treeNoController.dispose();
    _treeWtController.dispose();
    _requireMetalController.dispose();
    _reqPureMetalController.dispose();
    _requireAlloyController.dispose();
    _styleNoController.dispose();
    _bagNoController.dispose();

    super.dispose();
  }

  // ============================================================
  // ENTER ROW
  // ============================================================

  void _onEnter() {
    final treeNo = _treeNoController.text.trim();
    final treeWt = _treeWtController.text.trim();

    if (treeNo.isEmpty) {
      _showMessage('Please enter a Tree No.');
      return;
    }

    if (treeWt.isEmpty) {
      _showMessage('Please enter Tree Weight.');
      return;
    }

    if (double.tryParse(treeWt) == null) {
      _showMessage('Please enter a valid Tree Weight.');
      return;
    }

    if (_selectedPurity == null ||
        _selectedPurity!.trim().isEmpty) {
      _showMessage('Please select Purity.');
      return;
    }

    if (_selectedColour == null ||
        _selectedColour!.trim().isEmpty) {
      _showMessage('Please select Colour.');
      return;
    }

    setState(() {
      _rows.add(
        TreeModuleRow(
          slNo: _rows.length + 1,
          styleNo: _styleNoController.text.trim(),
          bagNo: _bagNoController.text.trim(),
          treeNo: treeNo,
          treeWt: _treeWtController.text.trim(),
          purity: _selectedPurity ?? '',
          colour: _selectedColour ?? '',
          requireMetal: _requireMetalController.text.trim(),
          reqPureMetal: _reqPureMetalController.text.trim(),
          requireAlloy: _requireAlloyController.text.trim(),
        ),
      );

      

      _styleNoController.clear();
      _bagNoController.clear();

    });
  }

  // ============================================================
  // REMOVE PENDING ROW
  // ============================================================

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index);

      for (var i = 0; i < _rows.length; i++) {
        final old = _rows[i];

        _rows[i] = TreeModuleRow(
          slNo: i + 1,
          styleNo: old.styleNo,
          bagNo: old.bagNo,
          treeNo: old.treeNo,
          treeWt: old.treeWt,
          purity: old.purity,
          colour: old.colour,
          requireMetal: old.requireMetal,
          reqPureMetal: old.reqPureMetal,
          requireAlloy: old.requireAlloy,
        );
      }
    });
  }

  // ============================================================
  // CALCULATIONS
  // ============================================================

  void _calculateAll() {
    _calculateRequiredMetal();
    _calculateRequiredPureMetal();
    _calculateRequiredAlloy();

    if (mounted) {
      setState(() {});
    }
  }

  void _calculateRequiredMetal() {
    final treeWt =
        double.tryParse(_treeWtController.text.trim());

    final purity =
        double.tryParse(_selectedPurity ?? '');

    if (treeWt == null || purity == null) {
      _requireMetalController.clear();
      return;
    }

    // ----------------------------------------------------------
    // Existing calculation
    //
    // Purity 75 - 76
    // Required Metal = Tree Weight x 15.5
    //
    // Purity 58 - 60
    // Required Metal = Tree Weight x 14.5
    // ----------------------------------------------------------

    if (purity >= 75.0 && purity <= 76.0) {
      final requiredMetal = treeWt * 15.5;

      _requireMetalController.text =
          requiredMetal.toStringAsFixed(2);
    } else if (purity >= 58.0 && purity <= 60.0) {
      final requiredMetal = treeWt * 14.5;

      _requireMetalController.text =
          requiredMetal.toStringAsFixed(2);
    } else {
      _requireMetalController.clear();
    }
  }

  void _calculateRequiredPureMetal() {
    final purity =
        double.tryParse(_selectedPurity ?? '');

    final requiredMetal =
        double.tryParse(
      _requireMetalController.text.trim(),
    );

    if (purity == null || requiredMetal == null) {
      _reqPureMetalController.clear();
      return;
    }

    final requiredPureMetal =
        (requiredMetal * purity) / 100;

    _reqPureMetalController.text =
        requiredPureMetal.toStringAsFixed(2);
  }

  void _calculateRequiredAlloy() {
    final requiredMetal =
        double.tryParse(
      _requireMetalController.text.trim(),
    );

    final requiredPureMetal =
        double.tryParse(
      _reqPureMetalController.text.trim(),
    );

    if (requiredMetal == null ||
        requiredPureMetal == null) {
      _requireAlloyController.clear();
      return;
    }

    final requiredAlloy =
        requiredMetal - requiredPureMetal;

    _requireAlloyController.text =
        requiredAlloy.toStringAsFixed(2);
  }

  // ============================================================
  // IMAGE PICKING
  // ============================================================

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();

      final picked = await picker.pickMultiImage(
        imageQuality: 85,
      );

      if (picked.isEmpty) {
        return;
      }

      final newImages = <_PickedTreeImage>[];

      for (final file in picked) {
        final bytes = await file.readAsBytes();

        if (bytes.isEmpty) {
          continue;
        }

        newImages.add(
          _PickedTreeImage(
            file: file,
            bytes: bytes,
          ),
        );
      }

      if (!mounted || newImages.isEmpty) {
        return;
      }

      setState(() {
        _images.addAll(newImages);
      });
    } catch (e) {
      _showMessage(
        'Unable to select images: $e',
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // ============================================================
  // SUBMIT BATCH
  // ============================================================

  // ============================================================
  // SUBMIT BATCH
  // ============================================================

  Future<void> _onSubmit() async {
    if (_rows.isEmpty) {
      _showMessage(
        'Add at least one row with ENTER before submitting.',
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final submittedRowCount = _rows.length;

      final batchId =
          await _api.submitTreeModuleBatch(_rows);

      if (_images.isNotEmpty) {
        await _api.uploadTreeModuleImages(
          batchId,
          _images
              .map(
                (image) => image.file,
              )
              .toList(),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        // ------------------------------------------------------
        // CRITICAL FIXES APPLIED HERE:
        // ------------------------------------------------------
        _treeNoController.clear();
        _treeWtController.clear();
        _requireMetalController.clear();
        _reqPureMetalController.clear();
        _requireAlloyController.clear();
        _styleNoController.clear();
        _bagNoController.clear();
        
        // Reset the selection variables, NOT the option arrays
        _selectedPurity = null;
        _selectedColour = null;
        
        _rows.clear();
        _images.clear();
        _submitting = false;
      });

      _showMessage(
        'Submitted $submittedRowCount row(s) successfully.',
      );

      await _loadSubmittedBatches(
        preferredBatchId: batchId,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      _showMessage(
        'Submit failed: $e',
      );
    }
  }


  // ============================================================
  // LOAD SUBMITTED BATCHES
  // ============================================================

  Future<void> _loadSubmittedBatches({
    int? preferredBatchId,
  }) async {
    if (mounted) {
      setState(() {
        _loadingBatches = true;
        _batchError = null;
      });
    }

    try {
      final data =
          await _api.fetchTreeModuleBatches();

      final batches = data
          .whereType<Map>()
          .map(
            (item) =>
                Map<String, dynamic>.from(item),
          )
          .toList();

      if (!mounted) {
        return;
      }

      Map<String, dynamic>? selected;

      // Prefer newly submitted batch.
      if (preferredBatchId != null) {
        for (final batch in batches) {
          if (_intValue(batch['id']) ==
              preferredBatchId) {
            selected = batch;
            break;
          }
        }
      }

      // Keep currently selected batch.
      if (selected == null &&
          _selectedBatch != null) {
        selected = _findBatchById(
          batches,
          _intValue(
            _selectedBatch!['id'],
          ),
        );
      }

      // Otherwise select latest batch.
      selected ??=
          batches.isNotEmpty
              ? batches.first
              : null;

      setState(() {
        _submittedBatches = batches;
        _selectedBatch = selected;
        _loadingBatches = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingBatches = false;
        _batchError = e.toString();
      });
    }
  }

  Map<String, dynamic>? _findBatchById(
    List<Map<String, dynamic>> batches,
    int? id,
  ) {
    if (id == null) {
      return null;
    }

    for (final batch in batches) {
      if (_intValue(batch['id']) == id) {
        return batch;
      }
    }

    return null;
  }

  void _selectBatch(
    Map<String, dynamic> batch,
  ) {
    setState(() {
      _selectedBatch = batch;
    });
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F6FD),
      child: LayoutBuilder(
        builder: (context, viewport) {
          final isMobile = viewport.maxWidth < 800;

          // On phones/tablets, the whole page must scroll naturally.
          // Do not use Expanded for the pending/submitted panels here:
          // their internal table bodies need a real, positive height.
          if (isMobile) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildEntryPanel(),
                const SizedBox(height: 10),
                SizedBox(
                  // The table contains its own Expanded body.
                  // Give it enough room for the title, column header,
                  // empty state and footer so Flutter never overflows.
                  height: 255,
                  child: _buildTable(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 430,
                  child: _buildSubmittedPanel(),
                ),
              ],
            );
          }

          // Desktop keeps the efficient side-by-side layout.
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildEntryPanel(),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildTable(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: _buildSubmittedPanel(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2E6B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.account_tree_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Tree Module Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Enter tree, style, bag and metal information',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFD7E4FF),
                    fontSize: 9.5,
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
  // FULL WIDTH ENTRY PANEL
  // ============================================================

  Widget _buildEntryPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        11,
        12,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.025),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.account_tree_outlined,
            'Tree Entry Details',
            'Enter tree and style information',
          ),

          const SizedBox(height: 9),

          // ----------------------------------------------------
          // ROW 1
          // ----------------------------------------------------

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _textField(
                  'Tree No',
                  _treeNoController,
                  hint: 'Enter Tree No',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                flex: 3,
                child: _textField(
                  'Tree Weight',
                  _treeWtController,
                  hint: 'Enter weight',
                  numeric: true,
                  onChanged: (_) {
                    _calculateAll();
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                flex: 3,
                child: _dropdownField(
                  'Purity',
                  _selectedPurity,
                  _purityOptions,
                  (value) {
                    setState(() {
                      _selectedPurity = value;
                    });

                    _calculateAll();
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                flex: 3,
                child: _dropdownField(
                  'Colour',
                  _selectedColour,
                  _colourOptions,
                  (value) {
                    setState(() {
                      _selectedColour = value;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // ----------------------------------------------------
          // METAL CALCULATION
          // ----------------------------------------------------

          Row(
            children: [
              _sectionHeader(
                Icons.calculate_outlined,
                'Metal Calculation',
                '',
              ),

              const SizedBox(width: 7),

              _autoChip(),
            ],
          ),

          const SizedBox(height: 7),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _textField(
                  'Required Metal',
                  _requireMetalController,
                  hint: 'Calculated automatically',
                  numeric: true,
                  readOnly: true,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _textField(
                  'Pure Metal',
                  _reqPureMetalController,
                  hint: 'Calculated automatically',
                  numeric: true,
                  readOnly: true,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _textField(
                  'Alloy',
                  _requireAlloyController,
                  hint: 'Calculated automatically',
                  numeric: true,
                  readOnly: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // ----------------------------------------------------
          // STYLE / BAG / ACTIONS
          // ----------------------------------------------------

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: _textField(
                  'Style No',
                  _styleNoController,
                  hint: 'Enter Style No',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                flex: 3,
                child: _textField(
                  'Bag No',
                  _bagNoController,
                  hint: 'Enter Bag No',
                ),
              ),

              const SizedBox(width: 10),

              SizedBox(
                width: 120,
                height: 42,
                child: FilledButton.icon(
                  onPressed:
                      _submitting
                          ? null
                          : _onEnter,
                  icon: const Icon(
                    Icons.add,
                    size: 17,
                  ),
                  label: const Text(
                    'ENTER',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1D5CFF),
                    disabledBackgroundColor:
                        const Color(0xFFCBD5E1),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

            
            ],
          ),

          const SizedBox(height: 9),

          // ----------------------------------------------------
          // IMAGE STRIP
          // ----------------------------------------------------

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 15,
                color: Color(0xFF64748B),
              ),

              const SizedBox(width: 6),

              const Text(
                'Tree Images',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),

              const SizedBox(width: 7),

              if (_images.isNotEmpty)
                _countChip(
                  _images.length,
                  background:
                      const Color(0xFFEFF6FF),
                  foreground:
                      const Color(0xFF1D5CFF),
                ),

              const Spacer(),

              TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 15,
                ),
                label: Text(
                  _images.isEmpty
                      ? 'Add Images'
                      : 'Add More',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor:
                      const Color(0xFF1D5CFF),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  minimumSize:
                      const Size(0, 28),
                ),
              ),
            ],
          ),

          if (_images.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildImageStrip(),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BEAUTIFIED TEXT FIELD
  // ============================================================

  Widget _textField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool numeric = false,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),

        const SizedBox(height: 4),

        TextField(
          controller: controller,
          enabled: !readOnly,
          readOnly: readOnly,
          onChanged: onChanged,

          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),

          cursorColor:
              const Color(0xFF2563EB),

          keyboardType: numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                )
              : TextInputType.text,

          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
            ),

            filled: true,

            fillColor: readOnly
                ? const Color(0xFFF1F5F9)
                : Colors.white,

            isDense: true,

            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),

            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(7),
              borderSide: const BorderSide(
                color: Color(0xFFDCE4EE),
              ),
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(7),
              borderSide: const BorderSide(
                color: Color(0xFFDCE4EE),
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(7),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.2,
              ),
            ),

            disabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(7),
              borderSide: const BorderSide(
                color: Color(0xFFDCE4EE),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BEAUTIFIED DROPDOWN
  // ============================================================

  Widget _dropdownField(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    final validValue =
        options.contains(value)
            ? value
            : null;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),

        const SizedBox(height: 4),

        DropdownButtonFormField<String>(
          value: validValue,

          isExpanded: true,

          isDense: true,

          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF64748B),
          ),

          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),

          decoration: InputDecoration(
            hintText: 'Select $label',
            hintStyle: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
            ),

            filled: true,

            fillColor: Colors.white,

            isDense: true,

            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),

            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(7),
              borderSide: const BorderSide(
                color: Color(0xFFDCE4EE),
              ),
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(7),
              borderSide: const BorderSide(
                color: Color(0xFFDCE4EE),
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(7),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.2,
              ),
            ),
          ),

          items: options
              .map(
                (option) =>
                    DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),

          onChanged: onChanged,
        ),
      ],
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _sectionHeader(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius:
                BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: const Color(0xFF1D5CFF),
          ),
        ),

        const SizedBox(width: 7),

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),

            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // AUTO CHIP
  // ============================================================

  Widget _autoChip() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: const Text(
        'AUTO',
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1D5CFF),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE STRIP
  // ============================================================

  Widget _buildImageStrip() {
    return Container(
      width: double.infinity,
      height: 54,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius:
            BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(width: 6),
        itemBuilder:
            (context, index) {
          final image = _images[index];

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(5),
                child: Image.memory(
                  image.bytes,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),

              Positioned(
                top: -4,
                right: -4,
                child: InkWell(
                  onTap: () =>
                      _removeImage(index),
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration:
                        const BoxDecoration(
                      color: Color(0xFF0F172A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // PENDING TABLE
  // ============================================================

  Widget _buildTable() {
    const headers = [
      'SL NO',
      'STYLE NO',
      'BAG NO',
      'TREE NO',
      'PURITY',
      'COLOUR',
      '',
    ];

    const flexes = [
      1,
      2,
      2,
      2,
      2,
      2,
      1,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          // ----------------------------------------------------
          // TABLE TITLE
          // ----------------------------------------------------

          Container(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              9,
              12,
              8,
            ),
            decoration:
                const BoxDecoration(
              color: Color(0xFFFFFBEA),
              borderRadius:
                  BorderRadius.only(
                topLeft:
                    Radius.circular(9),
                topRight:
                    Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.table_rows_outlined,
                  size: 16,
                  color: Color(0xFF64748B),
                ),

                const SizedBox(width: 6),

                const Text(
                  'Pending Tree Entries',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF334155),
                  ),
                ),

                const SizedBox(width: 7),

                _countChip(
                  _rows.length,
                  background:
                      const Color(0xFFEFF6FF),
                  foreground:
                      const Color(0xFF1D5CFF),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------
          // TABLE HEADER
          // ----------------------------------------------------

          Container(
            color:
                const Color(0xFFFFF6C8),
            padding:
                const EdgeInsets.symmetric(
              vertical: 7,
              horizontal: 8,
            ),
            child: Row(
              children:
                  List.generate(
                headers.length,
                (index) {
                  return Expanded(
                    flex: flexes[index],
                    child: Text(
                      headers[index],
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 8.5,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            Color(0xFF334155),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFE2E8F0),
          ),

          // ----------------------------------------------------
          // TABLE BODY
          // ----------------------------------------------------

          Expanded(
            child: _rows.isEmpty
                ? _emptyState(
                    Icons.table_rows_outlined,
                    'No rows yet',
                    'Fill the form and tap ENTER.',
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 2,
                    ),
                    itemCount:
                        _rows.length,
                    separatorBuilder:
                        (_, __) =>
                            const Divider(
                      height: 1,
                      color:
                          Color(0xFFF1F5F9),
                    ),
                    itemBuilder:
                        (context, index) {
                      final row =
                          _rows[index];

                      final cells = [
                        '${row.slNo}',
                        row.styleNo,
                        row.bagNo,
                        row.treeNo,
                        row.purity,
                        row.colour,
                      ];

                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 7,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            ...List.generate(
                              cells.length,
                              (cellIndex) {
                                return Expanded(
                                  flex:
                                      flexes[cellIndex],
                                  child: Text(
                                    cells[cellIndex]
                                            .isEmpty
                                        ? '-'
                                        : cells[
                                            cellIndex],
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      fontSize: 9.5,
                                      color:
                                          Color(
                                        0xFF334155,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            Expanded(
                              flex: flexes.last,
                              child: IconButton(
                                onPressed: () =>
                                    _removeRow(
                                  index,
                                ),
                                tooltip:
                                    'Remove row',
                                visualDensity:
                                    VisualDensity
                                        .compact,
                                icon:
                                    const Icon(
                                  Icons
                                      .delete_outline,
                                  size: 16,
                                  color:
                                      Color(
                                    0xFFDC2626,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ----------------------------------------------------
          // TABLE FOOTER
          // ----------------------------------------------------

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius:
                  BorderRadius.only(
                bottomLeft:
                    Radius.circular(9),
                bottomRight:
                    Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _rows.isEmpty
                      ? 'No rows added yet'
                      : '${_rows.length} row(s) ready',
                  style: const TextStyle(
                    fontSize: 9,
                    color:
                        Color(0xFF64748B),
                  ),
                ),

                const Spacer(),

                if (_rows.isNotEmpty)
                    SizedBox(
                width: 140,
                height: 42,
                child: FilledButton.icon(
                  onPressed:
                      (_rows.isEmpty ||
                              _submitting)
                          ? null
                          : _onSubmit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.cloud_upload_outlined,
                          size: 16,
                        ),
                  label: Text(
                    _submitting
                        ? 'Submitting...'
                        : 'SUBMIT',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF0F766E),
                    disabledBackgroundColor:
                        const Color(0xFFCBD5E1),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(7),
                    ),
                  ),
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
  // SUBMITTED PANEL
  // ============================================================

  Widget _buildSubmittedPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          _buildSubmittedHeader(),

          const Divider(
            height: 1,
            color: Color(0xFFE2E8F0),
          ),

          Expanded(
            child:
                _buildSubmittedBody(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMITTED HEADER
  // ============================================================

  Widget _buildSubmittedHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        8,
        7,
        8,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFEFF6FF),
              borderRadius:
                  BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.account_tree_outlined,
              color:
                  Color(0xFF1D5CFF),
              size: 15,
            ),
          ),

          const SizedBox(width: 7),

          const Expanded(
            child: Text(
              'Submitted Tree Details',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xFF1E293B),
              ),
            ),
          ),

          if (_submittedBatches.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedBatch = null;
                });
              },
              icon: const Icon(
                Icons.arrow_back,
                size: 12,
              ),
              label: const Text(
                'All Trees',
                style: TextStyle(
                  fontSize: 9.5,
                ),
              ),
              style:
                  TextButton.styleFrom(
                foregroundColor:
                    const Color(0xFF0F766E),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                minimumSize:
                    const Size(0, 28),
              ),
            ),

          IconButton(
            onPressed: _loadingBatches
                ? null
                : () =>
                    _loadSubmittedBatches(),
            tooltip: 'Refresh',
            visualDensity:
                VisualDensity.compact,
            icon: const Icon(
              Icons.refresh,
              size: 17,
              color:
                  Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMITTED BODY
  // ============================================================

  Widget _buildSubmittedBody() {
    if (_loadingBatches) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      );
    }

    if (_batchError != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 32,
                color:
                    Color(0xFFEF4444),
              ),

              const SizedBox(height: 7),

              const Text(
                'Unable to load submitted trees',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                _batchError!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 9.5,
                  color:
                      Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed:
                    () =>
                        _loadSubmittedBatches(),
                icon: const Icon(
                  Icons.refresh,
                  size: 14,
                ),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_submittedBatches.isEmpty) {
      return _emptyState(
        Icons.cloud_upload_outlined,
        'No submitted trees',
        'Submitted tree details will appear here.',
      );
    }

    if (_selectedBatch == null) {
      return _buildBatchList();
    }

    return _buildSelectedBatch();
  }

  // ============================================================
  // TREE / BATCH LIST
  // ============================================================

  Widget _buildBatchList() {
    return ListView.separated(
      padding:
          const EdgeInsets.all(10),
      itemCount:
          _submittedBatches.length,
      separatorBuilder:
          (_, __) =>
              const SizedBox(height: 7),
      itemBuilder:
          (context, index) {
        final batch =
            _submittedBatches[index];

        final details =
            _detailsFromBatch(batch);

        final treeNumbers =
            _treeNumbersFromDetails(
          details,
        );

        final reference =
            _treeReference(
          treeNumbers,
        );

        return InkWell(
          onTap: () =>
              _selectBatch(batch),
          borderRadius:
              BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  const Color(0xFFF8FAFC),
              borderRadius:
                  BorderRadius.circular(8),
              border: Border.all(
                color:
                    const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment:
                      Alignment.center,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xFFEFF6FF),
                    borderRadius:
                        BorderRadius.circular(
                      7,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .account_tree_outlined,
                    size: 17,
                    color:
                        Color(0xFF1D5CFF),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        reference,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              FontWeight.w700,
                          color:
                              Color(0xFF1E293B),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _formatDateTime(
                          batch[
                              'submitted_on'],
                        ),
                        style:
                            const TextStyle(
                          fontSize: 8.5,
                          color:
                              Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                _countChip(
                  details.length,
                  background:
                      const Color(0xFFEFF6FF),
                  foreground:
                      const Color(0xFF1D5CFF),
                ),

                const SizedBox(width: 4),

                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color:
                      Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SELECTED BATCH
  // ============================================================

  Widget _buildSelectedBatch() {
    final batch =
        _selectedBatch!;

    final details =
        _detailsFromBatch(batch);

    final images =
        _imagesFromBatch(batch);

    final treeNumbers =
        _treeNumbersFromDetails(
      details,
    );

    final styles = details
        .map(
          (detail) =>
              _textValue(
            detail['style_no'],
          ),
        )
        .where(
          (value) => value != '-',
        )
        .toSet();

    final bags = details
        .map(
          (detail) =>
              _textValue(
            detail['bag_no'],
          ),
        )
        .where(
          (value) => value != '-',
        )
        .toSet();

    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildBatchSummary(
            batch,
          ),

          if (images.isNotEmpty) ...[
            const SizedBox(height: 8),

            _buildSubmittedImages(
              images,
            ),
          ],

          const SizedBox(height: 9),

          Row(
            children: [
              const Icon(
                Icons.account_tree_outlined,
                size: 15,
                color:
                    Color(0xFF1D5CFF),
              ),

              const SizedBox(width: 6),

              const Text(
                'Tree-wise Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF1E293B),
                ),
              ),

              const Spacer(),

              Text(
                '${treeNumbers.length} tree(s)',
                style:
                    const TextStyle(
                  fontSize: 9,
                  color:
                      Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          if (details.isEmpty)
            _emptyState(
              Icons.description_outlined,
              'No details',
              'This tree does not contain detail rows.',
            )
          else
            ..._buildTreeWiseCards(
              details,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildBatchSummary(
  Map<String, dynamic> batch,
) {
  // Get submitted detail rows for this batch.
  final details = _detailsFromBatch(batch);

  // Get unique Tree Nos.
  final uniqueTrees = details
      .map(
        (item) =>
            (item['tree_no'] ?? '').toString().trim(),
      )
      .where(
        (value) => value.isNotEmpty,
      )
      .toSet()
      .toList();

  // Get unique Style Nos.
  final uniqueStyles = details
      .map(
        (item) =>
            (item['style_no'] ?? '').toString().trim(),
      )
      .where(
        (value) => value.isNotEmpty,
      )
      .toSet()
      .length;

  // Get unique Bag Nos.
  final uniqueBags = details
      .map(
        (item) =>
            (item['bag_no'] ?? '').toString().trim(),
      )
      .where(
        (value) => value.isNotEmpty,
      )
      .toSet()
      .length;

  // User-facing reference.
  // Do NOT show Batch ID.
  final treeReference = uniqueTrees.isEmpty
      ? 'Tree Details'
      : uniqueTrees.length == 1
          ? 'Tree ${uniqueTrees.first}'
          : 'Trees ${uniqueTrees.join(', ')}';

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: const Color(0xFFE2E8F0),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------
        // TREE REFERENCE
        // ------------------------------------------------------

        Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: Color(0xFF1D5CFF),
              ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: Text(
                treeReference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Text(
              _formatDateTime(
                batch['submitted_on'],
              ),
              style: const TextStyle(
                fontSize: 8.5,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        // ------------------------------------------------------
        // SUMMARY CARDS
        // ------------------------------------------------------

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.account_tree_outlined,
                value: uniqueTrees.length.toString(),
                label: 'Trees',
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _summaryCard(
                icon: Icons.style_outlined,
                value: uniqueStyles.toString(),
                label: 'Styles',
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _summaryCard(
                icon: Icons.inventory_2_outlined,
                value: uniqueBags.toString(),
                label: 'Bags',
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _summaryCard(
                icon: Icons.table_rows_outlined,
                value: details.length.toString(),
                label: 'Rows',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _summaryCard({
  required IconData icon,
  required String value,
  required String label,
}) {
  return Container(
    height: 75,
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 8,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: const Color(0xFFE2E8F0),
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    ),
  );
}
  // ============================================================
  // SUMMARY STAT
  // ============================================================

  Widget _summaryStat(
    IconData icon,
    int value,
    String label,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 58,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(7),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color:
                const Color(0xFF64748B),
          ),

          const SizedBox(height: 2),

          Text(
            '$value',
            style:
                const TextStyle(
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w700,
              color:
                  Color(0xFF1E293B),
            ),
          ),

          const SizedBox(height: 1),

          Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 8,
              color:
                  Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMITTED IMAGES
  // ============================================================

  Widget _buildSubmittedImages(
    List<Map<String, dynamic>> images,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF8FAFC),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 14,
                color:
                    Color(0xFF1D5CFF),
              ),

              SizedBox(width: 5),

              Text(
                'Tree Images',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF334155),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              itemCount:
                  images.length,
              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                width: 6,
              ),
              itemBuilder:
                  (context, index) {
                final url =
                    _imageUrl(
                  images[index],
                );

                if (url.isEmpty) {
                  return _missingImageBox();
                }

                return ClipRRect(
                  borderRadius:
                      BorderRadius.circular(6),
                  child: Image.network(
                    url,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                            _missingImageBox(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingImageBox() {
    return Container(
      width: 58,
      height: 58,
      alignment:
          Alignment.center,
      decoration: BoxDecoration(
        color:
            const Color(0xFFE2E8F0),
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.broken_image_outlined,
        size: 20,
        color:
            Color(0xFF94A3B8),
      ),
    );
  }

  // ============================================================
  // TREE-WISE CARDS
  // ============================================================

  List<Widget> _buildTreeWiseCards(
    List<Map<String, dynamic>> details,
  ) {
    final groups =
        <String, List<Map<String, dynamic>>>{};

    for (final detail in details) {
      final treeNo =
          _textValue(
        detail['tree_no'],
        fallback: 'Unknown Tree',
      );

      groups.putIfAbsent(
        treeNo,
        () => [],
      );

      groups[treeNo]!.add(detail);
    }

    final entries =
        groups.entries.toList();

    return List.generate(
      entries.length,
      (index) {
        final treeNo =
            entries[index].key;

        final treeRows =
            entries[index].value;

        return Padding(
          padding:
              EdgeInsets.only(
            bottom:
                index == entries.length - 1
                    ? 0
                    : 7,
          ),
          child: _buildTreeWiseCard(
            treeNo,
            treeRows,
          ),
        );
      },
    );
  }

  Widget _buildTreeWiseCard(
    String treeNo,
    List<Map<String, dynamic>> rows,
  ) {
    final first = rows.first;

    final styles = rows
        .map(
          (row) =>
              _textValue(
            row['style_no'],
          ),
        )
        .where(
          (value) => value != '-',
        )
        .toSet()
        .toList();

    final bags = rows
        .map(
          (row) =>
              _textValue(
            row['bag_no'],
          ),
        )
        .where(
          (value) => value != '-',
        )
        .toSet()
        .toList();

    return Container(
      padding:
          const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(6),
                ),
                child: Text(
                  treeNo,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF1D5CFF),
                  ),
                ),
              ),

              const SizedBox(width: 7),

              Text(
                '${rows.length} row(s)',
                style:
                    const TextStyle(
                  fontSize: 8.5,
                  color:
                      Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _detailBox(
                'Tree Weight',
                _textValue(
                  first['tree_wt'],
                ),
              ),

              _detailBox(
                'Purity',
                _textValue(
                  first['purity'],
                ),
              ),

              _detailBox(
                'Colour',
                _textValue(
                  first['colour'],
                ),
              ),

              _detailBox(
                'Bags',
                '${bags.length}',
              ),

              _detailBox(
                'Required Metal',
                _textValue(
                  first['require_metal'],
                ),
              ),

              _detailBox(
                'Pure Metal',
                _textValue(
                  first['req_pure_metal'],
                ),
              ),

              _detailBox(
                'Alloy',
                _textValue(
                  first['require_alloy'],
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          if (styles.isNotEmpty)
            _detailLine(
              'Style No',
              styles.join(', '),
            ),

          if (bags.isNotEmpty)
            _detailLine(
              'Bag No',
              bags.join(', '),
            ),
        ],
      ),
    );
  }

  Widget _detailBox(
  String label,
  String value,
) {
  return Container(
    height: 64,
    padding: const EdgeInsets.symmetric(
      horizontal: 9,
      vertical: 7,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: const Color(0xFFE2E8F0),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 8,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    ),
  );
}

  // ============================================================
  // DETAIL MINI CARD
  // ============================================================

  Widget _detailMiniCard(
    String label,
    String value,
  ) {
    return Container(
      width: 104,
      constraints:
          const BoxConstraints(
        minHeight: 40,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF8FAFC),
        borderRadius:
            BorderRadius.circular(6),
        border: Border.all(
          color:
              const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 7.5,
              color:
                  Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 2),

          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w600,
              color:
                  Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL LINE
  // ============================================================

  Widget _detailLine(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 2,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 8,
                color:
                    Color(0xFF64748B),
              ),
            ),
          ),

          const SizedBox(width: 4),

          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 8.5,
                color:
                    Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON UI
  // ============================================================

  Widget _emptyState(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 30,
              color:
                  const Color(0xFFCBD5E1),
            ),

            const SizedBox(height: 7),

            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
                color:
                    Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 3),

            Text(
              subtitle,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 9,
                color:
                    Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countChip(
    int count, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 8,
          fontWeight:
              FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  // ============================================================
  // RESPONSE HELPERS
  // ============================================================

  

  List<Map<String, dynamic>>
      _detailsFromBatch(
    Map<String, dynamic> batch,
  ) {
    final raw =
        batch['details'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>>
      _imagesFromBatch(
    Map<String, dynamic> batch,
  ) {
    final raw =
        batch['images'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  // ============================================================
  // TREE NUMBER HELPERS
  // ============================================================

  List<String> _treeNumbersFromDetails(
    List<Map<String, dynamic>> details,
  ) {
    return details
        .map(
          (detail) =>
              _textValue(
            detail['tree_no'],
          ),
        )
        .where(
          (value) => value != '-',
        )
        .toSet()
        .toList();
  }

  String _treeReference(
    List<String> treeNumbers,
  ) {
    if (treeNumbers.isEmpty) {
      return 'Tree';
    }

    if (treeNumbers.length == 1) {
      return 'Tree ${treeNumbers.first}';
    }

    return 'Trees ${treeNumbers.join(', ')}';
  }

  // ============================================================
  // IMAGE URL
  // ============================================================

  String _imageUrl(
    Map<String, dynamic> image,
  ) {
    final raw =
        image['image_url'] ??
            image['image'];

    if (raw == null) {
      return '';
    }

    final value =
        raw.toString().trim();

    if (value.isEmpty) {
      return '';
    }

    if (value.startsWith(
          'http://',
        ) ||
        value.startsWith(
          'https://',
        )) {
      return value;
    }

    if (value.startsWith('/')) {
      final apiBase =
          ApiService.baseUrl;

      final host =
          apiBase.endsWith('/api')
              ? apiBase.substring(
                  0,
                  apiBase.length - 4,
                )
              : apiBase;

      return '$host$value';
    }

    final apiBase =
        ApiService.baseUrl;

    if (apiBase.endsWith('/')) {
      return '$apiBase$value';
    }

    return '$apiBase/$value';
  }

  // ============================================================
  // TEXT HELPERS
  // ============================================================

  String _textValue(
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

  int? _intValue(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final parsed =
        DateTime.tryParse(
      value.toString(),
    );

    if (parsed == null) {
      return value.toString();
    }

    final local =
        parsed.toLocal();

    final day = local.day
        .toString()
        .padLeft(2, '0');

    final month = local.month
        .toString()
        .padLeft(2, '0');

    final year =
        local.year.toString();

    var hour =
        local.hour;

    final minute =
        local.minute
            .toString()
            .padLeft(2, '0');

    final suffix =
        hour >= 12
            ? 'PM'
            : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    return '$day/$month/$year '
        '$hour:$minute $suffix';
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(
            fontSize: 11,
          ),
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }
}

// ================================================================
// WEB-SAFE PICKED IMAGE HOLDER
// ================================================================

class _PickedTreeImage {
  final XFile file;
  final Uint8List bytes;

  const _PickedTreeImage({
    required this.file,
    required this.bytes,
  });
}