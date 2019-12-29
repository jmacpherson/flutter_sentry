import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

import 'src/breadcrumb_tracker.dart';

export 'src/navigator_observer.dart' show FlutterSentryNavigatorObserver;

/// API entrypoint for Sentry.io Flutter plugin. Start using Sentry.io by
/// calling either [initialize] or [wrap] static methods.
class FlutterSentry {
  FlutterSentry._(SentryClient client) : _sentry = client;

  static const MethodChannel _channel = MethodChannel('flutter_sentry');
  static FlutterSentry _instance;

  final SentryClient _sentry;

  /// Breadcrumbs collected so far for reporting in the next event.
  // This type is inferred: https://github.com/dart-lang/linter/issues/1319.
  // ignore: type_annotate_public_apis
  final breadcrumbs = BreadcrumbTracker();

  /// Cause a crash on the native platform (Android or iOS). Unlike most Dart
  /// [Exception]s, such crashes are usually fatal for application. The use case
  /// here is to cause a fatal crash and test reporting of this edge condition
  /// to Sentry.io.
  ///
  /// NOTE: if native Sentry client has failed to initialize, this method throws
  /// a Dart exception and does nothing (on iOS) or simply crashes the app
  /// without reporting to Sentry.io (on Android).
  static Future<void> nativeCrash() => _channel.invokeMethod('nativeCrash');

  /// A wrapper function for `runApp()` application code. It intercepts few
  /// different error conditions:
  ///
  /// - uncaught exceptions in the zone;
  /// - uncaught exceptions that has been propagated to the current Dart
  ///   isolate;
  /// - FlutterError errors (such as layout errors);
  ///
  /// and reports them to Sentry.io.
  ///
  /// Note that this function calls for [FlutterSentry.initialize], and
  /// therefore cannot be used more than once, or in combination with
  /// [FlutterSentry.initialize].
  static Future<T> wrap<T>(Future<T> Function() f, {@required String dsn}) {
    initialize(dsn: dsn);
    return runZoned<Future<T>>(() async {
      // This is necessary to initialize Flutter method channels so that
      // our plugin can call into the native code. It also must be in the same
      // zone as the app: https://github.com/flutter/flutter/issues/42682.
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
        instance._sentry.captureException(
          exception: details.exception,
          stackTrace: details.stack,
        );
      };

      Isolate.current
          .addErrorListener(RawReceivePort((dynamic errorAndStacktrace) async {
        // This must be a 2-element list per documentation:
        // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
        final dynamic error = errorAndStacktrace[0],
            stackTrace = errorAndStacktrace[1];
        debugPrint('Uncaught error in Flutter isolate: $error\n$stackTrace');
        await instance._sentry.captureException(
          exception: error,
          stackTrace:
              stackTrace is String ? StackTrace.fromString(stackTrace) : null,
        );
      }).sendPort);

      return f();
    }, onError: (Object exception, StackTrace stackTrace) {
      debugPrint('Uncaught error in zone: $exception\n$stackTrace');
      instance._sentry.captureException(
        exception: exception,
        stackTrace: stackTrace,
      );
    });
  }

  /// Return the configured instance of [FlutterSentry] after it has been
  /// initialized with [initialize] method, or `null` if the instance has not
  /// been initialized.
  static FlutterSentry get instance => _instance;

  /// Initialize [FlutterSentry] with [dsn] received from Sentry.io, making an
  /// instance available via [instance] property. It is an [Error] to call this
  /// method more than once during the application lifecycle.
  static void initialize({@required String dsn}) {
    if (_instance == null) {
      _instance = FlutterSentry._(SentryClient(dsn: dsn));
    } else {
      throw StateError('FlutterSentry has already been initialized');
    }
  }
}
