import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'add_user_dialog.dart';

/// Embeddable content for the "Settings" sidebar section — drops straight
/// into the dashboard's IndexedStack, same pattern as FlaxListView.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;

  bool _isAdmin = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refreshData() async {
    await _load();
  }

  Future<void> _init() async {
    final role = await _auth.getRole();
    final user = await _auth.getUser();

    if (!mounted) return;

    setState(() {
      _isAdmin = role == 'admin';
      _currentUserId = user?['id'] as int?;
    });

    await _load();
  }

  Future<void> _load() async {
    if (!_isAdmin) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await _api.fetchUsers(
        search: _searchController.text,
      );

      if (!mounted) return;
      setState(() {
        _users = users;
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

  Future<void> _addUser() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddUserDialog(),
    );

    if (result == true) await _load();
  }

  Future<void> _editUser(AppUser user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddUserDialog(user: user),
    );

    if (result == true) await _load();
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('This will permanently remove "${user.username}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteUser(user.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin && !_loading) {
      return const Center(
        child: Text(
          'Only admins can manage users.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                const Text(
                  'Users',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addUser,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Add User'),
                  ),
                ),
              ] else
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Users',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _load(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _addUser,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Add User'),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Expanded(child: _buildBody()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('No users found.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _users[index];
        final isSelf = user.id == _currentUserId;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: user.isAdmin
                ? const Color(0xFF1D5CFF)
                : Colors.grey.shade400,
            child: Icon(
              user.isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: Text(
            user.name.isNotEmpty ? user.name : user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '@${user.username} · ${user.isAdmin ? "Admin" : "User"}'
            '${user.isActive ? "" : " · Inactive"}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _editUser(user),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                onPressed: isSelf ? null : () => _deleteUser(user),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }
}