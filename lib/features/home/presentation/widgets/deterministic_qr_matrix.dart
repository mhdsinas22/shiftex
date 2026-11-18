import 'package:flutter/material.dart';
import 'package:shiftex/core/constants/app_colors.dart';

/// Renders a crisp, deterministic QR matrix from an opaque cryptographic token payload.
/// Contains standard 7x7 finder patterns in top-left, top-right, and bottom-left corners.
class DeterministicQrMatrix extends StatelessWidget {
  final String payload;
  final double size;

  const DeterministicQrMatrix({
    super.key,
    required this.payload,
    this.size = 176,
  });

  static const int _gridSize = 21;

  bool _isFinderModule(int r, int c) {
    bool inFinder(int rowOffset, int colOffset) {
      final lr = r - rowOffset;
      final lc = c - colOffset;
      if (lr < 0 || lr >= 7 || lc < 0 || lc >= 7) return false;
      if (lr == 0 || lr == 6 || lc == 0 || lc == 6) return true;
      if (lr >= 2 && lr <= 4 && lc >= 2 && lc <= 4) return true;
      return false;
    }

    return inFinder(0, 0) ||
        inFinder(0, _gridSize - 7) ||
        inFinder(_gridSize - 7, 0);
  }

  bool _isFinderSeparator(int r, int c) {
    if (r < 8 && c < 8) return true;
    if (r < 8 && c >= _gridSize - 8) return true;
    if (r >= _gridSize - 8 && c < 8) return true;
    return false;
  }

  bool _moduleDark(int r, int c) {
    if (_isFinderModule(r, c)) return true;
    if (_isFinderSeparator(r, c)) return false;
    if (r == 6 || c == 6) return (r + c).isEven;

    final seed = payload.isEmpty ? 'SHIIFTEX' : payload;
    final idx = r * _gridSize + c;
    final codeUnit = seed.codeUnitAt(idx % seed.length);
    final mix = ((codeUnit * 31) ^ (r * 17) ^ (c * 13) ^ idx) & 0xFF;
    return (mix % 3) != 0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_gridSize, (r) {
          return Expanded(
            child: Row(
              children: List.generate(_gridSize, (c) {
                final dark = _moduleDark(r, c);
                return Expanded(
                  child: ColoredBox(
                    color: dark ? AppColors.textPrimary : AppColors.white,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
