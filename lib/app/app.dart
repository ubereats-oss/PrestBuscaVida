import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_page.dart';
import '../features/home/home_page.dart';
class PrestServBuscaVidaApp extends StatelessWidget {
  const PrestServBuscaVidaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catálogo de Fornecedores de Serviço do Busca Vida',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == null) {
            return const AuthPage();
          }
          return const HomePage();
        },
      ),
    );
  }
}
