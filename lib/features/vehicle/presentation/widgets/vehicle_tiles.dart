import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/vehicle/domain/vehicle_type.dart';

export 'package:the_audit/features/vehicle/domain/vehicle_type.dart';

// Shared vehicle visuals: the type images, the dark blue hexagon tile, the
// carousel arrows / dots, and a single-select carousel of given vehicles.

/// Dark blue hexagon showing a vehicle type's image (or [icon] when the type
/// is unknown / for the add card).
class VehicleHexTile extends StatelessWidget {
  final VehicleType? type;
  final bool isSelected;
  final IconData icon;

  const VehicleHexTile({
    required this.type,
    required this.isSelected,
    this.icon = Icons.flight,
  });

  @override
  Widget build(BuildContext context) {
    final glyphColor = isSelected
        ? AppVehicleTile.selectedGlyph
        : AppVehicleTile.glyph;
    final image = type?.imageAsset;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      // Pointy-top regular hexagon: height = width * 2 / sqrt(3).
      width: 112,
      height: 129,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      decoration: ShapeDecoration(
        color: isSelected ? AppVehicleTile.selectedFill : AppVehicleTile.fill,
        shape: HexagonTileBorder(
          side: BorderSide(
            color: isSelected
                ? AppVehicleTile.selectedBorder
                : AppVehicleTile.border,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        shadows: isSelected
            ? const [
                BoxShadow(
                  color: AppVehicleTile.glow,
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppVehicleTile.selectedShadow,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: image == null
          ? Icon(icon, size: 44, color: glyphColor)
          : Stack(
              fit: StackFit.expand,
              children: [
                // Blurred copy of the drawing behind it gives the glow.
                if (isSelected)
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Image.asset(
                      image,
                      color: AppVehicleTile.glyphGlow,
                      fit: BoxFit.contain,
                    ),
                  ),
                Image.asset(image, color: glyphColor, fit: BoxFit.contain),
              ],
            ),
    );
  }
}

/// Pointy-top hexagon outline for the vehicle image tile.
class HexagonTileBorder extends ShapeBorder {
  final BorderSide side;

  const HexagonTileBorder({this.side = BorderSide.none});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final cx = rect.center.dx;
    final quarter = rect.height / 4;
    return Path()
      ..moveTo(cx, rect.top)
      ..lineTo(rect.right, rect.top + quarter)
      ..lineTo(rect.right, rect.bottom - quarter)
      ..lineTo(cx, rect.bottom)
      ..lineTo(rect.left, rect.bottom - quarter)
      ..lineTo(rect.left, rect.top + quarter)
      ..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      _path(rect.deflate(side.width / 2)),
      side.toPaint()..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  ShapeBorder scale(double t) => HexagonTileBorder(side: side.scale(t));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is HexagonTileBorder
      ? HexagonTileBorder(side: BorderSide.lerp(a.side, side, t))
      : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is HexagonTileBorder
      ? HexagonTileBorder(side: BorderSide.lerp(side, b.side, t))
      : super.lerpTo(b, t);

  @override
  bool operator ==(Object other) =>
      other is HexagonTileBorder && other.side == side;

  @override
  int get hashCode => side.hashCode;
}

class CarouselArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const CarouselArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        side: const BorderSide(color: AppColors.borderStrong),
      ),
    );
  }
}

class PageDots extends StatelessWidget {
  final int count;
  final int current;

  const PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    if (count > 8) {
      return Text('${current + 1} / $count', style: AppTextStyles.caption);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? AppColors.darkNavy : AppColors.borderStrong,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Single-select carousel of [vehicles] (e.g. the vehicles taken on a
/// session): tap a hexagon to pick it; the picked one glows.
class SessionVehiclePicker extends StatefulWidget {
  /// Vehicles in display order; [id] is what [onSelected] reports back.
  final List<({String id, String name, String type})> vehicles;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  /// Shown when [vehicles] is empty.
  final String emptyMessage;

  const SessionVehiclePicker({
    super.key,
    required this.vehicles,
    required this.selectedId,
    required this.onSelected,
    this.emptyMessage = 'No vehicles on this session.',
  });

  @override
  State<SessionVehiclePicker> createState() => _SessionVehiclePickerState();
}

class _SessionVehiclePickerState extends State<SessionVehiclePicker> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final count = widget.vehicles.length;
    if (count == 0) {
      return Text(widget.emptyMessage, style: AppTextStyles.secondary);
    }
    final page = _page.clamp(0, count - 1);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Row(
            children: [
              CarouselArrow(
                icon: Icons.chevron_left,
                tooltip: 'Previous',
                onPressed: page > 0 ? () => _goTo(page - 1) : null,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: count,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) {
                    final vehicle = widget.vehicles[index];
                    final type = VehicleType.fromDb(vehicle.type);
                    final isSelected = vehicle.id == widget.selectedId;
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: 'Fly ${vehicle.name}',
                      child: GestureDetector(
                        onTap: () => widget.onSelected(vehicle.id),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              vehicle.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.vehicleName,
                            ),
                            const SizedBox(height: 10),
                            VehicleHexTile(type: type, isSelected: isSelected),
                            const SizedBox(height: 10),
                            Text(
                              isSelected
                                  ? 'SELECTED'
                                  : '${type?.label.toUpperCase() ?? vehicle.type}'
                                        ' · TAP TO SELECT',
                              style: isSelected
                                  ? AppTextStyles.vehicleMeta.copyWith(
                                      color: AppColors.darkNavy,
                                    )
                                  : AppTextStyles.vehicleMeta,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              CarouselArrow(
                icon: Icons.chevron_right,
                tooltip: 'Next',
                onPressed: page < count - 1 ? () => _goTo(page + 1) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        PageDots(count: count, current: page),
      ],
    );
  }
}
