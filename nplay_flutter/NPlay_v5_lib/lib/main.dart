import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'handler.dart';
import 'home.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Store.init();
  handler = await AudioService.init<NPlayHandler>(
    builder: () => NPlayHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.nazmul.nplay.channel.audio',
      androidNotificationChannelName: 'NPlay',
      androidNotificationOngoing: true,
    ),
  );
  handler.setSavedPosReader((id) => Store.pos(id));
  runApp(const NPlayApp());
}

class NPlayApp extends StatelessWidget {
  const NPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NPlay',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomePage(),
    );
  }
}
