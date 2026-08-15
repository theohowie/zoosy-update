import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/reflection.dart';
import '../../services/cloud_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/toast_util.dart';

class CloudSyncScreen extends StatefulWidget {
  final List<Reflection> reflections;
  final Function(List<Reflection>) onSyncCompleted;

  const CloudSyncScreen({
    Key? key,
    required this.reflections,
    required this.onSyncCompleted,
  }) : super(key: key);

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _testing = false;
  bool _syncing = false;
  String? _testResult;
  bool _isSuccess = false;
  int _autoSyncInterval = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await CloudService.getConfig();
    final interval = await CloudService.getAutoSyncInterval();
    if (mounted) {
      setState(() {
        _serverController.text = config['server'] ?? '';
        _usernameController.text = config['username'] ?? '';
        _passwordController.text = config['password'] ?? '';
        _autoSyncInterval = interval;
      });
    }
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });

    // 先保存配置
    await CloudService.saveConfig(
      server: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    final error = await CloudService.testConnection();

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = error == null ? context.l10n.cs_conn_success : error;
      _isSuccess = error == null;
    });
  }

  Future<void> _saveConfig() async {
    await CloudService.saveConfig(
      server: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    if (mounted) {
      ToastUtil.showToast(context, message: context.l10n.config_saved, icon: Icons.check, color: Colors.green);
    }
  }

  Future<void> _upload() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    final error = await CloudService.upload(widget.reflections);

    if (!mounted) return;
    setState(() => _syncing = false);

    if (error == null) {
      ToastUtil.showToast(context, message: context.l10n.cs_upload_success, icon: Icons.cloud_done, color: Colors.green);
    } else {
      ToastUtil.showToast(context, message: error, icon: Icons.error_outline, color: Colors.red);
    }
  }

  Future<void> _download() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    final reflections = await CloudService.download();

    if (!mounted) return;
    setState(() => _syncing = false);

    if (reflections != null) {
      widget.onSyncCompleted(reflections);
      ToastUtil.showToast(
        context,
        message: context.l10n.cs_download_done(reflections.length),
        icon: Icons.cloud_download,
        color: Colors.green,
      );
    } else {
      ToastUtil.showToast(context, message: context.l10n.cs_download_failed, icon: Icons.error_outline, color: Colors.red);
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    final result = await CloudService.sync(widget.reflections);

    if (!mounted) return;
    setState(() => _syncing = false);

    widget.onSyncCompleted(result.reflections);
    ToastUtil.showToast(
      context,
      message: context.l10n.cs_upload_result(result.message, result.reflections.length),
      icon: result.hasUpdate ? Icons.sync : Icons.check,
      color: Colors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cloud_sync, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: ZoosyTheme.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const CloudSyncTutorialScreen(),
            )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZoosyTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: ZoosyTheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.cloud_sync_desc,
                      style: TextStyle(fontSize: 13, color: ZoosyTheme.textDarkOf(context)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 服务器地址
            _buildTextField(
              controller: _serverController,
              label: context.l10n.server_address,
              hint: context.l10n.cs_jg_step7_d,
              icon: Icons.dns,
            ),
            const SizedBox(height: 16),

            // 用户名
            _buildTextField(
              controller: _usernameController,
              label: context.l10n.username,
              hint: 'your@email.com',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // 密码
            _buildTextField(
              controller: _passwordController,
              label: context.l10n.app_password,
              hint: context.l10n.cs_pwd_hint,
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              suffix: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 16),

            // 测试连接
            if (_testResult != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error,
                      color: _isSuccess ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_testResult!, style: TextStyle(
                        fontSize: 13,
                        color: _isSuccess ? Colors.green : Colors.red,
                      )),
                    ),
                  ],
                ),
              ),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.wifi_find, size: 18),
                    label: Text(_testing ? context.l10n.testing : context.l10n.test_connection),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZoosyTheme.primary,
                      side: BorderSide(color: ZoosyTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveConfig,
                    icon: Icon(Icons.save, size: 18),
                    label: Text(context.l10n.save_config),
                    style: FilledButton.styleFrom(
                      backgroundColor: ZoosyTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 同步操作
            Text(context.l10n.cs_sync_ops, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: ZoosyTheme.textDarkOf(context),
            )),
            const SizedBox(height: 12),

            // 双向同步
            _buildSyncButton(
              icon: Icons.sync,
              title: context.l10n.smart_sync,
              subtitle: context.l10n.smart_sync_desc,
              onTap: _sync,
              color: ZoosyTheme.primary,
            ),
            const SizedBox(height: 8),

            // 上传
            _buildSyncButton(
              icon: Icons.cloud_upload,
              title: context.l10n.upload_to_cloud,
              subtitle: context.l10n.upload_desc,
              onTap: _upload,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),

            // 下载
            _buildSyncButton(
              icon: Icons.cloud_download,
              title: context.l10n.download_from_cloud,
              subtitle: context.l10n.download_desc,
              onTap: _download,
              color: Colors.orange,
            ),

            const SizedBox(height: 24),

            // 自动同步设置
            Text(context.l10n.auto_sync, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: ZoosyTheme.textDarkOf(context),
            )),
            const SizedBox(height: 12),
            _buildAutoSyncOption(0, context.l10n.auto_sync_off),
            _buildAutoSyncOption(5, context.l10n.auto_sync_5min),
            _buildAutoSyncOption(10, context.l10n.auto_sync_10min),
            _buildAutoSyncOption(20, context.l10n.auto_sync_20min),

            if (_syncing)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(context.l10n.syncing, style: TextStyle(color: ZoosyTheme.textMutedOf(context))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSyncButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: _syncing
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.chevron_right, color: ZoosyTheme.textMutedOf(context)),
        onTap: _syncing ? null : onTap,
      ),
    );
  }

  Widget _buildAutoSyncOption(int minutes, String label) {
    final isSelected = _autoSyncInterval == minutes;
    return GestureDetector(
      onTap: () async {
        await CloudService.setAutoSyncInterval(minutes);
        setState(() => _autoSyncInterval = minutes);

        if (minutes > 0) {
          CloudService.startAutoSync(
            getReflections: () => widget.reflections,
            onSynced: (refs) {
              widget.onSyncCompleted(refs);
            },
          );
        } else {
          await CloudService.stopAutoSync();
        }

        if (mounted) {
          ToastUtil.showToast(
            context,
            message: minutes > 0 ? context.l10n.auto_sync_enabled(label) : context.l10n.auto_sync_disabled,
            icon: minutes > 0 ? Icons.timer : Icons.timer_off,
            color: Colors.green,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ZoosyTheme.primary.withOpacity(0.1) : ZoosyTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ZoosyTheme.primary : ZoosyTheme.outlineOf(context).withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textDarkOf(context),
            )),
          ],
        ),
      ),
    );
  }
}

/// 云同步教程页面
class CloudSyncTutorialScreen extends StatefulWidget {
  const CloudSyncTutorialScreen({Key? key}) : super(key: key);

  @override
  State<CloudSyncTutorialScreen> createState() => _CloudSyncTutorialScreenState();
}

class _CloudSyncTutorialScreenState extends State<CloudSyncTutorialScreen> {
  int _selectedTab = 0;
  List<String> get _tabs => [context.l10n.cs_tab_jianguoyun, 'NextCloud', context.l10n.cs_tab_selfhosted];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cloud_sync_tutorial, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 顶部切换按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final isSelected = _selectedTab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? ZoosyTheme.primary : ZoosyTheme.surfaceOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? ZoosyTheme.primary : ZoosyTheme.outlineOf(context).withOpacity(0.2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(_tabs[i], style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : ZoosyTheme.textDarkOf(context),
                      )),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 内容区
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0: return _buildJianguoyunGuide();
      case 1: return _buildNextCloudGuide();
      case 2: return _buildSelfHostedGuide();
      default: return const SizedBox();
    }
  }

  // ==================== 坚果云 ====================
  Widget _buildJianguoyunGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context.l10n.cs_jg_s1_title),
        _buildParagraph(context.l10n.cs_jg_s1_para),
        const SizedBox(height: 16),

        _buildSectionTitle(context.l10n.cs_jg_s2_title),
        _buildStep(1, context.l10n.cs_jg_step1_t, context.l10n.cs_jg_step1_d),
        _buildStep(2, context.l10n.cs_jg_step2_t, context.l10n.cs_jg_step2_d),
        _buildStep(3, context.l10n.cs_jg_step3_t, context.l10n.cs_jg_step3_d),
        _buildStep(4, context.l10n.cs_jg_step4_t, context.l10n.cs_jg_step4_d),
        _buildStep(5, context.l10n.cs_jg_step5_t, context.l10n.cs_jg_step5_d),
        const SizedBox(height: 16),

        _buildSectionTitle(context.l10n.cs_jg_s3_title),
        _buildStep(6, context.l10n.cs_jg_step6_t, context.l10n.cs_jg_step6_d),
        _buildStep(7, context.l10n.cs_jg_step7_t, context.l10n.cs_jg_step7_d),
        _buildStep(8, context.l10n.cs_jg_step8_t, context.l10n.cs_jg_step8_d),
        _buildStep(9, context.l10n.cs_jg_step9_t, context.l10n.cs_jg_step9_d),
        _buildStep(10, context.l10n.cs_jg_step10_t, context.l10n.cs_jg_step10_d),
        _buildStep(11, context.l10n.cs_jg_step11_t, context.l10n.cs_jg_step11_d),
        const SizedBox(height: 16),

        _buildWarningBox([
          context.l10n.cs_jg_warn1,
          context.l10n.cs_jg_warn2,
          context.l10n.cs_jg_warn3,
        ]),
      ],
    );
  }

  // ==================== NextCloud ====================
  Widget _buildNextCloudGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context.l10n.cs_nc_s1_title),
        _buildParagraph(context.l10n.cs_nc_s1_para),
        const SizedBox(height: 16),

        _buildSectionTitle(context.l10n.cs_nc_s2_title),
        _buildStep(1, context.l10n.cs_nc_step1_t, context.l10n.cs_nc_step1_d),
        _buildStep(2, context.l10n.cs_nc_step2_t, context.l10n.cs_nc_step2_d),
        _buildStep(3, context.l10n.cs_nc_step3_t, context.l10n.cs_nc_step3_d),
        const SizedBox(height: 16),

        _buildSectionTitle(context.l10n.cs_jg_s3_title),
        _buildStep(4, context.l10n.cs_server_addr, context.l10n.cs_nc_step4_d),
        _buildStep(5, context.l10n.cs_username, context.l10n.cs_nc_step5_d),
        _buildStep(6, context.l10n.cs_password, context.l10n.cs_nc_step6_d),
        _buildStep(7, context.l10n.cs_test_save, context.l10n.cs_test_save_desc),
        const SizedBox(height: 16),

        _buildInfoBox(context.l10n.cs_nc_info1),
      ],
    );
  }

  // ==================== 自建服务器 ====================
  Widget _buildSelfHostedGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context.l10n.cs_sh_s1_title),
        _buildParagraph(context.l10n.cs_sh_s1_para),
        _buildBulletItem(context.l10n.cs_sh_bullet1),
        _buildBulletItem(context.l10n.cs_sh_bullet2),
        _buildBulletItem(context.l10n.cs_sh_bullet3),
        _buildBulletItem(context.l10n.cs_sh_bullet4),
        _buildBulletItem(context.l10n.cs_sh_bullet5),
        const SizedBox(height: 16),

        _buildSectionTitle(context.l10n.cs_sh_s2_title),
        _buildCodeBlock('# 使用 rclone 搭建 WebDAV\n'
            'docker run -d \\\n'
            '  -p 8080:8080 \\\n'
            '  -v /data/webdav:/data \\\n'
            '  rclone/rclone serve webdav /data \\\n'
            '  --addr :8080 \\\n'
            '  --user admin \\\n'
            '  --pass your-password'),
        const SizedBox(height: 16),

        _buildSectionTitle(context.l10n.cs_jg_s3_title),
        _buildStep(1, context.l10n.cs_server_addr, context.l10n.cs_sh_step1_d),
        _buildStep(2, context.l10n.cs_username, context.l10n.cs_sh_step2_d),
        _buildStep(3, context.l10n.cs_password, context.l10n.cs_sh_step3_d),
        _buildStep(4, context.l10n.cs_test_save, context.l10n.cs_test_save_desc),
        const SizedBox(height: 16),

        _buildSectionTitle(context.l10n.cs_sh_s4_title),
        _buildCodeBlock('server {\n'
            '    listen 443 ssl;\n'
            '    server_name dav.example.com;\n\n'
            '    location / {\n'
            '        dav_methods PUT DELETE MKCOL COPY MOVE;\n'
            '        dav_ext_methods PROPFIND OPTIONS;\n'
            '        dav_access user:rw group:rw all:r;\n'
            '        create_full_put_path on;\n'
            '        basic_user_file /etc/nginx/.htpasswd;\n'
            '    }\n'
            '}'),
        const SizedBox(height: 16),

        _buildWarningBox([
          context.l10n.cs_sh_warn1,
          context.l10n.cs_sh_warn2,
          context.l10n.cs_sh_warn3,
        ]),
      ],
    );
  }

  // ==================== 通用组件 ====================

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold,
        color: ZoosyTheme.primary,
      )),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey.shade700)),
    );
  }

  Widget _buildStep(int step, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: ZoosyTheme.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$step', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 8),
      child: Row(
        children: [
          Text('• ', style: TextStyle(color: ZoosyTheme.primary)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(code, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey.shade800)),
    );
  }

  Widget _buildWarningBox(List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 18),
            const SizedBox(width: 6),
            Text(context.l10n.cs_note, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
          ]),
          const SizedBox(height: 8),
          ...items.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: Colors.orange.shade800)),
                Expanded(child: Text(t, style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.blue.shade800))),
        ],
      ),
    );
  }
}
