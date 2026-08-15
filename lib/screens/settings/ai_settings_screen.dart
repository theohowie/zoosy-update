import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/ai_service.dart';
import '../../utils/input_sanitizer.dart';
import '../../widgets/toast_util.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({Key? key}) : super(key: key);

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  bool _enabled = false;
  late TextEditingController _keyController;
  late TextEditingController _urlController;
  String _selectedModel = 'OpenAI';
  bool _isLoading = true;
  bool _isValidating = false;
  String? _validateResult;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
    _urlController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    _enabled = await AIService.isEnabled();
    _keyController.text = await AIService.getApiKey();
    _urlController.text = await AIService.getApiUrl();
    _selectedModel = await AIService.getModel();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onModelChanged(String? model) {
    if (model == null) return;
    setState(() {
      _selectedModel = model;
      _urlController.text = AIService.urlForModel(model);
      _validateResult = null;
    });
  }

  Future<void> _save() async {
    // 输入消毒
    final sanitizedKey = InputSanitizer.sanitizeText(_keyController.text.trim(), maxLength: 200);
    final sanitizedUrl = InputSanitizer.sanitizeUrl(_urlController.text.trim()).sanitized;

    await AIService.setEnabled(_enabled);
    await AIService.setApiKey(sanitizedKey);
    await AIService.setApiUrl(sanitizedUrl);
    await AIService.setModel(_selectedModel);
    if (!mounted) return;
    ToastUtil.showToast(context, message: context.l10n.ai_saved, icon: Icons.check, color: Colors.green);
    Navigator.pop(context);
  }

  Future<void> _validateKey() async {
    final key = _keyController.text.trim();
    final url = _urlController.text.trim();
    if (key.isEmpty) {
      setState(() => _validateResult = context.l10n.fill_api_key);
      return;
    }
    if (url.isEmpty) {
      setState(() => _validateResult = context.l10n.fill_api_url);
      return;
    }
    setState(() { _isValidating = true; _validateResult = null; });
    final result = await AIService.validateApiKey(key, url, model: _selectedModel);
    if (mounted) {
      setState(() {
        _isValidating = false;
        _validateResult = result ?? context.l10n.validation_passed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ai_settings, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ai_settings, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0,
        actions: [TextButton(onPressed: _save, child: Text(context.l10n.save, style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              SwitchListTile(
                title: Text(context.l10n.ai_summary, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(context.l10n.auto_generate_ai, style: TextStyle(fontSize: 11)),
                value: _enabled, activeColor: ZoosyTheme.primary,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ]),
          ),
          if (_enabled) ...[
            const SizedBox(height: 20),
            Text(context.l10n.api_config, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 12),
            Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 模型选择
                  Text(context.l10n.select_model, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedModel,
                    items: AIService.modelList.map((name) {
                      return DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: _onModelChanged,
                    decoration: InputDecoration(
                      filled: true, fillColor: ZoosyTheme.containerLowOf(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // API 地址（自动填充，允许手动修改）
                  Text(context.l10n.api_url_label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
                  const SizedBox(height: 6),
                  TextField(controller: _urlController,
                    decoration: InputDecoration(hintText: 'https://api.openai.com/v1/chat/completions', filled: true, fillColor: ZoosyTheme.containerLowOf(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // API Key
                  Text('API Key（sk-...）', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextField(controller: _keyController, obscureText: true,
                        decoration: InputDecoration(hintText: 'sk-...', filled: true, fillColor: ZoosyTheme.containerLowOf(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          suffixIcon: _keyController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 16, color: ZoosyTheme.textMutedOf(context)),
                                onPressed: () {
                                  _keyController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        ),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _isValidating ? null : _validateKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZoosyTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: _isValidating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(context.l10n.validate, style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                  if (_validateResult != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _validateResult!.startsWith(context.l10n.ais_verified)
                            ? Colors.green.withOpacity(0.08)
                            : Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(
                          _validateResult!.startsWith(context.l10n.ais_verified) ? Icons.check_circle : Icons.error_outline,
                          size: 14,
                          color: _validateResult!.startsWith(context.l10n.ais_verified) ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_validateResult!, style: TextStyle(
                            fontSize: 11,
                            color: _validateResult!.startsWith(context.l10n.ais_verified) ? Colors.green : Colors.red,
                          )),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: ZoosyTheme.primary.withOpacity(0.1))),
                    child: Text(context.l10n.ai_config_hint, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}
