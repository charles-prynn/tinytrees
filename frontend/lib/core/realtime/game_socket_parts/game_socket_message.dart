part of '../game_socket.dart';

class GameSocketMessage {
  const GameSocketMessage({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;
}
