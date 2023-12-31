import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  CameraScreen({required this.cameras});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  XFile? _imageFile;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras[0], // Use a camera here, you can switch it later
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_isProcessing) return; // Evita múltiplas chamadas simultâneas

    try {
      setState(() {
        _isProcessing = true;
      });

      await _initializeControllerFuture;
      final XFile image = await _controller.takePicture();

      setState(() {
        _imageFile = image;
      });

      // Abrir um modal para mostrar a foto
      _showImagePreview();
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_isProcessing) return; // Evita alternar enquanto estiver processando

    final cameras = widget.cameras;
    if (cameras.length < 2) {
      return; // Não há câmeras suficientes para alternar
    }

    setState(() {
      _isProcessing = true;
    });

    final currentCameraIndex = cameras.indexOf(_controller.description);
    final newCameraIndex = (currentCameraIndex + 1) % cameras.length;
    final newCamera = cameras[newCameraIndex];

    if (_controller.value.isRecordingVideo) {
      // Se estiver gravando um vídeo, pare a gravação antes de alternar
      try {
        await _controller.stopVideoRecording();
      } catch (e) {
        print(e);
      }
    }

    setState(() {
      _controller = CameraController(
        newCamera,
        ResolutionPreset.medium,
      );
      _initializeControllerFuture = _controller.initialize();
      _isProcessing = false;
    });
  }

  Future<void> _showImagePreview() async {
    if (_imageFile != null) {
      try {
        List<int> imageBytes = await _imageFile!.readAsBytes();
        String base64Image = base64Encode(Uint8List.fromList(imageBytes));
        print('make the request');
        final response = await http.post(
          Uri.parse('http://192.168.169.240:5000/classify'),
          headers: <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, String>{
            'image': base64Image,
          })
        );
        Map<String, dynamic> data = jsonDecode(response.body);
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Column(
                children: [
                  Image.file(File(_imageFile!.path)),
                  SizedBox(height: 16),
                  Text(
                    'A flor é uma ${data["class_name"]}. Certeza de ${data["certainty"].toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Fechar'),
                ),
              ],
            );
          },
        );
      } catch(e) {
        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera App'),
        backgroundColor: Colors.black,
        actions: <Widget>[
          IconButton(
            onPressed: _isProcessing ? null : _switchCamera,
            icon: Icon(Icons.switch_camera),
            color: Colors.tealAccent,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    children: [
                      CameraPreview(_controller),
                      if (_isProcessing)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: SpinKitCircle(
                              color: Colors.white,
                              size: 50.0,
                            ),
                          ),
                        ),
                    ],
                    fit: StackFit.expand,
                  );
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
            flex: 1,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _isProcessing ? null : _takePicture,
                    icon: Icon(Icons.camera),
                    color: Colors.tealAccent,
                  ),
                ],
              ),
              color: Colors.black
            )
          ),
        ],
      ),
    );
  }
}
