import 'package:flutter/material.dart';

const _primaryBlue = Color(0xFF4B6EF5);
const _textPrimary = Color(0xFF1A1A2E);
const _textSecondary = Color(0xFF6B7280);
const _background = Color(0xFFF8F8F8);

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: _textPrimary),
        title: const Text('', style: TextStyle(color: _textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Text('👥', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            const Text(
              'Найди друзей за 10 секунд и получай комплименты!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Добавь контакты — мы автоматически найдем одноклассников из твоей школы',
              style: TextStyle(color: _textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Контакты синхронизированы!')),
                  );
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) Navigator.pushNamed(context, '/photo');
                  });
                },
                child: const Text('Включить контакты', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '🔒 Никаких звонков или спама. Мы уважаем приватность',
              style: TextStyle(color: _textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/photo'),
              child: const Text('Пропустить', style: TextStyle(color: _textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
