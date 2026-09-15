import 'package:flutter/material.dart';

import '../models/flax.dart';
import '../services/api_service.dart';

class AddFlaxDialog extends StatefulWidget {
  final Flax? flax;

  const AddFlaxDialog({
    super.key,
    this.flax,
  });

  bool get isEdit => flax != null;

  @override
  State<AddFlaxDialog> createState() => _AddFlaxDialogState();
}

class _AddFlaxDialogState extends State<AddFlaxDialog> {
  final _formKey = GlobalKey<FormState>();

  final ApiService _api = ApiService();

  late final TextEditingController _flaxNoController;
  String? _selectedSize;
  late final TextEditingController _designController;
  late final TextEditingController _categoryController;
  late final TextEditingController _remarksController;

  String _assignmentStatus = 'Available';

  bool _saving = false;

  static const List<String> _flaxSizes = [
    '9x4.5',
    '9x4',
    '9x3.5',
    '9x3',
    '8x4.5',
    '8x4',
    '8x3.5',
    '8x3',
    '7x4.5',
    '7x4',
    '7x3.5',
    '7x3',
    '6x4.5',
    '6x4',
    '6x3.5',
    '6x3',
    '5x4.5',
    '5x4',
    '5x3.5',
    '5x3',
  ];

  @override
  void initState() {
    super.initState();

    final flax = widget.flax;

    _flaxNoController = TextEditingController(
      text: flax?.flaxNo ?? '',
    );

    _selectedSize = flax?.flaxSize;

    _designController = TextEditingController(
      text: flax?.designName ?? '',
    );

    _categoryController = TextEditingController(
      text: flax?.category ?? '',
    );

    _remarksController = TextEditingController(
      text: flax?.remarks ?? '',
    );

    _assignmentStatus = flax?.assignmentStatus.isNotEmpty == true
        ? flax!.assignmentStatus
        : 'Available';
  }

  @override
  void dispose() {
    _flaxNoController.dispose();
    // _selectedSize.dispose();
    _designController.dispose();
    _categoryController.dispose();
    _remarksController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final flaxNo = _flaxNoController.text.trim();
    final size = _selectedSize;
    final design = _designController.text.trim();
    final category = _categoryController.text.trim();
    final remarks = _remarksController.text.trim();

    if (_assignmentStatus == 'Under Maintenance' && remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a reason for maintenance.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final data = {
        'flax_no': flaxNo,
        'flax_size': size,
        'design_name': design,
        'category': category,
        'assignment_status': _assignmentStatus,
        'remarks': remarks,
      };

      if (widget.isEdit) {
        await _api.updateFlax(
          widget.flax!.flaxNo,
          data,
        );
      } else {
        await _api.createFlax(data);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------
                  // HEADER
                  // ------------------------------------------------

                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF1D5CFF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isEdit ? 'Edit Flax' : 'Add New Flax',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.isEdit
                                  ? 'Update flax information'
                                  : 'Enter flax information',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ------------------------------------------------
                  // FLAX NO + SIZE
                  // ------------------------------------------------

                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          controller: _flaxNoController,
                          label: 'Flax No.',
                          hint: 'e.g. FLX-001',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSize,
                          decoration: _inputDecoration('Size'),
                          hint: const Text('Select size'),
                          items: _flaxSizes.map((size) {
                            return DropdownMenuItem<String>(
                              value: size,
                              child: Text(size),
                            );
                          }).toList(),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedSize = value;
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Size is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ------------------------------------------------
                  // DESIGN + CATEGORY
                  // ------------------------------------------------

                  const SizedBox(height: 16),

                  // ------------------------------------------------
                  // STATUS
                  // ------------------------------------------------

                  widget.isEdit
                      ? DropdownButtonFormField<String>(
                          value: _assignmentStatus,
                          decoration: _inputDecoration(
                            'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Available',
                              child: Text('Available'),
                            ),
                            DropdownMenuItem(
                              value: 'Assigned',
                              child: Text('Assigned'),
                            ),
                            DropdownMenuItem(
                              value: 'Under Maintenance',
                              child: Text(
                                'Under Maintenance',
                              ),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value == null) return;

                                  setState(() {
                                    _assignmentStatus = value;
                                  });
                                },
                        )
                      : Container(),

                  const SizedBox(height: 16),

                  // ------------------------------------------------
                  // REMARKS
                  // ------------------------------------------------
                  widget.isEdit
                      ? TextFormField(
                          controller: _remarksController,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            'Remarks',
                            hint: 'e.g. Damaged, Old stock, Not in use',
                          ),
                        )
                      : Container(),

                  const SizedBox(height: 28),

                  // ------------------------------------------------
                  // BUTTONS
                  // ------------------------------------------------

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_outlined,
                              ),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : widget.isEdit
                                  ? 'Update Flax'
                                  : 'Save Flax',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled && !_saving,
      decoration: _inputDecoration(
        label,
        hint: hint,
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }

              return null;
            }
          : null,
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
}
