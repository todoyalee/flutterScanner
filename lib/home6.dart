import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'result_screen.dart';

class DL extends StatefulWidget {
  const DL({super.key});

  @override
  State<DL> createState() => _DLState();
}

class _DLState extends State<DL> with WidgetsBindingObserver {
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
                            width: 450, // Adjust the size as needed
                            height: 350, // Adjust the size as needed
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white,
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
                title: const Text('Driven licence'),
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
                            padding: const EdgeInsets.only(bottom: 75),
                            child: ElevatedButton(
                              onPressed: _scanImage,
                              style: ElevatedButton.styleFrom(
                                  padding:
                                      EdgeInsets.all(40), // Adjust size here

                                  backgroundColor:
                                      Colors.grey.shade600.withOpacity(0.3),
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      color: Colors.red, // Border color
                                      width: 2, // Border width
                                    ),
                                    //padding: EdgeInsets.symmetric(vertical: 15),
                                  )),
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
      final containerHeight = 350.0; // Height of the container

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

      // Parse the MRZ text
      final mrzText = recognizedText.text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (mrzText != null) {
        // Extract and format information f

        // Display the results
        // Display the results in a full-screen dialog
        await showDialog(
          context: context,
          barrierDismissible:
              false, // Prevents closing the dialog by tapping outside
          builder: (BuildContext context) {
            return Dialog(
              insetPadding: EdgeInsets.all(0), // Removes the default padding
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Result'),
                  leading: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop(); // Closes the dialog
                    },
                  ),
                ),
                body: Center(
                  child: ResultScreen(
                      text:
                          //rextractCapitalWordsAndDates(
                          //removeCommasAndSlashes(
                          insertNewlineAfterCommas(mrzText.toString())

//                            )
                      //)
                      ), // Use your ResultScreen widget here
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient MRZ text to process'),
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

  String extractCapitalWordsAndDates(String input) {
    // Define a regular expression pattern for detecting capitalized words
    final capitalCasePattern = RegExp(r'\b[A-Z][A-Z]+\b');

    // Define a regular expression pattern for detecting dates in formats like DD-MM-YYYY, YYYY-MM-DD, DD/MM/YYYY
    final datePattern =
        RegExp(r'\b(\d{2}[-/]\d{2}[-/]\d{4}|\d{4}[-/]\d{2}[-/]\d{2})\b');

    // Find all capitalized words
    final capitalWords = capitalCasePattern
        .allMatches(input)
        .map((match) => match.group(0))
        .where((word) => word != null)
        .join(' ');

    // Find all dates
    final dates = datePattern
        .allMatches(input)
        .map((match) => match.group(0))
        .where((date) => date != null)
        .join(' ');

    // Combine capital words and dates
    return '$capitalWords\n$dates';
  }

  String removeCommasAndSlashes(String text) {
    // Replace all commas and slashes with an empty string
    String cleanedText = text.replaceAll(RegExp(r'[,/]+'), '');
    return cleanedText;
  }

  String extractPersonalInformation(String text) {
    // Define the pattern for headers and personal information
    RegExp headerPattern = RegExp(r'(?:Header:.*?\n)+', multiLine: true);

    // Remove headers from the text
    String textWithoutHeaders = text.replaceAll(headerPattern, '');

    // Define patterns for extracting personal information (customize as needed)
    RegExp personalInfoPattern =
        RegExp(r'(?<=Personal Information:\n)(.*?)(?=\n\n|$)', dotAll: true);

    // Extract personal information
    Match? match = personalInfoPattern.firstMatch(textWithoutHeaders);

    // Return the extracted personal information or an empty string if not found
    return match?.group(0)?.trim() ?? '';
  }

  String extractKeyValuePairs(String text) {
    // Split the text into lines
    List<String> lines = text.split('\n');

    // Initialize variables
    Map<String, String?> keyValuePairs = {};
    String? currentKey;

    // Iterate through the lines
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      // Check if the line might be a key (customize the condition if needed)
      if (line.isNotEmpty && (i + 1) < lines.length) {
        // The next line is expected to be the value
        String value = lines[i + 1].trim();
        if (value.isNotEmpty) {
          keyValuePairs[line] = value;
          i++; // Skip the next line as it's already processed as a value
        }
      }
    }

    return keyValuePairs.toString();
  }

  String replaceCommaWithColon(String input) {
    input.replaceAll("STATURA:", "");

    input.replaceAll("SESSO:", "");
    input.replaceAll("LUOGO E DATA DI NASCITA:", "");
    return input.replaceAll(',', ':');
  }

  String insertNewlineAfterCommas(String text) {
    // Replace each comma with a comma followed by a newline character
    String result = text
        .replaceAll('1.', 'Surname:')
        .replaceAll('2.', 'Given name:')
        .replaceAll('3.', 'Date of birth: ')
        .replaceAll('4a.', 'Start date of the license:')
        .replaceAll('4b.', 'Expiry date of the license:')
        .replaceAll('5.', 'License number:')
        .replaceAll('7.', '')
        .replaceAll(RegExp(r'9\..*'), '')
        .replaceAll(RegExp(r'4C.\..*'), '')
        .replaceAll(RegExp(r'8.\..*'), '')
        .replaceAll(',', ',\n'); // Add a newline after each comma

    // Remove the surrounding brackets if needed
    result = result.replaceAll(RegExp(r'[\[\]]'), '').trim();

    /*
     license number
    result = text.replaceAll('4b.', 'Restrictions');
    */

    return result;
  }
}
