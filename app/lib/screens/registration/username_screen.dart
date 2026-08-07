import 'dart:async';
import 'package:flutter/material.dart';

const _primaryBlue = Color(0xFF4B6EF5);
const _accentRed = Color(0xFFFF3B5C);
const _textPrimary = Color(0xFF1A1A2E);
const _background = Color(0xFFF8F8F8);

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});
  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool isChecking = false;
  bool? isAvailable;
  final _formKey = GlobalKey<FormState>();
  final _unavailableNames = const ['admin', 'user', 'test'];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
      isChecking = true;
      isAvailable = null;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          isChecking = false;
          isAvailable = value.length >= 3 &&
              RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value) &&
              !_unavailableNames.contains(value.toLowerCase());
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: _textPrimary),
        title: const Text('Придумайте логин', style: TextStyle(color: _textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Придумайте логин вашего аккаунта',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                onChanged: _onUsernameChanged,
                decoration: InputDecoration(
                  labelText: 'Логин',
                  hintText: 'Введите логин',
                  helperText: 'Только латинские буквы, цифры и символ _',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : isAvailable == true
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : isAvailable == false
                              ? const Icon(Icons.cancel, color: _accentRed)
                              : null,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите логин';
                  if (v.length < 3) return 'Минимум 3 символа';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return 'Только латинские буквы, цифры и _';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAvailable == true ? _primaryBlue : Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isAvailable == true
                      ? () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pushNamed(context, '/contacts');
                          }
                        }
                      : null,
                  child: const Text('Сохранить', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
