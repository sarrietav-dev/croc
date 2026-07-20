import 'package:shared_preferences/shared_preferences.dart';

import '../model/transfer_models.dart';

class SettingsStore {
  static const _addressKey = 'relay_address';
  static const _portsKey = 'relay_ports';
  static const _passwordKey = 'relay_password';

  Future<RelaySettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    const defaults = RelaySettings();
    return RelaySettings(
      address: preferences.getString(_addressKey) ?? defaults.address,
      ports: preferences.getString(_portsKey) ?? defaults.ports,
      password: preferences.getString(_passwordKey) ?? defaults.password,
    );
  }

  Future<void> save(RelaySettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_addressKey, settings.address),
      preferences.setString(_portsKey, settings.ports),
      preferences.setString(_passwordKey, settings.password),
    ]);
  }
}
