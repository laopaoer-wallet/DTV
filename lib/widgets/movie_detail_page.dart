import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:libretv_app/widgets/full_screen_player_page.dart';

class MovieDetailPage extends StatefulWidget {
  final dynamic movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  List<Map<String, String>> _episodes = [];
  final FocusNode _episodesFocusNode = FocusNode();
  final ScrollController _episodesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _parseEpisodes();
    _episodesFocusNode.addListener(() {
      if (_episodesFocusNode.hasFocus) {
        // Handle episodes list focus
      }
    });
  }

  @override
  void dispose() {
    _episodesFocusNode.dispose();
    _episodesScrollController.dispose();
    super.dispose();
  }

  void _parseEpisodes() {
    final playUrl = widget.movie['vod_play_url'];
    if (playUrl != null && playUrl is String) {
      final parts = playUrl.split('#');
      for (var part in parts) {
        final episodeParts = part.split('\$');
        if (episodeParts.length == 2) {
          _episodes.add({
            'title': episodeParts[0],
            'url': episodeParts[1],
          });
        }
      }
    }
    setState(() {});
  }

  void _playEpisode(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenPlayerPage(
          movie: widget.movie,
          episodes: _episodes,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.movie['vod_name'] ?? '未知标题',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie header
            Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withOpacity(0.8),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'poster-${widget.movie['vod_id']}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.movie['vod_pic'] ?? '',
                          width: 120,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surface,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surface,
                            child: const Center(
                              child: Icon(Icons.error_outline, size: 32),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.movie['vod_name'] ?? '未知标题',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (widget.movie['vod_year'] != null)
                                Chip(
                                  label: Text(widget.movie['vod_year']!),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (widget.movie['type_name'] != null)
                                Chip(
                                  label: Text(widget.movie['type_name']!),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (widget.movie['vod_remarks'] != null)
                                Chip(
                                  label: Text(widget.movie['vod_remarks']!),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '主演: ${widget.movie['vod_actor'] ?? '未知'}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '导演: ${widget.movie['vod_director'] ?? '未知'}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Description
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '剧情简介',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movie['vod_content'] ??
                        widget.movie['vod_blurb'] ??
                        '暂无简介',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),

            // Episodes
            if (_episodes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '选集',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: Focus(
                  focusNode: _episodesFocusNode,
                  child: ListView.builder(
                    controller: _episodesScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _episodes.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.select) {
                                _playEpisode(index);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => _playEpisode(index),
                            child: Text(
                              _episodes[index]['title']!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
