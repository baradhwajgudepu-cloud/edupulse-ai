import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../providers/school_setup_providers.dart';

class RoomItem {
  final String id;
  final String roomNumber;
  final String name;
  final String roomType;
  final int capacity;
  final String? floor;
  final String? building;
  final bool isActive;

  const RoomItem({
    required this.id,
    required this.roomNumber,
    required this.name,
    required this.roomType,
    required this.capacity,
    this.floor,
    this.building,
    required this.isActive,
  });

  factory RoomItem.fromJson(Map<String, dynamic> json) {
    return RoomItem(
      id: json['id'] as String,
      roomNumber: json['room_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      roomType: json['room_type'] as String? ?? 'CLASSROOM',
      capacity: (json['capacity'] as num?)?.toInt() ?? 40,
      floor: json['floor'] as String?,
      building: json['building'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

final roomsListProvider = FutureProvider.autoDispose<List<RoomItem>>((ref) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return [];
  final apiClient = ref.watch(apiClientProvider);
  final res = await apiClient.get(
    '/rooms?school_id=$schoolId',
    mapper: (json) {
      final list = (json as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      return list.map((e) => RoomItem.fromJson(e as Map<String, dynamic>)).toList();
    },
  );
  return res.when(
    onSuccess: (data) => data,
    onFailure: (err) => throw Exception(err.message),
  );
});

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String _searchQuery = '';
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomsAsync = ref.watch(roomsListProvider);
    final schoolId = ref.watch(selectedSchoolIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classrooms & Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(roomsListProvider),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Room'),
            onPressed: schoolId == null ? null : () => _showAddEditRoomDialog(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter / Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by room number or name...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String?>(
                  value: _selectedType,
                  hint: const Text('All Types'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Types')),
                    DropdownMenuItem(value: 'CLASSROOM', child: Text('Classroom')),
                    DropdownMenuItem(value: 'LAB', child: Text('Lab')),
                    DropdownMenuItem(value: 'LIBRARY', child: Text('Library')),
                    DropdownMenuItem(value: 'AUDITORIUM', child: Text('Auditorium')),
                    DropdownMenuItem(value: 'STAFF_ROOM', child: Text('Staff Room')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (val) => setState(() => _selectedType = val),
                ),
              ],
            ),
          ),
          Expanded(
            child: roomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error loading rooms: $e', style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(roomsListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (rooms) {
                var filtered = rooms;
                if (_selectedType != null) {
                  filtered = filtered.where((r) => r.roomType == _selectedType).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((r) =>
                    r.roomNumber.toLowerCase().contains(_searchQuery) ||
                    r.name.toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          rooms.isEmpty ? 'No rooms configured yet.' : 'No rooms match your filter.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (rooms.isEmpty)
                          FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Room'),
                            onPressed: () => _showAddEditRoomDialog(context),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final room = filtered[idx];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            _getIconForType(room.roomType),
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${room.roomNumber} - ${room.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Type: ${room.roomType} | Capacity: ${room.capacity} | Building: ${room.building ?? "Main"} | Floor: ${room.floor ?? "Ground"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () => _showAddEditRoomDialog(context, room: room),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDeleteRoom(context, room),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'LAB':
        return Icons.science_outlined;
      case 'LIBRARY':
        return Icons.menu_book_outlined;
      case 'AUDITORIUM':
        return Icons.theater_comedy_outlined;
      case 'STAFF_ROOM':
        return Icons.people_outline;
      default:
        return Icons.meeting_room_outlined;
    }
  }

  Future<void> _showAddEditRoomDialog(BuildContext context, {RoomItem? room}) async {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final roomNumberCtrl = TextEditingController(text: room?.roomNumber ?? '');
    final nameCtrl = TextEditingController(text: room?.name ?? '');
    final capacityCtrl = TextEditingController(text: room?.capacity.toString() ?? '40');
    final floorCtrl = TextEditingController(text: room?.floor ?? '');
    final buildingCtrl = TextEditingController(text: room?.building ?? '');
    String roomType = room?.roomType ?? 'CLASSROOM';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(room == null ? 'Add Room' : 'Edit Room'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: roomNumberCtrl,
                    decoration: const InputDecoration(labelText: 'Room Number (e.g. 101, Lab-1)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Room Name (e.g. Physics Lab)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: roomType,
                    decoration: const InputDecoration(labelText: 'Room Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'CLASSROOM', child: Text('Classroom')),
                      DropdownMenuItem(value: 'LAB', child: Text('Lab')),
                      DropdownMenuItem(value: 'LIBRARY', child: Text('Library')),
                      DropdownMenuItem(value: 'AUDITORIUM', child: Text('Auditorium')),
                      DropdownMenuItem(value: 'STAFF_ROOM', child: Text('Staff Room')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => roomType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityCtrl,
                    decoration: const InputDecoration(labelText: 'Student Capacity', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: floorCtrl,
                    decoration: const InputDecoration(labelText: 'Floor (Optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: buildingCtrl,
                    decoration: const InputDecoration(labelText: 'Building (Optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (roomNumberCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
                final apiClient = ref.read(apiClientProvider);
                final capacity = int.tryParse(capacityCtrl.text.trim()) ?? 40;

                if (room == null) {
                  await apiClient.post(
                    '/rooms',
                    data: {
                      'school_id': schoolId,
                      'room_number': roomNumberCtrl.text.trim(),
                      'name': nameCtrl.text.trim(),
                      'room_type': roomType,
                      'capacity': capacity,
                      'floor': floorCtrl.text.trim().isEmpty ? null : floorCtrl.text.trim(),
                      'building': buildingCtrl.text.trim().isEmpty ? null : buildingCtrl.text.trim(),
                      'is_active': true,
                    },
                    mapper: (json) => json,
                  );
                } else {
                  await apiClient.put(
                    '/rooms/${room.id}',
                    data: {
                      'room_number': roomNumberCtrl.text.trim(),
                      'name': nameCtrl.text.trim(),
                      'room_type': roomType,
                      'capacity': capacity,
                      'floor': floorCtrl.text.trim().isEmpty ? null : floorCtrl.text.trim(),
                      'building': buildingCtrl.text.trim().isEmpty ? null : buildingCtrl.text.trim(),
                    },
                    mapper: (json) => json,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(roomsListProvider);
              },
              child: Text(room == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRoom(BuildContext context, RoomItem room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room?'),
        content: Text('Are you sure you want to delete room "${room.roomNumber} - ${room.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete(
        '/rooms/${room.id}',
        mapper: (json) => json,
      );
      ref.invalidate(roomsListProvider);
    }
  }
}
