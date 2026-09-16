import 'dart:async';
import 'dart:io';
import 'package:agrhi/controllers/model_manager_controller.dart';
import 'package:agrhi/models/model_download_status.dart';
import 'package:agrhi/services/model_download_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDownloads implements ModelDownloadService {
  bool fail = false;
  bool cancel = false;
  int inspections = 0;
  Completer<void>? pending;

  @override
  Future<bool> isModelDownloaded(String crop) async {
    inspections++;
    await pending?.future;
    if (fail) throw const FileSystemException('private path');
    return false;
  }

  @override
  Future<void> downloadModel(
    String crop, {
    required CancelToken cancelToken,
    required void Function(int, int) onProgress,
  }) async {
    if (cancel) {
      cancelToken.cancel('cancelled');
      throw cancelToken.cancelError!;
    }
    if (fail) throw const FileSystemException('private path');
  }

  @override
  Future<double> getTotalSize() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'loading failure clears spinner and allows a successful retry',
    () async {
      final service = FakeDownloads()..fail = true;
      final controller = ModelManagerController(downloadService: service);
      await controller.initialize();
      expect(controller.isLoading, false);
      expect(controller.failure, isNotNull);
      service.fail = false;
      await controller.initialize();
      expect(controller.failure, isNull);
      expect(
        controller.modelStatuses.length,
        ModelDownloadService.modelInfo.length,
      );
      controller.dispose();
    },
  );

  test('concurrent refreshes share one scan', () async {
    final service = FakeDownloads()..pending = Completer<void>();
    final controller = ModelManagerController(downloadService: service);
    final first = controller.initialize();
    final second = controller.initialize();
    expect(identical(first, second), true);
    service.pending!.complete();
    await Future.wait([first, second]);
    expect(service.inspections, ModelDownloadService.modelInfo.length);
    controller.dispose();
  });

  test('cancelled download clears state and can be started again', () async {
    final service = FakeDownloads()..cancel = true;
    final controller = ModelManagerController(downloadService: service);
    await controller.downloadModel('Rice');
    expect(controller.downloadProgress, isEmpty);
    expect(controller.modelStatuses['Rice'], ModelDownloadStatus.notDownloaded);
    service.cancel = false;
    await controller.downloadModel('Rice');
    expect(controller.modelStatuses['Rice'], ModelDownloadStatus.downloaded);
    controller.dispose();
  });

  test(
    'failed user action remains an error and releases its download lock',
    () async {
      final service = FakeDownloads()..fail = true;
      final controller = ModelManagerController(downloadService: service);
      await expectLater(
        controller.downloadModel('Rice'),
        throwsA(isA<FileSystemException>()),
      );
      expect(controller.downloadProgress, isEmpty);
      expect(controller.modelStatuses['Rice'], ModelDownloadStatus.error);
      service.fail = false;
      await controller.downloadModel('Rice');
      expect(controller.modelStatuses['Rice'], ModelDownloadStatus.downloaded);
      controller.dispose();
    },
  );

  test('in-flight loading does not notify after disposal', () async {
    final service = FakeDownloads()..pending = Completer<void>();
    final controller = ModelManagerController(downloadService: service);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final load = controller.initialize();
    controller.dispose();
    final before = notifications;
    service.pending!.complete();
    await load;
    expect(notifications, before);
  });
}
