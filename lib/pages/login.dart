import 'package:flutter/material.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Center(child: Text('Login Page')),
    );
  }
}
