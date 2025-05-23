import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class FullScreenPlayerPage extends StatefulWidget {
  final dynamic movie;
  final List<Map<String, String>> episodes;
  final int initialIndex;

  const FullScreenPlayerPage({
    super.key,
    required this.movie,
    required this.episodes,
    required this.initialIndex,
  });

  @override
  State<FullScreenPlayerPage> createState() => _FullScreenPlayerPageState();
}

class _FullScreenPlayerPageState extends State<FullScreenPlayerPage> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  int _currentEpisodeIndex;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = true;
  bool _showEpisodeMenu = false;
  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _episodeMenuFocusNode = FocusNode();
  final ScrollController _episodeMenuScrollController = ScrollController();

  _FullScreenPlayerPageState() : _currentEpisodeIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentEpisodeIndex = widget.initialIndex;
    _initializePlayer(widget.episodes[_currentEpisodeIndex]['url']!);


    _playerFocusNode.addListener(() {
      if (_playerFocusNode.hasFocus) {
        setState(() {
          _showControls = true;
        });
        // Auto-hide controls after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_showEpisodeMenu) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    });

    _episodeMenuFocusNode.addListener(() {
      if (_episodeMenuFocusNode.hasFocus) {
        setState(() {
          _showControls = true;
          _showEpisodeMenu = true;
        });
      }
    });
  }

  void _controlWakelock(bool enable) async {
    try {
      enable ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Wakelock控制失败: $e');
    }
  }

  void _setupWakelockListener() {
    bool _wasPlaying = false;

    _controller.addListener(() {
      final isPlaying = _controller.value.isPlaying;
      if (_wasPlaying != isPlaying) {
        _wasPlaying = isPlaying;
        _controlWakelock(isPlaying); // 统一控制
      }
    });
  }


  @override
  void dispose() {
    WakelockPlus.disable().catchError((e) => debugPrint(e.toString()));
    _controller.dispose();
    _chewieController?.dispose();
    _playerFocusNode.dispose();
    _episodeMenuFocusNode.dispose();
    _episodeMenuScrollController.dispose();
    _controller.removeListener(() {});
    super.dispose();
  }

  Future<void> _initializePlayer(String url) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _controller = VideoPlayerController.network(url);
      await _controller.initialize();
      _setupWakelockListener();

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowedScreenSleep: false,
        showControls: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF0066FF),
          handleColor: const Color(0xFF0066FF),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[300]!,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '播放失败: ${e.toString()}';
        });
      }
    }
  }

  void _changeEpisode(int index) async {
    // 边界检查
    if (widget.episodes.isEmpty) return;
    if (index < 0 || index >= widget.episodes.length) return;
    if (index == _currentEpisodeIndex) {
      setState(() {
        _showEpisodeMenu = false;
      });
      _playerFocusNode.requestFocus();
      return;
    }

    final url = widget.episodes[index]['url'];
    if (url == null || url.isEmpty) {
      setState(() {
        _errorMessage = '无效的视频URL';
        _isLoading = false;
      });
      return;
    }

    // 释放旧资源
    try {
      await _controller?.pause();
      await _controller?.dispose();
      _chewieController?.dispose();
    } catch (e) {
      debugPrint('释放旧控制器错误: $e');
    }

    setState(() {
      _currentEpisodeIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _showEpisodeMenu = false;
    });

    try {
      // 初始化新控制器
      _controller = VideoPlayerController.network(url);
      await _controller.initialize();
      _setupWakelockListener();

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        // 其他配置...
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '播放失败: ${e.toString()}';
        });
      }
      debugPrint('初始化播放器错误: $e');
    }

    _playerFocusNode.requestFocus();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _seekForward() {
    final newPosition = _controller.value.position + const Duration(seconds: 10);
    _controller.seekTo(newPosition > _controller.value.duration
        ? _controller.value.duration
        : newPosition);
  }

  void _seekBackward() {
    final newPosition = _controller.value.position - const Duration(seconds: 10);
    _controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  void _increaseVolume() {
    _controller.setVolume(_controller.value.volume + 0.1);
  }

  void _decreaseVolume() {
    _controller.setVolume(_controller.value.volume - 0.1);
  }

  void _toggleEpisodeMenu() {
    setState(() {
      _showEpisodeMenu = !_showEpisodeMenu;
      if (_showEpisodeMenu) {
        _episodeMenuFocusNode.requestFocus();
      } else {
        _playerFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const UpIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const DownIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): const LeftIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): const RightIntent(),
          const SingleActivator(LogicalKeyboardKey.contextMenu): const MenuIntent(),
          const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
        },
        child: Actions(
          actions: {
            BackIntent: CallbackAction<BackIntent>(
              onInvoke: (intent) {
                if (_showEpisodeMenu) {
                  setState(() {
                    _showEpisodeMenu = false;
                    _playerFocusNode.requestFocus();
                  });
                } else {
                  Navigator.pop(context);
                }
                return null;
              },
            ),
          },
          child: Stack(
            children: [
              // Video player area
              Focus(
                autofocus: true,
                focusNode: _playerFocusNode,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.select) {
                      _togglePlayPause();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      _seekForward();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _seekBackward();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _increaseVolume();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _decreaseVolume();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
                      _toggleEpisodeMenu();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                      Navigator.pop(context);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 3)
                      : _errorMessage != null
                      ? Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white),
                  )
                      : Chewie(controller: _chewieController!),
                ),
              ),

              // Top gradient overlay
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom controls overlay
              if (_showControls && !_showEpisodeMenu)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Progress bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: const Color(0xFF0066FF),
                              bufferedColor: Colors.grey,
                              backgroundColor: Colors.grey[600]!,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Control buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left side controls
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _controller.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous,
                                        color: Colors.white, size: 24),
                                    onPressed: _currentEpisodeIndex > 0
                                        ? () => _changeEpisode(
                                        _currentEpisodeIndex - 1)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next,
                                        color: Colors.white, size: 24),
                                    onPressed: _currentEpisodeIndex <
                                        widget.episodes.length - 1
                                        ? () => _changeEpisode(
                                        _currentEpisodeIndex + 1)
                                        : null,
                                  ),
                                ],
                              ),
                              // Right side controls
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.volume_up,
                                        color: Colors.white, size: 24),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.list,
                                        color: Colors.white, size: 24),
                                    onPressed: _toggleEpisodeMenu,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

              // Right-side episode menu
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                right: _showEpisodeMenu ? 0 : -320,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        offset: const Offset(-8, 0),
                      ),
                    ],
                  ),
                  child: Focus(
                    focusNode: _episodeMenuFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          // Scroll up in episode list
                          if (_currentEpisodeIndex > 0) {
                            setState(() {
                              _currentEpisodeIndex--;
                            });
                            _episodeMenuScrollController.animateTo(
                              (_currentEpisodeIndex * 56.0).clamp(
                                0.0,
                                _episodeMenuScrollController.position
                                    .maxScrollExtent,
                              ),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                          return KeyEventResult.handled;
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.arrowDown) {
                          // Scroll down in episode list
                          if (_currentEpisodeIndex <
                              widget.episodes.length - 1) {
                            setState(() {
                              _currentEpisodeIndex++;
                            });
                            _episodeMenuScrollController.animateTo(
                              (_currentEpisodeIndex * 56.0).clamp(
                                0.0,
                                _episodeMenuScrollController.position
                                    .maxScrollExtent,
                              ),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                          return KeyEventResult.handled;
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.select) {
                          // Select current highlighted episode
                          _changeEpisode(_currentEpisodeIndex);
                          return KeyEventResult.handled;
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.contextMenu) {
                          // Close episode menu
                          _toggleEpisodeMenu();
                          return KeyEventResult.handled;
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.escape) {
                          // Close episode menu
                          _toggleEpisodeMenu();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: _toggleEpisodeMenu,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '选集',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium!
                                    .copyWith(color: Colors.white),
                              ),
                              const Spacer(),
                              Text(
                                '${_currentEpisodeIndex + 1}/${widget.episodes.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _episodeMenuScrollController,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: widget.episodes.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Material(
                                  color: _currentEpisodeIndex == index
                                      ? const Color(0xFF0066FF)
                                      .withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _changeEpisode(index),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          if (_currentEpisodeIndex == index)
                                            const Icon(
                                              Icons.play_arrow,
                                              color: Color(0xFF0066FF),
                                              size: 20,
                                            ),
                                          if (_currentEpisodeIndex == index)
                                            const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              widget.episodes[index]['title']!,
                                              style: TextStyle(
                                                color: _currentEpisodeIndex ==
                                                    index
                                                    ? const Color(0xFF0066FF)
                                                    : Colors.white,
                                                fontWeight:
                                                _currentEpisodeIndex == index
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Intents
class UpIntent extends Intent {
  const UpIntent();
}

class DownIntent extends Intent {
  const DownIntent();
}

class LeftIntent extends Intent {
  const LeftIntent();
}

class RightIntent extends Intent {
  const RightIntent();
}

class MenuIntent extends Intent {
  const MenuIntent();
}

class BackIntent extends Intent {
  const BackIntent();
}