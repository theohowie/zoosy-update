import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/prefs_util.dart';
import '../../services/auth_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({Key? key}) : super(key: key);
  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  bool _isLoggedIn = false;
  List<Map<String, String>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = await AuthService.getLoggedInEmail();
    _isLoggedIn = email != null;
    if (_isLoggedIn) {
      _devices = await _loadDevices();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<List<Map<String, String>>> _loadDevices() async {
    final prefs = await PrefsUtil.get();
    final deviceName = prefs.getString('device_name') ?? _getDeviceName();
    // 只记录当前设备
    return [{
      'name': deviceName,
      'model': 'Android',
      'time': DateTime.now().toLocal().toString().substring(0, 16),
      'isCurrent': 'true',
    }];
  }

  String _getDeviceName() {
    // 简单获取设备名称
    return context.l10n.dm_android_device;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(
      appBar: AppBar(title: Text(context.l10n.device_management, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.device_management, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: _isLoggedIn
          ? _buildDeviceList()
          : Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.devices, size: 64, color: ZoosyTheme.textMutedOf(context).withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(context.l10n.please_login, style: TextStyle(fontSize: 16, color: ZoosyTheme.textMutedOf(context))),
              ]),
            ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return Center(child: Text(context.l10n.no_device_records, style: TextStyle(color: ZoosyTheme.textMutedOf(context))));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, idx) {
        final device = _devices[idx];
        final isCurrent = device['isCurrent'] == 'true';
        return ListTile(
          leading: Icon(isCurrent ? Icons.phone_android : Icons.devices_other, color: ZoosyTheme.primary),
          title: Text(device['name'] ?? context.l10n.unknown_device, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          subtitle: Text(isCurrent ? context.l10n.current_device : context.l10n.other_device, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
          trailing: isCurrent
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(context.l10n.current_device, style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                )
              : IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.6), size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: ZoosyTheme.surfaceOf(ctx),
                        surfaceTintColor: Colors.transparent,
                        title: Text(ctx.l10n.delete_device, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
                        content: Text(ctx.l10n.delete_device_confirm, style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary),
                            child: Text(ctx.l10n.delete, style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      setState(() => _devices.removeAt(idx));
                      // 持久化
                      final prefs = await PrefsUtil.get();
                      await prefs.setStringList('login_devices', _devices.map((d) => d['name'] ?? '').toList());
                    }
                  },
                ),
        );
      },
    );
  }
}
