import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isPermissionGranted = false;

  late final Future<void> _future;
  CameraController? _cameraController;

  final textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _future = _requestCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      _startCamera();
    }
  }

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        return Stack(
          children: [
            if (_isPermissionGranted)
              FutureBuilder<List<CameraDescription>>(
                future: availableCameras(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    _initCameraController(snapshot.data!);

                    return Stack(
                      children: [
                        Center(child: CameraPreview(_cameraController!)),
                        // Add a container to show the overlay

                        Center(
                          child: Container(
                            width: 300, // Adjust the size as needed
                            height: 210, // Adjust the size as needed
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.lightBlue,
                                width: 3.0,
                              ),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return const LinearProgressIndicator();
                  }
                },
              ),
            Scaffold(
              appBar: AppBar(
                title: const Text('driven_licence'),
                automaticallyImplyLeading: false,
                centerTitle: true,
              ),
              backgroundColor: _isPermissionGranted ? Colors.transparent : null,
              body: _isPermissionGranted
                  ? Column(
                      children: [
                        Expanded(
                          child: Container(),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2.4,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: ElevatedButton(
                              onPressed: _scanImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isLoading)
                                    SizedBox(
                                      height: 21,
                                      width: 21,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.57,
                                      ),
                                    ),
                                  if (isLoading)
                                    SizedBox(
                                      width: 20,
                                    ),
                                  Text("Scan Text",
                                      style: TextStyle(
                                        fontSize: 18,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.only(left: 24.0, right: 24.0),
                        child: const Text(
                          'Camera permission denied',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    _isPermissionGranted = status == PermissionStatus.granted;
  }

  void _startCamera() {
    if (_cameraController != null) {
      _cameraSelected(_cameraController!.description);
    }
  }

  void _stopCamera() {
    if (_cameraController != null) {
      _cameraController?.dispose();
    }
  }

  void _initCameraController(List<CameraDescription> cameras) {
    if (_cameraController != null) {
      return;
    }

    // Select the first rear camera.
    CameraDescription? camera;
    for (var i = 0; i < cameras.length; i++) {
      final CameraDescription current = cameras[i];
      if (current.lensDirection == CameraLensDirection.back) {
        camera = current;
        break;
      }
    }

    if (camera != null) {
      _cameraSelected(camera);
    }
  }

  Future<void> _cameraSelected(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.off);

    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _scanImage() async {
    setState(() {
      isLoading = true;
    });
    if (_cameraController == null) return;

    final navigator = Navigator.of(context);

    try {
      // Capture the image
      final pictureFile = await _cameraController!.takePicture();
      final file = File(pictureFile.path);
      final image = img.decodeImage(file.readAsBytesSync());

      // Get the screen size and container position/size
      final screenSize = MediaQuery.of(context).size;
      final containerWidth = 450.0; // Width of the container
      final containerHeight = 50.0; // Height of the container

      // Calculate scaling factors to match the actual image resolution
      final scaleX = image!.width / screenSize.width;
      final scaleY = image.height / screenSize.height;

      // Calculate the cropping rectangle (centered on the container)
      final left = (screenSize.width - containerWidth) / 2 * scaleX;
      final top = (screenSize.height / 2 - containerHeight / 2) * scaleY;

      // Crop the image to the container area
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

      // Process the cropped image with Google ML Kit
      final inputImage = InputImage.fromFile(croppedFile);
      final recognizedText = await textRecognizer.processImage(inputImage);
      print('Recognized Text: ${recognizedText.text}');

      // Parse the recognized text
      final lines = recognizedText.text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      // Extract and format information from driving license text
      final info = _extractDrivingLicenseInformation(lines);

      if (info.isNotEmpty) {
        // Format the information with newlines
        final formattedInfo = info.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n');

        // Display the results
        await navigator.push(
          MaterialPageRoute(
            builder: (BuildContext context) =>
                ResultScreen(text: formattedInfo),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient text to process driving license'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred when scanning text'),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, String> _extractDrivingLicenseInformation(List<String> lines) {
    // Assuming the driving license text has a consistent format:
    // For example:
    // Surname: MARTIN
    // Name: Marie
    // Date and place of birth: 14.07.1981 Utopia City
    // Date of issue: 01.01.2013
    // Date of expire: 31.12.2015
    // Identification number of driving license: 13AA00001

    final info = <String, String>{};

    for (var line in lines) {
      if (line.contains('Surname:')) {
        info['Surname'] = line.split(':').last.trim();
      } else if (line.contains('Name:')) {
        info['Name'] = line.split(':').last.trim();
      } else if (line.contains('Date and place of birth:')) {
        info['Date and place of birth'] = line.split(':').last.trim();
      } else if (line.contains('Date of issue:')) {
        info['Date of issue'] = line.split(':').last.trim();
      } else if (line.contains('Date of expire:')) {
        info['Date of expire'] = line.split(':').last.trim();
      } else if (line.contains('Identification number of driving license:')) {
        info['Identification number of driving license'] =
            line.split(':').last.trim();
      }
    }

    return info;
  }
}
