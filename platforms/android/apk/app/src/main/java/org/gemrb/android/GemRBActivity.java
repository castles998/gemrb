// SPDX-License-Identifier: GPL-2.0-or-later
package org.gemrb.android;

import android.system.Os;
import org.libsdl.app.SDLActivity;

public final class GemRBActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {"c++_shared", "SDL2", "iconv", "openal", "python3.10", "gemrb"};
    }

    @Override
    protected String[] getArguments() {
        String runtime = getIntent().getStringExtra("runtime");
        try {
            Os.setenv("PYTHONHOME", runtime + "/pythonhome", true);
            Os.setenv("PYTHONPATH", runtime + "/GUIScripts", true);
            Os.setenv("PYTHONDONTWRITEBYTECODE", "1", true);
            Os.setenv("GEMRB_ANDROID_RUNTIME", runtime, true);
            Os.setenv("GEMRB_ANDROID_REPORT", getFilesDir() + "/runtime-check.txt", true);
        } catch (Exception error) {
            throw new IllegalStateException("Cannot configure Python paths", error);
        }
        if (getIntent().getBooleanExtra("diagnostic", false))
            return new String[] {"--android-runtime-check"};
        return new String[] {"-c", getIntent().getStringExtra("config")};
    }
}
