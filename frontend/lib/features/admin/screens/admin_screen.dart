import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);
    final currentUser = ref.watch(authProvider).user;

    ref.listen<AdminState>(adminProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Users'),
      ),
      body: _buildBody(context, ref, state, currentUser),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, AdminState state, UserModel? currentUser) {
    if (state.isLoading && state.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No users found.',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminProvider.notifier).loadUsers(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = state.users[index];
          final isSelf = user.id == currentUser?.id;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    user.role == 'admin' ? Colors.deepPurple : Colors.blueGrey,
                child: Icon(
                  user.role == 'admin' ? Icons.shield : Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(user.email)),
                  if (isSelf)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Chip(
                        label: Text('You'),
                        padding: EdgeInsets.zero,
                        labelPadding: EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                'Joined ${_formatDate(user.createdAt.toLocal())}  ·  '
                '${user.isActive ? 'Active' : 'Inactive'}',
              ),
              trailing: isSelf
                  ? _roleChip(user.role)
                  : _roleToggleButton(context, ref, user),
            ),
          );
        },
      ),
    );
  }

  Widget _roleChip(String role) {
    return Chip(
      label: Text(role == 'admin' ? 'Admin' : 'User'),
      backgroundColor: role == 'admin' ? Colors.deepPurple.shade50 : null,
      labelStyle: TextStyle(
        color: role == 'admin' ? Colors.deepPurple : null,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: role == 'admin' ? Colors.deepPurple.shade200 : Colors.grey.shade300,
      ),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _roleToggleButton(BuildContext context, WidgetRef ref, UserModel user) {
    final isAdmin = user.role == 'admin';
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: isAdmin ? Colors.red.shade50 : Colors.green.shade50,
        foregroundColor: isAdmin ? Colors.red : Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => _confirmRoleChange(context, ref, user),
      child: Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
    );
  }

  void _confirmRoleChange(BuildContext context, WidgetRef ref, UserModel user) {
    final isAdmin = user.role == 'admin';
    final newRole = isAdmin ? 'user' : 'admin';
    final action = isAdmin ? 'remove admin rights from' : 'grant admin rights to';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
        content: Text('Are you sure you want to $action ${user.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: isAdmin
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ref.read(adminProvider.notifier).updateRole(user.id, newRole);
              });
            },
            child: Text(isAdmin ? 'Remove' : 'Grant'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
