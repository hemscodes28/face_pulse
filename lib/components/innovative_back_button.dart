import 'dart:ui';
import 'package:flutter/material.dart';

class InnovativeBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const InnovativeBackButton({super.key, required this.onTap});

  @override
  State<InnovativeBackButton> createState() => _InnovativeBackButtonState();
}

class _InnovativeBackButtonState extends State<InnovativeBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.55),
            border: Border.all(color: Colors.black.withOpacity(0.08), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 2.0), // center chevron alignment
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
