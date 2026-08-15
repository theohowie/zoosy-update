import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/profile_service.dart';

class EditGenderScreen extends StatefulWidget {
  final String currentGender;
  const EditGenderScreen({Key? key, required this.currentGender}) : super(key: key);

  @override
  State<EditGenderScreen> createState() => _EditGenderScreenState();
}

class _EditGenderScreenState extends State<EditGenderScreen> {
  late String _selected;

  List<String> get _options => [context.l10n.male, context.l10n.female, context.l10n.secret];

  @override
  void initState() {
    super.initState();
    _selected = _options.contains(widget.currentGender) ? widget.currentGender : '保密';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.gender_label, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await ProfileService.setGender(_selected);
              if (mounted) Navigator.pop(context, _selected);
            },
            child: Text(context.l10n.save, style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: Card(
        margin: const EdgeInsets.all(16),
        color: ZoosyTheme.surfaceOf(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _options.map((option) {
            final isSel = _selected == option;
            return Column(
              children: [
                if (option != _options.first)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text(option, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
                  trailing: isSel ? Icon(Icons.check, color: ZoosyTheme.primary, size: 22) : null,
                  onTap: () => setState(() => _selected = option),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
