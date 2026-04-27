import 'package:flutter/material.dart';
import 'package:tiendaw/core/theme/system_w_theme.dart';
import 'package:tiendaw/features/home/presentation/system_w_shell.dart';

class SystemWApp extends StatelessWidget {
  const SystemWApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema W',
      debugShowCheckedModeBanner: false,
      theme: SystemWTheme.light(),
      home: const SystemWShell(),
    );
  }
}
