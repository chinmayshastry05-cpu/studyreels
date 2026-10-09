package com.studyreels.app;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;

/**
 * Exports a reel as a real clip file: stream-copy trim with
 * MediaExtractor + MediaMuxer — NO re-encode, fast, keyframe-aligned.
 *
 * The clip starts at the keyframe at/before the requested start (standard
 * for stream-copy trims: up to one GOP earlier) and ends at the first
 * sample past the requested end. Saved to the gallery via MediaStore
 * (Movies/StudyReels), scoped-storage compliant — no storage permission
 * needed on API 29+, no INTERNET permission involved.
 *
 * Burned-in captions are NOT done here: drawing text into pixels requires
 * a full decode → render → re-encode pass, which is a separate (slower)
 * pipeline, intentionally not the default.
 */
public class VideoExporter {

    /**
     * Trims [startSec, endSec] from videoPath and saves to the gallery.
     *
     * @return the MediaStore URI of the saved clip.
     */
    public static String exportClip(
            Context context, String videoPath, double startSec, double endSec)
            throws IOException {
        long startUs = (long) (startSec * 1_000_000L);
        long endUs = (long) (endSec * 1_000_000L);
        if (endUs <= startUs) {
            throw new IOException("Invalid range: end must be after start");
        }

        File tmp = File.createTempFile("reel_", ".mp4", context.getCacheDir());
        try {
            trimToFile(videoPath, tmp.getAbsolutePath(), startUs, endUs);
            Uri uri = insertIntoGallery(context, tmp);
            return uri.toString();
        } finally {
            // noinspection ResultOfMethodCallIgnored
            tmp.delete();
        }
    }

    private static void trimToFile(
            String videoPath, String outPath, long startUs, long endUs)
            throws IOException {
        MediaExtractor extractor = new MediaExtractor();
        extractor.setDataSource(videoPath);

        int videoTrack = -1;
        int audioTrack = -1;
        for (int i = 0; i < extractor.getTrackCount(); i++) {
            MediaFormat f = extractor.getTrackFormat(i);
            String mime = f.getString(MediaFormat.KEY_MIME);
            if (mime == null) continue;
            if (videoTrack < 0 && mime.startsWith("video/")) videoTrack = i;
            else if (audioTrack < 0 && mime.startsWith("audio/")) audioTrack = i;
        }
        if (videoTrack < 0) {
            extractor.release();
            throw new IOException("No video track in " + videoPath);
        }

        MediaMuxer muxer = new MediaMuxer(
                outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        int[] trackIndex = new int[extractor.getTrackCount()];
        try {
            // Register tracks (no selection yet; copyTrack selects each).
            trackIndex[videoTrack] =
                    muxer.addTrack(extractor.getTrackFormat(videoTrack));
            if (audioTrack >= 0) {
                trackIndex[audioTrack] =
                        muxer.addTrack(extractor.getTrackFormat(audioTrack));
            }
            muxer.start();

            int maxInput = 1024 * 1024;
            try {
                MediaFormat vf = extractor.getTrackFormat(videoTrack);
                if (vf.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    maxInput = Math.max(maxInput,
                            vf.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE));
                }
            } catch (Exception ignored) {
            }
            ByteBuffer buffer = ByteBuffer.allocateDirect(maxInput);
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();

            // Mux samples track by track (simpler and correct for trims;
            // interleaving is the muxer's job).
            copyTrack(extractor, muxer, trackIndex, videoTrack,
                    buffer, info, startUs, endUs, true);
            if (audioTrack >= 0) {
                copyTrack(extractor, muxer, trackIndex, audioTrack,
                        buffer, info, startUs, endUs, false);
            }
            muxer.stop();
        } finally {
            try {
                muxer.release();
            } catch (Exception ignored) {
            }
            extractor.release();
        }
    }

    private static void copyTrack(
            MediaExtractor extractor,
            MediaMuxer muxer,
            int[] trackIndex,
            int track,
            ByteBuffer buffer,
            MediaCodec.BufferInfo info,
            long startUs,
            long endUs,
            boolean isVideo) {
        // Select only this track.
        for (int i = 0; i < trackIndex.length; i++) {
            if (i != track) {
                try {
                    extractor.unselectTrack(i);
                } catch (Exception ignored) {
                }
            }
        }
        extractor.selectTrack(track);
        // Video: the clip must begin on a keyframe for stream-copy playback.
        // Audio: closest sync is fine (AAC frames are tiny).
        extractor.seekTo(startUs, isVideo
                ? MediaExtractor.SEEK_TO_PREVIOUS_SYNC
                : MediaExtractor.SEEK_TO_CLOSEST_SYNC);
        boolean firstVideoSample = isVideo;
        while (true) {
            buffer.clear();
            int n = extractor.readSampleData(buffer, 0);
            if (n < 0) break;
            long pts = extractor.getSampleTime();
            if (pts > endUs) break;
            // For video, the first sample is the keyframe we sought to
            // (possibly before startUs) — it must be kept so the clip
            // decodes. Later samples before startUs are skipped.
            if (!firstVideoSample && pts < startUs) {
                extractor.advance();
                continue;
            }
            firstVideoSample = false;
            info.set(0, n, pts, extractor.getSampleFlags());
            muxer.writeSampleData(trackIndex[track], buffer, info);
            extractor.advance();
        }
        extractor.unselectTrack(track);
    }

    private static Uri insertIntoGallery(Context context, File tmp)
            throws IOException {
        ContentResolver resolver = context.getContentResolver();
        ContentValues values = new ContentValues();
        values.put(MediaStore.Video.Media.DISPLAY_NAME,
                "studyreels_" + System.currentTimeMillis() + ".mp4");
        values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.Video.Media.RELATIVE_PATH,
                    "Movies/StudyReels");
        }
        Uri uri = resolver.insert(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) {
            throw new IOException("MediaStore insert failed");
        }
        try (OutputStream out = resolver.openOutputStream(uri);
             FileInputStream in = new FileInputStream(tmp)) {
            if (out == null) throw new IOException("Cannot open gallery output");
            byte[] chunk = new byte[8192];
            int n;
            while ((n = in.read(chunk)) > 0) out.write(chunk, 0, n);
        } catch (IOException e) {
            resolver.delete(uri, null, null);
            throw e;
        }
        return uri;
    }
}
