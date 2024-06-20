import 'package:dental_camera_s700c_plugin/dental_camera_s700c_plugin_method_channel.dart';

class DentalCameraS700cPlugin {
  Future<String?> getPlatformVersion() {
    return MethodChannelDentalCameraS700cPlugin.instance.getPlatformVersion();
  }
}
