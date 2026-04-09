import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class YoutubeEmbedView extends StatefulWidget {
  const YoutubeEmbedView({super.key, required this.videoId, this.autoplay = true});

  final String videoId;
  final bool autoplay;

  @override
  State<YoutubeEmbedView> createState() => _YoutubeEmbedViewState();
}

class _YoutubeEmbedViewState extends State<YoutubeEmbedView> {
  static var _counter = 0;

  late final String _viewType = 'yt-embed-${widget.videoId}-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  @override
  void initState() {
    super.initState();
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final autoplay = widget.autoplay ? '1' : '0';
      final src = 'https://www.youtube.com/embed/${widget.videoId}?autoplay=$autoplay&controls=1&fs=1&rel=0&playsinline=1';
      final element = web.HTMLIFrameElement()
        ..src = src
        ..setAttribute('style', 'border:0; width:100%; height:100%;')
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
      return element;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
