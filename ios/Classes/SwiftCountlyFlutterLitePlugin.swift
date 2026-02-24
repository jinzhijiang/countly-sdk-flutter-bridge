import Flutter
import UIKit

public class SwiftCountlyFlutterLitePlugin: NSObject, FlutterPlugin {
  private static let channelName = "countly_flutter_lite/migration"
  private static let methodGet = "getLegacyData"
  private static let methodClear = "clearIOSLegacyData"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = SwiftCountlyFlutterLitePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case Self.methodGet:
      result(readLegacyData())
    case Self.methodClear:
      clearLegacyData()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func readLegacyData() -> [String: Any?] {
    var ios: [String: Any?] = [:]
    let defaults = UserDefaults.standard
    ios["deviceId"] = defaults.string(forKey: Keys.deviceId)
    ios["nsuuid"] = defaults.string(forKey: Keys.nsuuid)
    ios["isCustomDeviceId"] = defaults.object(forKey: Keys.isCustomDeviceId) as? Bool
    ios["remoteConfig"] = defaults.dictionary(forKey: Keys.remoteConfig)
    ios["serverConfig"] = defaults.dictionary(forKey: Keys.serverConfig)
    ios["queuedRequests"] = readQueuedRequests()
    ios["recordedEvents"] = readRecordedEvents()
    ios["legacyAppKey"] = readLegacyAppKey()

    let hasData = ios.values.contains { value in
      if let str = value as? String { return !str.isEmpty }
      if let arr = value as? [Any] { return !arr.isEmpty }
      if let dict = value as? [AnyHashable: Any] { return !dict.isEmpty }
      return value != nil
    }

    return hasData ? ["ios": ios] : [:]
  }

  private func readQueuedRequests() -> [String]? {
    if let liveQueued = readLiveQueuedRequests(), !liveQueued.isEmpty {
      return liveQueued
    }

    guard let url = persistencyURL else { return nil }
    guard let data = try? Data(contentsOf: url) else { return nil }

    if let unarchived = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: Any],
       let queued = unarchived[Keys.queuedRequestsPersistencyKey] as? [String],
       !queued.isEmpty {
      return queued
    }

    do {
      if let unarchived = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any],
         let queued = unarchived[Keys.queuedRequestsPersistencyKey] as? [String] {
        return queued
      }
    } catch {
      return nil
    }
    return nil
  }

  private func readLiveQueuedRequests() -> [String]? {
    guard let persistency = sharedInstance(className: Keys.persistencyClassName) else {
      return nil
    }

    if let queued = property(from: persistency, selectorName: Keys.queuedRequestsSelector) as? [String] {
      return queued.filter { !$0.isEmpty }
    }

    if let queued = property(from: persistency, selectorName: Keys.queuedRequestsSelector) as? [Any] {
      let mapped = queued.compactMap { item -> String? in
        if let value = item as? String {
          return value.isEmpty ? nil : value
        }
        if let value = item as? NSString {
          let stringValue = value as String
          return stringValue.isEmpty ? nil : stringValue
        }
        return nil
      }
      return mapped.isEmpty ? nil : mapped
    }

    return nil
  }

  private func readRecordedEvents() -> [[String: Any]]? {
    guard let persistency = sharedInstance(className: Keys.persistencyClassName) else {
      return nil
    }

    guard let recordedEvents = property(from: persistency, selectorName: Keys.recordedEventsSelector) as? [Any],
          !recordedEvents.isEmpty else {
      return nil
    }

    let selector = NSSelectorFromString(Keys.eventDictionarySelector)
    var events: [[String: Any]] = []
    for event in recordedEvents {
      guard let eventObject = event as? NSObject, eventObject.responds(to: selector) else {
        continue
      }

      if let unmanaged = eventObject.perform(selector),
         let dict = unmanaged.takeUnretainedValue() as? [String: Any] {
        events.append(dict)
      }
    }

    return events.isEmpty ? nil : events
  }

  private func readLegacyAppKey() -> String? {
    guard let connectionManager = sharedInstance(className: Keys.connectionManagerClassName) else {
      return nil
    }
    return property(from: connectionManager, selectorName: Keys.appKeySelector) as? String
  }

  private func sharedInstance(className: String) -> NSObject? {
    guard let cls = NSClassFromString(className) as? NSObject.Type else {
      return nil
    }
    let selector = NSSelectorFromString(Keys.sharedInstanceSelector)
    guard cls.responds(to: selector), let unmanaged = cls.perform(selector) else {
      return nil
    }
    return unmanaged.takeUnretainedValue() as? NSObject
  }

  private func property(from object: NSObject, selectorName: String) -> Any? {
    let selector = NSSelectorFromString(selectorName)
    guard object.responds(to: selector), let unmanaged = object.perform(selector) else {
      return nil
    }
    return unmanaged.takeUnretainedValue()
  }

  private func clearLegacyData() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: Keys.deviceId)
    defaults.removeObject(forKey: Keys.nsuuid)
    defaults.removeObject(forKey: Keys.isCustomDeviceId)
    defaults.removeObject(forKey: Keys.remoteConfig)
    defaults.removeObject(forKey: Keys.serverConfig)

    if let url = persistencyURL {
      try? FileManager.default.removeItem(at: url)
    }
  }

  private var persistencyURL: URL? {
    guard var url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last else {
      return nil
    }
#if targetEnvironment(macCatalyst)
    if let bundleId = Bundle.main.bundleIdentifier {
      url = url.appendingPathComponent(bundleId)
    }
#endif
    return url.appendingPathComponent(Keys.persistencyFileName)
  }

  private enum Keys {
    static let deviceId = "kCountlyStoredDeviceIDKey"
    static let nsuuid = "kCountlyStoredNSUUIDKey"
    static let isCustomDeviceId = "kCountlyIsCustomDeviceIDKey"
    static let remoteConfig = "kCountlyRemoteConfigKey"
    static let serverConfig = "kCountlyServerConfigPersistencyKey"
    static let queuedRequestsPersistencyKey = "kCountlyQueuedRequestsPersistencyKey"
    static let persistencyFileName = "Countly.dat"
    static let persistencyClassName = "CountlyPersistency"
    static let connectionManagerClassName = "CountlyConnectionManager"
    static let sharedInstanceSelector = "sharedInstance"
    static let queuedRequestsSelector = "queuedRequests"
    static let recordedEventsSelector = "recordedEvents"
    static let eventDictionarySelector = "dictionaryRepresentation"
    static let appKeySelector = "appKey"
  }
}
