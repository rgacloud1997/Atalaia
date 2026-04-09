import 'package:flutter/widgets.dart';

class YoutubeEmbedView extends StatelessWidget {
  const YoutubeEmbedView({super.key, required this.videoId, this.autoplay = true});

  final String videoId;
  final bool autoplay;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
