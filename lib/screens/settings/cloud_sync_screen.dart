import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/reflection.dart';
import '../../services/cloud_service.dart';
import '../../services/theme_service.dart';
import '../../services/translation_service.dart';
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
    if (mounted) {
      setState(() {
        _serverController.text = config['server'] ?? '';
        _usernameController.text = config['username'] ?? '';
        _passwordController.text = config['password'] ?? '';
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
      _testResult = error == null ? '连接成功' : error;
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
      ToastUtil.showToast(context, message: '配置已保存', icon: Icons.check, color: Colors.green);
    }
  }

  Future<void> _upload() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    final error = await CloudService.upload(widget.reflections);

    if (!mounted) return;
    setState(() => _syncing = false);

    if (error == null) {
      ToastUtil.showToast(context, message: '上传成功', icon: Icons.cloud_done, color: Colors.green);
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
        message: '下载完成，共 ${reflections.length} 条记录',
        icon: Icons.cloud_download,
        color: Colors.green,
      );
    } else {
      ToastUtil.showToast(context, message: '下载失败或无数据', icon: Icons.error_outline, color: Colors.red);
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
      message: '${result.message}，共 ${result.reflections.length} 条记录',
      icon: result.hasUpdate ? Icons.sync : Icons.check,
      color: Colors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('云同步', style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                      '支持 WebDAV 协议的云服务，如坚果云、NextCloud、自建服务器等。',
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
              label: '服务器地址',
              hint: 'https://dav.jianguoyun.com/dav/',
              icon: Icons.dns,
            ),
            const SizedBox(height: 16),

            // 用户名
            _buildTextField(
              controller: _usernameController,
              label: '用户名',
              hint: 'your@email.com',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // 密码
            _buildTextField(
              controller: _passwordController,
              label: '密码 / 应用密码',
              hint: '输入密码或应用专用密码',
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
                    label: Text(_testing ? '测试中...' : '测试连接'),
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
                    label: Text('保存配置'),
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
            Text('同步操作', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: ZoosyTheme.textDarkOf(context),
            )),
            const SizedBox(height: 12),

            // 双向同步
            _buildSyncButton(
              icon: Icons.sync,
              title: '智能同步',
              subtitle: '合并本地和云端数据，自动去重',
              onTap: _sync,
              color: ZoosyTheme.primary,
            ),
            const SizedBox(height: 8),

            // 上传
            _buildSyncButton(
              icon: Icons.cloud_upload,
              title: '上传到云端',
              subtitle: '将本地数据覆盖到云端',
              onTap: _upload,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),

            // 下载
            _buildSyncButton(
              icon: Icons.cloud_download,
              title: '从云端下载',
              subtitle: '将云端数据覆盖到本地',
              onTap: _download,
              color: Colors.orange,
            ),

            if (_syncing)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text('同步中...', style: TextStyle(color: ZoosyTheme.textMutedOf(context))),
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
}
