// lib/screens/face_scanner_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceScannerScreen extends StatefulWidget {
  const FaceScannerScreen({super.key});

  @override
  State<FaceScannerScreen> createState() => _FaceScannerScreenState();
}

class _FaceScannerScreenState extends State<FaceScannerScreen> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _isInitializing = true;
  bool _isProcessingFrame = false;

  // Estado de la prueba de vida (Liveness)
  bool _eyesOpenDetected = false;
  bool _blinkDetected = false;
  String _instruccion = 'Encuadre su rostro e intente PARPADEAR';

  @override
  void initState() {
    super.initState();
    _initMLKitAndCamera();
  }

  Future<void> _initMLKitAndCamera() async {
    final options = FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();

      _controller!.startImageStream((CameraImage image) {
        if (_isProcessingFrame || _blinkDetected) return;
        _procesarFotograma(image, frontCamera);
      });
    } catch (e) {
      debugPrint('Error en la cámara o ML Kit: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _procesarFotograma(CameraImage image, CameraDescription camera) async {
    _isProcessingFrame = true;

    try {
      final InputImageMetadata metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _obtenerRotacionCamara(camera.sensorOrientation),
        format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: metadata,
      );

      final List<Face> faces = await _faceDetector!.processImage(inputImage);

      if (faces.isNotEmpty) {
        final Face face = faces.first;
        final double? leftEye = face.leftEyeOpenProbability;
        final double? rightEye = face.rightEyeOpenProbability;

        if (leftEye != null && rightEye != null) {
          if (leftEye > 0.7 && rightEye > 0.7) {
            _eyesOpenDetected = true;
          }

          if (_eyesOpenDetected && leftEye < 0.2 && rightEye < 0.2) {
            setState(() {
              _blinkDetected = true;
              _instruccion = '¡Prueba de Vida Confirmada! Presione Marcar';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error procesando frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImageRotation _obtenerRotacionCamara(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  void _capturarYValidarRostro() async {
    if (!_blinkDetected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe PARPADEAR frente a la cámara para validar que es un rostro vivo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final XFile photo = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, photo.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al capturar la imagen')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconocimiento Facial + Prueba de Vida'),
        backgroundColor: Colors.purple.shade800,
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          CameraPreview(_controller!),

          Center(
            child: Container(
              width: 250,
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _blinkDetected ? Colors.greenAccent : Colors.amber,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(160),
              ),
            ),
          ),

          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _blinkDetected ? Colors.green.shade800 : Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _instruccion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              onPressed: _blinkDetected ? _capturarYValidarRostro : null,
              icon: Icon(_blinkDetected ? Icons.check_circle : Icons.remove_red_eye),
              label: Text(_blinkDetected ? 'Confirmar y Marcar' : 'Por favor Parpadee'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                backgroundColor: _blinkDetected ? Colors.green.shade700 : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}