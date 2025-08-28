// import 'dart:math';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:record/record.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'dart:async';
// import 'dart:typed_data';

// class AudioRecorderPage extends StatefulWidget {
//   const AudioRecorderPage({super.key});

//   @override
//   _AudioRecorderPageState createState() => _AudioRecorderPageState();
// }

// class _AudioRecorderPageState extends State<AudioRecorderPage> {
//   final AudioRecorder _recorder = AudioRecorder();
//   bool _isRecording = false;
//   WebSocketChannel? _channel;
//   final String _webSocketUrl = 'wss://dcapi.mo.vc/ws';
//   StreamSubscription<Uint8List>? _recorderSubscription;
//   StreamSubscription? _webSocketSubscription;
//   String _connectionStatus = 'Disconnected';
//   bool _isWebSocketConnected = false;
//   Timer? _connectionTimer;
//   List<String> _messages = [];
//   //store bytes from websocket 
//   List<Uint8List> _audioChunks = [];
//   static const double backGroundNoise = -25.0;
//   static const double humanVoice = -20.0;
//   static const double maxVoice = 5;

//   @override
//   void initState() {
//     super.initState();
//     _initializeRecorder();
//   }

//   Future<void> _initializeRecorder() async {
//     await Permission.microphone.request();
//   }

//   Future<void> _connectWebSocket() async {
//     try {
//       setState(() {
//         _connectionStatus = 'Connecting...';
//       });

//       _channel = WebSocketChannel.connect(Uri.parse(_webSocketUrl));

//       // Set up WebSocket listener
//       _webSocketSubscription = _channel!.stream.listen(
//         (event) {
//           print('WebSocket event: $event');
//           if (!_isWebSocketConnected && event is Uint8List) {
//             setState(() {
//               _isWebSocketConnected = true;
//               _connectionStatus = 'Connected';
//               _messages.add(event.toString());
//               //store audio bytes to list of strings
//               _audioChunks.add(event);
//             });
//           }
//         },
//         onDone: () {
//           setState(() {
//             _isWebSocketConnected = false;
//             _connectionStatus = 'Disconnected';
//           });
//           _cleanupWebSocket();
//         },
//         onError: (error) {
//           setState(() {
//             _isWebSocketConnected = false;
//             _connectionStatus = 'Connection Error: ${error.toString()}';
//           });
//           print('WebSocket error: $error');
//           _cleanupWebSocket();
//         },
//       );

//       // Check if connection is still alive
//       if (_channel?.closeCode == null) {
//         setState(() {
//           _isWebSocketConnected = true;
//           _connectionStatus = 'Connected';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _connectionStatus = 'Error: ${e.toString()}';
//         _isWebSocketConnected = false;
//       });
//       print('Error connecting WebSocket: $e');
//       _cleanupWebSocket();
//     }
//   }

//   void _cleanupWebSocket() {
//     _connectionTimer?.cancel();
//     _webSocketSubscription?.cancel();
//     _channel?.sink.close();
//     _channel = null;
//     _webSocketSubscription = null;
//     _connectionTimer = null;
//   }

//   Future<void> _startRecording() async {
//     try {
//       if (await _recorder.hasPermission()) {
//         // First connect to WebSocket
//         await _connectWebSocket();

//         // Wait for connection to be established
//         if (!_isWebSocketConnected) {
//           // Wait up to 5 seconds for connection
//           int attempts = 0;
//           while (!_isWebSocketConnected && attempts < 50) {
//             await Future.delayed(const Duration(milliseconds: 100));
//             attempts++;
//           }
//         }

//         if (!_isWebSocketConnected) {
//           setState(() {
//             _connectionStatus = 'Failed to connect to WebSocket';
//           });
//           return;
//         }

//         // Start recording
//         final stream = await _recorder.startStream(
//           const RecordConfig(
//             encoder: AudioEncoder.pcm16bits,
//             bitRate: 1411000,
//             sampleRate: 48000,
//             noiseSuppress: true,
//             echoCancel: false,          ),
//         );

//         // _messages.clear();

//         _recorderSubscription = stream.listen(
//           (Uint8List data) {
//            if (data.isNotEmpty) {
//              _sendBytes(data);
//             //  _messages.add(data.toString());
//             _audioChunks.addAll([data]);
//            }
//             print('Sent audio data: ${data.length} bytes');
//             if (kDebugMode) {
//               print('Audio data sample: ${data.toList()}');
//             }
//           },
//           onError: (error) {
//             print('Recording stream error: $error');
//             _stopRecording();
//           },
//         );

//         setState(() {
//           _isRecording = true;
//         });
//       } else {
//         setState(() {
//           _connectionStatus = 'Microphone permission not granted';
//         });
//         print('Microphone permission not granted');
//       }
//     } catch (e) {
//       setState(() {
//         _connectionStatus = 'Error: ${e.toString()}';
//       });
//       print('Error starting recording: $e');
//       _cleanupWebSocket();
//     }
//   }

//   Future<void> _stopRecording() async {
//     try {
//       await _recorder.stop();
//       await _recorderSubscription?.cancel();
//       await _webSocketSubscription?.cancel();

//       setState(() {
//         _isRecording = false;
//       });

//       // Close WebSocket connection
//       _cleanupWebSocket();

//       setState(() {
//         _connectionStatus = 'Disconnected';
//         _isWebSocketConnected = false;
//         _messages.clear();
//       });
//     } catch (e) { 
//       print('Error stopping recording: $e');
//     }
//   }

  
//   bool _isVoiceDetected(Uint8List audioData) {
//     List<double> samples = [];
//     for (int i = 0; i < audioData.length - 1; i += 2) {
//       int sample = (audioData[i + 1] << 8) | audioData[i];
//       if (sample > 32767) sample -= 65536;
//       samples.add(sample / 32768.0);
//     }

//     double sumSquares = 0.0;
//     for (double sample in samples) {
//       sumSquares += sample * sample;
//     }
//     double rms = sqrt(sumSquares / samples.length);
//     double decibels = 20 * log(rms + 1e-10) / ln10;

//     // Check if the sound is above background noise but below maximum threshold
//     bool isVoice = decibels > humanVoice && decibels <= maxVoice;

//     if (decibels < backGroundNoise) {
//       return false; // Ignore background noise
//     }

//     return isVoice;
//   }

//   void _sendBytes(Uint8List bytes) {
//     try {
//       if (_channel != null &&
//           _channel!.closeCode == null &&
//           _isWebSocketConnected) {
//         _channel!.sink.add(bytes);
//       } else {
//         print('WebSocket not connected, cannot send data');
//         if (!_isWebSocketConnected) {
//           setState(() {
//             _connectionStatus = 'WebSocket disconnected';
//           });
//         }
//       }
//     } catch (e) {
//       print('Error sending bytes: $e');
//       setState(() {
//         _connectionStatus = 'Send Error: ${e.toString()}';
//       }
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _recorderSubscription?.cancel();
//     _recorder.dispose();
//     _cleanupWebSocket();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Audio WebSocket Streamer',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.blue,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Expanded(
//               child: ListView.builder(
//                 itemCount: _messages.length,
//                 itemBuilder: (context, index) {
//                   return Text(
//                     _messages[index],
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 20),
//             ElevatedButton.icon(
//               onPressed: _isRecording ? _stopRecording : _startRecording,
//               icon: Icon(_isRecording ? Icons.stop : Icons.mic),
//               label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _isRecording ? Colors.red : Colors.green,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 24,
//                   vertical: 12,
//                 ),
//                 textStyle: const TextStyle(fontSize: 18),
//               ),
//             ),
//             const SizedBox(height: 20),
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: _getStatusColor(),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 'WebSocket Status: $_connectionStatus',
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//             if (_isRecording)
//               const CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//               ),
//             const SizedBox(height: 20),
//           ],
//         ),
//       ),
//     );
//   }

//   Color _getStatusColor() {
//     switch (_connectionStatus) {
//       case 'Connected':
//         return Colors.green;
//       case 'Connecting...':
//         return Colors.orange;
//       case 'Disconnected':
//         return Colors.grey;
//       default:
//         return Colors.red;
//     }
//   }
// }
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:typed_data';

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  _AudioRecorderPageState createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  WebSocketChannel? _channel;
  final String _webSocketUrl = 'wss://dcapi.mo.vc/ws';
  StreamSubscription<Uint8List>? _recorderSubscription;
  StreamSubscription? _webSocketSubscription;
  String _connectionStatus = '';
  bool _isWebSocketConnected = false;
  Timer? _connectionTimer;
  List<String> _messages = [];
  //store bytes from websocket 
  List<Uint8List> _audioChunks = [];
  
  // Voice detection thresholds (adjusted for better detection)
  static const double backgroundNoiseThreshold = -35.0;  // Lower threshold for background noise
  static const double humanVoiceThreshold = -25.0;       // Threshold for human voice detection
  static const double maxVoiceThreshold = 5.0;           // Maximum voice level
  
  // Voice activity detection state
  bool _isVoiceActive = false;
  int _voiceInactiveCount = 0;
  static const int voiceInactiveLimit = 5; // Number of consecutive silent frames before stopping transmission

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
  }

  Future<void> _connectWebSocket() async {
    try {
      setState(() {
        _connectionStatus = 'Connecting...';
      });

      _channel = WebSocketChannel.connect(Uri.parse(_webSocketUrl));

      // Set up WebSocket listener
      _webSocketSubscription = _channel!.stream.listen(
        (event) {
          print('WebSocket event: $event');
          if (!_isWebSocketConnected && event is Uint8List) {
            setState(() {
              _isWebSocketConnected = true;
              _connectionStatus = 'Connected';
              // _messages.add(event.toString());
              //store audio bytes to list of strings
              _audioChunks.add(event);
            });
          }
        },
        onDone: () {
          setState(() {
            _isWebSocketConnected = false;
            _connectionStatus = 'Disconnected';
          });
          _cleanupWebSocket();
        },
        onError: (error) {
          setState(() {
            _isWebSocketConnected = false;
            _connectionStatus = 'Connection Error: ${error.toString()}';
          });
          print('WebSocket error: $error');
          _cleanupWebSocket();
        },
      );

      // Check if connection is still alive
      if (_channel?.closeCode == null) {
        setState(() {
          _isWebSocketConnected = true;
          _connectionStatus = 'Connected';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: ${e.toString()}';
        _isWebSocketConnected = false;
      });
      print('Error connecting WebSocket: $e');
      _cleanupWebSocket();
    }
  }

  void _cleanupWebSocket() {
    _connectionTimer?.cancel();
    _webSocketSubscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _webSocketSubscription = null;
    _connectionTimer = null;
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        // First connect to WebSocket
        await _connectWebSocket();

        // Wait for connection to be established
        if (!_isWebSocketConnected) {
          // Wait up to 5 seconds for connection
          int attempts = 0;
          while (!_isWebSocketConnected && attempts < 50) {
            await Future.delayed(const Duration(milliseconds: 100));
            attempts++;
          }
        }

        if (!_isWebSocketConnected) {
          setState(() {
            _connectionStatus = 'Failed to connect to WebSocket';
          });
          return;
        }

        // Start recording
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            bitRate: 1411000,
            sampleRate: 48000,
            noiseSuppress: true,
            echoCancel: false,
          ),
        );

        // Reset voice detection state
        _isVoiceActive = false;
        _voiceInactiveCount = 0;

        _recorderSubscription = stream.listen(
          (Uint8List data) {
            if (data.isNotEmpty) {
              // Check if voice is detected before sending
              if (_isVoiceDetected(data)) {
                _sendBytes(data);
                _audioChunks.add(data);
                print('Voice detected - Sent audio data: ${data.length} bytes');
                
                if (kDebugMode) {
                  print('Audio data sample: ${data.toList()}...');
                }
              } else {
                print('Background noise detected - Skipping transmission');
              }
            }
          },
          onError: (error) {
            print('Recording stream error: $error');
            _stopRecording();
          },
        );

        setState(() {
          _isRecording = true;
        });
      } else {
        setState(() {
          _connectionStatus = 'Microphone permission not granted';
        });
        print('Microphone permission not granted');
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: ${e.toString()}';
      });
      print('Error starting recording: $e');
      _cleanupWebSocket();
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      await _recorderSubscription?.cancel();
      await _webSocketSubscription?.cancel();

      _recorderSubscription = null;
      _webSocketSubscription = null;

      print('Stopped recording');

      setState(() {
        _connectionStatus = 'Stopped recording';
      });

      setState(() {
        _isRecording = false;
      });

      // Close WebSocket connection
      _cleanupWebSocket();

      setState(() {
        _connectionStatus = 'Disconnected';
        _isWebSocketConnected = false;
        _messages.clear();
        _isVoiceActive = false;
        _voiceInactiveCount = 0;
      });
    } catch (e) { 
      print('Error stopping recording: $e');
    }
  }

  bool _isVoiceDetected(Uint8List audioData) {
    try {
      // Convert audio bytes to samples
      List<double> samples = [];
      for (int i = 0; i < audioData.length - 1; i += 2) {
        int sample = (audioData[i + 1] << 8) | audioData[i];
        if (sample > 32767) sample -= 65536;
        samples.add(sample / 32768.0);
      }

      if (samples.isEmpty) return false;

      // Calculate RMS (Root Mean Square) for volume level
      double sumSquares = 0.0;
      for (double sample in samples) {
        sumSquares += sample * sample;
      }
      double rms = sqrt(sumSquares / samples.length);
      
      // Convert to decibels
      double decibels = 20 * log(rms + 1e-10) / ln10;

      // Voice activity detection with hysteresis
      bool currentFrameHasVoice = decibels > humanVoiceThreshold && decibels <= maxVoiceThreshold;
      
      if (currentFrameHasVoice) {
        _isVoiceActive = true;
        _voiceInactiveCount = 0;
        print('Voice detected: ${decibels.toStringAsFixed(2)} dB');
        return true;
      } else {
        // If voice was active but current frame is silent, wait for a few frames before stopping
        if (_isVoiceActive) {
          _voiceInactiveCount++;
          if (_voiceInactiveCount >= voiceInactiveLimit) {
            _isVoiceActive = false;
            _voiceInactiveCount = 0;
            print('Voice activity ended: ${decibels.toStringAsFixed(2)} dB');
            return false;
          } else {
            // Continue sending during brief pauses in speech
            print('Brief pause in voice: ${decibels.toStringAsFixed(2)} dB');
            return true;
          }
        } else {
          // No voice activity
          if (decibels > backgroundNoiseThreshold) {
            print('Background noise: ${decibels.toStringAsFixed(2)} dB');
          }
          return false;
        }
      }
    } catch (e) {
      print('Error in voice detection: $e');
      return false;
    }
  }

  void _sendBytes(Uint8List bytes) {
    try {
      if (_channel != null &&
          _channel!.closeCode == null &&
          _isWebSocketConnected) {
        _channel!.sink.add(bytes);
      } else {
        print('WebSocket not connected, cannot send data');
        if (!_isWebSocketConnected) {
          setState(() {
            _connectionStatus = 'WebSocket disconnected';
          });
        }
      }
    } catch (e) {
      print('Error sending bytes: $e');
      setState(() {
        _connectionStatus = 'Send Error: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _recorder.dispose();
    _cleanupWebSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audio WebSocket Streamer',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return Text(
                    _messages[index],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            
            // Voice activity indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isVoiceActive ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isVoiceActive ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isVoiceActive ? 'Voice Active' : 'Voice Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'WebSocket Status: $_connectionStatus',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isRecording)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_connectionStatus) {
      case 'Connected':
        return Colors.green;
      case 'Connecting...':
        return Colors.orange;
      case 'Disconnected':
        return Colors.grey;
      default:
        return Colors.red;
    }
  }
}