import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MethodChannelDentalCameraS700cPlugin {
  /// The method channel used to interact with the native platform.
  static final MethodChannelDentalCameraS700cPlugin _instance =
      MethodChannelDentalCameraS700cPlugin();
  static MethodChannelDentalCameraS700cPlugin get instance => _instance;

  @visibleForTesting
  final methodChannel = const MethodChannel('dental_camera_s700c_plugin');

  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
