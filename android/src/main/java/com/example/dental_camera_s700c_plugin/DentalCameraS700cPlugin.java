package com.example.dental_camera_s700c_plugin;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.util.Log;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.PaintFlagsDrawFilter;
import android.graphics.PixelFormat;
import android.graphics.PorterDuff;
import android.graphics.Rect;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import com.yilushi.mjpegsdk.OnStreamListener;
import com.yilushi.mjpegsdk.StreamClient;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import io.flutter.plugin.common.StandardMessageCodec;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.lang.ref.WeakReference;
import java.util.Locale;
import java.util.concurrent.LinkedBlockingQueue;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import android.graphics.Paint;
import android.util.AttributeSet;
import java.util.Arrays;
import java.util.Comparator;

/** DentalCameraS700cPlugin */
public class DentalCameraS700cPlugin implements FlutterPlugin, MethodCallHandler {
  private MethodChannel channel;
  private MjpegView mjpegView;
  private StreamClient mStreamClient;
  private Handler handler = new Handler();
  private byte[] previewImageByteArray;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "dental_camera_s700c_plugin");
    channel.setMethodCallHandler(this);

    mjpegView = new MjpegView(flutterPluginBinding.getApplicationContext(), null);

    mStreamClient = StreamClient.getInstance();
    mStreamClient.startServer();
    mStreamClient.setOnStreamListener(mOnStreamListener);

    flutterPluginBinding
        .getPlatformViewRegistry()
        .registerViewFactory("mjpeg-view-type", new MjpegViewFactory());
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "getPlatformVersion":
        result.success("Android " + android.os.Build.VERSION.RELEASE);
        break;
      case "foto":
        takePhoto();
        result.success("Photo capturing initiated");
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private void takePhoto() {
    Bitmap currentFrame = mjpegView.getLastFrame();
    if (currentFrame != null) {
      ByteArrayOutputStream stream = new ByteArrayOutputStream();
      currentFrame.compress(Bitmap.CompressFormat.JPEG, 100, stream);
      previewImageByteArray = stream.toByteArray();
      invokeChannelMethod("photoPreview", previewImageByteArray);
    } else {
      invokeChannelMethod("noFrameAvailable", null);
    }
  }

  private void invokeChannelMethod(String method, Object arguments) {
    channel.invokeMethod(method, arguments);
  }

  private final OnStreamListener mOnStreamListener = new OnStreamListener() {
    @Override
    public void onVideo(final byte[] data, int quality, byte[] appendix) {
      handler.post(new Runnable() {
        @Override
        public void run() {
          if (appendix != null && appendix.length > 0) {
            invokeChannelMethod("gsensorData", appendix);
          }
          mjpegView.drawBitmap(data);
        }
      });
    }

    @Override
    public void onReceiver(byte[] datas) {
      handler.post(new Runnable() {
        @Override
        public void run() {
        }
      });
    }
  };

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  class MjpegViewFactory extends PlatformViewFactory {
    MjpegViewFactory() {
      super(StandardMessageCodec.INSTANCE);
    }

    @Override
    public PlatformView create(Context context, int viewId, Object args) {
      return new PlatformView() {
        @Override
        public View getView() {
          return mjpegView;
        }

        @Override
        public void dispose() {
          mjpegView.release();
        }
      };
    }
  }

  class MjpegView extends SurfaceView implements SurfaceHolder.Callback {
    private boolean surfaceDone = false;
    private BitmapFactory.Options bitmapOptions;
    private VideoThread mVideoThread;
    private Bitmap lastFrame;
    private final Object surfaceLock = new Object();

    public Bitmap getLastFrame() {
      return lastFrame;
    }

    public MjpegView(Context context, AttributeSet attrs) {
      super(context, attrs);
      init();
    }

    private void init() {
      SurfaceHolder holder = getHolder();
      holder.addCallback(this);
      setZOrderOnTop(true);
      holder.setFormat(PixelFormat.TRANSLUCENT);
      setFocusable(true);
      bitmapOptions = new BitmapFactory.Options();
      bitmapOptions.inPreferredConfig = Bitmap.Config.ARGB_8888;
      bitmapOptions.inPurgeable = true;
    }

    public void drawBitmap(byte[] data) {
      Bitmap frame = BitmapFactory.decodeByteArray(data, 0, data.length, bitmapOptions);
      lastFrame = frame;
      if (!surfaceDone) {
        return;
      }

      synchronized (surfaceLock) {
        if (surfaceDone && mVideoThread != null && data != null) {
          mVideoThread.addData(data);
        }
      }
    }

    private class VideoThread extends Thread {
      private final LinkedBlockingQueue<byte[]> mBufList = new LinkedBlockingQueue<>(5);
      private int dispWidth;
      private int dispHeight;
      private volatile boolean isWaiting = false;
      private WeakReference<SurfaceHolder> mWeakRefSurfaceHolder;
      private boolean isVideoThreadRunning = false;

      VideoThread(SurfaceHolder surfaceHolder) {
        mWeakRefSurfaceHolder = new WeakReference<>(surfaceHolder);
      }

      void addData(byte[] data) {
        if (mBufList.remainingCapacity() <= 1) {
          mBufList.poll();
        }
        try {
          mBufList.put(data);
        } catch (InterruptedException e) {
          e.printStackTrace();
        }
        if (isWaiting) {
          synchronized (mBufList) {
            mBufList.notify();
          }
        }
      }

      void stopRunning() {
        isVideoThreadRunning = false;
        synchronized (mBufList) {
          mBufList.notify();
          mBufList.clear();
        }
      }

      void setSurfaceSize(int width, int height) {
        dispWidth = width;
        dispHeight = height;
      }

      private Rect resizeRect(int bitmapWidth, int bitmapHeight) {
        float ar = (float) bitmapWidth / (float) bitmapHeight;
        bitmapWidth = dispWidth;
        bitmapHeight = (int) (dispWidth / ar);
        int tempX = (dispWidth / 2) - (bitmapWidth / 2);
        int tempY = (dispHeight / 2) - (bitmapHeight / 2);
        return new Rect(tempX, tempY, bitmapWidth + tempX, bitmapHeight + tempY);
      }

      @Override
      public void run() {
        super.run();
        isVideoThreadRunning = true;
        Bitmap bitmap = null;
        while (isVideoThreadRunning) {
          byte[] data = null;
          synchronized (mBufList) {
            while (mBufList.isEmpty()) {
              try {
                isWaiting = true;
                mBufList.wait();
              } catch (InterruptedException e) {
                e.printStackTrace();
              }
            }
            isWaiting = false;
            data = mBufList.poll();
          }
          if (data != null) {
            final SurfaceHolder surfaceHolder = mWeakRefSurfaceHolder.get();
            if (surfaceHolder != null) {
              synchronized (surfaceLock) {
                if (!surfaceDone) {
                  return;
                }
                Canvas canvas = null;
                try {
                  bitmap = BitmapFactory.decodeByteArray(data, 0, data.length, bitmapOptions);
                  canvas = surfaceHolder.lockCanvas(null);
                  Rect destRect = resizeRect(bitmap.getWidth(), bitmap.getHeight());
                  if (canvas != null) {
                    canvas.setDrawFilter(new PaintFlagsDrawFilter(0, Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG));
                    canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);
                    canvas.drawBitmap(bitmap, null, destRect, null);
                  }
                } finally {
                  if (canvas != null) {
                    surfaceHolder.unlockCanvasAndPost(canvas);
                  }
                  if (bitmap != null && !bitmap.isRecycled()) {
                    bitmap.recycle();
                  }
                }
              }
            }
          }
        }
      }
    }

    public void release() {
      if (mVideoThread != null) {
        mVideoThread.stopRunning();
        mVideoThread = null;
      }
      SurfaceHolder holder = getHolder();
      synchronized (surfaceLock) {
        if (holder != null && holder.getSurface() != null) {
            holder.getSurface().release();
        }
        surfaceDone = false;
    }
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
      synchronized (surfaceLock) {
        surfaceDone = true;
        if (mVideoThread == null) {
          mVideoThread = new VideoThread(holder);
        }
        if (mVideoThread.getState() == Thread.State.NEW) {
          mVideoThread.start();
        }
      }
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int f, int w, int h) {
      if (mVideoThread != null) {
        mVideoThread.setSurfaceSize(w, h);
      }
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
      surfaceDone = false;
      release();
    }
  }
}
