import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  MyApp(this.cameras);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(cameras),
    );
  }
}

class HomePage extends StatelessWidget {
  final List<CameraDescription> cameras;

  HomePage(this.cameras);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Face Recognition App"),
        backgroundColor: const Color.fromARGB(255, 12, 62, 103),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color.fromARGB(255, 196, 172, 244),
      body: Center(
        // color: const Color.fromARGB(255, 196, 172, 244),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CameraPage(cameras),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 12, 62, 103),
            padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
              textStyle: TextStyle(
                fontSize: 18.0, 
                fontWeight: FontWeight.bold,
              ),
          ),
          child: Text("Start Face Recognition"),
        ),
      ),
    );
  }
}

class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  CameraPage(this.cameras);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _cameraController;
  List<Map<String, dynamic>> _detectedFaces = [];

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
    );
    _cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _startFaceDetection();
    });
  }

  void _startFaceDetection() async {
    while (mounted) {
      try {
        final image = await _cameraController.takePicture();
        final bytes = await image.readAsBytes();

        var request = http.MultipartRequest(
          'POST', Uri.parse("http://127.0.0.1:8000/detect")
        );

        var multipartFile = http.MultipartFile.fromBytes(
          'frame',
          bytes,
          filename: 'image.jpg', 
          contentType: MediaType('image', 'jpg'),
        );

        request.files.add(multipartFile);

        var response = await request.send();

        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          final data = json.decode(responseBody);
          if (data["faces"] != null) {
            setState(() {
              _detectedFaces = List<Map<String, dynamic>>.from(data["faces"]);
            });
          }
        } else {
          print("Error in response: ${response.statusCode}");
        }
      } catch (e) {
        print("Error during face detection: $e");
      }

      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Face Recognition App"),
        backgroundColor: const Color.fromARGB(255, 12, 62, 103),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          ..._detectedFaces.map((face) {
            return Positioned(
              left: face["x"].toDouble(),
              top: face["y"].toDouble(),
              width: face["w"].toDouble(),
              height: face["h"].toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color.fromARGB(255, 12, 62, 103), width: 2),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: const Color.fromARGB(255, 12, 62, 103),
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      face["name"],
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}
