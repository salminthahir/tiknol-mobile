import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme.dart';

class ImageCropDialog extends StatefulWidget {
  final File imageFile;

  const ImageCropDialog({super.key, required this.imageFile});

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final _cropController = CropController();
  bool _showGrid = true;
  bool _isCropping = false;
  Uint8List? _imageData;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    if (mounted) {
      setState(() {
        _imageData = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 500,
        height: 600, // Fixed height for popup
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Potong Foto Produk (1:1)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 20),
                    color: Colors.grey.shade600,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Cropper Area
            Expanded(
              child: Stack(
                children: [
                  if (_imageData == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    Crop(
                      image: _imageData!,
                      controller: _cropController,
                      onCropped: (result) async {
                        if (result is CropSuccess) {
                          try {
                            final tempDir = await getTemporaryDirectory();
                            final tempFile = File(
                              '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
                            );
                            await tempFile.writeAsBytes(result.croppedImage);
                            if (mounted && context.mounted) {
                              Navigator.of(context).pop(tempFile);
                            }
                          } catch (e) {
                            if (mounted) {
                              _showError('Gagal menyimpan foto hasil crop.');
                            }
                          }
                        } else if (result is CropFailure) {
                          if (mounted) {
                            _showError('Gagal memotong foto.');
                          }
                        }
                        if (mounted) {
                          setState(() => _isCropping = false);
                        }
                      },
                      aspectRatio: 1.0,
                      interactive: true,
                      baseColor: const Color(0xFF1E1E24),
                      maskColor: Colors.black.withValues(alpha: 0.6),
                      overlayBuilder: (context, rect) {
                        if (!_showGrid) return const SizedBox.shrink();
                        return CustomPaint(
                          painter: RulerGridPainter(rect: rect),
                        );
                      },
                      cornerDotBuilder: (size, edgeAlignment) =>
                          const SizedBox.shrink(),
                    ),

                  // Loading Overlay (When cropping)
                  if (_isCropping)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            // Footer / Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.ruler,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tampilkan Grid & Ruler',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _showGrid,
                        onChanged: (val) {
                          setState(() => _showGrid = val);
                        },
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isCropping
                              ? null
                              : () {
                                  setState(() => _isCropping = true);
                                  _cropController.crop();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Gunakan Foto',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class RulerGridPainter extends CustomPainter {
  final Rect rect;

  RulerGridPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // We draw inside the crop area only. 
    // The provided 'rect' is already sized to the crop window relative to this overlay.
    // Wait, the overlayBuilder passes 'rect' which is the viewport of the crop.
    // Actually, in crop_your_image's overlayBuilder, the context is wrapped tightly around the crop rect.
    // So the Size of the canvas is exactly the size of the crop rect.
    
    // Draw 3x3 Rule of Thirds grid
    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;

    // Vertical lines
    canvas.drawLine(Offset(cellWidth, 0), Offset(cellWidth, size.height), linePaint);
    canvas.drawLine(Offset(cellWidth * 2, 0), Offset(cellWidth * 2, size.height), linePaint);

    // Horizontal lines
    canvas.drawLine(Offset(0, cellHeight), Offset(size.width, cellHeight), linePaint);
    canvas.drawLine(Offset(0, cellHeight * 2), Offset(size.width, cellHeight * 2), linePaint);

    // Draw Ruler Ticks on the Top edge
    final numTicksX = 20; // How many ticks across the width
    final tickSpacingX = size.width / numTicksX;
    for (int i = 0; i <= numTicksX; i++) {
      double x = i * tickSpacingX;
      double tickLength = (i % 5 == 0) ? 12.0 : 6.0;
      canvas.drawLine(Offset(x, 0), Offset(x, tickLength), tickPaint);
    }

    // Draw Ruler Ticks on the Left edge
    final numTicksY = 20; // How many ticks across the height
    final tickSpacingY = size.height / numTicksY;
    for (int i = 0; i <= numTicksY; i++) {
      double y = i * tickSpacingY;
      double tickLength = (i % 5 == 0) ? 12.0 : 6.0;
      canvas.drawLine(Offset(0, y), Offset(tickLength, y), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RulerGridPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
