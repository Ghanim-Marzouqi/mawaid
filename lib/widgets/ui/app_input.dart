import 'package:flutter/material.dart';

class AppInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final void Function(String)? onFieldSubmitted;

  const AppInput({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textDirection,
    this.validator,
    this.onTap,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textDirection: textDirection,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      validator: validator,
      onTap: onTap,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
