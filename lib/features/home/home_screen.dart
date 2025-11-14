import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_credentials.dart';
import '../../core/models/device_summary.dart';
import '../../core/routes/app_routes.dart';
import '../devices/devices_page.dart';
import '../history/history_page.dart';
import '../modify/modify_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _userEmail;
  final String _devicesTable = SupabaseCredentials.devicesTable;

  final List<String> _titles = [
    'Dashboard',
    'Modify',
    'History',
    'Devices',
  ];

  final List<String> _icons = [
    'assets/icons/dashboard.png',
    'assets/icons/edit.png',
    'assets/icons/history.png',
    'assets/icons/devices.png',
  ];

  bool _isLoadingDevices = false;
  List<DeviceSummary> _availableDevices = const [];
  DeviceSummary? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _userEmail = Supabase.instance.client.auth.currentUser?.email;
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final client = Supabase.instance.client;
    final String? userId = client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    setState(() {
      _isLoadingDevices = true;
    });

    try {
      final List<dynamic> response = await client
          .from(_devicesTable)
          .select('id, device_id, device_name')
          .eq('user_id', userId)
          .order('device_name', ascending: true);

      final List<DeviceSummary> parsed = response
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => DeviceSummary(
              rowId: row['id']?.toString() ?? '',
              deviceId: row['device_id']?.toString() ?? '',
              name: row['device_name'] as String? ?? 'Sin nombre',
            ),
          )
          .toList();

      DeviceSummary? newSelected = _selectedDevice;
      if (parsed.isNotEmpty) {
        if (_selectedDevice == null) {
          newSelected = parsed.first;
        } else if (parsed.length == 1) {
          newSelected = parsed.first;
        } else {
          newSelected = parsed.firstWhere(
            (device) => device.rowId == _selectedDevice?.rowId,
            orElse: () => parsed.first,
          );
        }
      } else {
        newSelected = null;
      }

      if (!mounted) return;
      setState(() {
        _availableDevices = parsed;
        _selectedDevice = newSelected;
        _isLoadingDevices = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDevices = false;
      });
      _showSnackBar('No pudimos cargar tus dispositivos: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDevices = false;
      });
      _showSnackBar('Error inesperado al cargar dispositivos: $error');
    }
  }

  Future<void> _onLogout() async {
    if (!mounted) return;

    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthException catch (error) {
      _showSnackBar(error.message, color: Colors.redAccent);
      return;
    } catch (error) {
      _showSnackBar('Error inesperado: $error', color: Colors.redAccent);
      return;
    }

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Widget _buildDashboardPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildDeviceSelectorCard(),
            const SizedBox(height: 24),
            const Text(
              'Dashboard Principal',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Bienvenido${_userEmail != null ? ' ${_userEmail!}' : ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedDevice != null
                  ? 'Mostrando datos de "${_selectedDevice!.name}".'
                  : 'Selecciona un dispositivo para ver su información.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _onLogout,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelectorCard() {
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: _isLoadingDevices ? null : _showDevicePicker,
        title: const Text(
          'Dispositivo seleccionado',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _isLoadingDevices
            ? const Padding(
                padding: EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Text(
                _selectedDevice?.name ?? 'Ninguno seleccionado',
                style: subtitleStyle,
              ),
        trailing: const Icon(Icons.expand_more),
      ),
    );
  }

  Future<void> _showDevicePicker() async {
    if (_availableDevices.isEmpty) {
      await _loadDevices();
    }

    if (!mounted) return;

    if (_availableDevices.isEmpty) {
      _showSnackBar(
        'No encontramos dispositivos disponibles. Agrega uno desde la pestaña Devices.',
      );
      return;
    }

    final DeviceSummary? selected = await showModalBottomSheet<DeviceSummary>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selecciona un dispositivo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _availableDevices.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final device = _availableDevices[index];
                      final bool isSelected =
                          device.rowId == _selectedDevice?.rowId;
                      return ListTile(
                        leading: const Icon(Icons.developer_board),
                        title: Text(device.name),
                        subtitle: Text(
                          device.deviceId.isEmpty
                              ? 'ID no disponible'
                              : 'ID: ${device.deviceId}',
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => Navigator.of(context).pop(device),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      setState(() {
                        _currentIndex = 3;
                      });
                    },
                    icon: const Icon(Icons.devices_other_outlined),
                    label: const Text('Gestionar dispositivos'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedDevice = selected;
      });
      _showSnackBar(
        'Dispositivo "${selected.name}" seleccionado.',
        color: Colors.green,
      );
    }
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardPage();
      case 1:
        return ModifyPage(selectedDevice: _selectedDevice);
      case 2:
        return HistoryPage(selectedDevice: _selectedDevice);
      case 3:
        return const DevicesPage();
      default:
        return _buildDashboardPage();
    }
  }

  void _showSnackBar(String message, {Color color = Colors.blueGrey}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            _loadDevices();
          }
        },
        items: List.generate(_titles.length, (index) {
          return BottomNavigationBarItem(
            icon: Image.asset(
              _icons[index],
              width: 24,
              height: 24,
              color: _currentIndex == index ? Colors.blueAccent : Colors.grey,
            ),
            label: _titles[index],
          );
        }),
      ),
    );
  }
}
