import 'package:flutter/material.dart';

class StagePhotoGalleryPage extends StatefulWidget {
  const StagePhotoGalleryPage({
    super.key,
    required this.title,
    required this.photoUrls,
    required this.initialIndex,
  });

  final String title;
  final List<String> photoUrls;
  final int initialIndex;

  @override
  State<StagePhotoGalleryPage> createState() => _StagePhotoGalleryPageState();
}

class _StagePhotoGalleryPageState extends State<StagePhotoGalleryPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.title} (${_index + 1}/${widget.photoUrls.length})'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photoUrls.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 0.7,
            maxScale: 5,
            child: Center(
              child: Image.network(
                widget.photoUrls[i],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 56),
              ),
            ),
          );
        },
      ),
    );
  }
}
