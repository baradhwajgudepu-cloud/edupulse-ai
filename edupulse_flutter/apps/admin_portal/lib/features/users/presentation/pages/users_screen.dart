// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../providers/user_provider.dart';
import '../../../../core/presentation/widgets/safe_dropdown.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  String? _selectedRole;
  String? _selectedStatus;
  String? _selectedSchool;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(usersListProvider.notifier).fetchUsers(reset: true);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(usersListProvider.notifier).search(val);
      }
    });
  }

  void _clearFilters() {
    _debounceTimer?.cancel();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedRole = null;
      _selectedStatus = null;
      _selectedSchool = null;
    });
    ref.read(usersListProvider.notifier).clearFilters();
  }

  List<UserResponseDto> _applyFilters(List<UserResponseDto> loadedUsers, {bool isServerSearchActive = false}) {
    return loadedUsers.where((user) {
      // 1. Search Query Match
      // When server-side search has loaded matching results for this search query,
      // the server is the authoritative source across all directory attributes, relations,
      // linked students, guardians, phones, admission numbers, and teacher codes.
      // Do not discard server-matched records using a restrictive client-side name/email check.
      if (_searchQuery.isNotEmpty && !isServerSearchActive) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = '${user.firstName} ${user.lastName}'.toLowerCase().contains(query);
        final emailMatch = user.email.toLowerCase().contains(query);
        final loginMatch = (user.loginId ?? '').toLowerCase().contains(query);
        if (!nameMatch && !emailMatch && !loginMatch) return false;
      }

      // 2. Role Filter Match
      if (_selectedRole != null) {
        final target = _selectedRole!.trim().toUpperCase();
        final hasRole = user.roles.any((r) {
          if (r is Map) {
            final code = (r['code'] ?? '').toString().trim().toUpperCase();
            final name = (r['name'] ?? '').toString().trim().toUpperCase();
            return code == target || name == target;
          }
          final str = r.toString().trim().toUpperCase();
          return str == target;
        });
        if (!hasRole) return false;
      }

      // 3. Status Filter Match
      if (_selectedStatus != null) {
        if (user.status.toUpperCase() != _selectedStatus!.toUpperCase()) return false;
      }

      // 4. School Filter Match
      if (_selectedSchool != null) {
        final belongsToSchool = user.schools.any((s) {
          final name = s is Map ? s['name'] : s.toString();
          return name.toString() == _selectedSchool;
        });
        if (!belongsToSchool) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersState = ref.watch(usersListProvider);
    final actionState = ref.watch(userActionProvider);

    // When the server state holds the active search query, server results are authoritative
    final isServerSearchActive = _searchQuery.trim().isNotEmpty &&
        usersState.searchQuery.trim().toLowerCase() == _searchQuery.trim().toLowerCase();

    // Apply filters strictly on currently loaded data
    final filteredUsers = _applyFilters(usersState.users, isServerSearchActive: isServerSearchActive);

    // Collect distinct school names from loaded data for the filter dropdown
    final distinctSchools = usersState.users
        .expand((u) => u.schools.map((s) => s is Map ? s['name']?.toString() ?? '' : s.toString()))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    // Listen to action state changes for success/error dialogs
    ref.listen<UserActionState>(userActionProvider, (prev, next) {
      if (next is UserActionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: Colors.green.shade800,
          ),
        );
      } else if (next is UserActionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.message}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Management',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage, inspect, and configure access for your platform users.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (actionState is UserActionLoading) ...[
                        const SizedBox(height: 8),
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Management',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage, inspect, and configure access for your platform users.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (actionState is UserActionLoading) ...[
                      const SizedBox(width: 16),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Filters & Actions Toolbar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, filterConstraints) {
                    final isFilterNarrow = filterConstraints.maxWidth < 850;
                    return Column(
                      children: [
                        if (isFilterNarrow) ...[
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search users',
                              hintText: 'Search by name, father/guardian, student, admission number, role, email, phone...',
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _debounceTimer?.cancel();
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                        ref.read(usersListProvider.notifier).search('');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: _onSearchChanged,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset Filters'),
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              // Search bar
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Search users',
                                    hintText: 'Search by name, father/guardian, student, admission number, role, email, phone...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _debounceTimer?.cancel();
                                              setState(() {
                                                _searchController.clear();
                                                _searchQuery = '';
                                              });
                                              ref.read(usersListProvider.notifier).search('');
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Reset button
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reset Filters'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (isFilterNarrow) ...[
                          SafeDropdownButtonFormField<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin')),
                              DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                              DropdownMenuItem(value: 'PRINCIPAL', child: Text('Principal')),
                              DropdownMenuItem(value: 'TEACHER', child: Text('Teacher')),
                              DropdownMenuItem(value: 'PARENT', child: Text('Parent')),
                              DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedRole = val;
                              });
                              ref.read(usersListProvider.notifier).setRoleFilter(val);
                            },
                          ),
                          const SizedBox(height: 12),
                          SafeDropdownButtonFormField<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                              DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                              DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                              DropdownMenuItem(value: 'LOCKED', child: Text('Locked')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedStatus = val;
                              });
                              ref.read(usersListProvider.notifier).setStatusFilter(val);
                            },
                          ),
                          const SizedBox(height: 12),
                          SafeDropdownButtonFormField<String>(
                            value: _selectedSchool,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'School Affiliation',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: distinctSchools
                                .map((schoolName) => DropdownMenuItem(
                                      value: schoolName,
                                      child: Text(
                                        schoolName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSchool = val;
                              });
                              final matchedSchool = usersState.users
                                  .expand((u) => u.schools)
                                  .firstWhere(
                                    (s) => s is Map && s['name'] == val,
                                    orElse: () => null,
                                  );
                              final schoolId = matchedSchool is Map ? matchedSchool['id']?.toString() : null;
                              ref.read(usersListProvider.notifier).setSchoolFilter(schoolId);
                            },
                          ),
                        ] else
                          Row(
                            children: [
                              // Role Dropdown
                              Expanded(
                                child: SafeDropdownButtonFormField<String>(
                                  value: _selectedRole,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Role',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin')),
                                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                                    DropdownMenuItem(value: 'PRINCIPAL', child: Text('Principal')),
                                    DropdownMenuItem(value: 'TEACHER', child: Text('Teacher')),
                                    DropdownMenuItem(value: 'PARENT', child: Text('Parent')),
                                    DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedRole = val;
                                    });
                                    ref.read(usersListProvider.notifier).setRoleFilter(val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Status Dropdown
                              Expanded(
                                child: SafeDropdownButtonFormField<String>(
                                  value: _selectedStatus,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                                    DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                                    DropdownMenuItem(value: 'LOCKED', child: Text('Locked')),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedStatus = val;
                                    });
                                    ref.read(usersListProvider.notifier).setStatusFilter(val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // School Dropdown
                              Expanded(
                                child: SafeDropdownButtonFormField<String>(
                                  value: _selectedSchool,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'School Affiliation',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  items: distinctSchools
                                      .map((schoolName) => DropdownMenuItem(
                                            value: schoolName,
                                            child: Text(
                                              schoolName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedSchool = val;
                                    });
                                    final matchedSchool = usersState.users
                                        .expand((u) => u.schools)
                                        .firstWhere(
                                          (s) => s is Map && s['name'] == val,
                                          orElse: () => null,
                                        );
                                    final schoolId = matchedSchool is Map ? matchedSchool['id']?.toString() : null;
                                    ref.read(usersListProvider.notifier).setSchoolFilter(schoolId);
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content Area
            Expanded(
              child: Builder(
                builder: (context) {
                  if (usersState.isLoading && usersState.users.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (usersState.error != null && usersState.users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                          Text('Failed to load users: ${usersState.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(usersListProvider.notifier).fetchUsers(reset: true);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (filteredUsers.isEmpty) {
                    final hasActiveFilters = _searchQuery.isNotEmpty ||
                        _selectedRole != null ||
                        _selectedStatus != null ||
                        _selectedSchool != null;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            hasActiveFilters
                                ? (_searchQuery.isNotEmpty
                                    ? 'No users found matching "$_searchQuery".'
                                    : 'No matching users found for the selected filters.')
                                : 'No users found in directory.',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (hasActiveFilters)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Clear Filters'),
                            ),
                        ],
                      ),
                    );
                  }

                  // Render table or cards
                  return isMobile
                      ? _buildMobileCards(context, filteredUsers)
                      : _buildDesktopTable(context, filteredUsers);
                },
              ),
            ),

            // Pagination Controls Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: LayoutBuilder(
                builder: (context, footerConstraints) {
                  final isFooterNarrow = footerConstraints.maxWidth < 500;
                  final totalCount = usersState.totalCount > 0 ? usersState.totalCount : usersState.users.length;
                  final isFiltered = _searchQuery.isNotEmpty || _selectedRole != null || _selectedStatus != null || _selectedSchool != null;
                  final countText = isFiltered
                      ? 'Showing ${filteredUsers.length} matching of $totalCount users'
                      : (filteredUsers.length < totalCount
                          ? 'Showing ${filteredUsers.length} of $totalCount users'
                          : 'Showing all $totalCount users');

                  final resetPageButton = ElevatedButton.icon(
                    onPressed: usersState.skip > 0
                        ? () {
                            ref.read(usersListProvider.notifier).fetchUsers(reset: true);
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Reset Page'),
                  );

                  final loadMoreButton = ElevatedButton.icon(
                    onPressed: usersState.hasMore && !usersState.isLoadingMore
                        ? () {
                            ref.read(usersListProvider.notifier).fetchUsers();
                          }
                        : null,
                    icon: usersState.isLoadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(usersState.isLoadingMore
                        ? 'Loading...'
                        : (usersState.hasMore ? 'Load More' : 'All Loaded')),
                  );

                  if (isFooterNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          countText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: resetPageButton),
                            const SizedBox(width: 12),
                            Expanded(child: loadMoreButton),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        countText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        children: [
                          resetPageButton,
                          const SizedBox(width: 12),
                          loadMoreButton,
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<UserResponseDto> users) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withAlpha((0.4 * 255).round())),
                  columns: const [
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Superuser')),
                    DataColumn(label: Text('Schools')),
                    DataColumn(label: Text('Created At')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: users.map((user) {
                    // Get role code safely
                    final roleText = user.roles.map((r) {
                      if (r is Map) return r['code']?.toString() ?? 'USER';
                      return r.toString();
                    }).join(', ');

                    // Formatted date
                    final dateStr = _formatDate(user.createdAt);

                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${user.firstName} ${user.lastName}',
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                user.email,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Chip(
                            label: Text(roleText.isEmpty ? 'USER' : roleText),
                            backgroundColor: theme.colorScheme.secondaryContainer,
                            labelStyle: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        DataCell(_buildStatusChip(context, user.status)),
                        DataCell(
                          user.isSuperuser
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.cancel_outlined, color: Colors.grey),
                        ),
                        DataCell(
                          Text(
                            user.schools.length > 1
                                ? '${user.schools.length} schools'
                                : user.schools.isEmpty
                                    ? 'None'
                                    : (user.schools.first is Map ? user.schools.first['name'] : user.schools.first).toString(),
                          ),
                        ),
                        DataCell(Text(dateStr)),
                        DataCell(
                          PopupMenuButton<String>(
                            onSelected: (action) => _handleAction(context, action, user),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'view', child: Text('View Details')),
                              if (user.status.toUpperCase() != 'ACTIVE')
                                const PopupMenuItem(value: 'activate', child: Text('Activate')),
                              if (user.status.toUpperCase() == 'ACTIVE')
                                const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                              const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                              if (user.status.toUpperCase() == 'LOCKED')
                                const PopupMenuItem(value: 'unlock', child: Text('Unlock Account')),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileCards(BuildContext context, List<UserResponseDto> users) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, idx) {
        final user = users[idx];
        final roleText = user.roles.map((r) {
          if (r is Map) return r['code']?.toString() ?? 'USER';
          return r.toString();
        }).join(', ');

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${user.firstName} ${user.lastName}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildStatusChip(context, user.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Role: $roleText', style: theme.textTheme.bodyMedium),
                    if (user.isSuperuser)
                      Chip(
                        label: const Text('SUPERUSER'),
                        backgroundColor: theme.colorScheme.errorContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Affiliations: ${user.schools.length} schools',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.push('/users/${user.id}'),
                      child: const Text('View Details'),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (action) => _handleAction(context, action, user),
                      child: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        if (user.status.toUpperCase() != 'ACTIVE')
                          const PopupMenuItem(value: 'activate', child: Text('Activate')),
                        if (user.status.toUpperCase() == 'ACTIVE')
                          const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                        const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                        if (user.status.toUpperCase() == 'LOCKED')
                          const PopupMenuItem(value: 'unlock', child: Text('Unlock Account')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final theme = Theme.of(context);
    Color color;
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'INACTIVE':
        color = Colors.grey;
        break;
      case 'SUSPENDED':
        color = Colors.orange;
        break;
      case 'LOCKED':
        color = Colors.red;
        break;
      default:
        color = theme.colorScheme.onSurface;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.5 * 255).round())),
      ),
      child: Text(
        status.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _handleAction(BuildContext context, String action, UserResponseDto user) {
    if (action == 'view') {
      context.push('/users/${user.id}');
      return;
    }

    String title;
    String content;
    VoidCallback onConfirm;

    switch (action) {
      case 'activate':
        title = 'Activate User?';
        content = 'Are you sure you want to activate the account for ${user.firstName} ${user.lastName}?';
        onConfirm = () {
          ref.read(userActionProvider.notifier).activateUser(user.id);
        };
        break;
      case 'deactivate':
        title = 'Deactivate User?';
        content = 'Are you sure you want to deactivate the account for ${user.firstName} ${user.lastName}? The user will lose portal access immediately.';
        onConfirm = () {
          ref.read(userActionProvider.notifier).deactivateUser(user.id);
        };
        break;
      case 'reset':
        title = 'Reset Password?';
        content = 'Are you sure you want to reset the password for ${user.firstName} ${user.lastName}? A temporary password will be generated.';
        onConfirm = () {
          ref.read(userActionProvider.notifier).resetPassword(user.id);
        };
        break;
      case 'unlock':
        title = 'Unlock User?';
        content = 'Are you sure you want to unlock the account for ${user.firstName} ${user.lastName}?';
        onConfirm = () {
          ref.read(userActionProvider.notifier).unlockUser(user.id);
        };
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
