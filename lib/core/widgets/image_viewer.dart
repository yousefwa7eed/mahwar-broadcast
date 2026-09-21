import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// عارض صور بملء الشاشة مع إمكانية التنقل بين الصور والتكبير.
class ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const ImageViewerScreen({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.urls.length}',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.urls[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.orangePrimary),
                      );
                    },
                    errorBuilder: (context, error, stack) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.white54),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// يفتح عارض الصور بملء الشاشة.
void showAttachmentsViewer(BuildContext context, List<String> urls, [int index = 0]) {
  if (urls.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ImageViewerScreen(urls: urls, initialIndex: index),
    ),
  );
}