import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_credentials.dart';
import '../../core/models/device_summary.dart';
import 'services/setpoint_repository.dart';

class ReservoirSizePage extends StatefulWidget {
  const ReservoirSizePage({super.key, this.device});

  final DeviceSummary? device;

  @override
  State<ReservoirSizePage> createState() => _ReservoirSizePageState();
}

class _ReservoirSizePageState extends State<ReservoirSizePage> {
  final TextEditingController _reservoirController = TextEditingController();
  final String _setpointsTable = SupabaseCredentials.setpointsTable;

  String _unit = 'L';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _setpointId;
  String? _errorMessage;
  late final SetpointRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = SetpointRepository();
    _loadInitialData();
  }

  @override
  void dispose() {
    _reservoirController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'No encontramos la sesión activa.';
        _isLoading = false;
      });
      return;
    }

    if (widget.device == null || widget.device!.deviceId.isEmpty) {
      setState(() {
        _errorMessage =
            'Selecciona un dispositivo en el Dashboard antes de ajustar el reservorio.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final DeviceSetpoint? setpoint = await _repository.fetch(widget.device);

      if (!mounted) return;

      setState(() {
        if (setpoint == null) {
          _errorMessage = 'No pudimos recuperar los datos del dispositivo.';
          _unit = 'L';
          _reservoirController.clear();
        } else {
          _unit = setpoint.units;
          _setpointId = setpoint.id;
          _reservoirController.text = setpoint.reservoirSize?.toString() ?? '';
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error inesperado: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _onSave() async {
    final valueText = _reservoirController.text.trim();
    final double? value = double.tryParse(valueText.replaceAll(',', '.'));

    if (value == null || value <= 0) {
      _showSnackBar('Ingresa un valor numérico válido para el reservorio.');
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      _showSnackBar('No encontramos la sesión activa.');
      return;
    }

    if (widget.device == null || widget.device!.deviceId.isEmpty) {
      _showSnackBar('Selecciona un dispositivo válido antes de guardar.');
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
            .update({'reservoir_size': value})
            .eq('id', _setpointId!)
            .select('id')
            .maybeSingle();
      } else {
        response = await client
            .from(_setpointsTable)
            .insert({
              'user_id': user.id,
              'device_id': widget.device!.deviceId,
              'reservoir_size': value,
            })
            .select('id')
            .maybeSingle();
      }

      if (!mounted) return;
      setState(() {
        _setpointId = response?['id']?.toString() ?? _setpointId;
        _isSaving = false;
      });

      _showSnackBar(
        'Reservorio actualizado a ${value.toStringAsFixed(1)} $_unit.',
        color: Colors.green,
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showSnackBar('No pudimos guardar el cambio: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showSnackBar('Error inesperado: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservoir Size'),
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
                  const Text(
                    'Introduce el tamaño actual del reservorio.',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _reservoirController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Reservoir size',
                      hintText: 'Ej. 45',
                      suffixText: _unit,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unidades actuales: $_unit',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving || _errorMessage != null
                          ? null
                          : _onSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showSnackBar(String message, {Color color = Colors.redAccent}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}
