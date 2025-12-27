import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:venera/foundation/annotation.dart';

class AnnotationLayer extends StatefulWidget {
  final Widget? child;
  final String comicId;
  final String chapterId;
  final int pageIndex;
  final bool isEditing;
  final String selectedTool;
  final Color selectedColor;
  final double strokeWidth;
  final ValueNotifier<double> fontSizeNotifier;

  const AnnotationLayer({
    super.key,
    this.child,
    required this.comicId,
    required this.chapterId,
    required this.pageIndex,
    required this.isEditing,
    required this.selectedTool,
    required this.selectedColor,
    required this.strokeWidth,
    required this.fontSizeNotifier,
  });

  @override
  State<AnnotationLayer> createState() => _AnnotationLayerState();
}

class _AnnotationLayerState extends State<AnnotationLayer> {
  PageAnnotations? _annotations;
  List<Offset>? _currentLine;
  String? _editingTextId;

  @override
  void initState() {
    super.initState();
    _loadAnnotations();
    AnnotationManager().addListener(_onAnnotationUpdate);
  }

  @override
  void dispose() {
    AnnotationManager().removeListener(_onAnnotationUpdate);
    super.dispose();
  }

  void _onAnnotationUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant AnnotationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comicId != widget.comicId ||
        oldWidget.chapterId != widget.chapterId ||
        oldWidget.pageIndex != widget.pageIndex) {
      _loadAnnotations();
    }
    if (!widget.isEditing) {
      setState(() {
        _editingTextId = null;
      });
    }
  }

  void _loadAnnotations() async {
    final annotations = await AnnotationManager().getAnnotations(
      widget.comicId,
      widget.chapterId,
      widget.pageIndex,
    );
    if (mounted) {
      setState(() {
        _annotations = annotations;
      });
    }
  }

  void _save() {
    if (_annotations != null) {
      AnnotationManager().saveAnnotations(_annotations!);
    }
  }

  void _eraseAt(Offset position, Size size) {
    if (_annotations == null) return;
    
    final toRemove = <AnnotationItem>[];
    for (var item in _annotations!.items) {
      if (item is LineAnnotation) {
        if (_isPointNearLine(position, item, size)) {
          toRemove.add(item);
        }
      }
    }
    
    if (toRemove.isNotEmpty) {
      setState(() {
        _annotations!.items.removeWhere((e) => toRemove.contains(e));
      });
      _save();
    }
  }

  bool _isPointNearLine(Offset point, LineAnnotation line, Size size) {
    const double threshold = 20.0;
    if (line.points.isEmpty) return false;
    
    final points = line.points.map((p) => _denormalize(p, size)).toList();

    for (int i = 0; i < points.length - 1; i++) {
      if (_distanceToSegment(point, points[i], points[i + 1]) < threshold) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final double l2 = (a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy);
    if (l2 == 0) return _distance(p, a);
    
    final double t = ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    if (t < 0) return _distance(p, a);
    if (t > 1) return _distance(p, b);
    
    final Offset projection = Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy));
    return _distance(p, projection);
  }

  double _distance(Offset a, Offset b) {
    return math.sqrt((a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy));
  }

  void _updateTextAnnotation(TextAnnotation old, TextAnnotation newAnnotation) {
    setState(() {
      final index = _annotations!.items.indexOf(old);
      if (index != -1) {
        _annotations!.items[index] = newAnnotation;
      }
    });
    _save();
  }

  void _deleteAnnotation(AnnotationItem item) {
    setState(() {
      _annotations!.items.remove(item);
      if (item.id == _editingTextId) {
        _editingTextId = null;
      }
    });
    _save();
  }

  void _stopEditing() {
    if (_editingTextId != null) {
      final index = _annotations!.items.indexWhere((e) => e.id == _editingTextId);
      if (index != -1) {
        final item = _annotations!.items[index];
        if (item is TextAnnotation && item.text.trim().isEmpty) {
          _annotations!.items.removeAt(index);
          _save();
        }
      }
      setState(() {
        _editingTextId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isEmpty) return widget.child ?? const SizedBox();

        return Stack(
          children: [
            if (widget.child != null) widget.child!,
            if (_annotations != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: AnnotationPainter(
                    annotations: _annotations!,
                    currentLine: _currentLine,
                    currentColor: widget.selectedColor,
                    currentStrokeWidth: widget.strokeWidth,
                    size: size,
                  ),
                ),
              ),
            if (widget.isEditing)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) {
                    if (_editingTextId != null) {
                      _stopEditing();
                      return;
                    }
                    if (widget.selectedTool == 'pen') {
                      setState(() {
                        _currentLine = [_normalize(details.localPosition, size)];
                      });
                    } else if (widget.selectedTool == 'eraser') {
                      _eraseAt(details.localPosition, size);
                    }
                  },
                  onPanUpdate: (details) {
                    if (_editingTextId != null) return;
                    if (widget.selectedTool == 'pen' && _currentLine != null) {
                      setState(() {
                        _currentLine!.add(_normalize(details.localPosition, size));
                      });
                    } else if (widget.selectedTool == 'eraser') {
                      _eraseAt(details.localPosition, size);
                    }
                  },
                  onPanEnd: (details) {
                    if (_editingTextId != null) return;
                    if (widget.selectedTool == 'pen' && _currentLine != null) {
                      setState(() {
                        _annotations!.items.add(LineAnnotation(
                          points: List.from(_currentLine!),
                          strokeWidth: widget.strokeWidth,
                          color: widget.selectedColor,
                        ));
                        _currentLine = null;
                      });
                      _save();
                    }
                  },
                  onTapUp: (details) {
                    if (_editingTextId != null) {
                      _stopEditing();
                      return;
                    }
                    if (widget.selectedTool == 'text') {
                      _createNewText(details.localPosition, size);
                    } else if (widget.selectedTool == 'eraser') {
                      _eraseAt(details.localPosition, size);
                    }
                  },
                ),
              ),
            if (_annotations != null)
              ..._annotations!.items.whereType<TextAnnotation>().map((text) {
                final position = _denormalize(text.position, size);
                if (text.id == _editingTextId) {
                  return Positioned(
                    left: position.dx - 24,
                    top: position.dy - 24,
                    child: _EditableTextWidget(
                      key: ValueKey(text.id),
                      annotation: text,
                      initialPosition: position,
                      size: size,
                      onUpdate: (updated) => _updateTextAnnotation(text, updated),
                      onDelete: () => _deleteAnnotation(text),
                      onBlur: _stopEditing,
                    ),
                  );
                }
                
                Widget textWidget = Container(
                  width: text.width,
                  color: Colors.transparent,
                  child: Text(
                    text.text,
                    style: TextStyle(
                      color: text.color,
                      fontSize: text.fontSize,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 3.0,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                );

                if (widget.isEditing) {
                  return Positioned(
                    left: position.dx,
                    top: position.dy,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (widget.selectedTool == 'eraser') {
                          _deleteAnnotation(text);
                        } else if (widget.selectedTool == 'text') {
                          setState(() {
                            _editingTextId = text.id;
                          });
                        }
                      },
                      child: textWidget,
                    ),
                  );
                } else {
                  return Positioned(
                    left: position.dx,
                    top: position.dy,
                    child: textWidget,
                  );
                }
              }),
          ],
        );
      },
    );
  }

  Offset _normalize(Offset offset, Size size) {
    return Offset(offset.dx / size.width, offset.dy / size.height);
  }

  Offset _denormalize(Offset offset, Size size) {
    if (offset.dx > 2.0 || offset.dy > 2.0) return offset;
    return Offset(offset.dx * size.width, offset.dy * size.height);
  }

  void _createNewText(Offset position, Size size) {
    final newText = TextAnnotation(
      text: '',
      position: _normalize(position, size),
      color: widget.selectedColor,
      fontSize: widget.fontSizeNotifier.value,
      width: 200.0,
    );
    setState(() {
      _annotations!.items.add(newText);
      _editingTextId = newText.id;
    });
    _save();
  }
}

class _EditableTextWidget extends StatefulWidget {
  final TextAnnotation annotation;
  final Offset initialPosition;
  final Size size;
  final Function(TextAnnotation) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onBlur;

  const _EditableTextWidget({
    super.key,
    required this.annotation,
    required this.initialPosition,
    required this.size,
    required this.onUpdate,
    required this.onDelete,
    required this.onBlur,
  });

  @override
  State<_EditableTextWidget> createState() => _EditableTextWidgetState();
}

class _EditableTextWidgetState extends State<_EditableTextWidget> {
  late TextEditingController _controller;
  late double _width;
  late Offset _currentPosition;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.annotation.text);
    _width = widget.annotation.width ?? 200.0;
    _currentPosition = widget.initialPosition;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        if (_controller.text.isEmpty) {
          widget.onDelete();
        } else {
          _update();
          // Optional: Exit editing mode on blur
          // widget.onBlur(); 
        }
      }
    });
  }

  @override
  void didUpdateWidget(_EditableTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPosition != widget.initialPosition) {
      // If the parent recalculates position (e.g. resize), update our local position
      // But only if we are not currently dragging? 
      // Actually, if we are dragging, we are updating _currentPosition.
      // If resize happens, we should probably respect the new denormalized position.
      _currentPosition = widget.initialPosition;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _update() {
    widget.onUpdate(TextAnnotation(
      id: widget.annotation.id,
      text: _controller.text,
      position: Offset(
        _currentPosition.dx / widget.size.width,
        _currentPosition.dy / widget.size.height,
      ),
      color: widget.annotation.color,
      fontSize: widget.annotation.fontSize,
      width: _width,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: _width,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 1),
              color: Colors.black.withOpacity(0.1),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              style: TextStyle(
                color: widget.annotation.color,
                fontSize: widget.annotation.fontSize,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black,
                  ),
                ],
              ),
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(4),
                isDense: true,
              ),
              onChanged: (value) {
                _update();
              },
            ),
          ),
        ),
        // Move Handle (Top Left)
        Positioned(
          left: 0,
          top: 0,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _currentPosition += details.delta;
              });
              _update();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.transparent, // Hit test area
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.open_with, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
        // Delete button (Top Right)
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.transparent, // Hit test area
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
        // Resize handle (Bottom Right)
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _width = math.max(50.0, _width + details.delta.dx);
              });
              _update();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.transparent, // Hit test area
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.drag_handle, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnnotationPainter extends CustomPainter {
  final PageAnnotations annotations;
  final List<Offset>? currentLine;
  final Color currentColor;
  final double currentStrokeWidth;
  final Size size;

  AnnotationPainter({
    required this.annotations,
    this.currentLine,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.size,
  });

  Offset _denormalize(Offset offset) {
    if (offset.dx > 2.0 || offset.dy > 2.0) return offset;
    return Offset(offset.dx * size.width, offset.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var item in annotations.items) {
      if (item is LineAnnotation) {
        final paint = Paint()
          ..color = item.color
          ..strokeWidth = item.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        if (item.points.length > 1) {
          final path = Path();
          final start = _denormalize(item.points.first);
          path.moveTo(start.dx, start.dy);
          for (int i = 1; i < item.points.length; i++) {
            final p = _denormalize(item.points[i]);
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, paint);
        } else if (item.points.isNotEmpty) {
          final points = item.points.map(_denormalize).toList();
          canvas.drawPoints(PointMode.points, points, paint);
        }
      }
    }

    if (currentLine != null && currentLine!.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final start = _denormalize(currentLine!.first);
      path.moveTo(start.dx, start.dy);
      for (int i = 1; i < currentLine!.length; i++) {
        final p = _denormalize(currentLine![i]);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return true;
  }
}
