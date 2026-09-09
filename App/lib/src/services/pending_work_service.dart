import '../database/database_helper.dart';
import '../../utils/storage_helper.dart';

class PendingWorkService {
  static Future<bool> hasPendingWork() async {
    final db = DatabaseHelper.instance;
    final rows = await Future.wait([
      db.getPendingFarms(),
      db.getPendingCrops(),
      db.getPendingAnalyses(),
      db.getPendingFarmDeletions(),
      db.getPendingCropDeletions(),
    ]);
    if (rows.any((items) => items.isNotEmpty)) return true;
    final storage = StorageHelper();
    return await storage.read('profile_data_pending') == 'true' ||
        await storage.read('profile_picture_pending_upload') == 'true';
  }
}
