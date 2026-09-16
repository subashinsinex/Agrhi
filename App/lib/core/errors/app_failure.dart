import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Safe copy for users. Never construct these messages from exception text.
class AppFailure implements Exception {
  const AppFailure(this.title, this.message);

  final String title;
  final String message;

  static const startup = AppFailure(
    'Unable to open AGRHI',
    'Your saved data could not be opened. Check available device storage and try again.',
  );
  static const screen = AppFailure(
    'This screen could not be displayed',
    'Reopen the app to continue. Unsaved changes on this screen may be lost.',
  );
  static const unexpected = AppFailure(
    'Something went wrong',
    'We could not complete that action. Please try again.',
  );

  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    final permissionCode = switch (error) {
      CameraException error => error.code,
      PlatformException error => error.code,
      _ => null,
    };
    if (const {
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
      'camera_access_denied',
      'photo_access_denied',
      'AudioAccessDenied',
      'AudioAccessDeniedWithoutPrompt',
    }.contains(permissionCode)) {
      return const AppFailure(
        'Permission needed',
        'Allow the required camera, photo or microphone access in device settings, then try again.',
      );
    }
    if (error is TimeoutException ||
        (error is DioException &&
            const {
              DioExceptionType.connectionTimeout,
              DioExceptionType.receiveTimeout,
              DioExceptionType.sendTimeout,
            }.contains(error.type))) {
      return const AppFailure(
        'Taking longer than expected',
        'The request timed out. Check your connection and try again.',
      );
    }
    if (error is SocketException ||
        (error is DioException &&
            error.type == DioExceptionType.connectionError)) {
      return const AppFailure(
        'Connection unavailable',
        'Check your internet connection and try again.',
      );
    }
    if (error is FileSystemException) {
      return const AppFailure(
        'Unable to access this file',
        'Check available device storage and try again.',
      );
    }
    return unexpected;
  }
}
