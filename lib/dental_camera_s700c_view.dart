// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_settings_plus/core/open_settings_plus.dart';
import 'package:screen_recorder/screen_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:gal/gal.dart';

bool _isRecording = false;

class S700cView extends StatefulWidget {
  const S700cView({super.key});

  @override
  State<S700cView> createState() => _S700cViewState();
}

class _S700cViewState extends State<S700cView> {
  static const platform = MethodChannel('dental_camera_s700c_plugin');
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  bool isExporting = false;
  double angle = 0.0;
  final ScreenRecorderController _screenRecorderController =
      ScreenRecorderController();
  bool get canExport => _screenRecorderController.exporter.hasFrames;
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void initState() {
    platform.setMethodCallHandler(_handleMethodCall);
    super.initState();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'gsensorData':
        final String hexData =
            Platform.isAndroid ? bytesToHex(call.arguments) : '';
        setState(() {
          angle = getAngle(hexData);
        });
        break;
      case 'photoCaptured':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Foto scattata"),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'noFrameAvailable':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nessun frame disponibile"),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'photoPreview':
        Uint8List imageData = call.arguments;
        bool? saveResult = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Anteprima',
                style: TextStyle(fontSize: 16),
              ),
              content: Image.memory(imageData),
              actions: <Widget>[
                TextButton(
                  child: const Text(
                    'Salva',
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
                TextButton(
                  child: const Text(
                    'Annulla',
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            );
          },
        );
        if (saveResult ?? false) {
          await _saveImage(imageData);
        }
        break;
      case 'videoPreview':
        if (Platform.isIOS) {
          Uint8List videoData = call.arguments;
          bool? saveResult = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Salva il video?'),
                content: const Text('Vuoi salvare il video registrato?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('No'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  TextButton(
                    child: const Text('Sì'),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              );
            },
          );

          if (saveResult ?? false) {
            await _saveVideo(videoData);
          }
        }
        break;
      case 'RECORDING_STARTED':
        if (Platform.isIOS) {
          setState(() {
            _isRecording = true;
            _startTimer();
          });
        }
        break;
      case 'RECORDING_STOPPED':
        if (Platform.isIOS) {
          setState(() {
            _isRecording = false;
            _stopTimer();
          });
        }
        break;
      default:
        throw PlatformException(
            code: "Not Implemented",
            message: "Method ${call.method} not implemented.");
    }
  }

  String bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }

  void _startTimer() {
    if (Platform.isIOS) {
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        setState(() {
          _recordDuration++;
        });
      });
    }
  }

  void _stopTimer() {
    if (Platform.isIOS) {
      _timer?.cancel();
    }
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _saveImage(Uint8List imageData) async {
    try {
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/temp_image.png';
      final file = File(imagePath);
      await file.writeAsBytes(imageData);
      bool result = true;
      try {
        await Gal.putImage(imagePath);
      } catch (e) {
        result = false;
      }

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Immagine salvata con successo"),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Salvataggio immagine fallito"),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await file.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Errore durante il salvataggio dell'immagine: $e"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveVideo(Uint8List videoData) async {
    try {
      final directory = await getTemporaryDirectory();
      final videoPath = '${directory.path}/dental_Cam.mp4';
      final file = File(videoPath);
      await file.writeAsBytes(videoData);
      bool result = true;
      try {
        await Gal.putVideo(videoPath);
      } catch (e) {
        result = false;
      }

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Video salvato con successo"),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Salvataggio video fallito"),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await file.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Errore durante il salvataggio del video: $e"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _foto() async {
    try {
      if (Platform.isAndroid) {
        await platform.invokeMethod('foto');
      } else if (Platform.isIOS) {
        await platform.invokeMethod('foto_ios');
      }
    } catch (e) {
      //print("Failed to capture photo: '${e}'.");
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (Platform.isAndroid) {
        if (await _requestPermissions()) {
          _screenRecorderController.exporter
              .clear(); // Pulisce i frame precedenti
          _screenRecorderController.start();
          setState(() {
            _isRecording = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Storage permission denied"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (Platform.isIOS) {
        setState(() {
          _recordDuration = 0; // Reset the timer
        });
        await platform.invokeMethod('startVideoRecording');
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (Platform.isAndroid) {
        _screenRecorderController.stop();
        setState(() {
          _isRecording = false;
          isExporting = true;
        });

        bool? saveResult = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Vuoi salvare il video?',
                style: TextStyle(fontSize: 32),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: <Widget>[
                TextButton(
                  child: const Text(
                    'Salva',
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
                TextButton(
                  child: const Text(
                    'Annulla',
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            );
          },
        );

        if (!(saveResult ?? false)) {
          setState(() {
            isExporting = false;
            _screenRecorderController.exporter.clear();
          });
          return;
        }

        try {
          List<RawFrame>? frames =
              await _screenRecorderController.exporter.exportFrames();
          if (frames == null || frames.isEmpty) {
            setState(() {
              isExporting = false;
            });
            throw Exception("Failed to export frames");
          }

          final directory = await getTemporaryDirectory();
          final framePathTemplate = '${directory.path}/DentalCam_%03d.png';

          for (int i = 0; i < frames.length; i++) {
            final framePath = framePathTemplate.replaceAll(
                '%03d', i.toString().padLeft(3, '0'));
            final file = File(framePath);
            await file.writeAsBytes(frames[i].image.buffer.asUint8List());
          }

          await _convertFramesToVideo(framePathTemplate);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Errore durante l'esportazione dei frame"),
              duration: Duration(seconds: 2),
            ),
          );
        } finally {
          setState(() {
            isExporting = false;
            _screenRecorderController.exporter.clear();
          });
        }
      } else if (Platform.isIOS) {
        await platform.invokeMethod('stopVideoRecording');
        setState(() {
          _isRecording = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _convertFramesToVideo(String framePathTemplate) async {
    try {
      final directory = await getTemporaryDirectory();
      final videoPath = '${directory.path}/recorded_video.mp4';

      final command =
          '-r 8 -i $framePathTemplate -vf "fps=8,format=yuv420p" -y $videoPath';

      await _flutterFFmpeg.execute(command).then((rc) async {
        if (rc == 0) {
          bool result = true;
          try {
            await Gal.putVideo(videoPath);
          } catch (e) {
            result = false;
          }

          if (result) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Video salvato con successo"),
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Salvataggio video fallito"),
                duration: Duration(seconds: 2),
              ),
            );
          }
          await File(videoPath).delete();
        } else {
          //print("[DEBUG] FFmpeg process failed with return code $rc");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Errore durante la conversione del video"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      // print("[DEBUG] Error during frame to video conversion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Errore durante la conversione del video: $e"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<bool> _requestPermissions() async {
    if (await Permission.storage.isGranted) {
      return true;
    }
    if (await Permission.videos.isGranted) {
      return true;
    }
    // Check for specific permissions on Android 13 and above
    if (await Permission.videos.request().isGranted) {
      return true;
    }
    // Request the storage permission
    if (await Permission.storage.request().isGranted) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness:
              Platform.isAndroid ? Brightness.light : Brightness.dark,
          statusBarIconBrightness:
              Platform.isAndroid ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              Platform.isAndroid ? Brightness.light : Brightness.dark,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (isExporting)
              const Center(
                  child: SizedBox(
                      height: 60,
                      width: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 8,
                        color: Colors.teal,
                      )))
            else ...[
              Expanded(
                child: Center(
                  child: ScreenRecorder(
                    background: Colors.black,
                    height: 480,
                    width: 640,
                    controller: _screenRecorderController,
                    child: Platform.isIOS
                        ? const UiKitView(
                            viewType: 'my_uikit_view',
                          )
                        : const AndroidView(
                            viewType: 'mjpeg-view-type',
                          ),
                  ),
                ),
              ),
              if (_isRecording && Platform.isIOS)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _formatDuration(_recordDuration),
                    style: const TextStyle(color: Colors.red, fontSize: 24),
                  ),
                ),
              _FinalButtonRow(
                fotoCallBack: () {
                  _foto();
                },
                videoCallBack: _toggleRecording,
              )
            ],
          ],
        ),
      ),
    );
  }

  double getAngle(String hexData) {
    // Implement your logic to calculate the angle based on hexData
    return 0.0;
  }
}

_CameraMode _mode = _CameraMode.photo;

class _FinalButtonRow extends StatefulWidget {
  const _FinalButtonRow(
      {required this.fotoCallBack, required this.videoCallBack});
  final VoidCallback fotoCallBack;
  final Function() videoCallBack;
  @override
  State<_FinalButtonRow> createState() => __FinalButtonRowState();
}

class __FinalButtonRowState extends State<_FinalButtonRow> {
  Timer? videoTimer;

  final cnt = StreamController<String?>.broadcast();
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    cnt.close();
    cancelTimer();
    super.dispose();
  }

  prepareTimer() {
    final startTime = DateTime.now();
    videoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final dur = DateTime.now().difference(startTime);
      cnt.add(dur.toString().split('.')[0]);
    });
  }

  cancelTimer() {
    videoTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<String?>(
                stream: cnt.stream,
                builder: (context, snapshot) {
                  return Opacity(
                    opacity: snapshot.data != null ? 1 : 0,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.all(Radius.circular(80))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          snapshot.data ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  );
                }),
          ),
          Row(
            children: [
              Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: InkWell(
                        enableFeedback: false,
                        highlightColor: Colors.transparent,
                        splashFactory: NoSplash.splashFactory,
                        onTap: () {
                          if (Platform.isAndroid) {
                            const OpenSettingsPlusAndroid().wifi();
                          } else if (Platform.isIOS) {
                            const OpenSettingsPlusIOS().wifi();
                          }
                        },
                        child: Icon(
                          Icons.wifi,
                          color: Colors.white.withOpacity(0.7),
                          size: 35,
                        ),
                      ),
                    )),
              ),
              InkWell(
                enableFeedback: false,
                highlightColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                onTap: () async {
                  if (_mode == _CameraMode.photo) {
                    widget.fotoCallBack();
                  } else {
                    await widget.videoCallBack();
                    if (Platform.isAndroid) {
                      if (_isRecording) {
                        prepareTimer();
                      } else {
                        cancelTimer();
                      }
                    }
                  }
                },
                child: Container(
                  height: 75,
                  width: 75,
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.7),
                      shape: BoxShape.circle),
                ),
              ),
              Expanded(
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                        padding: const EdgeInsets.only(right: 32.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Column(
                                children: [
                                  InkWell(
                                    enableFeedback: false,
                                    highlightColor: Colors.transparent,
                                    splashFactory: NoSplash.splashFactory,
                                    onTap: () {
                                      _mode = _CameraMode.photo;
                                      setState(() {});
                                    },
                                    child: Icon(
                                      Icons.camera_alt_outlined,
                                      color: _mode == _CameraMode.photo
                                          ? Colors.teal
                                          : Colors.white.withOpacity(0.7),
                                      size: 35,
                                    ),
                                  ),
                                  Text(
                                    'Foto',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _mode == _CameraMode.photo
                                            ? Colors.teal
                                            : Colors.black),
                                  )
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                InkWell(
                                  enableFeedback: false,
                                  highlightColor: Colors.transparent,
                                  splashFactory: NoSplash.splashFactory,
                                  onTap: () {
                                    _mode = _CameraMode.video;
                                    setState(() {});
                                  },
                                  child: Icon(
                                    Icons.videocam_outlined,
                                    color: _mode == _CameraMode.video
                                        ? Colors.teal
                                        : Colors.white.withOpacity(0.7),
                                    size: 35,
                                  ),
                                ),
                                Text(
                                  'Video',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _mode == _CameraMode.video
                                          ? Colors.teal
                                          : Colors.black),
                                )
                              ],
                            ),
                          ],
                        ))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _CameraMode {
  photo,
  video;
}
