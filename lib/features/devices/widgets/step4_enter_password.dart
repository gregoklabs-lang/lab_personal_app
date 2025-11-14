import 'package:flutter/material.dart';

class Step4EnterPassword extends StatelessWidget {
  final String? selectedWifi;
  final TextEditingController passController;
  final bool connecting;
  final Future<void> Function(String pass) onConnect;
  final VoidCallback onBack;

  const Step4EnterPassword({
    super.key,
    required this.selectedWifi,
    required this.passController,
    required this.connecting,
    required this.onConnect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Red seleccionada: ${selectedWifi ?? '-'}'),
        const SizedBox(height: 10),
        TextField(
          controller: passController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: connecting
              ? null
              : () async {
                  final pass = passController.text.trim();
                  await onConnect(pass);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            connecting ? 'Conectando...' : 'Conectar',
            style: const TextStyle(color: Colors.white),
          ),
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
