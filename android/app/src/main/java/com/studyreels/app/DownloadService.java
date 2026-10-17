package com.studyreels.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

/**
 * Foreground service that keeps the process alive while the model download
 * runs in Dart, and owns the progress / completion notifications. The bytes
 * are still downloaded by the Dart ModelDownloader (resumable .part files);
 * this service only prevents Android from killing the app in the background.
 */
public class DownloadService extends Service {
    static final String CH_PROGRESS = "download_progress";
    static final String CH_DONE = "download_done";
    static final int ID_PROGRESS = 4101;
    static final int ID_DONE = 4102;

    static final String ACTION_START = "start";
    static final String ACTION_UPDATE = "update";
    static final String ACTION_STOP = "stop";

    private PowerManager.WakeLock wakeLock;

    static void ensureChannels(Context c) {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationManager nm = c.getSystemService(NotificationManager.class);
        NotificationChannel p = new NotificationChannel(CH_PROGRESS,
                "Model download", NotificationManager.IMPORTANCE_LOW);
        p.setDescription("Progress of the one-time AI model download");
        nm.createNotificationChannel(p);
        NotificationChannel d = new NotificationChannel(CH_DONE,
                "Download finished", NotificationManager.IMPORTANCE_DEFAULT);
        d.setDescription("Tells you when the models are ready or failed");
        nm.createNotificationChannel(d);
    }

    static Notification build(Context c, String title, String text,
            int percent, boolean ongoing, String channel) {
        Intent open = new Intent(c, MainActivity.class);
        open.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP
                | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pi = PendingIntent.getActivity(c, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT
                        | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder b = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(c, channel)
                : new Notification.Builder(c);
        b.setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setContentIntent(pi)
                .setOnlyAlertOnce(true)
                .setOngoing(ongoing);
        if (!ongoing) {
            b.setSmallIcon(android.R.drawable.stat_sys_download_done);
            b.setAutoCancel(true);
        } else if (percent >= 0) {
            b.setProgress(100, percent, false);
        } else {
            b.setProgress(0, 0, true);
        }
        return b.build();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent == null ? ACTION_START : intent.getAction();
        if (ACTION_STOP.equals(action)) {
            releaseLock();
            stopForeground(true);
            stopSelf();
            return START_NOT_STICKY;
        }
        String title = intent == null ? "Downloading models"
                : intent.getStringExtra("title");
        String text = intent == null ? "Resuming..."
                : intent.getStringExtra("text");
        int percent = intent == null ? -1 : intent.getIntExtra("percent", -1);
        ensureChannels(this);
        Notification n = build(this, title == null ? "StudyReels" : title,
                text == null ? "" : text, percent, true, CH_PROGRESS);
        if (ACTION_UPDATE.equals(action)) {
            getSystemService(NotificationManager.class).notify(ID_PROGRESS, n);
            return START_NOT_STICKY;
        }
        if (Build.VERSION.SDK_INT >= 29) {
            int type = Build.VERSION.SDK_INT >= 34
                    ? ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC : 0;
            if (type != 0) {
                startForeground(ID_PROGRESS, n, type);
            } else {
                startForeground(ID_PROGRESS, n);
            }
        } else {
            startForeground(ID_PROGRESS, n);
        }
        if (wakeLock == null) {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,
                    "studyreels:download");
            wakeLock.acquire(2 * 60 * 60 * 1000L);
        }
        return START_NOT_STICKY;
    }

    private void releaseLock() {
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
        wakeLock = null;
    }

    @Override
    public void onDestroy() {
        releaseLock();
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
