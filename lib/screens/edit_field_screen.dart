import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../models/reflection.dart';
import '../utils/input_sanitizer.dart';

class EditFieldScreen extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String> onSave;

  const EditFieldScreen({
    Key? key,
    required this.title,
    required this.initialValue,
    this.hintText = '',
    this.maxLines = 1,
    this.maxLength,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends State<EditFieldScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              // 输入消毒
              final sanitized = InputSanitizer.sanitizeText(
                _controller.text.trim(),
                maxLength: widget.maxLength ?? InputSanitizer.maxContentLength,
              );
              widget.onSave(sanitized);
              Navigator.pop(context);
            },
            child: Text(context.l10n.save, style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true, fillColor: ZoosyTheme.surfaceOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
            ),
          ),
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}
