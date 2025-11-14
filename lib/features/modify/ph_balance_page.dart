import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_credentials.dart';
import '../../core/models/device_summary.dart';
import 'services/setpoint_repository.dart';

class PhBalancePage extends StatefulWidget {
  const PhBalancePage({super.key, this.device});

  final DeviceSummary? device;

  @override
  State<PhBalancePage> createState() => _PhBalancePageState();
}

class _PhBalancePageState extends State<PhBalancePage> {
  final SetpointRepository _repository = SetpointRepository();
  final TextEditingController _phController = TextEditingController();
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
    _phController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PhBalancePage oldWidget) {
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
            'Selecciona un dispositivo en el Dashboard para ver este valor.';
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
        _phController.text = data?.phTarget?.toStringAsFixed(2) ?? '';
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
    final String valueText = _phController.text.trim();
    final double? value = double.tryParse(valueText.replaceAll(',', '.'));

    if (value == null || value < 0 || value > 14) {
      _showSnackBar('Ingresa un pH valido entre 0 y 14.');
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
            .update({'ph_target': value})
            .eq('id', _setpointId!)
            .select('id')
            .maybeSingle();
      } else {
        response = await client
            .from(_setpointsTable)
            .insert({
              'user_id': user.id,
              'device_id': widget.device!.deviceId,
              'ph_target': value,
            })
            .select('id')
            .maybeSingle();
      }

      if (!mounted) return;
      _setpointId = response?['id']?.toString() ?? _setpointId;
      _showSnackBar(
        'Target pH actualizado a ${value.toStringAsFixed(2)}.',
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
    final String phValue =
        _setpoint?.phTarget != null ? _setpoint!.phTarget!.toStringAsFixed(2) : '--';
    final DateTime? lastUpdated = _setpoint?.updatedAt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('pH Balance'),
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
                            'Target pH',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Ingresa el pH objetivo',
                              hintText: 'Ej. 5.8',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Valor actual reportado: $phValue',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Este objetivo controla el equilibrio acido/base del reservorio.',
                          ),
                          if (lastUpdated != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Ultima actualizacion: ${_formatDate(lastUpdated)}',
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

String _formatDate(DateTime date) {
  final DateTime local = date.toLocal();
  final String yyyy = local.year.toString();
  final String mm = local.month.toString().padLeft(2, '0');
  final String dd = local.day.toString().padLeft(2, '0');
  final String hh = local.hour.toString().padLeft(2, '0');
  final String min = local.minute.toString().padLeft(2, '0');

  return '$yyyy-$mm-$dd $hh:$min';
}
