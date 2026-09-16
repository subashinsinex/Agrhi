import 'dart:async';
import 'dart:isolate';
import 'package:agrhi/services/ml/model_service.dart';

/// One interpreter owner, one command at a time, away from Flutter's UI isolate.
class InferenceWorker {
  Isolate? _isolate;
  ReceivePort? _events;
  SendPort? _commands;
  Future<void> _queue = Future.value();
  Completer<dynamic>? _reply;

  Future<dynamic> request(String method, List<dynamic> args) {
    final result = _queue.then((_) => _send(method, args));
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<dynamic> _send(String method, List<dynamic> args) async {
    try {
      if (_commands == null) {
        final ready = Completer<SendPort>();
        _events = ReceivePort();
        _events!.listen((event) {
          if (event is SendPort) {
            if (!ready.isCompleted) ready.complete(event);
          } else if (event is Map) {
            final reply = _reply;
            if (reply != null && !reply.isCompleted) {
              if (event['error'] != null) {
                reply.completeError(StateError(event['error'].toString()));
              } else {
                reply.complete(event['value']);
              }
            }
          } else {
            final error = StateError('Inference worker stopped: $event');
            if (!ready.isCompleted) ready.completeError(error);
            if (_reply != null && !_reply!.isCompleted) {
              _reply!.completeError(error);
            }
            _stop();
          }
        });
        _isolate = await Isolate.spawn(
          inferenceWorkerMain,
          _events!.sendPort,
          onError: _events!.sendPort,
          onExit: _events!.sendPort,
        );
        _commands = await ready.future.timeout(const Duration(seconds: 30));
      }
      _reply = Completer<dynamic>();
      _commands!.send([method, args]);
      return await _reply!.future.timeout(const Duration(seconds: 60));
    } catch (_) {
      _stop();
      rethrow;
    } finally {
      _reply = null;
    }
  }

  void _stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commands = null;
    _events?.close();
    _events = null;
  }

  Future<void> close() async {
    // Queue shutdown behind outstanding inference rather than closing native
    // memory while it is being used.
    final done = _queue.then((_) async {
      if (_commands != null) await _send('close', []);
      _stop();
    });
    _queue = done.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    await done;
  }
}

void inferenceWorkerMain(SendPort host) async {
  final commands = ReceivePort();
  host.send(commands.sendPort);
  await for (final message in commands) {
    final method = message[0] as String;
    final args = message[1] as List;
    try {
      dynamic result;
      switch (method) {
        case 'gate':
          await ModelRuntime.loadGateModel(args[0] as String);
        case 'model':
          await ModelRuntime.loadModel(args[0] as String);
        case 'detect':
          result = await ModelRuntime.runGateInference(args[0] as String);
        case 'infer':
          result = await ModelRuntime.runInference(
            args[0] as String,
            List<String>.from(args[1] as List),
            args[2] as String,
            gateThreshold: args[3] as double,
          );
        case 'close':
          ModelRuntime.close();
        default:
          throw ArgumentError('Unknown inference command');
      }
      host.send({'value': result});
    } catch (error) {
      host.send({'error': error.toString()});
    }
  }
}
