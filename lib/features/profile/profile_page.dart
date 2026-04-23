import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> excluirConta(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await user.delete();

      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => excluirConta(context),
          child: const Text('Excluir conta'),
        ),
      ),
    );
  }
}
