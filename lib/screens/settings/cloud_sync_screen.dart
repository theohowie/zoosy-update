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
      ToastUtil.showToast(context, message: TranslationService.tr('config_saved'), icon: Icons.check, color: Colors.green);
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
        title: Text(TranslationService.tr('cloud_sync'), style: TextStyle(fontWeight: FontWeight.bold)),
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
                      TranslationService.tr('cloud_sync_desc'),
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
              label: TranslationService.tr('server_address'),
              hint: 'https://dav.jianguoyun.com/dav/',
              icon: Icons.dns,
            ),
            const SizedBox(height: 16),

            // 用户名
            _buildTextField(
              controller: _usernameController,
              label: TranslationService.tr('username'),
              hint: 'your@email.com',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // 密码
            _buildTextField(
              controller: _passwordController,
              label: TranslationService.tr('app_password'),
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
                    label: Text(_testing ? TranslationService.tr('testing') : TranslationService.tr('test_connection')),
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
                    label: Text(TranslationService.tr('save_config')),
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
              title: TranslationService.tr('smart_sync'),
              subtitle: TranslationService.tr('smart_sync_desc'),
              onTap: _sync,
              color: ZoosyTheme.primary,
            ),
            const SizedBox(height: 8),

            // 上传
            _buildSyncButton(
              icon: Icons.cloud_upload,
              title: TranslationService.tr('upload_to_cloud'),
              subtitle: TranslationService.tr('upload_desc'),
              onTap: _upload,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),

            // 下载
            _buildSyncButton(
              icon: Icons.cloud_download,
              title: TranslationService.tr('download_from_cloud'),
              subtitle: TranslationService.tr('download_desc'),
              onTap: _download,
              color: Colors.orange,
            ),

            const SizedBox(height: 24),

            // 自动同步设置
            Text(TranslationService.tr('auto_sync'), style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: ZoosyTheme.textDarkOf(context),
            )),
            const SizedBox(height: 12),
            _buildAutoSyncOption(0, TranslationService.tr('auto_sync_off')),
            _buildAutoSyncOption(5, TranslationService.tr('auto_sync_5min')),
            _buildAutoSyncOption(10, TranslationService.tr('auto_sync_10min')),
            _buildAutoSyncOption(20, TranslationService.tr('auto_sync_20min')),

            if (_syncing)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(TranslationService.tr('syncing'), style: TextStyle(color: ZoosyTheme.textMutedOf(context))),
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
            message: minutes > 0 ? TranslationService.tr('auto_sync_enabled', params: {'interval': label}) : TranslationService.tr('auto_sync_disabled'),
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
  final _tabs = ['坚果云', 'NextCloud', '自建服务器'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.tr('cloud_sync_tutorial'), style: TextStyle(fontWeight: FontWeight.bold)),
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
        _buildSectionTitle('一、什么是坚果云 WebDAV？'),
        _buildParagraph('坚果云是国内主流的云存储服务，支持 WebDAV 协议。你可以通过 Zoosy 直接将思考数据同步到坚果云，实现多设备备份。'),
        const SizedBox(height: 16),

        _buildSectionTitle('二、获取 WebDAV 凭据'),
        _buildStep(1, '打开坚果云网页版', '浏览器访问 www.jianguoyun.com，登录你的账号'),
        _buildStep(2, '进入安全设置', '点击右上角头像 → 选择「设置」→ 左侧点击「安全选项」'),
        _buildStep(3, '找到第三方应用管理', '滚动页面到「第三方应用管理」区域'),
        _buildStep(4, '添加应用密码', '点击「添加应用密码」按钮，应用名称填「Zoosy」，点击确定'),
        _buildStep(5, '保存应用密码', '系统会生成一个 16 位的应用密码（如 a1b2c3d4e5f6g7h8），复制并保存好'),
        const SizedBox(height: 16),

        _buildSectionTitle('三、在 Zoosy 中配置'),
        _buildStep(6, '打开云同步', 'Zoosy → 个人中心 → 云同步'),
        _buildStep(7, '填写服务器地址', 'https://dav.jianguoyun.com/dav/'),
        _buildStep(8, '填写用户名', '你的坚果云登录邮箱（如 xxx@qq.com）'),
        _buildStep(9, '填写密码', '粘贴刚才复制的 16 位应用密码'),
        _buildStep(10, '测试连接', '点击「测试连接」，显示成功后点「保存配置」'),
        _buildStep(11, '开始同步', '点击「智能同步」即可上传数据'),
        const SizedBox(height: 16),

        _buildWarningBox([
          '密码处填的是「应用密码」，不是你的坚果云登录密码',
          '坚果云免费版每月 1GB 上传 / 3GB 下载流量',
          '首次同步建议用「智能同步」，会自动合并本地和云端数据',
        ]),
      ],
    );
  }

  // ==================== NextCloud ====================
  Widget _buildNextCloudGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('一、什么是 NextCloud？'),
        _buildParagraph('NextCloud 是开源的自托管云存储方案，你可以搭建自己的私有云。很多 NAS（群晖、威联通）也内置了 WebDAV 功能。'),
        const SizedBox(height: 16),

        _buildSectionTitle('二、获取 WebDAV 地址'),
        _buildStep(1, '登录 NextCloud', '打开你的 NextCloud 网页端并登录'),
        _buildStep(2, '查看 WebDAV 地址', 'NextCloud 的 WebDAV 格式为：\nhttps://你的域名/remote.php/dav/files/用户名/'),
        _buildStep(3, '获取应用密码（推荐）', '点击右上角头像 → 设置 → 安全 → 应用密码\n创建一个新密码，复制保存'),
        const SizedBox(height: 16),

        _buildSectionTitle('三、在 Zoosy 中配置'),
        _buildStep(4, '服务器地址', 'https://你的域名/remote.php/dav/files/用户名/'),
        _buildStep(5, '用户名', '你的 NextCloud 用户名'),
        _buildStep(6, '密码', '应用密码（推荐）或登录密码'),
        _buildStep(7, '测试并保存', '点击「测试连接」确认成功后保存'),
        const SizedBox(height: 16),

        _buildInfoBox('如果 NextCloud 启用了 HTTPS 自签证书，请在 Zoosy 中正常使用，已内置证书跳过功能。'),
      ],
    );
  }

  // ==================== 自建服务器 ====================
  Widget _buildSelfHostedGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('一、支持的服务端软件'),
        _buildParagraph('任何支持 WebDAV 协议的服务器都可以使用，常见的有：'),
        _buildBulletItem('Nginx + WebDAV 模块'),
        _buildBulletItem('Apache + mod_dav'),
        _buildBulletItem('Caddy + webdav 插件'),
        _buildBulletItem('Rclone serve webdav'),
        _buildBulletItem('WebDAV Server（Docker）'),
        const SizedBox(height: 16),

        _buildSectionTitle('二、快速搭建（Docker 方式）'),
        _buildCodeBlock('# 使用 rclone 搭建 WebDAV\n'
            'docker run -d \\\n'
            '  -p 8080:8080 \\\n'
            '  -v /data/webdav:/data \\\n'
            '  rclone/rclone serve webdav /data \\\n'
            '  --addr :8080 \\\n'
            '  --user admin \\\n'
            '  --pass your-password'),
        const SizedBox(height: 16),

        _buildSectionTitle('三、在 Zoosy 中配置'),
        _buildStep(1, '服务器地址', 'http://你的服务器IP:端口/（或 https）'),
        _buildStep(2, '用户名', '服务端设置的用户名'),
        _buildStep(3, '密码', '服务端设置的密码'),
        _buildStep(4, '测试并保存', '点击「测试连接」确认成功后保存'),
        const SizedBox(height: 16),

        _buildSectionTitle('四、Nginx 配置示例'),
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
          '自建服务器请确保启用 HTTPS，避免密码明文传输',
          '如果使用内网地址，手机需要在同一局域网下才能同步',
          '建议使用 DDNS 或内网穿透服务实现外网访问',
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
            Text('注意事项', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
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
