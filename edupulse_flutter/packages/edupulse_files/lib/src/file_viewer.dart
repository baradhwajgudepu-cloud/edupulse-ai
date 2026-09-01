import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:edupulse_core/edupulse_core.dart';

class FileViewer extends StatefulWidget {
  final String path;
  final String title;

  const FileViewer({
    super.key,
    required this.path,
    required this.title,
  });

  @override
  State<FileViewer> createState() => _FileViewerState();
}

class _FileViewerState extends State<FileViewer> {
  String? _errorMessage;
  bool _isOpenAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openFile();
    });
  }

  Future<void> _openFile() async {
    if (_isOpenAttempted) return;
    _isOpenAttempted = true;

    // Safety guard for widget tests running on desktop/headless environments
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      EduLogger.i('[FileViewer] Skipping native file open in test environment.');
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      EduLogger.i('Attempting to natively open document at: ${widget.path}');
      final result = await OpenFilex.open(widget.path);
      EduLogger.i('OpenFilex result type: ${result.type}, message: ${result.message}');

      if (result.type == ResultType.noAppToOpen) {
        setState(() {
          _errorMessage = 'No PDF viewer is installed. Please install a PDF viewer and try again.';
        });
      } else if (result.type != ResultType.done) {
        setState(() {
          _errorMessage = 'Could not open file: ${result.message}';
        });
      } else {
        // Log open success
        EduLogger.i('Document opened successfully natively.');
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error opening file: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _errorMessage != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Opening document...'),
                  ],
                ),
        ),
      ),
    );
  }
}
