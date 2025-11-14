import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_credentials.dart';
import '../../../core/models/device_summary.dart';

class DeviceSetpoint {
  const DeviceSetpoint({
    required this.units,
    this.id,
    this.phTarget,
    this.ecTarget,
    this.reservoirSize,
    this.flowTargetLMin,
    this.tempTarget,
    this.dosingMode,
    this.active,
    this.updatedAt,
  });

  final String units;
  final String? id;
  final double? phTarget;
  final double? ecTarget;
  final double? reservoirSize;
  final double? flowTargetLMin;
  final double? tempTarget;
  final String? dosingMode;
  final bool? active;
  final DateTime? updatedAt;
}

class SetpointRepository {
  SetpointRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static final String _userSettingsTable = SupabaseCredentials.userSettingsTable;
  static final String _setpointsTable = SupabaseCredentials.setpointsTable;

  Future<DeviceSetpoint?> fetch(DeviceSummary? device) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    if (device == null || device.deviceId.isEmpty) {
      return null;
    }

    final settings = await _client
        .from(_userSettingsTable)
        .select('reservoir_size_units')
        .eq('user_id', user.id)
        .maybeSingle();

    final String units = _normalizeReservoirUnit(
      settings?['reservoir_size_units'] as String?,
    );

    final Map<String, dynamic>? row = await _client
        .from(_setpointsTable)
        .select(
          'id, ph_target, ec_target, reservoir_size, flow_target_l_min, temp_target, dosing_mode, active, updated_at',
        )
        .eq('user_id', user.id)
        .eq('device_id', device.deviceId)
        .order('updated_at', ascending: false, nullsFirst: false)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return DeviceSetpoint(units: units);
    }

    return DeviceSetpoint(
      units: units,
      id: row['id']?.toString(),
      phTarget: _toDouble(row['ph_target']),
      ecTarget: _toDouble(row['ec_target']),
      reservoirSize: _toDouble(row['reservoir_size']),
      flowTargetLMin: _toDouble(row['flow_target_l_min']),
      tempTarget: _toDouble(row['temp_target']),
      dosingMode: row['dosing_mode'] as String?,
      active: row['active'] as bool?,
      updatedAt: _toDate(row['updated_at']),
    );
  }

  RealtimeChannel subscribe({
    required DeviceSummary device,
    required void Function(DeviceSetpoint? data) onData,
    required void Function(Object error) onError,
  }) {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    final channel = _client.channel(
      'setpoints:${device.deviceId}',
      opts: const RealtimeChannelConfig(ack: true),
    );

    Future<void> loadInitial() async {
      try {
        final data = await fetch(device);
        onData(data);
      } catch (error) {
        onError(error);
      }
    }

    loadInitial();

    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: _setpointsTable,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'device_id',
          value: device.deviceId,
        ),
        callback: (_) async {
          try {
            final data = await fetch(device);
            onData(data);
          } catch (error) {
            onError(error);
          }
        },
      )
      ..subscribe();

    return channel;
  }
}

double? _toDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

DateTime? _toDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

String _normalizeReservoirUnit(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'gal':
    case 'galon':
    case 'galones':
    case 'gallon':
    case 'gallons':
      return 'gal';
    case 'l':
    case 'litro':
    case 'litros':
    default:
      return 'L';
  }
}
