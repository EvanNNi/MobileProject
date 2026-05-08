import 'package:flutter/cupertino.dart';

import 'camera_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('首页')),
      child: SafeArea(
        child: Center(
          child: CupertinoButton.filled(
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const CameraPreviewPage(),
                ),
              );
            },
            child: const Text('打开摄像头'),
          ),
        ),
      ),
    );
  }
}
