package app.agrhi.com;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.content.pm.PackageInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.os.Build;
import androidx.annotation.NonNull;
import androidx.exifinterface.media.ExifInterface;
import java.io.File;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends FlutterActivity {
    private final ExecutorService imageWorker = Executors.newSingleThreadExecutor();

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "app.agrhi.com/native")
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("packageInfo")) {
                    try {
                        PackageInfo info = getPackageManager().getPackageInfo(getPackageName(), 0);
                        HashMap<String, String> data = new HashMap<>();
                        data.put("packageName", getPackageName());
                        data.put("buildNumber", Long.toString(Build.VERSION.SDK_INT >= 28
                            ? info.getLongVersionCode() : info.versionCode));
                        result.success(data);
                    } catch (Exception e) {
                        result.error("metadata", e.getMessage(), null);
                    }
                } else if (call.method.equals("compressImage")) {
                    String source = call.argument("source");
                    String destination = call.argument("destination");
                    imageWorker.execute(() -> {
                        try {
                            compressImage(source, destination);
                            runOnUiThread(() -> result.success(destination));
                        } catch (Exception e) {
                            runOnUiThread(() -> result.error("compression", e.getMessage(), null));
                        }
                    });
                } else {
                    result.notImplemented();
                }
            });
    }

    private static void compressImage(String source, String destination) throws Exception {
        if (source == null || destination == null || source.equals(destination)) {
            throw new IllegalArgumentException("Distinct source and destination are required");
        }
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(source, options);
        if (options.outWidth <= 0 || options.outHeight <= 0) {
            throw new IllegalArgumentException("Unsupported image");
        }
        options.inSampleSize = 1;
        while (Math.max(options.outWidth, options.outHeight) / options.inSampleSize > 2560) {
            options.inSampleSize *= 2;
        }
        options.inJustDecodeBounds = false;
        Bitmap bitmap = BitmapFactory.decodeFile(source, options);
        if (bitmap == null) throw new IllegalArgumentException("Cannot decode image");
        File output = new File(destination);
        boolean complete = false;
        try {
            ExifInterface exif = new ExifInterface(source);
            Matrix transform = new Matrix();
            transform.setRotate(exif.getRotationDegrees());
            if (exif.isFlipped()) transform.postScale(-1, 1);
            Bitmap oriented = Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), transform, true);
            if (oriented != bitmap) { bitmap.recycle(); bitmap = oriented; }
            double scale = Math.min(1.0, 1280.0 / Math.max(bitmap.getWidth(), bitmap.getHeight()));
            Bitmap resized = Bitmap.createScaledBitmap(bitmap,
                Math.max(1, (int) Math.round(bitmap.getWidth() * scale)),
                Math.max(1, (int) Math.round(bitmap.getHeight() * scale)), true);
            if (resized != bitmap) { bitmap.recycle(); bitmap = resized; }
            try (FileOutputStream stream = new FileOutputStream(output)) {
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 82, stream)) {
                    throw new IllegalStateException("JPEG encoding failed");
                }
            }
            complete = true;
        } finally {
            bitmap.recycle();
            if (!complete) output.delete();
        }
    }

    @Override
    protected void onDestroy() {
        imageWorker.shutdown();
        super.onDestroy();
    }
}
