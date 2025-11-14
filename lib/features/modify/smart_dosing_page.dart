import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_credentials.dart';
import '../../core/models/device_summary.dart';
import 'services/setpoint_repository.dart';

class SmartDosingPage extends StatefulWidget {
  const SmartDosingPage({super.key, this.device});

  final DeviceSummary? device;

  @override
  State<SmartDosingPage> createState() => _SmartDosingPageState();
}

class _SmartDosingPageState extends State<SmartDosingPage> {
  final SetpointRepository _repository = SetpointRepository();
  final TextEditingController _ecController = TextEditingController();
  final String _setpointsTable = SupabaseCredentials.setpointsTable;

  DeviceSetpoint? _setpoint;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _setpointId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _ecController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SmartDosingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device?.deviceId != widget.device?.deviceId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _setpoint = null;
        _setpointId = null;
        _errorMessage = 'No encontramos la sesion activa.';
        _isLoading = false;
      });
      return;
    }

    if (widget.device == null || widget.device!.deviceId.isEmpty) {
      setState(() {
        _setpoint = null;
        _setpointId = null;
        _errorMessage =
            'Selecciona un dispositivo en el Dashboard para ver esta informacion.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final DeviceSetpoint? data = await _repository.fetch(widget.device);

      if (!mounted) return;
      setState(() {
        _setpoint = data;
        _setpointId = data?.id;
        _ecController.text = data?.ecTarget?.toStringAsFixed(2) ?? '';
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setpoint = null;
        _setpointId = null;
        _errorMessage = 'Error inesperado: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _onSave() async {
    final String valueText = _ecController.text.trim();
    final double? value = double.tryParse(valueText.replaceAll(',', '.'));

    if (value == null || value <= 0) {
      _showSnackBar('Ingresa una EC valida en mS/cm.');
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      _showSnackBar('No encontramos la sesion activa.');
      return;
    }

    if (widget.device == null || widget.device!.deviceId.isEmpty) {
      _showSnackBar('Selecciona un dispositivo valido antes de guardar.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      Map<String, dynamic>? response;

      if (_setpointId != null && _setpointId!.isNotEmpty) {
        response = await client
            .from(_setpointsTable)
            .update({'ec_target': value})
            .eq('id', _setpointId!)
            .select('id')
            .maybeSingle();
      } else {
        response = await client
            .from(_setpointsTable)
            .insert({
              'user_id': user.id,
              'device_id': widget.device!.deviceId,
              'ec_target': value,
            })
            .select('id')
            .maybeSingle();
      }

      if (!mounted) return;
      _setpointId = response?['id']?.toString() ?? _setpointId;
      _showSnackBar(
        'Target EC actualizada a ${value.toStringAsFixed(2)} mS/cm.',
        color: Colors.green,
      );
      await _loadData();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showSnackBar('No pudimos guardar el cambio: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Error inesperado: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message, {Color color = Colors.redAccent}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final String ecValue = _setpoint?.ecTarget != null
        ? '${_setpoint!.ecTarget!.toStringAsFixed(2)} mS/cm'
        : '--';
    final String tempTarget = _setpoint?.tempTarget != null
        ? '${_setpoint!.tempTarget!.toStringAsFixed(1)} \u00B0C'
        : '--';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Dosing'),
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
                        : 'Ningun dispositivo seleccionado',
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
                            'Target EC',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _ecController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Ingresa la EC objetivo',
                              hintText: 'Ej. 1.8',
                              suffixText: 'mS/cm',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Valor actual reportado: $ecValue',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Temperatura objetivo reportada: $tempTarget',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Smart dosing ajusta la concentracion de nutrientes segun esta meta.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refrescar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              _isSaving || _errorMessage != null ? null : _onSave,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
