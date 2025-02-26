import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ObjectBox {
  ObjectBox._create(this.store) {
    // Add any additional setup code, e.g. build queries.
  }

  /// The Store of this app.
  late final Store store;

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create(
    Store Function({required String directory}) openStore,
  ) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store =
        await openStore(directory: p.join(docsDir.path, 'object-box-instance'));
    return ObjectBox._create(store);
  }
}
