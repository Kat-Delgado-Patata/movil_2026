import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

const int verificationCodeLength = 6;
const int _resendSeconds = 60;

/// Tarjeta con las 6 casillas del código, su estado y el botón de reenviar.
class VerificationCodeCard extends StatefulWidget {
  const VerificationCodeCard({
    super.key,
    required this.onChanged,
    required this.onResend,
    this.hasError = false,
  });

  /// Se llama cada vez que cambia el código (puede estar incompleto).
  final ValueChanged<String> onChanged;
  final VoidCallback onResend;
  final bool hasError;

  @override
  State<VerificationCodeCard> createState() => _VerificationCodeCardState();
}

class _VerificationCodeCardState extends State<VerificationCodeCard> {
  final _controllers = List.generate(verificationCodeLength, (_) => TextEditingController());
  final _focusNodes = List.generate(verificationCodeLength, (_) => FocusNode());

  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _isCodeComplete => _code.length == verificationCodeLength;

  String get _timerText {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  void _resendCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    _startTimer();
    widget.onChanged('');
    widget.onResend();
  }

  void _onDigitChanged(int index, String value) {
    // Permite pegar el código completo en cualquier casilla.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < verificationCodeLength; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final next = digits.length.clamp(0, verificationCodeLength - 1);
      _focusNodes[next].requestFocus();
    } else if (value.isNotEmpty && index < verificationCodeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    setState(() {});
    widget.onChanged(_code);
    if (_isCodeComplete) FocusScope.of(context).unfocus();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    final isBackspace = event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace;
    if (isBackspace && _controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
      widget.onChanged(_code);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Código de 6 dígitos', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(verificationCodeLength, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < verificationCodeLength - 1 ? 8 : 0),
                  child: _buildDigitField(i),
                ),
              );
            }),
          ),
          if (widget.hasError)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Ingresa los 6 dígitos del código',
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          const SizedBox(height: 14),
          Center(child: _buildResend()),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final complete = _isCodeComplete;
    final color = complete ? AppColors.tertiaryContainer : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: complete ? AppColors.tertiaryFixed.withValues(alpha: 0.35) : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 5),
          Text(
            complete ? 'Código completo' : 'Esperando código',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitField(int index) {
    return Focus(
      onKeyEvent: (_, event) => _onKey(index, event),
      child: AspectRatio(
        aspectRatio: 0.85,
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.hasError ? AppColors.error : AppColors.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
            ),
          ),
          onChanged: (value) => _onDigitChanged(index, value),
        ),
      ),
    );
  }

  Widget _buildResend() {
    if (_secondsLeft > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              children: [
                const TextSpan(text: 'Reenviar código en '),
                TextSpan(
                  text: '$_timerText min',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return TextButton.icon(
      onPressed: _resendCode,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Reenviar código', style: TextStyle(fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
    );
  }
}
