import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/api_service.dart';

class AddUserDialog extends StatefulWidget {
  final AppUser? user;

  const AddUserDialog({super.key, this.user});

  bool get isEdit => user != null;

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  late final TextEditingController _usernameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  String _role = 'user';
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final user = widget.user;

    _usernameController = TextEditingController(text: user?.username ?? '');
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();

    _role = user?.role ?? 'user';
    _isActive = user?.isActive ?? true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final data = <String, dynamic>{
        'username': _usernameController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _role,
        'is_active': _isActive,
      };

      final password = _passwordController.text;
      if (password.isNotEmpty) {
        data['password'] = password;
      }

      if (widget.isEdit) {
        await _api.updateUser(widget.user!.id, data);
      } else {
        await _api.createUser(data);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          Icons.person_add_alt_1_outlined,
                          color: Color(0xFF1D5CFF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isEdit ? 'Edit User' : 'Add New User',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.isEdit
                                  ? 'Update user account'
                                  : 'Create a new login for a staff member',
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
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: 'e.g. jdoe',
                          required: true,
                          enabled: !widget.isEdit,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _role,
                          decoration: _inputDecoration('Role'),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('User'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _role = value);
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          controller: _firstNameController,
                          label: 'First Name',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _textField(
                          controller: _lastNameController,
                          label: 'Last Name',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'optional',
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    controller: _passwordController,
                    label: widget.isEdit ? 'New Password' : 'Password',
                    hint: widget.isEdit
                        ? 'Leave blank to keep current password'
                        : 'Minimum 8 characters',
                    required: !widget.isEdit,
                    obscure: true,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    title: const Text('Active'),
                    subtitle: const Text(
                      'Inactive users cannot log in',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _isActive = value),
                  ),
                  const SizedBox(height: 12),
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
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : widget.isEdit
                                  ? 'Update User'
                                  : 'Save User',
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
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled && !_saving,
      obscureText: obscure,
      decoration: _inputDecoration(label, hint: hint),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              if (label.contains('Password') && value.trim().length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            }
          : null,
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1D5CFF), width: 1.5),
      ),
    );
  }
}