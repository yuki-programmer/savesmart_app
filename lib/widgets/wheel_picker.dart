import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// 慣性スクロールを強化したFixedExtentScrollPhysics
/// 強くなぞると大きく動き、軽くなぞると少しだけ動く
class SmoothFixedExtentScrollPhysics extends FixedExtentScrollPhysics {
  final double itemHeight;

  const SmoothFixedExtentScrollPhysics({
    super.parent,
    this.itemHeight = 48.0,
  });

  @override
  SmoothFixedExtentScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothFixedExtentScrollPhysics(
      parent: buildParent(ancestor),
      itemHeight: itemHeight,
    );
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // 速度が非常に小さい場合は通常のスナップ動作
    if (velocity.abs() < 50) {
      return super.createBallisticSimulation(position, velocity);
    }

    // 速度に基づいて目標位置を計算
    final target = _getTargetPixels(position, velocity);

    if ((target - position.pixels).abs() < 1.0) {
      return super.createBallisticSimulation(position, velocity);
    }

    // スプリングシミュレーションで滑らかに移動
    const spring = SpringDescription(
      mass: 0.3,
      stiffness: 100.0,
      damping: 1.0,
    );

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
    );
  }

  double _getTargetPixels(ScrollMetrics position, double velocity) {
    // 速度に基づいて移動距離を計算（強くなぞると遠くまで）
    // velocity: ピクセル/秒
    final double velocityItems = velocity / itemHeight;

    // 速度に応じたアイテム数（非線形で大きい速度ほど効果的）
    final double itemsToMove = velocityItems * 0.15;

    final double currentItem = position.pixels / itemHeight;
    double targetItem = currentItem - itemsToMove;

    // 最も近い整数にスナップ
    targetItem = targetItem.roundToDouble();

    // 範囲制限
    final maxItem = position.maxScrollExtent / itemHeight;
    targetItem = targetItem.clamp(0.0, maxItem);

    return targetItem * itemHeight;
  }
}

class WheelPicker extends StatefulWidget {
  final int unit;
  final int maxMultiplier;
  final Function(int value) onChanged;
  final int initialValue;
  final Color highlightColor;

  const WheelPicker({
    super.key,
    required this.unit,
    this.maxMultiplier = 100,
    required this.onChanged,
    this.initialValue = 0,
    this.highlightColor = AppColors.accentGreenLight,
  });

  @override
  State<WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<WheelPicker> {
  late FixedExtentScrollController _scrollController;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialValue ~/ widget.unit;
    _scrollController = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatValue(int index) {
    final value = index * widget.unit;
    return '¥$value';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // 中央ハイライト背景
          Center(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: widget.highlightColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // ホイールピッカー
          ListWheelScrollView.useDelegate(
            controller: _scrollController,
            itemExtent: 48,
            perspective: 0.005,
            diameterRatio: 1.5,
            physics: const SmoothFixedExtentScrollPhysics(itemHeight: 48.0),
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
              widget.onChanged(index * widget.unit);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.maxMultiplier + 1,
              builder: (context, index) {
                final isSelected = index == _selectedIndex;
                return Center(
                  child: Text(
                    _formatValue(index),
                    style: isSelected
                        ? GoogleFonts.ibmPlexSans(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          )
                        : GoogleFonts.ibmPlexSans(
                            fontSize: 20,
                            fontWeight: FontWeight.normal,
                            color: AppColors.textMuted,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
