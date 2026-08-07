import 'dart:io';
import 'package:flutter/material.dart';

const _primaryBlue = Color(0xFF4B6EF5);
const _textPrimary = Color(0xFF1A1A2E);
const _textSecondary = Color(0xFF6B7280);
const _background = Color(0xFFF8F8F8);

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});
  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  File? selectedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/promo'),
            child: const Text('Пропустить', style: TextStyle(color: _textSecondary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Выберите аватар',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 70,
              backgroundColor: Color(0xFFE8EDFF),
              child: selectedImage != null
                  ? ClipOval(
                      child: Image.file(
                        selectedImage!,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.camera_alt, size: 40, color: _primaryBlue),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _primaryBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Галерея открыта')),
                ),
                child: const Text('Выбрать из галереи', style: TextStyle(color: _primaryBlue, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _primaryBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Камера открыта')),
                ),
                child: const Text('Сделать фото', style: TextStyle(color: _primaryBlue, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pushNamed(context, '/promo'),
                child: const Text('Сохранить', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
