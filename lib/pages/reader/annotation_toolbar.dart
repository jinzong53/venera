part of 'reader.dart';

class AnnotationToolbar extends StatefulWidget {
  const AnnotationToolbar({super.key});

  @override
  State<AnnotationToolbar> createState() => _AnnotationToolbarState();
}

class _AnnotationToolbarState extends State<AnnotationToolbar> {
  @override
  Widget build(BuildContext context) {
    final reader = context.reader;
    
    return GestureDetector(
      onPanUpdate: (details) {
        final currentPos = context.readerScaffold.annotationToolbarPosition;
        context.readerScaffold.updateAnnotationToolbarPosition(currentPos + details.delta);
      },
      child: _buildContent(reader),
    );
  }

  Widget _buildContent(_ReaderState reader) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const Icon(Icons.drag_handle, color: Colors.white54),
          const SizedBox(height: 8),
          
          // Tools
          IconButton(
            icon: Icon(Icons.edit,
                color: (reader.annotationTool == 'pen' || reader.annotationTool == 'eraser') ? Colors.blue : Colors.white),
            onPressed: () {
              setState(() => reader.annotationTool = 'pen');
              reader.annotationNotifier.notifyListeners();
            },
            tooltip: 'Pen',
          ),
          IconButton(
            icon: Icon(Icons.text_fields,
                color: reader.annotationTool == 'text' ? Colors.blue : Colors.white),
            onPressed: () {
              setState(() => reader.annotationTool = 'text');
              reader.annotationNotifier.notifyListeners();
            },
            tooltip: 'Text',
          ),
          
          const Divider(color: Colors.white24, height: 16),
          
          // Pen Settings (including Eraser)
          if (reader.annotationTool == 'pen' || reader.annotationTool == 'eraser') ...[
            IconButton(
              icon: Icon(Icons.cleaning_services,
                  color: reader.annotationTool == 'eraser' ? Colors.blue : Colors.white),
              onPressed: () {
                setState(() => reader.annotationTool = reader.annotationTool == 'eraser' ? 'pen' : 'eraser');
                reader.annotationNotifier.notifyListeners();
              },
              tooltip: 'Eraser',
            ),
            
            const SizedBox(height: 8),
            _buildColorPicker(reader),
            const SizedBox(height: 8),
            _buildStrokeWidthPicker(reader),
            const Divider(color: Colors.white24, height: 16),
          ],

          // Text Settings
          if (reader.annotationTool == 'text') ...[
            _buildColorPicker(reader),
            const SizedBox(height: 8),
            _buildFontSizePicker(reader),
            const Divider(color: Colors.white24, height: 16),
          ],

          // Undo Button
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: () {
              AnnotationManager().undo(reader.cid, reader.eid, reader.page);
            },
            tooltip: 'Undo',
          ),

          // Lock Scroll Button
          IconButton(
            icon: Icon(
              reader.isScrollLocked ? Icons.lock : Icons.lock_open,
              color: reader.isScrollLocked ? Colors.blue : Colors.white,
            ),
            onPressed: () {
              setState(() {
                reader.isScrollLocked = !reader.isScrollLocked;
              });
              reader.update();
            },
            tooltip: reader.isScrollLocked ? 'Unlock Scroll' : 'Lock Scroll',
          ),

          // Exit Button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              reader.toggleAnnotationMode();
            },
            tooltip: 'Exit Annotation Mode',
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(_ReaderState reader) {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.white,
      Colors.black
    ];
    
    return Column(
      children: colors.map((color) {
        return GestureDetector(
          onTap: () {
            setState(() => reader.annotationColor = color);
            reader.annotationNotifier.notifyListeners();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: reader.annotationColor == color ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrokeWidthPicker(_ReaderState reader) {
    return Column(
      children: [2.0, 4.0, 6.0, 8.0].map((width) {
        return GestureDetector(
          onTap: () {
            setState(() => reader.annotationStrokeWidth = width);
            reader.annotationNotifier.notifyListeners();
          },
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(12),
            child: Container(
              width: 24,
              height: 24,
              child: Center(
                child: Container(
                  width: width,
                  height: width,
                  decoration: BoxDecoration(
                    color: reader.annotationStrokeWidth == width ? Colors.white : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontSizePicker(_ReaderState reader) {
    return ValueListenableBuilder<double>(
      valueListenable: reader.annotationFontSize,
      builder: (context, currentSize, child) {
        return Column(
          children: [16.0, 20.0, 24.0, 32.0].map((size) {
            return GestureDetector(
              onTap: () {
                reader.annotationFontSize.value = size;
                reader.annotationNotifier.notifyListeners();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'A',
                  style: TextStyle(
                    color: currentSize == size ? Colors.white : Colors.grey,
                    fontSize: size,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
