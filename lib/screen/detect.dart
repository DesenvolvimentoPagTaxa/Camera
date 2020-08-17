import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:image/image.Dart' as imglib;

List<CameraDescription> cameras;

class CameraDetect extends StatefulWidget {
  @override
  _CameraDetectState createState() => _CameraDetectState();
}

class _CameraDetectState extends State<CameraDetect> {
  final StreamController<Color> _stateController = StreamController<Color>();

  CameraController controller;
  bool isDetecting = false;
  Timer _timer;
  GlobalKey key = GlobalKey();

  @override
  void initState() {
    super.initState();
    InitCamera();
  }

  InitCamera() async {
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Detecting ...'),
      ),
      body: Column(children: [
        _camera(),
        Container(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
            MaterialButton(
                child: Text("Start Scanning"),
                textColor: Colors.white,
                color: Colors.blue,
                onPressed: () async {
                  Timer.periodic(Duration(seconds: 1), (timer) {
                    isDetecting = false;
                  });
                  await controller.startImageStream((CameraImage StreamImage) async {
                    if (isDetecting) return;
                    isDetecting = true;
                    try {
                      imglib.Image img = await convertYUV420toImageColor(StreamImage);
//                      imglib.Image imgGreyScale = grayscale(img);
                      //todo teste get Location
                      final RenderBox box = key.currentContext.findRenderObject();
                      Offset position = box.localToGlobal(Offset.zero);
                      double px = position.dx + 45;
                      double py = position.dy - 50;
                      //todo teste get Location
                      setState(() {
//                        int pixel32 = imgGreyScale.getPixelSafe(px.toInt(), py.toInt()); //Image GrayScale
                        int pixel32 = img.getPixelSafe(px.toInt(), py.toInt()); //Image Color Normal
                        int hex = abgrToArgb(pixel32);
                        print('*******************************');
                        print(px);
                        print(py);
                        print(Color(hex));
                        print('*******************************');
                        _stateController.add(Color(hex));
                      });
                    } catch (e) {
                      print(e);
                    }
                  });
                }),
            MaterialButton(
                child: Text("Stop Scanning"),
                textColor: Colors.white,
                color: Colors.red,
                onPressed: () async {
                  isDetecting = false;
                  _timer?.cancel();
                  await controller.stopImageStream();
                  _stateController.add(Colors.transparent);
                }),
          ]),
        ),
        StreamBuilder(
            initialData: Colors.green[500],
            stream: _stateController.stream,
            builder: (buildContext, snapshot) {
              Color selectedColor = snapshot.data ?? Colors.green;
              return Row(
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedColor,
                        border: Border.all(width: 2.0, color: Colors.white),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                  ),
                  Text('${selectedColor}', style: TextStyle(color: Colors.white, backgroundColor: Colors.black54)),
                ],
              );
            })
      ]),
    );
  }

  //Size camera
  Widget _camera() {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Expanded(
      child: Stack(
        children: <Widget>[_cameraPreviewWidget(), point(), _cameraScan()],
      ),
    );
  }

  Widget _cameraPreviewWidget() {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    return Stack(children: <Widget>[
      Center(
        child: Transform.scale(
          scale: controller.value.aspectRatio / deviceRatio,
          child: new AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: new CameraPreview(controller),
          ),
        ),
      )
    ]);
  }

  Widget point() {
    return Center(
      child: Container(
        key: key,
        height: 0,
        width: 0,
      ),
    );
  }

  Widget _cameraScan() {
    return Center(
      child: Container(
        height: 150,
        width: 150,
        child: Image.asset("assets/images/scan.png"),
      ),
    );
  }

//todo convert image
  Future<imglib.Image> convertYUV420toImageColor(CameraImage image) async {
    final int width = image.planes[0].bytesPerRow;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel;
    var buffer = imglib.Image(width, height);
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        if (uvIndex > image.planes[1].bytes.length) {
          continue;
        }
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        buffer.data[index] = (0xFF << 24) | (b << 16) | (g << 8) | r;
      }
    }
    return imglib.copyRotate(imglib.copyCrop(buffer, 0, 0, image.width, image.height), 90);
  }

  //Convert the image to grayscale
  imglib.Image grayscale(imglib.Image src) {
    var p = src.getBytes();
    for (var i = 0; i < p.length; i += 4) {
      var l = imglib.getLuminanceRgb(p[i], p[i + 1], p[i + 2]);
      p[i] = l;
      p[i + 1] = l;
      p[i + 2] = l;
    }
    return src;
  }
}

int abgrToArgb(int argbColor) {
  int r = (argbColor >> 16) & 0xFF;
  int b = argbColor & 0xFF;
  return (argbColor & 0xFF00FF00) | (b << 16) | r;
}
