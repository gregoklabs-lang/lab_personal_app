import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../../core/services/auth_session.dart';

import 'services/ble_service.dart'; // 👈 NUEVO: usamos el servicio BLE

class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key});

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  int _currentStep = 1;
  final List<ScanResult> _scanResults = [];
  int? _selectedIndex;
  bool _isScanning = false;

  List<String> _wifiList = [];
  String? _selectedWifi;
  bool _wifiLoading = false;
  final TextEditingController _passController = TextEditingController();
  bool _connecting = false;
  bool _waitingProvisioning = false;

  String? _bleStatus;
  StreamSubscription<String>? _bleStatusSub;

  final Logger _logger = Logger();

  @override
  void dispose() {
    _bleStatusSub?.cancel();
    unawaited(BleService.I.disconnect());
    _passController.dispose();
    super.dispose();
  }

  // === Escaneo BLE usando el servicio ===
  Future<void> _scanAll() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _selectedIndex = null;
      _bleStatus = null;
      _wifiList = [];
      _selectedWifi = null;
    });

    try {
      // 1) Permisos
      final permsOk = await BleService.I.ensurePermissions();
      if (!mounted) return;
      if (!permsOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Otorga permisos de Bluetooth y Ubicación.'),
          ),
        );
        setState(() => _isScanning = false);
        return;
      }

      // 2) Ubicación del sistema (Android la exige para escanear BLE)
      final locOn = await BleService.I.ensureLocationServiceOn();
      if (!mounted) return;
      if (!locOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa la ubicación del sistema para escanear.'),
          ),
        );
        setState(() => _isScanning = false);
        return;
      }

      // 3) Escanear
      final results = await BleService.I.scanOleo(
        timeout: const Duration(seconds: 6),
      );
      if (!mounted) return;

      setState(() {
        _scanResults
          ..clear()
          ..addAll(results);
      });

      if (_scanResults.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se detectaron dispositivos OLEO cercanos.'),
          ),
        );
      } else {
        _nextStep();
      }
    } catch (e, st) {
      _logger.e('Error durante escaneo', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error durante escaneo: $e')));
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _nextStep() => setState(() => _currentStep++);

  void _previousStep() {
    if (_currentStep == 1) {
      Navigator.pop(context);
      return;
    }

    final nextStep = _currentStep - 1;

    setState(() {
      _currentStep = nextStep;

      if (nextStep <= 2) {
        _scanResults.clear();
        _selectedIndex = null;
        _isScanning = false;
      }

      if (nextStep <= 3) {
        _wifiList = [];
        _selectedWifi = null;
        _wifiLoading = false;
      }

      _bleStatus = null;
      _waitingProvisioning = false;
      _connecting = false;
      _bleStatusSub?.cancel();
      _bleStatusSub = null;
      _passController.clear();
    });

    if (nextStep <= 2) {
      unawaited(BleService.I.disconnect());
    }
  }

  Future<bool> _ensureWifiScanPermissions() async {
    if (!Platform.isAndroid) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El escaneo de Wi-Fi solo está disponible en Android.'),
        ),
      );
      return false;
    }

    final statuses = await [
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();

    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Otorga permisos de ubicación y Wi-Fi desde la configuración.',
          ),
        ),
      );
      unawaited(openAppSettings());
      return false;
    }

    if (statuses.values.any((s) => !s.isGranted)) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requieren permisos de ubicación y Wi-Fi.'),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _fetchWifiNetworks() async {
    if (_wifiLoading) return;
    if (_selectedIndex == null) return;

    setState(() {
      _wifiLoading = true;
      _wifiList = [];
      _selectedWifi = null;
      _bleStatus = null;
      _waitingProvisioning = false;
    });

    try {
      final selected = _scanResults[_selectedIndex!];
      final initialStatus = await BleService.I.ensureConnectedAndReady(
        selected,
      );
      _startBleStatusListener();
      if (!mounted) return;
      setState(() {
        _bleStatus = initialStatus;
      });

      final permsOk = await _ensureWifiScanPermissions();
      if (!permsOk) return;

      final locOn = await BleService.I.ensureLocationServiceOn();
      if (!locOn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Activa la ubicación del sistema para escanear Wi-Fi.',
            ),
          ),
        );
        return;
      }

      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        if (!mounted) return;
        final message =
            'No es posible iniciar el escaneo de Wi-Fi (estado: ${canScan.name}).';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final started = await WiFiScan.instance.startScan();
      if (!started) {
        throw Exception('No se pudo iniciar el escaneo de redes Wi-Fi.');
      }

      await Future.delayed(const Duration(seconds: 2));

      final canGet = await WiFiScan.instance.canGetScannedResults();
      if (canGet != CanGetScannedResults.yes) {
        if (!mounted) return;
        final message =
            'No es posible obtener las redes Wi-Fi escaneadas (estado: ${canGet.name}).';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final results = await WiFiScan.instance.getScannedResults();
      final filtered = results.where((ap) {
        final ssid = ap.ssid.trim();
        if (ssid.isEmpty) return false;
        final freq = ap.frequency;
        return freq >= 2400 && freq < 2500;
      }).toList()..sort((a, b) => b.level.compareTo(a.level));

      final seen = <String>{};
      final ssids = <String>[];
      for (final ap in filtered) {
        if (seen.add(ap.ssid)) {
          ssids.add(ap.ssid);
        }
      }

      if (!mounted) return;
      setState(() {
        _wifiList = ssids;
      });

      if (ssids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se detectaron redes Wi-Fi 2.4 GHz cercanas.'),
          ),
        );
      } else {
        _nextStep();
      }
    } catch (e, st) {
      _logger.e('Error preparando provisión Wi-Fi', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al preparar la conexión: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _wifiLoading = false);
      }
    }
  }

  void _startBleStatusListener() {
    _bleStatusSub?.cancel();
    _bleStatusSub = BleService.I.statusStream.listen((message) {
      if (!mounted) return;

      final lower = message.toLowerCase();
      bool success = false;
      bool error = false;
      bool finished = false;

      if (_waitingProvisioning) {
        if (lower.contains('conectado')) {
          success = true;
        } else if (lower.contains('error') || lower.contains('perdido')) {
          error = true;
        } else if (lower.contains('finalizado')) {
          finished = true;
        }
      }

      setState(() {
        _bleStatus = message;
        if (success || error || finished) {
          _waitingProvisioning = false;
        }
      });

      String snackBarMessage = message;
      if (finished && lower.contains('finalizado')) {
        snackBarMessage =
            '$message. Mantén presionado el botón 5 segundos para reactivar el modo BLE.';
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispositivo conectado a Wi-Fi.')),
        );
        unawaited(BleService.I.disconnect());
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else if (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(snackBarMessage)));
      } else if (finished) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(snackBarMessage)));
      }
    });
  }

  Widget _stepIndicator() {
    Widget dot(int step) {
      final active = _currentStep >= step;
      return CircleAvatar(
        radius: 15,
        backgroundColor: active ? Colors.blueAccent : Colors.grey.shade300,
        child: Text('$step', style: const TextStyle(color: Colors.white)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        dot(1),
        Expanded(child: Divider(color: Colors.grey.shade300)),
        dot(2),
        Expanded(child: Divider(color: Colors.grey.shade300)),
        dot(3),
        Expanded(child: Divider(color: Colors.grey.shade300)),
        dot(4),
      ],
    );
  }

  ButtonStyle _redOutline() => OutlinedButton.styleFrom(
    foregroundColor: Colors.redAccent,
    side: const BorderSide(color: Colors.redAccent, width: 1.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _backButton() => OutlinedButton(
    onPressed: _previousStep,
    style: _redOutline(),
    child: const Text('Atrás'),
  );

  // === UI Steps (idénticos a tu versión) ===
  Widget _step1() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Presiona el botón del OLEO por 5 segundos y luego presiona Buscar.',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _isScanning ? null : _scanAll,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isScanning
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Buscar', style: TextStyle(color: Colors.white)),
      ),
      const SizedBox(height: 12),
      _backButton(),
    ],
  );

  Widget _step2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Selecciona tu dispositivo OLEO detectado:',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      if (_scanResults.isEmpty)
        const Text(
          'No se encontraron dispositivos OLEO. Inicia una nueva búsqueda desde el paso anterior.',
        )
      else
        ..._scanResults.asMap().entries.map((entry) {
          final index = entry.key;
          final r = entry.value;
          final name = r.device.platformName.isEmpty
              ? 'Desconocido'
              : r.device.platformName;
          return ListTile(
            title: Text(name),
            subtitle: Text(r.device.remoteId.str),
            trailing: Icon(
              _selectedIndex == index
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: _selectedIndex == index ? Colors.blueAccent : Colors.grey,
            ),
            onTap: () => setState(() => _selectedIndex = index),
          );
        }),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed:
            _scanResults.isEmpty || _selectedIndex == null || _wifiLoading
            ? null
            : _fetchWifiNetworks,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _wifiLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text('Buscar Wi-Fi', style: TextStyle(color: Colors.white)),
      ),
      const SizedBox(height: 12),
      _backButton(),
    ],
  );

  Widget _step3() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Selecciona la red Wi-Fi del teléfono.',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      ..._wifiList.map((ssid) {
        final selected = _selectedWifi == ssid;
        return ListTile(
          title: Text(ssid),
          trailing: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? Colors.blueAccent : Colors.grey,
          ),
          onTap: () => setState(() => _selectedWifi = ssid),
        );
      }),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _selectedWifi == null ? null : _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Seleccionar Red',
          style: TextStyle(color: Colors.white),
        ),
      ),
      const SizedBox(height: 12),
      _backButton(),
    ],
  );

  Widget _step4() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Red seleccionada: ${_selectedWifi ?? '-'}'),
      const SizedBox(height: 10),
      TextField(
        controller: _passController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'Contraseña',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 20),
      if (_bleStatus != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Text(
            'Estado OLEO: $_bleStatus',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      if (_waitingProvisioning)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(minHeight: 4),
        ),
      ElevatedButton(
        onPressed: _connecting || _waitingProvisioning
            ? null
            : () async {
                final wifi = _selectedWifi;
                final password = _passController.text.trim();
                if (wifi == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Selecciona una red Wi-Fi antes de continuar.',
                      ),
                    ),
                  );
                  return;
                }
                if (password.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa la contrase?a.')),
                  );
                  return;
                }

                AuthSession.I.refreshCurrentUser();
                final userId = AuthSession.I.userId;
                if (userId == null || userId.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se pudo obtener el user_id del usuario autenticado.',
                      ),
                    ),
                  );
                  return;
                }

                FocusScope.of(context).unfocus();
                setState(() {
                  _connecting = true;
                  _waitingProvisioning = true;
                });

                try {
                  await BleService.I.sendWifiCredentials(
                    ssid: wifi,
                    password: password,
                    userId: userId,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Credenciales enviadas. Esperando confirmación del OLEO...',
                      ),
                    ),
                  );
                } catch (e, st) {
                  _logger.e(
                    'Error al enviar credenciales',
                    error: e,
                    stackTrace: st,
                  );
                  if (!mounted) return;
                  setState(() => _waitingProvisioning = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No se pudieron enviar las credenciales: $e',
                      ),
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() => _connecting = false);
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _connecting
            ? const Text('Enviando...', style: TextStyle(color: Colors.white))
            : _waitingProvisioning
            ? const Text('Esperando...', style: TextStyle(color: Colors.white))
            : const Text('Conectar', style: TextStyle(color: Colors.white)),
      ),
      const SizedBox(height: 12),
      _backButton(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final steps = [_step1(), _step2(), _step3(), _step4()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Dispositivo'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _stepIndicator(),
            const SizedBox(height: 20),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: steps[_currentStep - 1],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
