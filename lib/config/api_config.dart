/// API Configuration for Face Pulse Backend Services.
/// Configurable for Android Emulator, Physical Android Devices, and Local PC Development.
class ApiConfig {
  /// Base URL of the FastAPI Backend Server.
  /// 
  /// NOTE FOR PHYSICAL ANDROID PHONE TESTING:
  /// Replace '192.168.1.100' with your development PC's actual local Wi-Fi / LAN IP address
  /// (e.g. run `ipconfig` on Windows or `ifconfig` on Linux/macOS).
  /// 
  /// Options:
  /// - Physical Android Phone: "http://<YOUR_PC_LAN_IP>:8000" (e.g. "http://192.168.1.105:8000")
  /// - Android Emulator: "http://10.0.2.2:8000"
  /// - Local PC / Web: "http://127.0.0.1:8000"
  static String baseUrl = "http://192.168.1.100:8000";

  /// Endpoint for Periodic Structured JSON Measurement Push (~1 Hz)
  static const String measurementsEndpoint = "/api/v1/measurements";
}
