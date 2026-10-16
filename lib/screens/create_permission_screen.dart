// lib/screens/create_permission_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../services/permission_service.dart';

class CreatePermissionScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onSuccess;

  const CreatePermissionScreen({
    Key? key,
    required this.userId,
    this.onSuccess,
  }) : super(key: key);

  @override
  _CreatePermissionScreenState createState() => _CreatePermissionScreenState();
}

class _CreatePermissionScreenState extends State<CreatePermissionScreen> {
  String _selectedType = 'PERSONAL_PERMIT';
  final TextEditingController _reasonController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 2));

  late SignatureController _signatureController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startDate = newDateTime;
          } else {
            _endDate = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _submitRequest() async {
    // 1. Ocultar teclado inmediatamente
    FocusScope.of(context).unfocus();

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese el motivo del permiso.')),
      );
      return;
    }

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La firma táctil del colaborador es obligatoria.')),
      );
      return;
    }

    // 2. Exportar la firma en bytes ANTES de activar el spinner de carga
    // Esto evita que setState() rompa la superficie gráfica del canvas en Android
    final Uint8List? signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null) return;

    final String base64Signature = base64Encode(signatureBytes);

    // 3. Activar el indicador de carga y dar un margen de 200ms al motor gráfico
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      // 4. Petición HTTP al Backend Next.js
      final result = await PermissionService.createPermission(
        userId: widget.userId,
        type: _selectedType,
        reason: _reasonController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        signatureBase64: 'data:image/png;base64,$base64Signature',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // 5. Limpieza previa de controles
        _signatureController.clear();
        _reasonController.clear();

        setState(() {
          _isSubmitting = false;
          _selectedType = 'PERSONAL_PERMIT';
          _startDate = DateTime.now();
          _endDate = DateTime.now().add(const Duration(hours: 2));
        });

        // 6. Mensaje de confirmación en pantalla
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud y papeleta enviada a RRHH correctamente.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // 7. Ejecutar redirección
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Error al enviar la solicitud.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Permiso / Papeleta'),
        backgroundColor: const Color(0xFF005F87),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de Permiso / Licencia:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'PERSONAL_PERMIT', child: Text('Papeleta de Salida Particular')),
                DropdownMenuItem(value: 'MEDICAL_LEAVE', child: Text('Descanso Médico (ESSALUD)')),
                DropdownMenuItem(value: 'MATERNITY_PATERNITY', child: Text('Licencia Maternidad / Paternidad')),
                DropdownMenuItem(value: 'VACATION_LEAVE', child: Text('Saldo de Vacaciones')),
                DropdownMenuItem(value: 'COMMISSION', child: Text('Comisión de Servicio Externo')),
              ],
              onChanged: _isSubmitting ? null : (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _selectDateTime(true),
                    child: Text('Inicio: ${_startDate.day}/${_startDate.month} ${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _selectDateTime(false),
                    child: Text('Fin: ${_endDate.day}/${_endDate.month} ${_endDate.hour}:${_endDate.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Motivo Justificado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              enabled: !_isSubmitting,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ingrese el motivo detallado...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Firma Digital del Colaborador (Trazo Táctil):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00BFA5), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _signatureController,
                height: 180,
                backgroundColor: Colors.white,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => _signatureController.clear(),
                  child: const Text('Limpiar Firma', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005F87)),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
                    : const Text(
                  'Enviar Solicitud a RRHH',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}