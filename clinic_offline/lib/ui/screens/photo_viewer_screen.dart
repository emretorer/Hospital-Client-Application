import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class PhotoViewerScreen extends ConsumerWidget {
  const PhotoViewerScreen({super.key, required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(imageStorageProvider);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Photo'),
      ),
      child: SafeArea(
        child: FutureBuilder(
          future: storage.resolveFromRelative(relativePath),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }
            return Center(
              child: InteractiveViewer(
                child: Image.file(snapshot.data!),
              ),
            );
          },
        ),
      ),
    );
  }
}