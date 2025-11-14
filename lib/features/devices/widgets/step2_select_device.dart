import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Step2SelectDevice extends StatelessWidget {
  final List<ScanResult> scanResults;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step2SelectDevice({
    super.key,
    required this.scanResults,
    required this.selectedIndex,
    required this.onSelect,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona tu dispositivo OLEO detectado:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (scanResults.isEmpty)
          const Text(
            'No se encontraron dispositivos OLEO. Inicia una nueva búsqueda desde el paso anterior.',
          )
        else
          ...scanResults.asMap().entries.map((entry) {
            final index = entry.key;
            final r = entry.value;
            final name = r.device.platformName.isEmpty ? 'Desconocido' : r.device.platformName;
            return ListTile(
              title: Text(name),
              subtitle: Text(r.device.remoteId.str),
              trailing: Icon(
                selectedIndex == index ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selectedIndex == index ? Colors.blueAccent : Colors.grey,
              ),
              onTap: () => onSelect(index),
            );
          }),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: scanResults.isEmpty || selectedIndex == null ? null : onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Buscar Wi-Fi', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent, width: 1.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Atrás'),
        ),
      ],
    );
  }
}
