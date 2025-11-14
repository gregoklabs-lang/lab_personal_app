import 'package:flutter/material.dart';

class Step3SelectWifi extends StatelessWidget {
  final List<String> wifiList;
  final String? selectedWifi;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step3SelectWifi({
    super.key,
    required this.wifiList,
    required this.selectedWifi,
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
          'Selecciona la red Wi-Fi del teléfono.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (wifiList.isEmpty)
          const Text('No hay redes disponibles.')
        else
          ...wifiList.map((ssid) {
            final selected = selectedWifi == ssid;
            return ListTile(
              title: Text(ssid),
              trailing: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? Colors.blueAccent : Colors.grey,
              ),
              onTap: () => onSelect(ssid),
            );
          }),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: selectedWifi == null ? null : onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Seleccionar Red', style: TextStyle(color: Colors.white)),
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
