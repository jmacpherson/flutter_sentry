import Flutter
import UIKit
import Sentry

public class FlutterSentryPlugin: NSObject, FlutterPlugin {
    private static let SentryDSN = "SentryDSN"
    private static let SentryEnableAutoSessionTracking =
        "SentryEnableAutoSessionTracking"
    private static let SentrySessionTrackingIntervalMillis =
        "SentrySessionTrackingIntervalMillis"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_sentry",
            binaryMessenger: registrar.messenger())
        let instance = FlutterSentryPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    override init() {
        var options = [String: Any]()

        guard let dsn = Bundle.main.object(
            forInfoDictionaryKey: FlutterSentryPlugin.SentryDSN
        ) else {
            NSException.raise(
                NSExceptionName.invalidArgumentException,
                format:"The value for key %@ is not set in Info.plist",
                arguments: getVaList([
                    Self.SentryDSN,
                ]))
            return
        }

        guard let dsnString = dsn as? String else {
            NSException.raise(
                NSExceptionName.invalidArgumentException,
                format:"The value for key %@ is not a <string> type: %@",
                arguments: getVaList([
                    Self.SentryDSN,
                    String(describing: dsn),
                ]))
            return
        }
        options["dsn"] = dsnString

        let enableAutoSessionTracking = Bundle.main.object(
            forInfoDictionaryKey: FlutterSentryPlugin.SentryEnableAutoSessionTracking)
        // This is optional, skip if not set
        if enableAutoSessionTracking != nil {
            let value = enableAutoSessionTracking as? Bool
            if value == nil {
                NSException.raise(
                    NSExceptionName.invalidArgumentException,
                    format:"The value for key %@ is not a <boolean> type: %@",
                    arguments: getVaList([
                        Self.SentryEnableAutoSessionTracking,
                        String(describing: value),
                    ]))
            }
            options["enableAutoSessionTracking"] = value!
        }

        let sessionTrackingIntervalMillis = Bundle.main.object(
            forInfoDictionaryKey: FlutterSentryPlugin.SentrySessionTrackingIntervalMillis)
        // This is optional, skip if not set
        if sessionTrackingIntervalMillis != nil {
            let value = sessionTrackingIntervalMillis as? Int
            if value == nil {
                NSException.raise(
                    NSExceptionName.invalidArgumentException,
                    format:"The value for key %@ is not a <integer> type: %@",
                    arguments: getVaList([
                        Self.SentrySessionTrackingIntervalMillis,
                        String(describing: value),
                    ]))
            }
            options["sessionTrackingIntervalMillis"] = value!
        }

        SentrySDK.start(options: options)
    }

    public func handle(_ call: FlutterMethodCall,
                       result: @escaping FlutterResult) {
        switch call.method {
        case "nativeCrash":
            SentrySDK.crash()
        default:
           result(FlutterMethodNotImplemented)
        }
    }
}
