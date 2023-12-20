// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_key_in_widget_constructors, avoid_print, unused_field, deprecated_member_use, prefer_typing_uninitialized_variables, unnecessary_null_comparison, prefer_final_fields, prefer_const_constructors_in_immutables, prefer_collection_literals, unused_local_variable, unnecessary_string_interpolations, unnecessary_this
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Downloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final YoutubeExplode yt = YoutubeExplode();
  bool isDownloading = false;

  String formatDuration(Duration duration) {
    String hours = duration.inHours.remainder(60).toString().padLeft(2, '0');
    String minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours != '00') {
      return '$hours hrs $minutes mins $seconds secs';
    } else {
      return '$minutes mins $seconds secs';
    }
  }

  Future<void> getInfo() async {
    _outputController.text = "";
    var video = await yt.videos.get(_urlController.text);
    _outputController.text += "Title: ${video.title}\n";
    _outputController.text += "Author: ${video.author}\n";
    _outputController.text += "Duration: ${formatDuration(video.duration!)}\n";
  }

  Future<void> download() async {
    setState(() {
      isDownloading = true;
    });

    try {
      String? filePath = await FilePicker.platform.saveFile(
        type: FileType.custom,
        allowedExtensions: ['mp4'],
      );

      if (filePath != null) {
        var video = await yt.videos.get(_urlController.text);
        var manifest = await yt.videos.streamsClient.getManifest(video.id);
        var streamInfo = manifest.audioOnly.withHighestBitrate();

        var stream = yt.videos.streamsClient.get(streamInfo);

        var file = File('$filePath.mp3');
        var fileStream = file.openWrite();

        var subscription = stream.listen(
          (data) {
            fileStream.add(data);
          },
          onDone: () async {
            await fileStream.flush();
            await fileStream.close();
            setState(() {
              isDownloading = false;
            });
          },
          onError: (error) {
            print('Error during download: $error');
            setState(() {
              isDownloading = false;
            });
          },
        );

        // Download video only
        var videoStreamInfo = manifest.videoOnly.withHighestBitrate();
        var videoStream = yt.videos.streamsClient.get(videoStreamInfo);
        var videoFile = File('$filePath.mp4');
        var videoFileStream = videoFile.openWrite();
        var videoSubscription = videoStream.listen(
          (data) {
            videoFileStream.add(data);
          },
          onDone: () async {
            await videoFileStream.flush();
            await videoFileStream.close();
            setState(() {
              isDownloading = false;
            });
          },
          onError: (error) {
            print('Error during download: $error');
            setState(() {
              isDownloading = false;
            });
          },
        );

        // ffmpeg
        await _flutterFFmpeg
            .execute(
                '-i "$filePath.mp4" -i "$filePath.mp3" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 "$filePath.mp4"')
            .then((value) => print('FFmpeg: $value'));



        // Cancel download
        ElevatedButton(
          onPressed: () {
            subscription.cancel();
            setState(() {
              isDownloading = false;
            });
          },
          child: Text('Cancel Download'),
        );
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('YouTube Downloader'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Youtube URL: ',
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await getInfo();
                    setState(() {});
                  },
                  child: Text('Get Info'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _outputController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Video Information:',
                  ),
                  minLines: 3,
                  maxLines: 10,
                  readOnly: true,
                ),
                SizedBox(height: 16),
                if (isDownloading) LinearProgressIndicator(),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await download();
                  },
                  child: Text('Download'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    yt.close();
    super.dispose();
  }
}
