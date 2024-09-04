import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the camera
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  MyApp({required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Recognition App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ImageCaptureScreen(camera: camera),
    );
  }
}

class ImageCaptureScreen extends StatefulWidget {
  final CameraDescription camera;

  ImageCaptureScreen({required this.camera});

  @override
  _ImageCaptureScreenState createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  late CameraController _cameraController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _scanImage() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Capture the image
      final pictureFile = await _cameraController.takePicture();
      final file = File(pictureFile.path);
      final image = img.decodeImage(file.readAsBytesSync());

      // Define the container size (where the text is located)
      final containerWidth = 450.0; // Width of the container
      final containerHeight = 50.0; // Height of the container

      // Get screen size
      final screenSize = MediaQuery.of(context).size;

      // Calculate the scaling factors based on image size and screen size
      final scaleX = image!.width / screenSize.width;
      final scaleY = image.height / screenSize.height;

      // Calculate the cropping rectangle based on container's position
      final left = (screenSize.width - containerWidth) / 2 * scaleX;
      final top = (screenSize.height / 2 - containerHeight / 2) * scaleY;

      // Crop the image based on the calculated rectangle
      final croppedImage = img.copyCrop(
        image,
        x: left.toInt(),
        y: top.toInt(),
        width: (containerWidth * scaleX).toInt(),
        height: (containerHeight * scaleY).toInt(),
      );

      // Save the cropped image
      final croppedFile = File('${file.path}_cropped.jpg')
        ..writeAsBytesSync(img.encodeJpg(croppedImage));

      // Recognize text using Google ML Kit
      final inputImage = InputImage.fromFile(croppedFile);
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Handle the recognized text (You can process MRZ or other formats as needed)
      if (recognizedText.text.isNotEmpty) {
        _handleRecognizedText(recognizedText.text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text recognized in the image'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _handleRecognizedText(String text) {
    // Parse and handle recognized text
    print(text);
    // For example, navigate to a result screen or show the result in a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture & Recognize Text')),
      body: Stack(
        children: [
          if (_cameraController.value.isInitialized)
            CameraPreview(_cameraController),
          Center(
            child: Container(
              width: 450.0,
              height: 450.0,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2.0),
              ),
            ),
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanImage,
        child: const Icon(Icons.camera),
      ),
    );
  }
}
