// SPDX-License-Identifier: GPL-2.0-or-later
package org.gemrb.android;

import android.content.Context;
import android.system.ErrnoException;
import android.system.Os;
import android.util.Log;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

final class RuntimeAssets {
    static File prepare(Context context) throws IOException {
        String id;
        try (InputStream input = context.getAssets().open("runtime-id.txt")) {
            id = new String(readAll(input), StandardCharsets.UTF_8).trim();
        }
        if (!id.matches("[a-f0-9]{64}"))
            throw new IOException("Invalid runtime version");
        File runtime = new File(context.getFilesDir(), "runtime/" + id);
        File marker = new File(runtime, ".complete");
        if (!marker.isFile()) {
            if (!runtime.isDirectory() && !runtime.mkdirs())
                throw new IOException("Cannot create runtime");
            try (InputStream input = context.getAssets().open("runtime.zip")) {
                extract(input, runtime, new File(context.getApplicationInfo().nativeLibraryDir));
            }
            Files.write(marker.toPath(), id.getBytes(StandardCharsets.UTF_8));
            Log.i("GemRB", "ANDROID_ASSETS_EXTRACTED " + id);
        } else {
            Log.i("GemRB", "ANDROID_ASSETS_REUSED " + id);
        }
        // Android may change nativeLibraryDir on APK update, even when assets
        // haven't changed. Refresh only owned extension symlinks, not scripts.
        try (java.util.stream.Stream<java.nio.file.Path> paths = Files.walk(runtime.toPath())) {
            for (java.nio.file.Path path : (Iterable<java.nio.file.Path>) paths::iterator) {
                if (path.getFileName().toString().endsWith(".so"))
                    linkExtension(
                        path.toFile(), new File(context.getApplicationInfo().nativeLibraryDir));
            }
        }
        return runtime;
    }

    // Canonical-path validation prevents ZIP traversal; only owned runtime files
    // are extracted. Config, games and saves are outside this versioned tree.
    static void extract(InputStream input, File root, File nativeDir) throws IOException {
        String prefix = root.getCanonicalPath() + File.separator;
        try (ZipInputStream zip = new ZipInputStream(input)) {
            ZipEntry entry;
            byte[] buffer = new byte[65536];
            while ((entry = zip.getNextEntry()) != null) {
                File output = new File(root, entry.getName());
                // A previous interrupted extraction may already have extension
                // symlinks. Validate their parent, then their exact installed target.
                String parentPath = output.getParentFile().getCanonicalPath() + File.separator;
                if (!parentPath.startsWith(prefix))
                    throw new IOException("Unsafe asset path");
                if (!entry.getName().endsWith(".so")
                    && !output.getCanonicalPath().startsWith(prefix))
                    throw new IOException("Unsafe asset path");
                if (entry.isDirectory()) {
                    if (!output.isDirectory() && !output.mkdirs())
                        throw new IOException("Cannot create asset directory");
                    continue;
                }
                File parent = output.getParentFile();
                if (!parent.isDirectory() && !parent.mkdirs())
                    throw new IOException("Cannot create asset parent");
                if (entry.getName().endsWith(".so")) {
                    // Extension code lives in the installed APK's native library
                    // directory, not writable asset storage. Python sees its usual name.
                    linkExtension(output, nativeDir);
                } else {
                    try (OutputStream file = new FileOutputStream(output)) {
                        int count;
                        while ((count = zip.read(buffer)) != -1) file.write(buffer, 0, count);
                    }
                }
            }
        }
    }

    private static void linkExtension(File output, File nativeDir) throws IOException {
        File installed = new File(nativeDir, "libpy_" + output.getName());
        if (!installed.isFile())
            throw new IOException("Missing Python extension " + installed);
        if (Files.isSymbolicLink(output.toPath())) {
            if (Files.readSymbolicLink(output.toPath())
                    .toString()
                    .equals(installed.getAbsolutePath()))
                return;
            Files.delete(output.toPath()); // unlink only this owned extension link
        } else if (output.exists()) {
            throw new IOException("Unexpected Python extension file");
        }
        try {
            Os.symlink(installed.getAbsolutePath(), output.getAbsolutePath());
        } catch (ErrnoException error) {
            throw new IOException("Cannot link Python extension", error);
        }
    }

    private static byte[] readAll(InputStream input) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int count;
        while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
        return output.toByteArray();
    }
}
