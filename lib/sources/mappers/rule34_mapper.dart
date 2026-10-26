import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/sources/mappers/gelbooru_mapper.dart';

class Rule34Mapper {
  static List<Post> postsFromResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
  }) {
    return GelbooruMapper.postsFromResponse(
      data,
      providerId: providerId,
      providerName: providerName,
    );
  }
}
