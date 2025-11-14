import 'package:flutter/material.dart';

import '../../core/models/device_summary.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, this.selectedDevice});

  final DeviceSummary? selectedDevice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Historial del dispositivo',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              selectedDevice?.name ??
                  'Selecciona un dispositivo desde el Dashboard',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Aquí aparecerán los registros y eventos del dispositivo seleccionado.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
