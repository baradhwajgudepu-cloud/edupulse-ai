import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/planner_providers.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class PlannerCircularsScreen extends ConsumerStatefulWidget {
  const PlannerCircularsScreen({super.key});

  @override
  ConsumerState<PlannerCircularsScreen> createState() => _PlannerCircularsScreenState();
}

class _PlannerCircularsScreenState extends ConsumerState<PlannerCircularsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(announcementsListProvider.notifier).fetchAnnouncements();
    });
  }

  void _showCreateCircularDialog(BuildContext context) {
    final schoolId = ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final msgController = TextEditingController();
    final pdfUrlController = TextEditingController(text: 'https://edupulse-storage.s3.amazonaws.com/circulars/academic-calendar-2026.pdf');
    
    String selectedAudienceType = 'ROLE'; // ROLE, CLASS, SECTION
    String? selectedRole = 'PARENT';
    String? selectedClassId;
    String? selectedSectionId;
    
    ref.read(classesProvider(schoolId).notifier).fetchClasses();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final classesState = ref.watch(classesProvider(schoolId));
            final sectionsState = selectedClassId != null ? ref.watch(sectionsProvider(schoolId)) : null;

            return AlertDialog(
              title: const Text('New Circular Attachment'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Circular Title *'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: msgController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description / Message *'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: pdfUrlController,
                        decoration: const InputDecoration(labelText: 'Document URL (PDF/DOC) *'),
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
                            attachmentUrl: pdfUrlController.text,
                          );
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Circular created successfully as Draft.')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to create circular.')),
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
            'Please select a school campus from the header to view circulars.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final state = ref.watch(announcementsListProvider);
    final theme = Theme.of(context);

    // Filter announcements: only show ones with attachment URLs (circulars)
    final circularsList = state.announcements.where((a) => a.attachmentUrl != null && a.attachmentUrl!.isNotEmpty).toList();

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
                      'Circulars & Document Management',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload and distribute official school circular letters, brochures, and PDF schedules.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateCircularDialog(context),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Publish Circular'),
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
            else if (circularsList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60.0),
                child: Center(
                  child: Text('No circulars found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: circularsList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final circular = circularsList[index];
                  final isPublished = circular.status.name == 'published';

                  return Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
                          const SizedBox(width: 16),

                          // Circular Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      circular.title,
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
                                        circular.status.name.toUpperCase(),
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
                                Text(circular.message, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Downloading: ${circular.attachmentUrl}')),
                                    );
                                  },
                                  child: Text(
                                    circular.attachmentUrl!,
                                    style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline, fontSize: 12),
                                  ),
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
                                    final res = await ref.read(announcementsListProvider.notifier).publishAnnouncement(circular.id);
                                    if (res) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Circular published successfully.')),
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
                                      title: const Text('Delete Circular'),
                                      content: const Text('Are you sure you want to delete this circular?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final res = await ref.read(announcementsListProvider.notifier).deleteAnnouncement(circular.id);
                                    if (res) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Circular deleted successfully.')),
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
