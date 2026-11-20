import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

class RouterSshService {
  static final RouterSshService _instance = RouterSshService._internal();
  factory RouterSshService() => _instance;
  RouterSshService._internal();

  SSHClient? _client;
  SSHSession? _shell;
  String _buffer = '';
  bool isConnected = false;

  Future<bool> connect({
    required String ip,
    required String username,
    required String password,
  }) async {
    try {
      disconnect();
      final socket = await SSHSocket.connect(ip, 22, timeout: const Duration(seconds: 6));
      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      _shell = await _client!.shell();
      _shell!.stdout.listen((Uint8List data) {
        _buffer += utf8.decode(data, allowMalformed: true);
      });
      await Future.delayed(const Duration(milliseconds: 600));
      isConnected = true;
      return true;
    } catch (e) {
      isConnected = false;
      return false;
    }
  }

  Future<String> sendCommand(String cmd, {int waitMs = 700}) async {
    if (!isConnected || _shell == null) {
      throw Exception('غير متصل بالراوتر');
    }
    _buffer = '';
    _shell!.write(utf8.encode('$cmd\n'));
    await Future.delayed(Duration(milliseconds: waitMs));
    return _buffer;
  }

  Future<void> saveConfig() async {
    await sendCommand('save', waitMs: 1500);
  }

  // 1. WiFi Basic & Advanced
  Future<String> getWifiInfo() async {
    final sec = await sendCommand('show wlan security');
    final cfg = await sendCommand('show wlan config');
    return '$sec\n---\n$cfg';
  }

  Future<void> setWifiSettings({
    required bool enabled,
    required String ssid,
    required String password,
    required bool wpsDisabled,
    required bool hidden,
    required int channel,
    required int txPower,
    required int chanWidth,
  }) async {
    await sendCommand('config');
    await sendCommand(enabled ? 'wlan enable' : 'no wlan enable');
    if (ssid.isNotEmpty) await sendCommand('wlan ssid "$ssid"');
    if (password.length >= 8) {
      await sendCommand('wlan wpapsk "$password"');
      await sendCommand('wlan encrypt 6');
    }
    await sendCommand('wlan wscdisabled ${wpsDisabled ? 1 : 0}');
    await sendCommand('wlan hiddenap ${hidden ? 1 : 0}');
    await sendCommand('wlan channel $channel');
    await sendCommand('wlan txpower $txPower');
    await sendCommand('wlan chanwidth $chanWidth');
    await sendCommand('exit');
    await saveConfig();
  }

  // 2. Connected Devices & MAC Filter
  Future<String> getStationsAndAcl() async {
    final st = await sendCommand('show wlan station');
    final arp = await sendCommand('show arp');
    final acl = await sendCommand('show wlan acl');
    return '=== المتصلين (WiFi) ===\n$st\n=== جدول الشبكة (ARP) ===\n$arp\n=== قائمة الحظر/السماح ===\n$acl';
  }

  Future<void> setMacFilterMode(int mode) async {
    // 0: Disable, 1: Permit, 2: Block
    await sendCommand('config');
    await sendCommand('wlan aclmode $mode');
    await sendCommand('wlan restart');
    await sendCommand('exit');
    await saveConfig();
  }

  Future<void> addMacAcl(String mac) async {
    await sendCommand('config');
    await sendCommand('wlan acladdr $mac');
    await sendCommand('wlan restart');
    await sendCommand('exit');
    await saveConfig();
  }

  Future<void> deleteMacAcl(String mac) async {
    await sendCommand('config');
    await sendCommand('wlan acl delete $mac');
    await sendCommand('wlan restart');
    await sendCommand('exit');
    await saveConfig();
  }

  // 3. QoS Bandwidth Control
  Future<String> getQosStatus() async {
    return await sendCommand('show tc idx');
  }

  Future<void> setOverallBandwidth({required bool enable, int downKbps = 0, int upKbps = 0}) async {
    await sendCommand('config');
    if (!enable) {
      await sendCommand('qos tcitf 0 0');
    } else {
      await sendCommand('qos tcitf $downKbps $upKbps');
    }
    await sendCommand('exit');
    await saveConfig();
  }

  Future<void> addDeviceBandwidthRule({
    required String startIp,
    required String endIp,
    required int downKbps,
    required int upKbps,
  }) async {
    await sendCommand('config');
    await sendCommand('qos tc $startIp $endIp $downKbps $upKbps');
    await sendCommand('exit');
    await saveConfig();
  }

  Future<void> clearAllBandwidthRules() async {
    await sendCommand('config');
    await sendCommand('no qos tc');
    await sendCommand('exit');
    await saveConfig();
  }

  // 4. URL / Domain Filter
  Future<String> getBlockedDomains() async {
    return await sendCommand('show domainblock');
  }

  Future<void> addBlockedUrl(String domain) async {
    await sendCommand('config');
    await sendCommand('domainblock enable');
    await sendCommand('urlblock enable');
    await sendCommand('domainblock add domainname $domain');
    await sendCommand('urlblock add fqdn $domain');
    await sendCommand('exit');
    await saveConfig();
  }

  Future<void> removeBlockedUrl(String domain) async {
    await sendCommand('config');
    await sendCommand('domainblock delete domainname $domain');
    await sendCommand('urlblock delete fqdn $domain');
    await sendCommand('exit');
    await saveConfig();
  }

  // 5. WAN / PPPoE / Access Point Mode
  Future<String> getWanStatus() async {
    final wan = await sendCommand('show wan interface pppoe1');
    final phy = await sendCommand('cfgmib get WAN_PHY_TYPE');
    return '$phy\n$wan';
  }

  Future<void> configurePppoe({
    required String user,
    required String pass,
    required int mtu,
  }) async {
    await sendCommand('cfgmib set WAN_PHY_TYPE 0');
    await sendCommand('config');
    await sendCommand('wan interface modify pppoe1 pppsettings username $user password $pass connecttype continuous defaultgw on enable');
    await sendCommand('interface pppoe1 ppp mtu $mtu');
    await sendCommand('interface pppoe1 ppp mru $mtu');
    await sendCommand('exit');
    await saveConfig();
  }

  Future<void> configureAccessPointMode({
    required String staticIp,
    required String gateway,
  }) async {
    await sendCommand('cfgmib set WAN_PHY_TYPE 1');
    await sendCommand('config');
    await sendCommand('wan interface delete pppoe1');
    await sendCommand('wan interface delete a0');
    await sendCommand('wan interface add mer napt on static ip $staticIp mask 255.255.255.0 nexthop $gateway defaultgw on');
    await sendCommand('exit');
    await saveConfig();
  }

  // 6. LAN & DNS
  Future<String> getLanDnsInfo() async {
    final lan = await sendCommand('show lan');
    final dhcp = await sendCommand('show dhcp');
    final dns = await sendCommand('show dns server');
    return '$lan\n$dhcp\n$dns';
  }

  Future<void> setDnsServers(String dns1, String dns2) async {
    await sendCommand('config');
    await sendCommand('dhcp server dns $dns1 $dns2');
    await sendCommand('dns server $dns1 $dns2');
    await sendCommand('ip name-server clearcache');
    await sendCommand('exit');
    await saveConfig();
  }

  Future<void> setLanDhcp({
    required String routerIp,
    required String mask,
    required String poolStart,
    required String poolEnd,
  }) async {
    await sendCommand('config');
    await sendCommand('lan ip $routerIp mask $mask');
    await sendCommand('dhcp server poolstart $poolStart poolend $poolEnd');
    await sendCommand('exit');
    await saveConfig();
  }

  // 7. DSL Diagnostics & System Management
  Future<String> getDslDetails() async {
    return await sendCommand('show adsl');
  }

  Future<void> changeRouterPassword(String newPass) async {
    await sendCommand('config');
    await sendCommand('password $newPass');
    await sendCommand('exit');
    await saveConfig();
  }

  Future<void> changeWanMac(String mac) async {
    await sendCommand('flash set ELAN_MAC_ADDR $mac');
    await saveConfig();
  }

  Future<void> reboot() async {
    await sendCommand('reboot');
    disconnect();
  }

  Future<void> factoryReset() async {
    await sendCommand('reset');
    disconnect();
  }

  void disconnect() {
    isConnected = false;
    _shell?.close();
    _client?.close();
    _shell = null;
    _client = null;
  }
}
