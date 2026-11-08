import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:gel_rule_app/core/models/post.dart';

/// Resolves appropriate HTTP request headers (Referer, User-Agent, Accept)
/// required for fetching media from imageboards, manga portals, and cloud providers.
Map<String, String> getMediaUrlHeaders({
  String? providerId,
  String? url,
  Map<String, String>? extraHeaders,
  bool isVideo = false,
}) {
  String? defaultReferer;
  final pid = (providerId ?? '').toLowerCase();
  final u = (url ?? '').toLowerCase();

  if (pid.contains('gelbooru') || u.contains('gelbooru.com')) {
    defaultReferer = 'https://gelbooru.com/';
  } else if (pid.contains('tbib') || u.contains('tbib.org')) {
    defaultReferer = 'https://tbib.org/';
  } else if (pid.contains('safebooru') || u.contains('safebooru.org')) {
    defaultReferer = 'https://safebooru.org/';
  } else if (pid.contains('rule34_us') || u.contains('rule34.us')) {
    defaultReferer = 'https://rule34.us/';
  } else if (pid.contains('rule34') || u.contains('rule34.xxx')) {
    defaultReferer = 'https://rule34.xxx/';
  } else if (pid.contains('realbooru') || u.contains('realbooru.com')) {
    defaultReferer = 'https://realbooru.com/';
  } else if (pid.contains('wallhaven') || u.contains('wallhaven.cc')) {
    defaultReferer = 'https://wallhaven.cc/';
  } else if (pid.contains('arena') || u.contains('are.na')) {
    defaultReferer = 'https://www.are.na/';
  } else if (pid.contains('danbooru') || u.contains('donmai.us')) {
    defaultReferer = 'https://danbooru.donmai.us/';
  } else if (pid.contains('yande.re') || u.contains('yande.re')) {
    defaultReferer = 'https://yande.re/';
  } else if (pid.contains('konachan') || u.contains('konachan')) {
    defaultReferer = 'https://konachan.net/';
  } else if (pid.contains('e621') ||
      pid.contains('e926') ||
      u.contains('e621.net')) {
    defaultReferer = 'https://e621.net/';
  } else if (pid.contains('pixiv') || u.contains('pximg.net')) {
    defaultReferer = 'https://www.pixiv.net/';
  } else if (pid.contains('nhentai') || u.contains('nhentai.net')) {
    defaultReferer = 'https://nhentai.net/';
  } else if (pid.contains('mangadex') ||
      u.contains('mangadex.org') ||
      u.contains('mangadex.network')) {
    defaultReferer = 'https://mangadex.org/';
  } else if (pid.contains('mangalib') ||
      u.contains('mangalib.me') ||
      u.contains('imglib.info')) {
    defaultReferer = 'https://mangalib.me/';
  } else if (pid.contains('ranobelib') || u.contains('ranobelib.me')) {
    defaultReferer = 'https://ranobelib.me/';
  } else if (pid.contains('pawchive') || u.contains('pawchive.pw')) {
    defaultReferer = 'https://pawchive.pw/';
  } else if (pid.contains('hitomi') ||
      u.contains('hitomi.la') ||
      u.contains('gold-usergeneratedcontent.net')) {
    defaultReferer = 'https://hitomi.la/';
  } else if (pid.contains('ehentai') ||
      u.contains('e-hentai.org') ||
      u.contains('ehgt.org')) {
    defaultReferer = 'https://e-hentai.org/';
  } else if (pid.contains('mangaupdates') || u.contains('mangaupdates.com')) {
    defaultReferer = 'https://www.mangaupdates.com/';
  } else if (url != null && url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      defaultReferer = '${uri.scheme}://${uri.host}/';
    }
  }

  final isDanbooruOrPawchive = pid.contains('danbooru') ||
      u.contains('donmai.us') ||
      pid.contains('pawchive') ||
      u.contains('pawchive.pw');
  final userAgent = isDanbooruOrPawchive
      ? AppHeaders.defaultUserAgent
      : AppHeaders.desktopChromeUserAgent;

  return {
    'User-Agent': userAgent,
    'Accept': isVideo
        ? 'video/webm,video/mp4,video/*;q=0.9,*/*;q=0.8'
        : 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    if (defaultReferer != null) 'Referer': defaultReferer,
    if (extraHeaders != null) ...extraHeaders,
  };
}

/// Resolves standard media headers for [post] with optional extra overrides.
Map<String, String> getPostMediaHeaders(
  Post post, [
  Map<String, String>? extraHeaders,
]) {
  final url = post.fileUrl.isNotEmpty
      ? post.fileUrl
      : (post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl);
  final isVideo = post.fileType.toLowerCase() == 'mp4' ||
      post.fileType.toLowerCase() == 'webm' ||
      post.fileUrl.endsWith('.mp4') ||
      post.fileUrl.endsWith('.webm') ||
      post.sampleUrl.endsWith('.mp4') ||
      post.sampleUrl.endsWith('.webm');
  return getMediaUrlHeaders(
    providerId: post.providerId,
    url: url,
    extraHeaders: extraHeaders,
    isVideo: isVideo,
  );
}
