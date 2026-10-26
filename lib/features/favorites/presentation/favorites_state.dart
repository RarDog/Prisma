import 'package:prisma_app/backend/backend.dart';

class FavoritesState {
  const FavoritesState({this.posts = const []});
  final List<Post> posts;
}
