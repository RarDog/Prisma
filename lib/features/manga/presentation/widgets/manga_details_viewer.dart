import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prisma_app/backend/backend.dart';
import 'page_flip_3d.dart';

class MangaDetailsViewer extends StatelessWidget {
  const MangaDetailsViewer({
    super.key,
    required this.post,
    this.headers,
    required this.loadingPages,
    required this.pageUrls,
    required this.currentPage,
    required this.totalPages,
    required this.isRtl,
    required this.flipKey,
    required this.onPageChanged,
    required this.onEndReached,
    required this.onToggleRtl,
    required this.onReadFullscreen,
  });

  final Post post;
  final Map<String, String>? headers;
  final bool loadingPages;
  final List<String> pageUrls;
  final int currentPage;
  final int totalPages;
  final bool isRtl;
  final GlobalKey<PageFlip3DState> flipKey;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onEndReached;
  final VoidCallback onToggleRtl;
  final VoidCallback onReadFullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRect(
      child: Container(
        height: 440,
        color: Colors.black,
        child: Stack(
          children: [
            // Cinematic ambient cover blur backdrop
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.sampleUrl.isNotEmpty
                          ? post.sampleUrl
                          : post.previewUrl,
                      httpHeaders: headers,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            theme.scaffoldBackgroundColor
                                .withValues(alpha: 0.8),
                            theme.scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.45, 0.88, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (loadingPages)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6740)),
              )
            else
              Positioned.fill(
                child: PageFlip3D(
                  key: flipKey,
                  itemCount: totalPages,
                  isRtl: isRtl,
                  initialIndex: currentPage,
                  onPageChanged: onPageChanged,
                  onEndReached: onEndReached,
                  itemBuilder: (context, index) {
                    final url = pageUrls.isNotEmpty && index < pageUrls.length
                        ? pageUrls[index]
                        : (post.sampleUrl.isNotEmpty
                            ? post.sampleUrl
                            : post.previewUrl);
                    return Center(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        httpHeaders: headers,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white24),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: Colors.white38, size: 48),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Top controls overlay: Page count & Fullscreen toggle
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '${currentPage + 1} / $totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onToggleRtl();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Icon(
                            isRtl
                                ? Icons.format_textdirection_r_to_l_rounded
                                : Icons.format_textdirection_l_to_r_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onReadFullscreen,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF6740).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.fullscreen_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tap helpers (invisible left & right tap zones)
            Positioned(
              left: 0,
              top: 50,
              bottom: 0,
              width: 70,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => flipKey.currentState?.previousPage(),
              ),
            ),
            Positioned(
              right: 0,
              top: 50,
              bottom: 0,
              width: 70,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => flipKey.currentState?.nextPage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
