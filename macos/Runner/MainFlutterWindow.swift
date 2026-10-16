import Cocoa
import IOKit
import IOKit.hid
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  private var tabletMonitor: TabletMonitor?
  override func awakeFromNib() {
    self.appearance = NSAppearance(named: .darkAqua)
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.contentMinSize = NSSize(width: 960, height: 640)
    self.setContentSize(NSSize(width: 1200, height: 800))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    tabletMonitor = TabletMonitor(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

// Observe registry attachment/removal only: no raw input, device seizure, or
// Input Monitoring permission. Driver-hidden identities remain unidentifiable.
private final class TabletMonitor: NSObject, FlutterStreamHandler {
  private var port: IONotificationPortRef?
  private var attached: io_iterator_t = 0
  private var removed: io_iterator_t = 0
  private var monitoring = false
  private var sink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel!
  private var eventChannel: FlutterEventChannel!

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    methodChannel = FlutterMethodChannel(name: "novi/tablets", binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: "novi/tablets/events", binaryMessenger: messenger)
    methodChannel.setMethodCallHandler { [weak self] call, result in
      if call.method == "getState" { result(self?.state() ?? ["available": false, "devices": []]) }
      else { result(FlutterMethodNotImplemented) }
    }
    eventChannel.setStreamHandler(self)
    port = IONotificationPortCreate(kIOMainPortDefault)
    guard let port = port else { return }
    IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
    let callback: IOServiceMatchingCallback = { context, iterator in
      while case let entry = IOIteratorNext(iterator), entry != 0 { IOObjectRelease(entry) }
      guard let context = context else { return }
      let monitor = Unmanaged<TabletMonitor>.fromOpaque(context).takeUnretainedValue()
      monitor.sink?(monitor.state())
    }
    let context = Unmanaged.passUnretained(self).toOpaque()
    let matchResult = IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOHIDDevice"), callback, context, &attached)
    while case let entry = IOIteratorNext(attached), entry != 0 { IOObjectRelease(entry) }
    let removalResult = IOServiceAddMatchingNotification(port, kIOTerminatedNotification, IOServiceMatching("IOHIDDevice"), callback, context, &removed)
    while case let entry = IOIteratorNext(removed), entry != 0 { IOObjectRelease(entry) }
    monitoring = matchResult == KERN_SUCCESS && removalResult == KERN_SUCCESS
  }
  private func property(_ device: io_registry_entry_t, _ key: String) -> Any? {
    IORegistryEntryCreateCFProperty(device, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
  }
  private func state() -> [String: Any] {
    var iterator: io_iterator_t = 0
    let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iterator)
    guard result == KERN_SUCCESS else { return ["available": false, "devices": []] }
    defer { IOObjectRelease(iterator) }
    var devices = Set<String>()
    while case let device = IOIteratorNext(iterator), device != 0 {
      defer { IOObjectRelease(device) }
      var pairs = property(device, "DeviceUsagePairs") as? [[String: Any]] ?? []
      pairs.append(["DeviceUsagePage": property(device, "PrimaryUsagePage") ?? 0, "DeviceUsage": property(device, "PrimaryUsage") ?? 0])
      let tablet = pairs.contains { pair in
        let page = (pair["DeviceUsagePage"] as? NSNumber)?.intValue ?? 0
        let usage = (pair["DeviceUsage"] as? NSNumber)?.intValue ?? 0
        return page == 0x0d && [0x01, 0x02, 0x20].contains(usage)
      }
      if tablet {
        var identifier: UInt64 = 0
        if IORegistryEntryGetRegistryEntryID(device, &identifier) == KERN_SUCCESS { devices.insert(String(identifier)) }
      }
    }
    return ["available": monitoring, "devices": devices.sorted()]
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    events(state())
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
  deinit {
    if attached != 0 { IOObjectRelease(attached) }
    if removed != 0 { IOObjectRelease(removed) }
    if let port = port { IONotificationPortSetDispatchQueue(port, nil); IONotificationPortDestroy(port) }
  }
}
