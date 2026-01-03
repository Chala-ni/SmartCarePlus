/// SMARTCARE+ MJPEG Stream Widget
/// 
/// Custom MJPEG stream viewer that works with http ^1.1.0
/// Displays MJPEG streams from the backend video service

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// MJPEG Stream Widget
/// 
/// Displays a live MJPEG stream from a given URL
class MjpegStream extends StatefulWidget {
  /// The stream URL (e.g., http://server:port/api/guardian/video/video_id)
  final String streamUrl;
  
  /// Whether the stream is live (auto-reconnect on error)
  final bool isLive;
  
  /// How to fit the image in the available space
  final BoxFit fit;
  
  /// Timeout for connection
  final Duration timeout;
  
  /// Widget to show while loading
  final Widget? loadingWidget;
  
  /// Widget builder for error state
  final Widget Function(BuildContext context, dynamic error)? errorBuilder;
  
  /// Callback when stream starts
  final VoidCallback? onStreamStart;
  
  /// Callback when stream errors
  final void Function(dynamic error)? onError;
  
  const MjpegStream({
    super.key,
    required this.streamUrl,
    this.isLive = true,
    this.fit = BoxFit.cover,
    this.timeout = const Duration(seconds: 10),
    this.loadingWidget,
    this.errorBuilder,
    this.onStreamStart,
    this.onError,
  });

  @override
  State<MjpegStream> createState() => _MjpegStreamState();
}

class _MjpegStreamState extends State<MjpegStream> {
  http.Client? _client;
  Uint8List? _currentFrame;
  bool _isLoading = true;
  dynamic _error;
  bool _disposed = false;
  StreamSubscription? _subscription;
  
  // JPEG markers
  static const int _jpegStart1 = 0xFF;
  static const int _jpegStart2 = 0xD8;
  static const int _jpegEnd1 = 0xFF;
  static const int _jpegEnd2 = 0xD9;
  
  @override
  void initState() {
    super.initState();
    _startStream();
  }
  
  @override
  void didUpdateWidget(MjpegStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }
  
  @override
  void dispose() {
    _disposed = true;
    _stopStream();
    super.dispose();
  }
  
  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }
  
  Future<void> _startStream() async {
    if (_disposed) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      _client = http.Client();
      
      debugPrint('🎬 MJPEG: Connecting to ${widget.streamUrl}');
      
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['Connection'] = 'keep-alive';
      
      final streamedResponse = await _client!.send(request).timeout(widget.timeout);
      
      if (streamedResponse.statusCode != 200) {
        throw Exception('HTTP ${streamedResponse.statusCode}');
      }
      
      debugPrint('🎬 MJPEG: Connected! Content-Type: ${streamedResponse.headers['content-type']}');
      
      if (!_disposed && mounted) {
        setState(() => _isLoading = false);
        widget.onStreamStart?.call();
      }
      
      // Parse MJPEG stream
      _parseStream(streamedResponse.stream);
      
    } catch (e) {
      debugPrint('❌ MJPEG Error: $e');
      if (!_disposed && mounted) {
        setState(() {
          _isLoading = false;
          _error = e;
        });
        widget.onError?.call(e);
      }
    }
  }
  
  void _parseStream(Stream<List<int>> stream) {
    final buffer = BytesBuilder();
    bool inJpeg = false;
    
    _subscription = stream.listen(
      (List<int> chunk) {
        if (_disposed) return;
        
        for (int i = 0; i < chunk.length; i++) {
          final byte = chunk[i];
          
          // Look for JPEG start marker (0xFFD8)
          if (!inJpeg && byte == _jpegStart1 && i + 1 < chunk.length && chunk[i + 1] == _jpegStart2) {
            inJpeg = true;
            buffer.clear();
            buffer.addByte(byte);
          } else if (inJpeg) {
            buffer.addByte(byte);
            
            // Look for JPEG end marker (0xFFD9)
            if (byte == _jpegEnd2 && buffer.length >= 2) {
              final bytes = buffer.toBytes();
              if (bytes.length >= 2 && bytes[bytes.length - 2] == _jpegEnd1) {
                // Complete JPEG frame
                if (mounted && !_disposed) {
                  setState(() {
                    _currentFrame = Uint8List.fromList(bytes);
                  });
                }
                buffer.clear();
                inJpeg = false;
              }
            }
          }
        }
      },
      onError: (e) {
        debugPrint('❌ MJPEG Stream Error: $e');
        if (!_disposed && mounted) {
          setState(() => _error = e);
          widget.onError?.call(e);
          
          // Auto-reconnect if live
          if (widget.isLive) {
            Future.delayed(const Duration(seconds: 2), () {
              if (!_disposed && mounted) {
                _startStream();
              }
            });
          }
        }
      },
      onDone: () {
        debugPrint('🎬 MJPEG Stream ended');
        if (widget.isLive && !_disposed && mounted) {
          // Auto-reconnect
          Future.delayed(const Duration(seconds: 1), () {
            if (!_disposed && mounted) {
              _startStream();
            }
          });
        }
      },
      cancelOnError: false,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error) ?? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text('Stream Error: $_error', textAlign: TextAlign.center),
          ],
        ),
      );
    }
    
    if (_currentFrame == null) {
      return widget.loadingWidget ?? const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      gaplessPlayback: true, // Prevents flickering between frames
    );
  }
}
