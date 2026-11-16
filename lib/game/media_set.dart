/// The media a question or a Fragenhagel / last-team-standing item shows and
/// plays: any number of pictures, a sound and a video. Plain Dart.
///
/// Stored as `image` (the first picture, which older versions of the app
/// read), `images` (all of them, only when there are several), `music` and
/// `video`. If `image` no longer matches the first of `images`, an older
/// version changed the picture and that one counts.
library;

class MediaSet {
  const MediaSet({this.images = const [], this.music, this.video});

  static const MediaSet empty = MediaSet();

  final List<String> images;
  final String? music;

  /// A clip started, paused and stopped like [music]; it brings its own
  /// sound, so it plays instead.
  final String? video;

  String? get image => images.firstOrNull;

  /// Whether there is something to play: a sound or a clip.
  bool get hasSound => music != null || video != null;

  bool get isEmpty => images.isEmpty && !hasSound;

  Iterable<String> get paths => [...images, ?music, ?video];

  static String? _file(Object? v) => v is String && v.isNotEmpty ? v : null;

  /// The pictures stored in [data], first one first.
  static List<String> readImages(Map data) {
    final first = _file(data['image']);
    final all = data['images'] is List ? [for (final v in data['images'] as List) ?_file(v)] : const <String>[];
    if (all.isNotEmpty && all.first == first) return List.unmodifiable(all);
    return [?first];
  }

  static MediaSet fromMap(Object? data) {
    if (data is! Map) return empty;
    return MediaSet(images: readImages(data), music: _file(data['music']), video: _file(data['video']));
  }

  /// The fields to store; every one is written, so clearing one clears it.
  Map<String, dynamic> toMap() => {
    'image': image,
    'images': images.length > 1 ? images : null,
    'music': music,
    'video': video,
  };

  MediaSet copyWith({List<String>? images, Object? music = _keep, Object? video = _keep}) => MediaSet(
    images: images ?? this.images,
    music: music == _keep ? this.music : music as String?,
    video: video == _keep ? this.video : video as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaSet &&
      other.music == music &&
      other.video == video &&
      other.images.length == images.length &&
      [for (var i = 0; i < images.length; i++) other.images[i] == images[i]].every((same) => same);

  @override
  int get hashCode => Object.hash(Object.hashAll(images), music, video);
}

const Object _keep = Object();
