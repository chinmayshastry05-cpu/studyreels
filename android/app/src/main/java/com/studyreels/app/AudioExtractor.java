package com.studyreels.app;

import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;

import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Extracts the audio track from a video file and writes it as a
 * 16 kHz mono 16-bit PCM WAV — the exact format cactus_transcribe expects.
 *
 * Fully on-device (MediaExtractor + MediaCodec, no network). Decodes and
 * resamples in a single streaming pass, so memory stays constant even for
 * multi-hour lectures.
 */
public class AudioExtractor {

    private static final int TARGET_RATE = 16000;

    public static String extractWav(String videoPath, String outPath) throws IOException {
        MediaExtractor extractor = new MediaExtractor();
        extractor.setDataSource(videoPath);

        int audioTrack = -1;
        MediaFormat format = null;
        for (int i = 0; i < extractor.getTrackCount(); i++) {
            MediaFormat f = extractor.getTrackFormat(i);
            String mime = f.getString(MediaFormat.KEY_MIME);
            if (mime != null && mime.startsWith("audio/")) {
                audioTrack = i;
                format = f;
                break;
            }
        }
        if (audioTrack < 0) {
            extractor.release();
            throw new IOException("No audio track in " + videoPath);
        }
        extractor.selectTrack(audioTrack);

        int srcRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE);
        int channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
        String mime = format.getString(MediaFormat.KEY_MIME);

        MediaCodec codec = MediaCodec.createDecoderByType(mime);
        codec.configure(format, null, null, 0);
        codec.start();

        // Streaming linear resampler: output frame i sits at source position
        // p = i * srcRate / TARGET_RATE. Decoded source frames arrive in order,
        // so a 2-frame sliding window is enough.
        double ratio = (double) srcRate / TARGET_RATE;
        double nextSrcPos = 0.0;
        long outFrames = 0;
        double[] prev = null;
        double[] cur = null;
        long srcIndex = -1;

        WavWriter wav = new WavWriter(outPath);
        try {
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            boolean sawInputEos = false;
            boolean sawOutputEos = false;
            while (!sawOutputEos) {
                if (!sawInputEos) {
                    int inIdx = codec.dequeueInputBuffer(10000);
                    if (inIdx >= 0) {
                        ByteBuffer inBuf = codec.getInputBuffer(inIdx);
                        int n = extractor.readSampleData(inBuf, 0);
                        if (n < 0) {
                            codec.queueInputBuffer(inIdx, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                            sawInputEos = true;
                        } else {
                            codec.queueInputBuffer(inIdx, 0, n,
                                    extractor.getSampleTime(), 0);
                            extractor.advance();
                        }
                    }
                }
                int outIdx = codec.dequeueOutputBuffer(info, 10000);
                if (outIdx >= 0) {
                    ByteBuffer outBuf = codec.getOutputBuffer(outIdx);
                    if (info.size > 0 && outBuf != null) {
                        outBuf.order(ByteOrder.LITTLE_ENDIAN);
                        outBuf.position(info.offset);
                        outBuf.limit(info.offset + info.size);
                        while (outBuf.remaining() >= 2 * channels) {
                            double mono = 0;
                            for (int c = 0; c < channels; c++) {
                                mono += outBuf.getShort();
                            }
                            mono /= channels;
                            prev = cur;
                            cur = new double[]{mono};
                            srcIndex++;
                            // Emit every output frame whose source position
                            // falls inside [srcIndex - 1, srcIndex].
                            while (prev != null && nextSrcPos < srcIndex
                                    && nextSrcPos >= srcIndex - 1) {
                                double frac = nextSrcPos - (srcIndex - 1);
                                double s = prev[0] + (cur[0] - prev[0]) * frac;
                                wav.writeSample((short) Math.max(-32768,
                                        Math.min(32767, Math.round(s))));
                                outFrames++;
                                nextSrcPos += ratio;
                            }
                        }
                    }
                    codec.releaseOutputBuffer(outIdx, false);
                    if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        sawOutputEos = true;
                    }
                }
            }
            // Tail: emit remaining output frames against the last source frame.
            if (cur != null) {
                while (nextSrcPos < srcIndex + 1) {
                    wav.writeSample((short) Math.max(-32768,
                            Math.min(32767, Math.round(cur[0]))));
                    outFrames++;
                    nextSrcPos += ratio;
                }
            }
        } finally {
            try {
                wav.close();
            } finally {
                codec.stop();
                codec.release();
                extractor.release();
            }
        }
        return outPath;
    }

    /** Minimal WAV writer: reserves the 44-byte header, patches sizes on close. */
    private static class WavWriter {
        private final String path;
        private final FileOutputStream fos;
        private long dataBytes = 0;

        WavWriter(String path) throws IOException {
            this.path = path;
            fos = new FileOutputStream(path);
            fos.write(new byte[44]); // header patched in close()
        }

        void writeSample(short s) throws IOException {
            fos.write(s & 0xFF);
            fos.write((s >> 8) & 0xFF);
            dataBytes += 2;
        }

        void close() throws IOException {
            fos.flush();
            fos.close();
            // Patch the header.
            try (java.io.RandomAccessFile raf =
                         new java.io.RandomAccessFile(new java.io.File(path), "rw")) {
                ByteBuffer h = ByteBuffer.allocate(44)
                        .order(ByteOrder.LITTLE_ENDIAN);
                h.put("RIFF".getBytes());
                h.putInt((int) (36 + dataBytes));
                h.put("WAVE".getBytes());
                h.put("fmt ".getBytes());
                h.putInt(16);
                h.putShort((short) 1); // PCM
                h.putShort((short) 1); // mono
                h.putInt(TARGET_RATE);
                h.putInt(TARGET_RATE * 2); // byte rate
                h.putShort((short) 2); // block align
                h.putShort((short) 16); // bits
                h.put("data".getBytes());
                h.putInt((int) dataBytes);
                raf.write(h.array());
            }
        }
    }
}
