import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

class AnimatedBalanceText extends StatefulWidget {
  const AnimatedBalanceText({
    super.key,
    required this.value,
    required this.hideBalance,
    this.style,
    this.decimalStyle,
    this.symbolStyle,
    this.currencySymbol = '₦',
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final bool hideBalance;
  final TextStyle? style;
  final TextStyle? decimalStyle;
  final TextStyle? symbolStyle;
  final String currencySymbol;
  final Duration duration;

  @override
  State<AnimatedBalanceText> createState() => _AnimatedBalanceTextState();
}

class _AnimatedBalanceTextState extends State<AnimatedBalanceText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayValue = 0;
  
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _chimePlayer = AudioPlayer();
  int _lastPlayTime = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    
    _animation = Tween<double>(
      begin: _displayValue,
      end: _displayValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.addListener(_onAnimationUpdate);
    _controller.addStatusListener(_onAnimationStatus);

    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _tickPlayer.setReleaseMode(ReleaseMode.stop);
      await _chimePlayer.setReleaseMode(ReleaseMode.stop);
      await _tickPlayer.setSource(AssetSource('sounds/balance_counting.wav'));
      await _chimePlayer.setSource(AssetSource('sounds/balance_success.wav'));
    } catch (e) {
      debugPrint('[AnimatedBalanceText] Audio initialization failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedBalanceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.hideBalance || oldWidget.value == 0) {
        // Skip animation on first load from 0 or if balance is hidden
        setState(() {
          _displayValue = widget.value;
        });
      } else {
        // Animate from previous display value to the new target value
        _animation = Tween<double>(
          begin: _displayValue,
          end: widget.value,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ));
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationUpdate);
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    _tickPlayer.dispose();
    _chimePlayer.dispose();
    super.dispose();
  }

  void _onAnimationUpdate() {
    setState(() {
      _displayValue = _animation.value;
    });

    if (!widget.hideBalance && _controller.isAnimating) {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Play tick sound throttled to at most once per 60 milliseconds
      if (now - _lastPlayTime >= 60) {
        _lastPlayTime = now;
        _playTick();
      }
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !widget.hideBalance) {
      _playChime();
    }
  }

  Future<void> _playTick() async {
    try {
      await _tickPlayer.seek(Duration.zero);
      await _tickPlayer.resume();
    } catch (_) {}
  }

  Future<void> _playChime() async {
    try {
      await _chimePlayer.seek(Duration.zero);
      await _chimePlayer.resume();
    } catch (_) {}
  }

  String _formatNaira(double val) {
    return NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    ).format(val);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideBalance) {
      return Text(
        '${widget.currencySymbol} ••••••',
        style: widget.style,
      );
    }

    final formatted = _formatNaira(_displayValue);
    
    // If no decimal style is provided, render entire text under a single style
    if (widget.decimalStyle == null) {
      return Text(
        '${widget.currencySymbol}$formatted',
        style: widget.style,
      );
    }

    // Split formatted string into integer and decimal parts
    final parts = formatted.split('.');
    final integerPart = parts.first;
    final decimalPart = parts.length > 1 ? '.${parts.last}' : '.00';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          widget.currencySymbol,
          style: widget.symbolStyle ?? widget.style,
        ),
        const SizedBox(width: 4),
        Text(
          integerPart,
          style: widget.style,
        ),
        Text(
          decimalPart,
          style: widget.decimalStyle,
        ),
      ],
    );
  }
}
