import 'package:flutter/material.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/devices/add_device_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/modify/ph_balance_page.dart';
import '../../features/modify/manual_dosing_page.dart';
import '../../features/modify/smart_dosing_page.dart';
import '../../features/modify/flush_page.dart';
import '../../core/models/device_summary.dart';
import '../../features/modify/reservoir_size_page.dart';

class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const addDevice = '/add-device';
  static const login = '/login';
  static const register = '/register';
  static const phBalance = '/modify/ph-balance';
  static const manualDosing = '/modify/manual-dosing';
  static const smartDosing = '/modify/smart-dosing';
  static const flush = '/modify/flush';
  static const reservoirSize = '/modify/reservoir-size';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    home: (context) => const HomeScreen(),
    addDevice: (context) => const AddDevicePage(),
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
    phBalance: (context) {
      final device = _extractDeviceSummary(
        ModalRoute.of(context)?.settings.arguments,
      );
      return PhBalancePage(device: device);
    },
    manualDosing: (context) {
      final device = _extractDeviceSummary(
        ModalRoute.of(context)?.settings.arguments,
      );
      return ManualDosingPage(device: device);
    },
    smartDosing: (context) {
      final device = _extractDeviceSummary(
        ModalRoute.of(context)?.settings.arguments,
      );
      return SmartDosingPage(device: device);
    },
    flush: (context) {
      final device = _extractDeviceSummary(
        ModalRoute.of(context)?.settings.arguments,
      );
      return FlushPage(device: device);
    },
    reservoirSize: (context) {
      final device = _extractDeviceSummary(
        ModalRoute.of(context)?.settings.arguments,
      );
      return ReservoirSizePage(device: device);
    },
  };
}

DeviceSummary? _extractDeviceSummary(Object? args) {
  if (args is DeviceSummary) {
    return args;
  }
  if (args is Map<String, dynamic>) {
    final rowId =
        args['rowId']?.toString() ?? args['deviceRowId']?.toString() ?? '';
    final deviceId = args['deviceId']?.toString() ?? '';
    final name =
        args['name']?.toString() ??
        args['deviceName']?.toString() ??
        'Sin nombre';
    if (rowId.isEmpty && deviceId.isEmpty) {
      return null;
    }
    return DeviceSummary(rowId: rowId, deviceId: deviceId, name: name);
  }
  return null;
}
