import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/theme.dart';
import 'ui/screens/main_screen.dart';

void main() {
  runApp(const SenAlgoApp());
}

class SenAlgoApp extends StatelessWidget {
  const SenAlgoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'SenAlgo',
        debugShowCheckedModeBanner: false,
        theme: SenAlgoTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}
