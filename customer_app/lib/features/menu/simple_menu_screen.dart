import 'package:flutter/material.dart';

class SimpleMenuScreen extends StatelessWidget {
  final Map<String, dynamic> vendor;
  const SimpleMenuScreen({super.key, required this.vendor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(vendor['name'] ?? "Menu")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Menu for ${vendor['name']}",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text("If you see this, Navigation Works!"),
          ],
        ),
      ),
    );
  }
}
