import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/reflection.dart';
import '../../services/profile_service.dart';
import '../../services/translation_service.dart';
import '../edit_field_screen.dart';
import 'edit_gender_screen.dart';
import '../auth/change_email_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const EditProfileScreen({Key? key, required this.onSaved}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isLoading = true;
  String _nickname = '', _avatarUrl = '', _email = '';
  String _gender = '', _signature = '', _bio = '', _birthday = '', _occupation = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _nickname = await ProfileService.getNickname();
    _avatarUrl = await ProfileService.getAvatarUrl();
    _email = await ProfileService.getEmail();
    _gender = await ProfileService.getGender();
    _signature = await ProfileService.getSignature();
    _bio = await ProfileService.getBio();
    _birthday = await ProfileService.getBirthday();
    _occupation = await ProfileService.getOccupation();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file != null) {
      // 移动端使用本地文件路径作为头像
      await ProfileService.setAvatarUrl(file.path);
      await _loadProfile();
      widget.onSaved();
      if (mounted) setState(() {});
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(TranslationService.tr('change_avatar'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(ctx))),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: ZoosyTheme.primary),
            title: Text(TranslationService.tr('choose_from_gallery')),
            onTap: () { Navigator.pop(ctx); _pickImage(); },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: ZoosyTheme.primary),
            title: Text(TranslationService.tr('take_photo')),
            onTap: () async {
              Navigator.pop(ctx);
              final picker = ImagePicker();
              final file = await picker.pickImage(source: ImageSource.camera, maxWidth: 512, maxHeight: 512);
              if (file != null) {
                await ProfileService.setAvatarUrl(file.path);
                await _loadProfile();
                widget.onSaved();
                if (mounted) setState(() {});
              }
            },
          ),
          if (_avatarUrl.startsWith('/') || _avatarUrl.startsWith('file://'))
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(TranslationService.tr('restore_default_avatar'), style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                await ProfileService.setAvatarUrl(ProfileService.defaultAvatar);
                await _loadProfile();
                widget.onSaved();
                if (mounted) setState(() {});
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(TranslationService.tr('edit_profile'), style: TextStyle(fontWeight: FontWeight.bold)),
          surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料', style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),

          // 头像（可点击更换）
          Center(child: GestureDetector(
            onTap: _showAvatarOptions,
            child: Stack(children: [
              ClipOval(
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ZoosyTheme.primary, width: 2.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _avatarUrl.startsWith('/') || _avatarUrl.startsWith('file://')
                      ? Image.file(File(_avatarUrl.replaceFirst('file://', '')), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: ZoosyTheme.containerLowOf(context),
                            child: Icon(Icons.person, size: 40, color: ZoosyTheme.textMutedOf(context))))
                      : Image.network(_avatarUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: ZoosyTheme.containerLowOf(context),
                            child: Icon(Icons.person, size: 40, color: ZoosyTheme.textMutedOf(context)))),
                ),
              ),
              Positioned(bottom: 0, right: 0,
                child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: ZoosyTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                ),
              ),
            ]),
          )),
          const SizedBox(height: 12),
          Center(child: Text(_nickname, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ZoosyTheme.textDarkOf(context)))),
          const SizedBox(height: 24),

          // 资料列表卡片
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              _buildFieldTile(TranslationService.tr('nickname'), _nickname, Icons.person_outline, () => _editField(TranslationService.tr('nickname'), _nickname, TranslationService.tr('enter_nickname'), (v) => ProfileService.setNickname(v))),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildFieldTile(TranslationService.tr('email'), _email, Icons.email_outlined, () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeEmailScreen()));
                await _loadProfile();
                widget.onSaved();
                if (mounted) setState(() {});
              }),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildFieldTile(TranslationService.tr('gender'), _gender, Icons.people_outline, () => _openGenderEditor()),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildFieldTile(TranslationService.tr('birthday'), _birthday, Icons.cake_outlined, () => _pickBirthday()),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildFieldTile(TranslationService.tr('occupation'), _occupation, Icons.work_outline, () => _editField(TranslationService.tr('occupation'), _occupation, TranslationService.tr('enter_nickname'), (v) => ProfileService.setOccupation(v))),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildFieldTile(TranslationService.tr('signature'), _signature.isEmpty ? TranslationService.tr('not_set') : _signature, Icons.format_quote, () => _editField(TranslationService.tr('signature'), _signature, TranslationService.tr('write_signature'), (v) => ProfileService.setSignature(v), maxLines: 3)),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildFieldTile(TranslationService.tr('bio'), _bio.isEmpty ? TranslationService.tr('not_set') : _bio, Icons.description_outlined, () => _editField(TranslationService.tr('bio'), _bio, TranslationService.tr('introduce_yourself'), (v) => ProfileService.setBio(v), maxLines: 5)),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildFieldTile(String label, String value, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: ZoosyTheme.textMutedOf(context)),
      title: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
      subtitle: Text(value, style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context))),
      trailing: Icon(Icons.chevron_right, size: 20, color: ZoosyTheme.textMutedOf(context)),
      onTap: onTap,
    );
  }

  Future<void> _editField(String title, String current, String hint, Future<void> Function(String) saveFunc, {int maxLines = 1}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditFieldScreen(
      title: title, initialValue: current, hintText: hint, maxLines: maxLines,
      onSave: (v) async {
        await saveFunc(v);
        await _loadProfile();
        widget.onSaved();
      },
    )));
    if (mounted) setState(() {});
  }

  Future<void> _openGenderEditor() async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => EditGenderScreen(currentGender: _gender)));
    if (result != null) {
      await _loadProfile();
      widget.onSaved();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      locale: const Locale('zh'),
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: ZoosyTheme.primary, primary: ZoosyTheme.primary),
      ), child: child!),
    );
    if (date != null) {
      await ProfileService.setBirthday('${date.year}年${date.month}月${date.day}日');
      await _loadProfile();
      widget.onSaved();
      if (mounted) setState(() {});
    }
  }
}
