import 'package:flutter/material.dart';

class Step1Search extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onSearch;
  final VoidCallback onBack;

  const Step1Search({
    super.key,
    required this.isScanning,
    required this.onSearch,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Presiona el botón del OLEO por 5 segundos y luego presiona Buscar.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: isScanning ? null : onSearch,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isScanning
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Buscar', style: TextStyle(color: Colors.white)),
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
