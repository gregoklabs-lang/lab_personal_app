import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_credentials.dart';
import '../../core/routes/app_routes.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _devicesTable = SupabaseCredentials.devicesTable;
  final List<_DeviceRecord> _devices = [];

  RealtimeChannel? _realtimeChannel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _loadDevices({bool showLoader = true}) async {
    final String? userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _devices.clear();
        _isLoading = false;
      });
      _showSnackBar('No se encontro la sesion de usuario.');
      return;
    }

    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<dynamic> response = await _supabase
          .from(_devicesTable)
          .select('id, device_id, device_name, device_status, last_seen')
          .eq('user_id', userId)
          .order('last_seen', ascending: false, nullsFirst: false);

      final parsed = response
          .whereType<Map<String, dynamic>>()
          .map(_DeviceRecord.fromMap)
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _devices
          ..clear()
          ..addAll(parsed);
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      _handleLoadError(error.message);
    } catch (error) {
      _handleLoadError(error.toString());
    }
  }

  void _handleLoadError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
    });
    _showSnackBar('No pudimos cargar tus dispositivos: $message');
  }

  void _subscribeToRealtime() {
    final String? userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    _realtimeChannel =
        _supabase
            .channel('public:devices_user_$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _devicesTable,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (_) {
                if (!mounted) {
                  return;
                }
                _loadDevices(showLoader: false);
              },
            )
          ..subscribe();
  }

  Future<void> _onRefresh() => _loadDevices();

  Future<void> _onDeviceTap(_DeviceRecord device) async {
    final _DeviceAction? action = await _showDeviceActions(device);

    if (action == null) {
      return;
    }

    switch (action) {
      case _DeviceAction.rename:
        final String? newName = await _promptRename(device);
        if (newName == null || newName == device.name) {
          return;
        }
        await _renameDevice(device, newName);
        break;
      case _DeviceAction.delete:
        final bool confirmed = await _confirmDelete(device);
        if (!confirmed) {
          return;
        }
        await _deleteDevice(device);
        break;
    }
  }

  Future<_DeviceAction?> _showDeviceActions(_DeviceRecord device) {
    return showDialog<_DeviceAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set up del dispositivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Renombrar'),
                onTap: () =>
                    Navigator.of(dialogContext).pop(_DeviceAction.rename),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Eliminar'),
                onTap: () =>
                    Navigator.of(dialogContext).pop(_DeviceAction.delete),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptRename(_DeviceRecord device) {
    final TextEditingController controller = TextEditingController(
      text: device.name,
    );
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateError(String value) {
              final String trimmed = value.trim();
              setState(() {
                errorText = trimmed.isEmpty ? 'Ingresa un nombre.' : null;
              });
            }

            void submit() {
              final String trimmed = controller.text.trim();
              if (trimmed.isEmpty) {
                setState(() {
                  errorText = 'Ingresa un nombre.';
                });
                return;
              }
              Navigator.of(context).pop(trimmed);
            }

            return AlertDialog(
              title: const Text('Renombrar dispositivo'),
              content: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: updateError,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  labelText: 'Nombre del dispositivo',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(onPressed: submit, child: const Text('Guardar')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _renameDevice(_DeviceRecord device, String newName) async {
    final String? userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      _showSnackBar('No se encontro la sesion de usuario.');
      return;
    }

    if (device.rowId.isEmpty) {
      _showSnackBar(
        'No pudimos identificar el dispositivo. Refresca la lista e intenta de nuevo.',
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool shouldRefresh = false;

    try {
      var duplicatesQuery = _supabase
          .from(_devicesTable)
          .select('id')
          .eq('user_id', userId)
          .eq('device_name', newName);

      duplicatesQuery = duplicatesQuery.neq('id', device.rowId);

      final List<dynamic> duplicates = await duplicatesQuery.limit(1);

      if (duplicates.isNotEmpty) {
        _showSnackBar('Ya tienes un dispositivo con ese nombre.');
        return;
      }

      var updateQuery = _supabase
          .from(_devicesTable)
          .update({'device_name': newName})
          .eq('user_id', userId)
          .eq('id', device.rowId);

      await updateQuery;

      shouldRefresh = true;
      _showSnackBar('Nombre actualizado correctamente.');
    } on PostgrestException catch (error) {
      _showSnackBar('No pudimos actualizar el nombre: ${error.message}');
    } catch (error) {
      _showSnackBar('No pudimos actualizar el nombre: $error');
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (shouldRefresh) {
      await _loadDevices(showLoader: false);
    }
  }

  Future<bool> _confirmDelete(_DeviceRecord device) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar dispositivo'),
          content: Text(
            'Estas seguro de eliminar "${device.name}"? Esta accion no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _deleteDevice(_DeviceRecord device) async {
    final String? userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      _showSnackBar('No se encontro la sesion de usuario.');
      return;
    }

    if (device.rowId.isEmpty) {
      _showSnackBar(
        'No pudimos identificar el dispositivo. Refresca la lista e intenta de nuevo.',
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool success = false;

    try {
      final List<dynamic> deletedById = await _supabase
          .from(_devicesTable)
          .delete()
          .eq('id', device.rowId)
          .select('id');

      List<dynamic> deleted = deletedById;

      if (deleted.isEmpty && device.id != 'N/D') {
        deleted = await _supabase
            .from(_devicesTable)
            .delete()
            .eq('user_id', userId)
            .eq('device_id', device.id)
            .select('id');
      }

      if (deleted.isEmpty) {
        _showSnackBar('No encontramos el dispositivo a eliminar.');
      } else {
        success = true;
        _showSnackBar('Dispositivo eliminado.');
      }
    } on PostgrestException catch (error) {
      _showSnackBar('No pudimos eliminar el dispositivo: ${error.message}');
    } catch (error) {
      _showSnackBar('No pudimos eliminar el dispositivo: $error');
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (success) {
      await _loadDevices();
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices'), centerTitle: true),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.addDevice),
        icon: const Icon(Icons.add),
        label: const Text('Anadir dispositivo'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_devices.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            const SizedBox(height: 80),
            Icon(
              Icons.bluetooth_searching,
              size: 72,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No tienes dispositivos registrados aun.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega tu primer dispositivo con el boton "Anadir dispositivo".',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 80),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _DeviceCard(device: device, onTap: () => _onDeviceTap(device));
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _devices.length,
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onTap});

  final _DeviceRecord device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final decoration = _statusDecoration(device.status, colorScheme);

    final BorderRadius borderRadius = BorderRadius.circular(16);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: decoration.color.withValues(alpha: 0.16),
                child: Text(
                  decoration.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${device.id}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ultima conexion: ${device.formattedLastSeen}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text(
                  decoration.label,
                  style: TextStyle(
                    color: decoration.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                side: BorderSide(color: decoration.color),
                backgroundColor: decoration.color.withValues(alpha: 0.12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceRecord {
  const _DeviceRecord({
    required this.rowId,
    required this.name,
    required this.id,
    required this.status,
    required this.lastSeen,
  });

  final String rowId;
  final String name;
  final String id;
  final String status;
  final DateTime? lastSeen;

  static _DeviceRecord fromMap(Map<String, dynamic> map) {
    DateTime? parsedLastSeen;
    final dynamic lastSeenRaw = map['last_seen'];

    if (lastSeenRaw is String && lastSeenRaw.isNotEmpty) {
      parsedLastSeen = DateTime.tryParse(lastSeenRaw)?.toLocal();
    } else if (lastSeenRaw is DateTime) {
      parsedLastSeen = lastSeenRaw.toLocal();
    }

    return _DeviceRecord(
      rowId: map['id']?.toString() ?? '',
      name: map['device_name'] as String? ?? 'Sin nombre',
      id: map['device_id']?.toString() ?? 'N/D',
      status: (map['device_status'] as String? ?? 'unknown').toLowerCase(),
      lastSeen: parsedLastSeen,
    );
  }

  String get formattedLastSeen {
    if (lastSeen == null) {
      return 'Sin registro';
    }

    final DateTime local = lastSeen!;
    final String yyyy = local.year.toString();
    final String mm = local.month.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    final String hh = local.hour.toString().padLeft(2, '0');
    final String min = local.minute.toString().padLeft(2, '0');

    return '$yyyy-$mm-$dd $hh:$min';
  }
}

enum _DeviceAction { rename, delete }

class _StatusDecoration {
  const _StatusDecoration({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final String icon;
  final Color color;
}

_StatusDecoration _statusDecoration(String status, ColorScheme scheme) {
  switch (status) {
    case 'connected':
      return _StatusDecoration(
        label: 'Conectado',
        icon: '\u{1F7E2}',
        color: scheme.primary,
      );
    case 'provisioning':
      return _StatusDecoration(
        label: 'Provisionando',
        icon: '\u{1F7E1}',
        color: Colors.amber.shade700,
      );
    case 'disconnected':
      return _StatusDecoration(
        label: 'Desconectado',
        icon: '\u{1F534}',
        color: scheme.error,
      );
    default:
      return _StatusDecoration(
        label: status,
        icon: '\u{26AA}',
        color: scheme.outline,
      );
  }
}
