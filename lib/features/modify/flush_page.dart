import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/device_summary.dart';
import 'services/setpoint_repository.dart';

class FlushPage extends StatefulWidget {
  const FlushPage({super.key, this.device});

  final DeviceSummary? device;

  @override
  State<FlushPage> createState() => _FlushPageState();
}

class _FlushPageState extends State<FlushPage> {
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
  void didUpdateWidget(covariant FlushPage oldWidget) {
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
    final bool isActive = _setpoint?.active == true;
    final statusText = isActive ? 'Activo' : 'Inactivo';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flush'),
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
                            'Estado de flush',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                isActive
                                    ? Icons.check_circle
                                    : Icons.cancel_outlined,
                                color: isActive
                                    ? Colors.green
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.green
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'El flush limpia el sistema para evitar acumulaciones. '
                            'Pronto podrás iniciar ciclos desde esta pantalla.',
                          ),
                          if (_setpoint?.updatedAt != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Última actualización: ${_formatDate(_setpoint!.updatedAt!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
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

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
