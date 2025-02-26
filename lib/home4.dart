import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'result_screen.dart';

class Passport extends StatefulWidget {
  const Passport({super.key});

  @override
  State<Passport> createState() => _PassportState();
}

class _PassportState extends State<Passport> with WidgetsBindingObserver {
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
                            width: 350, // Adjust the size as needed/
                            height: 280, // Adjust the size as needed
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
                title: const Text('Takamuraa'),
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
                              onPressed: _scanPassport,
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

  Future<void> _scanPassport() async {
    setState(() {
      isLoading = true;
    });

    if (_cameraController == null) return;

    final navigator = Navigator.of(context);

    try {
      // Capture the image
      final pictureFile = await _cameraController!.takePicture();
      final file = File(pictureFile.path);

      // Process the entire image with Google ML Kit
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Parse the text and extract relevant information
      final allText = recognizedText.text;
      final info = _extractInformationFromPassportText(allText);

      // Format the information with newlines
      final formattedInfo = info.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');

      // Display the results
      await navigator.push(
        MaterialPageRoute(
          builder: (BuildContext context) => ResultScreen(text: formattedInfo),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred when scanning the passport'),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, String> _extractInformationFromPassportText(String text) {
    // Remove unwanted characters and split the text into lines
    final cleanedText = text.replaceAll('*', '').replaceAll('<<', '<');
    final lines = cleanedText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    // Assuming a basic passport format with MRZ at the bottom two lines
    // This will vary depending on the country and document type
    if (lines.length < 2) {
      return {};
    }

    final line1 = lines[lines.length - 2];
    final line2 = lines[lines.length - 1];

    // Extract information from the MRZ (this assumes a standard passport format)
    final info1 = _extractInformationFromText1(line1);
    final info2 = _extractInformationFromText2(line2);

    return {...info1, ...info2};
  }

  String _reformatDate(String date) {
    if (date.length == 6) {
      return '${date.substring(4, 6)}-${date.substring(2, 4)}-${date.substring(0, 2)}';
    }
    return date;
  }

  Map<String, String> _extractInformationFromText1(String text) {
    text = text.replaceAll('*', ''); // Remove asterisks used as fillers
    final typeCode = text[0]; // Document type (e.g., P for passport)
    final remainingText = text.substring(1).replaceAll('<<', '<');

    final codeOfState = remainingText.substring(0, 3); // Issuing state code
    final names = remainingText.substring(3).split('<'); // Split names by '<'
    final surname = names[0].replaceAll('<', ' ').trim(); // Surname (last name)
    final givenName = names
        .sublist(1)
        .join(' ')
        .replaceAll('<', ' ')
        .trim(); // Given name (first name)

    return {
      'Type': typeCode,
      'Code of State': codeOfState,
      'Surname': surname,
      'Given Name': givenName,
    };
  }

  Map<String, String> _extractInformationFromText2(String text) {
    final passportNo =
        text.substring(0, 9).replaceAll('<', ''); // Passport number
    final nationality = text.substring(10, 13); // Nationality code
    final dateOfBirth = _reformatDate(text.substring(13, 19)); // Date of birth
    final sex = text.substring(20, 21); // Sex (M/F)
    final dateOfExpiry = _reformatDate(text.substring(21, 27)); // Expiry date

    return {
      'Passport No': passportNo,
      'Nationality': nationality,
      'Date of Birth': dateOfBirth,
      'Sex': sex,
      'Date of Expiry': dateOfExpiry,
    };
  }
}
