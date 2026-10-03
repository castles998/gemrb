// SPDX-License-Identifier: GPL-2.0-or-later
package org.gemrb.android;

import static org.junit.Assert.*;

import java.io.*;
import java.nio.file.Files;
import java.util.zip.*;
import org.junit.Test;

public class RuntimeAssetsTest {
    private InputStream archive(String name, byte[] content) throws IOException {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(buffer)) {
            zip.putNextEntry(new ZipEntry(name));
            zip.write(content);
            zip.closeEntry();
        }
        return new ByteArrayInputStream(buffer.toByteArray());
    }

    @Test
    public void traversalCannotEscapeOwnedRuntime() throws Exception {
        File root = Files.createTempDirectory("gemrb-assets").toFile();
        File runtime = new File(root, "runtime");
        assertTrue(runtime.mkdir());
        try {
            RuntimeAssets.extract(archive("../config.cfg", new byte[] {1}), runtime, root);
            fail("Traversal accepted");
        } catch (IOException expected) {
            assertFalse(new File(root, "config.cfg").exists());
        }
    }

    @Test
    public void extractionAndRetryPreserveUserFiles() throws Exception {
        File root = Files.createTempDirectory("gemrb-assets").toFile();
        File runtime = new File(root, "runtime");
        assertTrue(runtime.mkdir());
        File config = new File(root, "GemRB.cfg");
        Files.write(config.toPath(), new byte[] {9, 8, 7});
        for (int attempt = 0; attempt < 2; attempt++) {
            RuntimeAssets.extract(archive("GUIScripts/test.py", new byte[] {1, 2}), runtime, root);
        }
        assertArrayEquals(new byte[] {9, 8, 7}, Files.readAllBytes(config.toPath()));
        assertArrayEquals(new byte[] {1, 2},
            Files.readAllBytes(new File(runtime, "GUIScripts/test.py").toPath()));
    }

    @Test
    public void missingInstalledExtensionFailsInsteadOfExtractingCode() throws Exception {
        File runtime = Files.createTempDirectory("gemrb-assets").toFile();
        try {
            RuntimeAssets.extract(
                archive("pythonhome/lib/module.so", new byte[] {1}), runtime, runtime);
            fail("Writable extension code accepted");
        } catch (IOException expected) {
            assertFalse(new File(runtime, "pythonhome/lib/module.so").exists());
        }
    }
}
