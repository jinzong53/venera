import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:venera/utils/io.dart';
import 'package:path/path.dart' as p;
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/app.dart';
import 'package:crypto/crypto.dart';

import 'package:uuid/uuid.dart';

class AnnotationItem {
  final String id;
  final String type;
  final Color color;

  AnnotationItem({
    String? id,
    required this.type,
    required this.color,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'color': color.value,
  };

  factory AnnotationItem.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'text') {
      return TextAnnotation.fromJson(json);
    } else if (json['type'] == 'line') {
      return LineAnnotation.fromJson(json);
    }
    throw Exception('Unknown annotation type');
  }
}

class TextAnnotation extends AnnotationItem {
  final String text;
  final Offset position;
  final double fontSize;
  final double? width;

  TextAnnotation({
    super.id,
    required this.text,
    required this.position,
    required super.color,
    this.fontSize = 20.0,
    this.width,
  }) : super(type: 'text');

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'text': text,
    'dx': position.dx,
    'dy': position.dy,
    'fontSize': fontSize,
    'width': width,
  };

  factory TextAnnotation.fromJson(Map<String, dynamic> json) {
    return TextAnnotation(
      id: json['id'],
      text: json['text'],
      position: Offset((json['dx'] as num).toDouble(), (json['dy'] as num).toDouble()),
      color: Color(json['color']),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 20.0,
      width: (json['width'] as num?)?.toDouble(),
    );
  }
}

class LineAnnotation extends AnnotationItem {
  final List<Offset> points;
  final double strokeWidth;

  LineAnnotation({
    super.id,
    required this.points,
    required this.strokeWidth,
    required super.color,
  }) : super(type: 'line');

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
    'strokeWidth': strokeWidth,
  };

  factory LineAnnotation.fromJson(Map<String, dynamic> json) {
    return LineAnnotation(
      points: (json['points'] as List)
          .map((p) => Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()))
          .toList(),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      color: Color(json['color']),
    );
  }
}

class PageAnnotations {
  final String comicId;
  final String chapterId;
  final int pageIndex;
  final List<AnnotationItem> items;

  PageAnnotations({
    required this.comicId,
    required this.chapterId,
    required this.pageIndex,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'comicId': comicId,
    'chapterId': chapterId,
    'pageIndex': pageIndex,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory PageAnnotations.fromJson(Map<String, dynamic> json) {
    return PageAnnotations(
      comicId: json['comicId'],
      chapterId: json['chapterId'],
      pageIndex: json['pageIndex'],
      items: (json['items'] as List)
          .map((e) => AnnotationItem.fromJson(e))
          .toList(),
    );
  }
}

class AnnotationManager with ChangeNotifier {
  static final AnnotationManager _instance = AnnotationManager._();
  factory AnnotationManager() => _instance;
  AnnotationManager._();

  final Map<String, PageAnnotations> _cache = {};

  String _getKey(String comicId, String chapterId, int pageIndex) {
    return '$comicId/$chapterId/$pageIndex';
  }
String _getSafePath(String id) {
    var bytes = utf8.encode(id);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  Future<PageAnnotations> getAnnotations(String comicId, String chapterId, int pageIndex) async {
    final key = _getKey(comicId, chapterId, pageIndex);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final file = File(p.join(App.dataPath, 'annotations', _getSafePath(comicId), _getSafePath(chapterId), '$pageIndex.json'));
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        if (content.trim().isEmpty) {
          return PageAnnotations(
            comicId: comicId,
            chapterId: chapterId,
            pageIndex: pageIndex,
            items: [],
          );
        }
        final json = jsonDecode(content);
        final annotations = PageAnnotations.fromJson(json);
        _cache[key] = annotations;
        return annotations;
      } catch (e) {
        // Return empty annotations on error
        return PageAnnotations(
          comicId: comicId,
          chapterId: chapterId,
          pageIndex: pageIndex,
          items: [],
        );
      }
    }

    final newAnnotations = PageAnnotations(
      comicId: comicId,
      chapterId: chapterId,
      pageIndex: pageIndex,
      items: [],
    );
    _cache[key] = newAnnotations;
    return newAnnotations;
  }
  Future<void> saveAnnotations(PageAnnotations annotations) async {
    final key = _getKey(annotations.comicId, annotations.chapterId, annotations.pageIndex);
    _cache[key] = annotations;
    notifyListeners();

    final file = File(p.join(App.dataPath, 'annotations', _getSafePath(annotations.comicId), _getSafePath(annotations.chapterId), '${annotations.pageIndex}.json'));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(annotations.toJson()));
  }

  void undo(String comicId, String chapterId, int pageIndex) {
    final key = _getKey(comicId, chapterId, pageIndex);
    if (_cache.containsKey(key)) {
      final annotations = _cache[key]!;
      if (annotations.items.isNotEmpty) {
        annotations.items.removeLast();
        saveAnnotations(annotations);
      }
    }
  }
}
