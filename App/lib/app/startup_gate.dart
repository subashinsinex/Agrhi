import 'package:flutter/material.dart';
import 'package:agrhi/core/errors/app_failure.dart';
import 'package:agrhi/core/errors/error_reporter.dart';
import 'package:agrhi/views/shared/app_error_screen.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.initialize,
    required this.builder,
  });
  final Future<String?> Function() initialize;
  final Widget Function(String? payload) builder;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<String?> _startup;
  bool _starting = false;
  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<String?> _initialize() async {
    _starting = true;
    try {
      return await widget.initialize();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'startup');
      throw AppFailure.startup;
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }
      if (snapshot.hasError) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: AppErrorScreen(
            failure: AppFailure.startup,
            onRetry: () {
              if (_starting) return;
              setState(() {
                _startup = _initialize();
              });
            },
          ),
        );
      }
      return widget.builder(snapshot.data);
    },
  );
}
