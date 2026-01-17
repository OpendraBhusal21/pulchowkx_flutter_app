import 'package:flutter/material.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomAppBar(),
      body: Center(child: Text('Map Page')),
    );
  }
}
