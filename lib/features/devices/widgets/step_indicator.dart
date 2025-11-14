import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    Widget dot(int step) {
      final active = currentStep >= step;
      return CircleAvatar(
        radius: 15,
        backgroundColor: active ? Colors.blueAccent : Colors.grey.shade300,
        child: Text(
          '$step',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    final items = <Widget>[];
    for (int i = 1; i <= totalSteps; i++) {
      items.add(dot(i));
      if (i != totalSteps) {
        items.add(Expanded(
          child: Divider(color: Colors.grey.shade300, thickness: 2),
        ));
      }
    }
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: items);
  }
}
