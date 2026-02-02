import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:pulchowkx_app/models/chat.dart';

/// Socket service for real-time chat communication
class SocketService {
  static const String _socketUrl = 'https://pulchowk-x.vercel.app';

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _currentUserId;
  int? _currentConversationId;

  // Stream controllers for real-time events
  final _newMessageController =
      StreamController<MarketplaceMessage>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<MarketplaceMessage> get newMessageStream =>
      _newMessageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Initialize and connect to the socket server
  Future<void> connect(String userId) async {
    if (_socket != null && _socket!.connected && _currentUserId == userId) {
      debugPrint('Socket already connected for user $userId');
      return;
    }

    // Disconnect existing socket if any
    await disconnect();

    _currentUserId = userId;

    _socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io/')
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _setupEventHandlers();

    // Wait for connection
    final completer = Completer<void>();

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      _connectionController.add(true);

      // Authenticate after connection
      _socket!.emit('authenticate', userId);

      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _socket!.onConnectError((error) {
      debugPrint('Socket connection error: $error');
      _connectionController.add(false);
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    // Set a timeout for connection
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError('Connection timeout');
      }
    });

    try {
      await completer.future;
    } catch (e) {
      debugPrint('Failed to connect socket: $e');
      rethrow;
    }
  }

  void _setupEventHandlers() {
    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
      _connectionController.add(false);
    });

    _socket!.onReconnect((_) {
      debugPrint('Socket reconnected');
      _connectionController.add(true);
      // Re-authenticate after reconnection
      if (_currentUserId != null) {
        _socket!.emit('authenticate', _currentUserId);
      }
      // Rejoin conversation if we were in one
      if (_currentConversationId != null) {
        joinConversation(_currentConversationId!);
      }
    });

    _socket!.on('authenticated', (data) {
      debugPrint('Socket authenticated: $data');
    });

    _socket!.on('error', (data) {
      debugPrint('Socket error: $data');
    });

    // Handle new messages
    _socket!.on('newMessage', (data) {
      debugPrint('New message received: $data');
      try {
        final message = _parseMessage(data['message']);
        _newMessageController.add(message);
      } catch (e) {
        debugPrint('Error parsing message: $e');
      }
    });

    // Handle typing indicators
    _socket!.on('userTyping', (data) {
      debugPrint('User typing: $data');
      _typingController.add({
        'isTyping': true,
        'conversationId': data['conversationId'],
        'userId': data['userId'],
      });
    });

    _socket!.on('userStoppedTyping', (data) {
      _typingController.add({
        'isTyping': false,
        'conversationId': data['conversationId'],
        'userId': data['userId'],
      });
    });

    // Handle message notifications (for when not viewing a conversation)
    _socket!.on('messageNotification', (data) {
      debugPrint('Message notification: $data');
      _notificationController.add(data);
    });

    _socket!.on('joinedConversation', (data) {
      debugPrint('Joined conversation: $data');
    });
  }

  MarketplaceMessage _parseMessage(Map<String, dynamic> data) {
    return MarketplaceMessage(
      id: data['id'] as int,
      conversationId: data['conversationId'] as int,
      senderId: data['senderId'] as String,
      content: data['content'] as String,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'].toString())
          : DateTime.now(),
      isRead: (data['isRead'] ?? 'false') == 'true',
    );
  }

  /// Join a conversation room to receive real-time messages
  void joinConversation(int conversationId) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Cannot join conversation: socket not connected');
      return;
    }
    _currentConversationId = conversationId;
    _socket!.emit('joinConversation', conversationId);
  }

  /// Leave a conversation room
  void leaveConversation(int conversationId) {
    if (_socket == null || !_socket!.connected) return;
    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
    }
    _socket!.emit('leaveConversation', conversationId);
  }

  /// Send typing indicator
  void sendTyping(int conversationId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('typing', conversationId);
  }

  /// Send stop typing indicator
  void sendStopTyping(int conversationId) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('stopTyping', conversationId);
  }

  /// Disconnect from the socket server
  Future<void> disconnect() async {
    _currentUserId = null;
    _currentConversationId = null;
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  /// Dispose of all resources
  void dispose() {
    disconnect();
    _newMessageController.close();
    _typingController.close();
    _connectionController.close();
    _notificationController.close();
  }
}
