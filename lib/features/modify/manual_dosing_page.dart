import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/device_summary.dart';
import 'services/setpoint_repository.dart';

class ManualDosingPage extends StatefulWidget {
  const ManualDosingPage({super.key, this.device});

  final DeviceSummary? device;

  @override
  State<ManualDosingPage> createState() => _ManualDosingPageState();
}

class _ManualDosingPageState extends State<ManualDosingPage> {
  final SetpointRepository _repository = SetpointRepository();

  DeviceSetpoint? _setpoint;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ManualDosingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device?.deviceId != widget.device?.deviceId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No encontramos la sesión activa.';
      });
      return;
    }

    if (widget.device == null || widget.device!.deviceId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Selecciona un dispositivo en el Dashboard para ver esta información.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.fetch(widget.device);
      if (!mounted) return;
      setState(() {
        _setpoint = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setpoint = null;
        _errorMessage = 'Error inesperado: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowText = _setpoint?.flowTargetLMin != null
        ? '${_setpoint!.flowTargetLMin!.toStringAsFixed(2)} L/min'
        : '--';
    final mode = _setpoint?.dosingMode ?? 'manual';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Dosing'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device != null
                        ? 'Dispositivo: ${widget.device!.name}'
                        : 'Ningún dispositivo seleccionado',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Haz shots manuales de nutrientes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Modo actual: ${mode.toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text('Flujo objetivo: $flowText'),
                          const SizedBox(height: 12),
                          const Text(
                            'Usa esta sección para inyectar nutrientes cuando lo necesites. '
                            'Próximamente podrás personalizar más parámetros desde aquí.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refrescar'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
