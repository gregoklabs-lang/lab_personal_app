import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/device_summary.dart';
import '../../core/routes/app_routes.dart';
import 'services/setpoint_repository.dart';

class ModifyPage extends StatefulWidget {
  const ModifyPage({super.key, this.selectedDevice});

  final DeviceSummary? selectedDevice;

  @override
  State<ModifyPage> createState() => _ModifyPageState();
}

class _ModifyPageState extends State<ModifyPage> {
  final SetpointRepository _repository = SetpointRepository();

  DeviceSetpoint? _setpoint;
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ModifyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDevice?.deviceId != widget.selectedDevice?.deviceId) {
      _subscription?.unsubscribe();
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _setpoint = null;
        _errorMessage = 'No encontramos la sesión activa.';
        _isLoading = false;
      });
      return;
    }

    if (widget.selectedDevice == null ||
        widget.selectedDevice!.deviceId.isEmpty) {
      setState(() {
        _setpoint = null;
        _errorMessage =
            'Selecciona un dispositivo en el Dashboard para ver sus valores.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _subscription?.unsubscribe();
    _subscription = _repository.subscribe(
      device: widget.selectedDevice!,
      onData: (data) {
        if (!mounted) return;
        setState(() {
          _setpoint = data;
          _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _setpoint = null;
          _errorMessage = 'Error inesperado: $error';
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasDevice =
        widget.selectedDevice != null &&
        widget.selectedDevice!.deviceId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modify'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 1,
              child: ListTile(
                leading: const Icon(Icons.memory),
                title: const Text(
                  'Dispositivo activo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  widget.selectedDevice?.name ??
                      'Selecciona un dispositivo desde el Dashboard',
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 1,
                child: Column(children: _buildOptions(theme, hasDevice)),
              ),
            if (_errorMessage != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptions(ThemeData theme, bool hasDevice) {
    final DeviceSetpoint? data = _setpoint;

    final phSubtitle =
        'Target pH: ${_formatNumber(data?.phTarget, decimals: 2)}';
    final manualSubtitle = [
      'Haz shots manuales de nutrientes.',
      if (data?.flowTargetLMin != null)
        'Flujo objetivo: ${_formatNumber(data?.flowTargetLMin, decimals: 2)} L/min',
      if ((data?.dosingMode ?? '').isNotEmpty)
        'Modo actual: ${data!.dosingMode}',
    ].join('\n');
    final reservoirSubtitle = data == null
        ? 'Reservorio sin configurar'
        : 'Reservorio: ${_formatNumber(data.reservoirSize, decimals: 1)} ${data.units}';
    final ecSubtitle =
        'Target EC: ${_formatNumber(data?.ecTarget, decimals: 2)} mS/cm';
    final flushSubtitle =
        'Estado: ${data?.active == true ? 'Activo' : 'Inactivo'}';

    final options = [
      _ModifyOption(
        title: 'pH balance',
        statusLabel: data?.active == true ? '(Active)' : null,
        statusColor: const Color(0xFF2E7D32),
        subtitle: phSubtitle,
        route: AppRoutes.phBalance,
      ),
      _ModifyOption(
        title: 'Manual dosing',
        subtitle: manualSubtitle,
        route: AppRoutes.manualDosing,
      ),
      _ModifyOption(
        title: 'Reservoir size',
        statusLabel: '(Beta)',
        statusColor: const Color(0xFF00838F),
        subtitle: reservoirSubtitle,
        route: AppRoutes.reservoirSize,
      ),
      _ModifyOption(
        title: 'Smart dosing',
        subtitle: ecSubtitle,
        route: AppRoutes.smartDosing,
      ),
      _ModifyOption(
        title: 'Flush',
        subtitle: flushSubtitle,
        route: AppRoutes.flush,
      ),
    ];

    return List.generate(options.length, (index) {
      final option = options[index];
      return Column(
        children: [
          ListTile(
            enabled: hasDevice,
            onTap: hasDevice
                ? () => Navigator.pushNamed(
                    context,
                    option.route,
                    arguments: widget.selectedDevice,
                  )
                : null,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    option.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (option.statusLabel != null)
                  Text(
                    option.statusLabel!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: option.statusColor ?? theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            subtitle: option.subtitle == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      option.subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
            trailing: const Icon(Icons.chevron_right),
          ),
          if (index < options.length - 1)
            const Divider(height: 0, indent: 16, endIndent: 16),
        ],
      );
    });
  }

  String _formatNumber(double? value, {int decimals = 1}) {
    if (value == null) {
      return '--';
    }
    return value.toStringAsFixed(decimals);
  }
}

class _ModifyOption {
  const _ModifyOption({
    required this.title,
    required this.route,
    this.subtitle,
    this.statusLabel,
    this.statusColor,
  });

  final String title;
  final String route;
  final String? subtitle;
  final String? statusLabel;
  final Color? statusColor;
}
