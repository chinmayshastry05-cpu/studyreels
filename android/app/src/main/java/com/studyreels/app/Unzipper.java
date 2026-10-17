package com.studyreels.app;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/** Native streaming unzip with per-file progress and cancel. */
final class Unzipper {
    interface Progress {
        void onFile(int done, int total, String name);
    }

    static volatile boolean cancelled = false;

    private Unzipper() {}

    static void unzip(String zipPath, String destDir, Progress progress)
            throws IOException {
        cancelled = false;
        File dest = new File(destDir);
        if (!dest.exists() && !dest.mkdirs()) {
            throw new IOException("cannot create " + destDir);
        }
        String destCanon = dest.getCanonicalPath() + File.separator;
        try (ZipFile zf = new ZipFile(zipPath)) {
            int total = zf.size();
            int done = 0;
            byte[] buf = new byte[256 * 1024];
            Enumeration<? extends ZipEntry> en = zf.entries();
            while (en.hasMoreElements()) {
                if (cancelled) throw new IOException("cancelled");
                ZipEntry e = en.nextElement();
                File out = new File(dest, e.getName());
                if (!out.getCanonicalPath().startsWith(destCanon)) {
                    throw new IOException("bad entry " + e.getName());
                }
                if (e.isDirectory()) {
                    out.mkdirs();
                } else {
                    File parent = out.getParentFile();
                    if (parent != null) parent.mkdirs();
                    try (InputStream in = zf.getInputStream(e);
                            BufferedOutputStream os = new BufferedOutputStream(
                                    new FileOutputStream(out), 256 * 1024)) {
                        int n;
                        while ((n = in.read(buf)) > 0) {
                            if (cancelled) throw new IOException("cancelled");
                            os.write(buf, 0, n);
                        }
                    }
                }
                done++;
                progress.onFile(done, total, e.getName());
            }
        }
    }
}
