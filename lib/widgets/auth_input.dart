import 'package:flutter/material.dart';

/// A text input field designed for authentication forms.
///
/// Includes a label, hint text, and specific styling for the auth context.
class AuthInput extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscure;
  final TextEditingController controller;

  const AuthInput({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF6A6AFF),
                width: 1.2, // soft focus
              ),
            ),
          ),
        ),
      ],
    );
  }
}
