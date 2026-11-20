import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'ssh_service.dart';

void main() {
  runApp(const TotoLinkApp());
}

class TotoLinkApp extends StatelessWidget {
  const TotoLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TotoLink Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00695C),
        brightness: Brightness.dark,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _ipCtrl = TextEditingController(text: '192.168.1.1');
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _detectGateway();
  }

  Future<void> _detectGateway() async {
    try {
      final gw = await NetworkInfo().getWifiGatewayIP();
      if (gw != null && gw.isNotEmpty) {
        setState(() => _ipCtrl.text = gw);
      }
    } catch (_) {}
  }

  Future<void> _connect() async {
    if (_passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كلمة مرور الراوتر أولاً')),
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await RouterSshService().connect(
      ip: _ipCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    setState(() => _loading = false);

    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const Directionality(
            textDirection: TextDirection.rtl,
            child: DashboardPage(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل الاتصال! تأكد من تفعيل SSH وكلمة المرور')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.router, size: 64, color: Colors.tealAccent),
                  const SizedBox(height: 12),
                  const Text('TotoLink ND300 Assistant',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _ipCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الراوتر (IP)',
                      prefixIcon: Icon(Icons.lan),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _connect,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: Text(_loading ? 'جاري الاتصال...' : 'اتصال بالراوتر'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuItem('إعدادات الواي فاي', Icons.wifi, const WifiSettingsPage()),
      _MenuItem('الأجهزة والحظر (MAC)', Icons.devices, const DevicesAndMacPage()),
      _MenuItem('تحديد السرعة (QoS)', Icons.speed, const BandwidthPage()),
      _MenuItem('حجب المواقع (URL)', Icons.block, const UrlFilterPage()),
      _MenuItem('الإنترنت ووضع AP', Icons.settings_ethernet, const WanModePage()),
      _MenuItem('الشبكة والـ DNS', Icons.dns, const LanDnsPage()),
      _MenuItem('تفاصيل الخط (DSL)', Icons.analytics, const DslDetailsPage()),
      _MenuItem('إدارة النظام والأمان', Icons.admin_panel_settings, const SystemPage()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الراوتر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'قطع الاتصال',
            onPressed: () {
              RouterSshService().disconnect();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const Directionality(
                    textDirection: TextDirection.rtl,
                    child: LoginPage(),
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: item.page,
                ),
              ),
            ),
            child: Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 42, color: Colors.tealAccent),
                  const SizedBox(height: 10),
                  Text(item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Widget page;
  _MenuItem(this.title, this.icon, this.page);
}

// 1. WiFi Page
class WifiSettingsPage extends StatefulWidget {
  const WifiSettingsPage({super.key});
  @override
  State<WifiSettingsPage> createState() => _WifiSettingsPageState();
}

class _WifiSettingsPageState extends State<WifiSettingsPage> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _enabled = true;
  bool _wpsDisabled = true;
  bool _hidden = false;
  int _channel = 6;
  int _txPower = 100;
  int _chanWidth = 0;
  String _statusOutput = '';

  Future<void> _load() async {
    final res = await RouterSshService().getWifiInfo();
    setState(() => _statusOutput = res);
  }

  Future<void> _save() async {
    await RouterSshService().setWifiSettings(
      enabled: _enabled,
      ssid: _ssidCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      wpsDisabled: _wpsDisabled,
      hidden: _hidden,
      channel: _channel,
      txPower: _txPower,
      chanWidth: _chanWidth,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ إعدادات الواي فاي بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الواي فاي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('تفعيل الواي فاي'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          TextField(
            controller: _ssidCtrl,
            decoration: const InputDecoration(labelText: 'اسم الشبكة (SSID)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            decoration: const InputDecoration(labelText: 'كلمة المرور (8 أحرف على الأقل)', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            title: const Text('إغلاق ثغرة WPS (موصى به)'),
            value: _wpsDisabled,
            onChanged: (v) => setState(() => _wpsDisabled = v),
          ),
          SwitchListTile(
            title: const Text('إخفاء الشبكة (Hidden SSID)'),
            value: _hidden,
            onChanged: (v) => setState(() => _hidden = v),
          ),
          DropdownButtonFormField<int>(
            value: _channel,
            decoration: const InputDecoration(labelText: 'القناة (Channel)'),
            items: List.generate(13, (i) => DropdownMenuItem(value: i + 1, child: Text('قناة ${i + 1}'))),
            onChanged: (v) => setState(() => _channel = v ?? 6),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _txPower,
            decoration: const InputDecoration(labelText: 'قوة الإشارة (TX Power)'),
            items: const [
              DropdownMenuItem(value: 100, child: Text('100%')),
              DropdownMenuItem(value: 80, child: Text('80%')),
              DropdownMenuItem(value: 50, child: Text('50%')),
              DropdownMenuItem(value: 25, child: Text('25%')),
              DropdownMenuItem(value: 10, child: Text('10%')),
            ],
            onChanged: (v) => setState(() => _txPower = v ?? 100),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _chanWidth,
            decoration: const InputDecoration(labelText: 'عرض النطاق (Channel Width)'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('20 MHz')),
              DropdownMenuItem(value: 1, child: Text('40 MHz')),
            ],
            onChanged: (v) => setState(() => _chanWidth = v ?? 0),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('تطبيق وحفظ')),
          OutlinedButton(onPressed: _load, child: const Text('قراءة الحالة الحالية')),
          if (_statusOutput.isNotEmpty) SelectableText(_statusOutput),
        ],
      ),
    );
  }
}

// 2. Devices & MAC Filter Page
class DevicesAndMacPage extends StatefulWidget {
  const DevicesAndMacPage({super.key});
  @override
  State<DevicesAndMacPage> createState() => _DevicesAndMacPageState();
}

class _DevicesAndMacPageState extends State<DevicesAndMacPage> {
  final _macCtrl = TextEditingController();
  String _output = '';

  Future<void> _scan() async {
    final res = await RouterSshService().getStationsAndAcl();
    setState(() => _output = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأجهزة وحظر MAC')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.refresh),
            label: const Text('فحص الأجهزة المتصلة وقائمة الحظر'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => RouterSshService().setMacFilterMode(0),
                child: const Text('تعطيل الفلتر'),
              ),
              ElevatedButton(
                onPressed: () => RouterSshService().setMacFilterMode(2),
                child: const Text('وضع الحظر (Block)'),
              ),
              ElevatedButton(
                onPressed: () => RouterSshService().setMacFilterMode(1),
                child: const Text('وضع السماح (Permit)'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _macCtrl,
            decoration: const InputDecoration(
              labelText: 'عنوان MAC (مثال: AA:BB:CC:DD:EE:FF)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => RouterSshService().addMacAcl(_macCtrl.text.trim()),
                  child: const Text('إضافة للقائمة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => RouterSshService().deleteMacAcl(_macCtrl.text.trim()),
                  child: const Text('حذف من القائمة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(_output),
        ],
      ),
    );
  }
}

// 3. Bandwidth QoS Page
class BandwidthPage extends StatefulWidget {
  const BandwidthPage({super.key});
  @override
  State<BandwidthPage> createState() => _BandwidthPageState();
}

class _BandwidthPageState extends State<BandwidthPage> {
  final _startIpCtrl = TextEditingController(text: '192.168.1.2');
  final _endIpCtrl = TextEditingController(text: '192.168.1.254');
  final _downCtrl = TextEditingController(text: '2048');
  final _upCtrl = TextEditingController(text: '512');
  String _output = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحديد السرعة (QoS)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _startIpCtrl,
            decoration: const InputDecoration(labelText: 'من IP', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _endIpCtrl,
            decoration: const InputDecoration(labelText: 'إلى IP', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _downCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'سرعة التحميل (kbps)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _upCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'سرعة الرفع (kbps)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => RouterSshService().addDeviceBandwidthRule(
              startIp: _startIpCtrl.text.trim(),
              endIp: _endIpCtrl.text.trim(),
              downKbps: int.tryParse(_downCtrl.text) ?? 2048,
              upKbps: int.tryParse(_upCtrl.text) ?? 512,
            ),
            child: const Text('إضافة قاعدة تحديد سرعة'),
          ),
          OutlinedButton(
            onPressed: () => RouterSshService().clearAllBandwidthRules(),
            child: const Text('حذف جميع القواعد'),
          ),
          OutlinedButton(
            onPressed: () async {
              final r = await RouterSshService().getQosStatus();
              setState(() => _output = r);
            },
            child: const Text('عرض القواعد الحالية'),
          ),
          SelectableText(_output),
        ],
      ),
    );
  }
}

// 4. URL Filter Page
class UrlFilterPage extends StatefulWidget {
  const UrlFilterPage({super.key});
  @override
  State<UrlFilterPage> createState() => _UrlFilterPageState();
}

class _UrlFilterPageState extends State<UrlFilterPage> {
  final _urlCtrl = TextEditingController();
  String _output = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حجب المواقع')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(labelText: 'رابط الموقع (مثال: facebook.com)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => RouterSshService().addBlockedUrl(_urlCtrl.text.trim()),
                  child: const Text('حجب الموقع'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => RouterSshService().removeBlockedUrl(_urlCtrl.text.trim()),
                  child: const Text('إلغاء الحجب'),
                ),
              ),
            ],
          ),
          OutlinedButton(
            onPressed: () async {
              final r = await RouterSshService().getBlockedDomains();
              setState(() => _output = r);
            },
            child: const Text('عرض المواقع المحجوبة'),
          ),
          SelectableText(_output),
        ],
      ),
    );
  }
}

// 5. WAN & Access Point Mode
class WanModePage extends StatefulWidget {
  const WanModePage({super.key});
  @override
  State<WanModePage> createState() => _WanModePageState();
}

class _WanModePageState extends State<WanModePage> {
  final _pppoeUser = TextEditingController();
  final _pppoePass = TextEditingController();
  final _mtuCtrl = TextEditingController(text: '1492');
  final _apIpCtrl = TextEditingController(text: '192.168.1.2');
  final _apGwCtrl = TextEditingController(text: '192.168.1.1');
  String _output = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإنترنت ووضع AP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('إعدادات ADSL (PPPoE)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _pppoeUser, decoration: const InputDecoration(labelText: 'اسم مستخدم الخدمة', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _pppoePass, decoration: const InputDecoration(labelText: 'كلمة مرور الخدمة', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _mtuCtrl, decoration: const InputDecoration(labelText: 'MTU', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => RouterSshService().configurePppoe(
              user: _pppoeUser.text.trim(),
              pass: _pppoePass.text.trim(),
              mtu: int.tryParse(_mtuCtrl.text) ?? 1492,
            ),
            child: const Text('تفعيل كراوتر ADSL'),
          ),
          const Divider(height: 32),
          const Text('تحويل إلى Access Point (Ethernet WAN)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _apIpCtrl, decoration: const InputDecoration(labelText: 'Static IP', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _apGwCtrl, decoration: const InputDecoration(labelText: 'Gateway IP', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => RouterSshService().configureAccessPointMode(
              staticIp: _apIpCtrl.text.trim(),
              gateway: _apGwCtrl.text.trim(),
            ),
            child: const Text('تفعيل وضع Access Point'),
          ),
          OutlinedButton(
            onPressed: () async {
              final r = await RouterSshService().getWanStatus();
              setState(() => _output = r);
            },
            child: const Text('عرض حالة الاتصال الحالية'),
          ),
          SelectableText(_output),
        ],
      ),
    );
  }
}

// 6. LAN & DNS Page
class LanDnsPage extends StatefulWidget {
  const LanDnsPage({super.key});
  @override
  State<LanDnsPage> createState() => _LanDnsPageState();
}

class _LanDnsPageState extends State<LanDnsPage> {
  final _dns1Ctrl = TextEditingController(text: '1.1.1.1');
  final _dns2Ctrl = TextEditingController(text: '8.8.8.8');
  final _lanIpCtrl = TextEditingController(text: '192.168.1.1');
  final _maskCtrl = TextEditingController(text: '255.255.255.0');
  final _poolStartCtrl = TextEditingController(text: '192.168.1.2');
  final _poolEndCtrl = TextEditingController(text: '192.168.1.254');
  String _output = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشبكة والـ DNS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('إعدادات DNS (مثل Cloudflare أو FamilyShield)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Cloudflare'),
                onPressed: () {
                  _dns1Ctrl.text = '1.1.1.1';
                  _dns2Ctrl.text = '1.0.0.1';
                },
              ),
              ActionChip(
                label: const Text('Google'),
                onPressed: () {
                  _dns1Ctrl.text = '8.8.8.8';
                  _dns2Ctrl.text = '8.8.4.4';
                },
              ),
              ActionChip(
                label: const Text('حجب الإباحية (FamilyShield)'),
                onPressed: () {
                  _dns1Ctrl.text = '208.67.222.123';
                  _dns2Ctrl.text = '208.67.220.123';
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: _dns1Ctrl, decoration: const InputDecoration(labelText: 'DNS 1', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _dns2Ctrl, decoration: const InputDecoration(labelText: 'DNS 2', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => RouterSshService().setDnsServers(_dns1Ctrl.text.trim(), _dns2Ctrl.text.trim()),
            child: const Text('تطبيق DNS'),
          ),
          const Divider(height: 32),
          const Text('إعدادات LAN و DHCP', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _lanIpCtrl, decoration: const InputDecoration(labelText: 'Router IP', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _maskCtrl, decoration: const InputDecoration(labelText: 'Subnet Mask', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _poolStartCtrl, decoration: const InputDecoration(labelText: 'بداية DHCP', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _poolEndCtrl, decoration: const InputDecoration(labelText: 'نهاية DHCP', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => RouterSshService().setLanDhcp(
              routerIp: _lanIpCtrl.text.trim(),
              mask: _maskCtrl.text.trim(),
              poolStart: _poolStartCtrl.text.trim(),
              poolEnd: _poolEndCtrl.text.trim(),
            ),
            child: const Text('حفظ إعدادات LAN'),
          ),
          OutlinedButton(
            onPressed: () async {
              final r = await RouterSshService().getLanDnsInfo();
              setState(() => _output = r);
            },
            child: const Text('عرض الإعدادات الحالية'),
          ),
          SelectableText(_output),
        ],
      ),
    );
  }
}

// 7. DSL Details Page
class DslDetailsPage extends StatefulWidget {
  const DslDetailsPage({super.key});
  @override
  State<DslDetailsPage> createState() => _DslDetailsPageState();
}

class _DslDetailsPageState extends State<DslDetailsPage> {
  String _dslInfo = 'اضغط على تحديث لقراءة بيانات الخط (SNR / Attenuation / Max Rate)...';

  Future<void> _fetch() async {
    final res = await RouterSshService().getDslDetails();
    setState(() => _dslInfo = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل خط DSL')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('قراءة بيانات الخط الآن'),
            ),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: SelectableText(_dslInfo))),
          ],
        ),
      ),
    );
  }
}

// 8. System Management Page
class SystemPage extends StatefulWidget {
  const SystemPage({super.key});
  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  final _newPassCtrl = TextEditingController();
  final _macCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة النظام والأمان')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _newPassCtrl,
            decoration: const InputDecoration(labelText: 'كلمة مرور دخول الراوتر الجديدة', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              if (_newPassCtrl.text.isNotEmpty) {
                RouterSshService().changeRouterPassword(_newPassCtrl.text.trim());
              }
            },
            child: const Text('تغيير باسورد الراوتر'),
          ),
          const Divider(height: 24),
          TextField(
            controller: _macCtrl,
            decoration: const InputDecoration(labelText: 'تغيير WAN MAC Address', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              if (_macCtrl.text.isNotEmpty) {
                RouterSshService().changeWanMac(_macCtrl.text.trim());
              }
            },
            child: const Text('تغيير الـ MAC'),
          ),
          const Divider(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => RouterSshService().reboot(),
            icon: const Icon(Icons.restart_alt),
            label: const Text('إعادة تشغيل الراوتر (Reboot)'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () => RouterSshService().factoryReset(),
            icon: const Icon(Icons.warning),
            label: const Text('إعادة ضبط المصنع (Factory Reset)'),
          ),
        ],
      ),
    );
  }
}
