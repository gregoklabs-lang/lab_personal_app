import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:location/location.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  BleService._();
  static final BleService I = BleService._();

  final Logger _log = Logger();

  BluetoothDevice? _connected;
  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothCharacteristic? _provisioningChar;
  StreamSubscription<List<int>>? _notifySub;
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  String? _lastStatusMessage;

  static const String _serviceUuid = '12345678-1234-1234-1234-1234567890ab';
  static const String _characteristicUuid =
      '87654321-4321-4321-4321-0987654321ba';

  // Exponer el device conectado (solo lectura)
  BluetoothDevice? get connectedDevice => _connected;
  Stream<String> get statusStream => _statusController.stream;
  String? get lastStatusMessage => _lastStatusMessage;

  void _emitStatus(List<int> data) {
    if (_statusController.isClosed) return;
    if (data.isEmpty) return;
    final message = utf8.decode(data, allowMalformed: true).trim();
    if (message.isEmpty) return;
    _lastStatusMessage = message;
    _statusController.add(message);
    _log.i('Estado OLEO: $message');
  }

  bool _uuidEquals(Guid uuid, String target) =>
      uuid.str.toLowerCase() == target;

  Future<String?> _prepareProvisioningCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();
    BluetoothCharacteristic? targetCharacteristic;

    for (final service in services) {
      if (!_uuidEquals(service.uuid, _serviceUuid)) continue;
      for (final characteristic in service.characteristics) {
        if (_uuidEquals(characteristic.uuid, _characteristicUuid)) {
          targetCharacteristic = characteristic;
          break;
        }
      }
      if (targetCharacteristic != null) break;
    }

    if (targetCharacteristic == null) {
      throw Exception(
        'El dispositivo OLEO no expone la característica de provisión esperada.',
      );
    }

    _provisioningChar = targetCharacteristic;
    await targetCharacteristic.setNotifyValue(true);

    await _notifySub?.cancel();
    _notifySub = targetCharacteristic.lastValueStream.listen(_emitStatus);

    _lastStatusMessage = null;
    try {
      final initialValue = await targetCharacteristic.read();
      _emitStatus(initialValue);
    } catch (e) {
      _log.w('No se pudo leer el valor inicial de la característica: $e');
    }

    return _lastStatusMessage;
  }

  Future<String?> ensureConnectedAndReady(
    ScanResult result, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_connected != null &&
        _connected!.remoteId == result.device.remoteId &&
        _provisioningChar != null) {
      return _lastStatusMessage;
    }

    final device = await connect(result, timeout: timeout);
    return _prepareProvisioningCharacteristic(device);
  }

  Future<void> _clearProvisioningCache() async {
    await _notifySub?.cancel();
    _notifySub = null;
    _provisioningChar = null;
    _lastStatusMessage = null;
  }

  BluetoothCharacteristic _requireProvisioningCharacteristic() {
    final characteristic = _provisioningChar;
    if (characteristic == null) {
      throw Exception(
        'No se encontró la característica de provisión en el dispositivo BLE.',
      );
    }
    return characteristic;
  }

  Future<void> _reconnectAndPrepare(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _log.w(
      'Reconectando con ${device.remoteId.str} para recuperar la característica de provisión...',
    );

    await _clearProvisioningCache();

    try {
      await device.disconnect();
    } catch (e) {
      _log.d('Ignorando error al forzar desconexión previa: $e');
    }

    try {
      await _waitForConnectionState(
        device,
        BluetoothConnectionState.disconnected,
        timeout: const Duration(seconds: 5),
      );
    } catch (_) {}

    try {
      await device.connect(timeout: timeout, autoConnect: false);

      await _waitForConnectionState(
        device,
        BluetoothConnectionState.connected,
        timeout: timeout,
      );
    } on TimeoutException catch (_) {
      throw Exception(
        'Timeout esperando reconexión con el dispositivo BLE ${device.remoteId.str}.',
      );
    } on FlutterBluePlusException catch (e) {
      throw Exception(
        'Error al reconectar con el dispositivo BLE ${device.remoteId.str}: ${e.toString()}',
      );
    }

    try {
      await device.requestMtu(247);
    } catch (_) {}

    await _prepareProvisioningCharacteristic(device);
    if (_provisioningChar == null) {
      throw Exception(
        'No se pudo preparar la característica de provisión tras reconectar.',
      );
    }
  }

  Future<void> sendWifiCredentials({
    required String ssid,
    required String password,
    String? userId,
  }) async {
    final device = _connected;
    if (device == null) {
      throw Exception('No hay un dispositivo BLE listo para provisionar.');
    }

    if (_provisioningChar == null) {
      await _prepareProvisioningCharacteristic(device);
    }

    BluetoothCharacteristic characteristic =
        _requireProvisioningCharacteristic();

    // Verificar estado de conexión y reintentar si se perdió.
    final currentState = await device.connectionState.first;
    if (currentState != BluetoothConnectionState.connected) {
      try {
        await _reconnectAndPrepare(device);
        characteristic = _requireProvisioningCharacteristic();
      } on TimeoutException catch (_) {
        throw Exception(
          'No se pudo reconectar con el dispositivo BLE (timeout).',
        );
      } catch (e) {
        throw Exception('Fallo al reconectar con el dispositivo BLE: $e');
      }
    }

    final supportsWrite =
        characteristic.properties.write ||
        characteristic.properties.writeWithoutResponse;
    if (!supportsWrite) {
      throw Exception(
        'La característica de provisión no permite escrituras desde la app.',
      );
    }

    String normalize(String value) => value.replaceAll('\n', '').trim();

    final normalizedSsid = normalize(ssid);
    final normalizedPass = normalize(password);
    final normalizedUserId = userId == null ? '' : normalize(userId);
    final hasUserId = normalizedUserId.isNotEmpty;

    // El firmware actualizado acepta "SSID\nPASS". Mantener un payload alternativo con
    // el antiguo separador "|" nos permite retrocompatibilidad si el usuario no ha
    // actualizado el firmware (o si el dispositivo todavía anuncia el modo antiguo).
    final payloads = <({String label, List<int> bytes})>[
      (
        label: 'newline',
        bytes: utf8.encode(
          hasUserId
              ? '$normalizedSsid\n$normalizedPass\n$normalizedUserId'
              : '$normalizedSsid\n$normalizedPass',
        ),
      ),
      (
        label: 'legacy',
        bytes: utf8.encode(
          hasUserId
              ? '$normalizedSsid|$normalizedPass|$normalizedUserId'
              : '$normalizedSsid|$normalizedPass',
        ),
      ),
    ];

    FlutterBluePlusException? lastGattError;

    for (final payload in payloads) {
      for (var attempt = 0; attempt < 2; attempt++) {
        characteristic = _requireProvisioningCharacteristic();

        final useWithoutResponse =
            !characteristic.properties.write &&
            characteristic.properties.writeWithoutResponse;

        try {
          await characteristic.write(
            payload.bytes,
            withoutResponse: useWithoutResponse,
          );
          _log.i(
            'Credenciales Wi-Fi enviadas al OLEO (formato ${payload.label}, intento ${attempt + 1}).',
          );
          return;
        } on FlutterBluePlusException catch (e) {
          lastGattError = e;
          final errorText = e.toString().toUpperCase();
          final isGatt133 =
              errorText.contains('ANDROID-CODE: 133') ||
              errorText.contains('GATT_ERROR');

          if (!isGatt133) {
            _log.e('Error al enviar credenciales al OLEO', error: e);
            throw Exception(
              'El dispositivo BLE rechazó las credenciales (${e.toString()}).',
            );
          }

          if (attempt == 0) {
            _log.w(
              'Fallo GATT 133 al enviar credenciales (formato ${payload.label}). Reintentando tras reconectar...',
            );
            try {
              await _reconnectAndPrepare(device);
              continue;
            } catch (reconnectError) {
              throw Exception(
                'No se pudo recuperar la conexión BLE tras un error GATT: $reconnectError',
              );
            }
          }

          // En la segunda caída GATT 133 cambiamos de formato para intentar la ruta legada.
          _log.w(
            'Persisten los errores GATT 133 al enviar credenciales (formato ${payload.label}). Intentando con un formato alternativo...',
          );
          break;
        }
      }
    }

    if (lastGattError != null) {
      throw Exception(
        'El dispositivo BLE rechazó las credenciales tras varios intentos (${lastGattError.toString()}).',
      );
    }

    throw Exception(
      'No se pudieron enviar las credenciales al dispositivo BLE.',
    );
  }

  /// Pide permisos necesarios. Devuelve true si todo OK.
  Future<bool> ensurePermissions() async {
    // Android 12+: bluetoothScan & bluetoothConnect. Además ubicación para escanear.
    final result = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // Log de apoyo
    result.forEach((perm, status) {
      _log.d('perm ${perm.toString()}: ${status.toString()}');
    });

    // Si alguno está permanentemente denegado, ofrecemos ir a ajustes desde UI (página)
    if (result.values.any((s) => s.isPermanentlyDenied)) {
      return false;
    }

    // Con que alguno esté denegado, no podemos continuar
    if (result.values.any((s) => s.isDenied || s.isRestricted)) {
      return false;
    }

    return true;
  }

  /// Asegura que el servicio de ubicación del sistema está activo (requerido por Android para escanear BLE).
  Future<bool> ensureLocationServiceOn() async {
    final loc = Location();
    bool enabled = await loc.serviceEnabled();
    if (!enabled) {
      enabled = await loc.requestService();
    }
    return enabled;
  }

  /// Verifica que el adaptador BT esté ON.
  Future<bool> ensureAdapterOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// Escanea dispositivos cuyo nombre (o advName) contenga "OLEO".
  /// Devuelve la lista (únicos por remoteId) ordenada por RSSI desc.
  Future<List<ScanResult>> scanOleo({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final isOn = await ensureAdapterOn();
    if (!isOn) {
      throw Exception('Bluetooth está apagado');
    }

    // Sanear cualquier escaneo previo
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    final Map<String, ScanResult> byId = {};
    final completer = Completer<List<ScanResult>>();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      bool changed = false;
      for (final r in results) {
        final id = r.device.remoteId.str;
        // Nombre preferido (platformName) y fallback a advName si llega vacío
        final name =
            (r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : r.advertisementData.advName)
                .trim();
        final upperName = name.toUpperCase();

        if (upperName.contains('OLEO') || upperName.contains('ESP32')) {
          if (!byId.containsKey(id) || r.rssi > (byId[id]?.rssi ?? -999)) {
            byId[id] = r;
            changed = true;
          }
        }
      }

      if (changed) {
        // no actualizamos UI aquí; solo acumulamos
      }
    });

    // Arrancar escaneo
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
    );

    // Esperar al timeout (startScan corta solo, pero esperamos a que el stream termine)
    await Future.delayed(timeout);
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;

    // Preparar salida
    final out = byId.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

    if (!completer.isCompleted) {
      completer.complete(out);
    }
    return completer.future;
  }

  /// Conexión directa al dispositivo de un ScanResult.
  /// No usa autoConnect para que la conexión sea inmediata.
  Future<BluetoothDevice> connect(
    ScanResult r, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Desconectar el anterior si existe
    if (_connected != null) {
      try {
        await _connected!.disconnect();
      } catch (_) {}
      _connected = null;
    }

    await _clearProvisioningCache();

    final device = r.device;

    // Conexión
    await device.connect(timeout: timeout, autoConnect: false);

    // Confirmar estado conectado
    try {
      await _waitForConnectionState(
        device,
        BluetoothConnectionState.connected,
        timeout: timeout,
      );
    } on TimeoutException catch (_) {
      throw Exception(
        'No se pudo conectar (timeout esperando estado conectado)',
      );
    }

    // Opcional: establecer MTU más alto (Android). Ignorado en iOS.
    try {
      await device.requestMtu(247);
    } catch (_) {}

    _connected = device;
    _log.i('Conectado a ${device.remoteId.str} (${device.platformName})');
    return device;
  }

  /// Desconectar si hay uno conectado
  Future<void> disconnect() async {
    await _clearProvisioningCache();
  }

  /// Descubre todos los servicios y características del dispositivo conectado.
  Future<List<BluetoothService>> discoverAllServices() async {
    final d = _connected;
    if (d == null) throw Exception('No hay dispositivo conectado');
    final services = await d.discoverServices();
    _log.d('Descubiertos ${services.length} servicios');
    return services;
  }

  /// Nombre "bonito" por si lo quieres usar en UI.
  String displayName(ScanResult r) {
    final p = r.device.platformName;
    final a = r.advertisementData.advName;
    return (p.isNotEmpty ? p : a).isEmpty
        ? 'Desconocido'
        : (p.isNotEmpty ? p : a);
    // Ej.: "OLEO Sensor"
  }

  /// Resetea estado (por si sales de la pantalla y quieres limpiar)
  Future<void> clear() async {
    await _scanSub?.cancel();
    _scanSub = null;
    // no desconectamos aquí intencionalmente
  }

  Future<BluetoothConnectionState> _waitForConnectionState(
    BluetoothDevice device,
    BluetoothConnectionState desired, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return device.connectionState
        .where((state) => state == desired)
        .first
        .timeout(timeout);
  }
}
