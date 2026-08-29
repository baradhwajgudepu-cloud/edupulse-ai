import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/planner_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class PlannerAnnouncementsScreen extends ConsumerStatefulWidget {
  const PlannerAnnouncementsScreen({super.key});

  @override
  ConsumerState<PlannerAnnouncementsScreen> createState() => _PlannerAnnouncementsScreenState();
}

class _PlannerAnnouncementsScreenState extends ConsumerState<PlannerAnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(announcementsListProvider.notifier).fetchAnnouncements();
    });
  }

  void _showCreateAnnouncementDialog(BuildContext context) {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final msgController = TextEditingController();
    
    String selectedAudienceType = 'ROLE'; // ROLE, CLASS, SECTION
    String? selectedRole = 'PARENT';
    String? selectedClassId;
    String? selectedSectionId;
    String selectedPriority = 'NORMAL';
    
    // Fetch classes list for school
    ref.read(classesProvider(schoolId).notifier).fetchClasses();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final classesState = ref.watch(classesProvider(schoolId));
            final sectionsState = selectedClassId != null ? ref.watch(sectionsProvider(schoolId)) : null;

            return AlertDialog(
              title: const Text('Compose Announcement'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title *'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: msgController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Message *'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Audience Type
                      DropdownButtonFormField<String>(
                        value: selectedAudienceType,
                        decoration: const InputDecoration(labelText: 'Audience Type *'),
                        items: const [
                          DropdownMenuItem(value: 'ROLE', child: Text('Target Role')),
                          DropdownMenuItem(value: 'CLASS', child: Text('Target Class')),
                          DropdownMenuItem(value: 'SECTION', child: Text('Target Section')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedAudienceType = val;
                              selectedRole = (val == 'ROLE') ? 'PARENT' : null;
                              selectedClassId = null;
                              selectedSectionId = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Conditional target dropdowns
                      if (selectedAudienceType == 'ROLE')
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(labelText: 'Select Role *'),
                          items: const [
                            DropdownMenuItem(value: 'PARENT', child: Text('Parents')),
                            DropdownMenuItem(value: 'TEACHER', child: Text('Teachers')),
                            DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                          ],
                          onChanged: (val) {
                            setDialogState(() => selectedRole = val);
                          },
                        )
                      else if (selectedAudienceType == 'CLASS')
                        DropdownButtonFormField<String>(
                          value: selectedClassId,
                          decoration: const InputDecoration(labelText: 'Select Class *'),
                          items: classesState.classes.map((c) {
                            return DropdownMenuItem(value: c.id, child: Text(c.name));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedClassId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Required' : null,
                        )
                      else if (selectedAudienceType == 'SECTION') ...[
                        DropdownButtonFormField<String>(
                          value: selectedClassId,
                          decoration: const InputDecoration(labelText: 'Select Class *'),
                          items: classesState.classes.map((c) {
                            return DropdownMenuItem(value: c.id, child: Text(c.name));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedClassId = val;
                              selectedSectionId = null;
                            });
                            if (val != null) {
                              ref.read(sectionsProvider(schoolId).notifier).fetchSections(classId: val);
                            }
                          },
                          validator: (val) => val == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedSectionId,
                          decoration: const InputDecoration(labelText: 'Select Section *'),
                          items: (sectionsState?.sections ?? []).map((s) {
                            return DropdownMenuItem(value: s.id, child: Text(s.name));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedSectionId = val);
                          },
                          validator: (val) => val == null ? 'Required' : null,
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Priority Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedPriority,
                        decoration: const InputDecoration(labelText: 'Priority *'),
                        items: const [
                          DropdownMenuItem(value: 'LOW', child: Text('Low')),
                          DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                          DropdownMenuItem(value: 'HIGH', child: Text('High')),
                          DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedPriority = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final success = await ref.read(announcementsListProvider.notifier).createAnnouncement(
                            title: titleController.text,
                            message: msgController.text,
                            audienceType: selectedAudienceType,
                            targetRole: selectedRole,
                            targetClassId: selectedClassId,
                            targetSectionId: selectedSectionId,
                            priority: selectedPriority,
                          );
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Announcement saved as Draft successfully.')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to save announcement.')),
                        );
                      }
                    }
                  },
                  child: const Text('Save Draft'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = ref.watch(selectedSchoolIdProvider);
    if (schoolId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please select a school campus from the header to view announcements.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final state = ref.watch(announcementsListProvider);
    final theme = Theme.of(context);

    // Filter announcements: exclude circular attachments here, as they have their own screen
    final announcementsList = state.announcements.where((a) => a.attachmentUrl == null || a.attachmentUrl!.isEmpty).toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcements Board',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send system broadcasts, announcements, and critical updates to parents, students, or staff.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateAnnouncementDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Compose Broadcast'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content Area
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.error != null)
              Center(
                child: Text('Error: ${state.error}', style: TextStyle(color: theme.colorScheme.error)),
              )
            else if (announcementsList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60.0),
                child: Center(
                  child: Text('No announcements found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: announcementsList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final announcement = announcementsList[index];
                  final isPublished = announcement.status.name == 'published';

                  return Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left priority indicator
                          Container(
                            width: 6,
                            height: 60,
                            decoration: BoxDecoration(
                              color: announcement.priority == 'URGENT' || announcement.priority == 'HIGH'
                                  ? Colors.red
                                  : Colors.blue,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Announcement Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      announcement.title,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPublished ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        announcement.status.name.toUpperCase(),
                                        style: TextStyle(
                                          color: isPublished ? Colors.green : Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(announcement.message, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.people, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Target: ${announcement.audienceType.name.toUpperCase()} '
                                      '${announcement.targetRole ?? ''}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.date_range, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Created: ${announcement.createdAt.substring(0, 10)}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Action Buttons
                          Row(
                            children: [
                              if (!isPublished) ...[
                                ElevatedButton(
                                  onPressed: () async {
                                    final res = await ref.read(announcementsListProvider.notifier).publishAnnouncement(announcement.id);
                                    if (res) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Announcement published & notification dispatched successfully.')),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to publish announcement.')),
                                      );
                                    }
                                  },
                                  child: const Text('Publish'),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Announcement'),
                                      content: const Text('Are you sure you want to delete this announcement?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final res = await ref.read(announcementsListProvider.notifier).deleteAnnouncement(announcement.id);
                                    if (res) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Announcement deleted successfully.')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
