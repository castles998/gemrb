// SPDX-License-Identifier: GPL-2.0-or-later
package org.gemrb.android;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.widget.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

public final class LauncherActivity extends Activity {
    private TextView status;
    private File runtime;
    private File config;

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(24, 24, 24, 24);
        status = new TextView(this);
        status.setText("Preparing GemRB runtime…");
        layout.addView(status);
        Button diagnostic = new Button(this);
        diagnostic.setText("Run runtime diagnostic (no game needed)");
        diagnostic.setEnabled(false);
        layout.addView(diagnostic);
        Button start = new Button(this);
        start.setText("Start configured game");
        start.setEnabled(false);
        layout.addView(start);
        ScrollView scroll = new ScrollView(this);
        scroll.addView(layout);
        setContentView(scroll);
        diagnostic.setOnClickListener(view -> launch(true));
        start.setOnClickListener(view -> launch(false));
        new Thread(() -> {
            try {
                runtime = RuntimeAssets.prepare(this);
                File user = getExternalFilesDir(null);
                if (user == null)
                    throw new IOException("App-specific storage unavailable");
                File game = new File(user, "game");
                File saves = new File(user, "saves");
                if (!game.isDirectory() && !game.mkdirs())
                    throw new IOException("Cannot create game directory");
                if (!saves.isDirectory() && !saves.mkdirs())
                    throw new IOException("Cannot create save directory");
                config = new File(user, "GemRB.cfg");
                if (!config.exists()) {
                    String defaults =
                        "# Preserved across runtime/app upgrades. No game data is bundled.\n"
                        + "GamePath=" + game + "\nSavePath=" + saves + "\nGameType=auto\n"
                        + ("VideoDriver=sdl\nAudioDriver=openal\nWidth=1280\nHeight="
                           + "720\nFullScreen=1\n");
                    Files.write(config.toPath(), defaults.getBytes(StandardCharsets.UTF_8));
                }
                runOnUiThread(() -> {
                    status.setText("Runtime ready.\n\nNo game data is bundled. Copy a complete "
                                   + "supported game into:\n"
                        + game + "\n\nConfiguration (never overwritten):\n" + config
                        + "\n\nRun the diagnostic first. Game import UI comes in milestone 4.");
                    diagnostic.setEnabled(true);
                    start.setEnabled(true);
                    if (getIntent().getBooleanExtra("diagnostic", false))
                        launch(true);
                    else if (getIntent().getBooleanExtra("startGame", false))
                        launch(false);
                });
            } catch (Exception error) {
                Log.e("GemRB", "Runtime preparation failed", error);
                runOnUiThread(
                    () -> status.setText("Runtime preparation failed: " + error.getMessage()));
            }
        }, "GemRB-assets").start();
    }

    private void launch(boolean diagnostic) {
        Intent intent = new Intent(this, GemRBActivity.class);
        intent.putExtra("runtime", runtime.getAbsolutePath());
        intent.putExtra("config", config.getAbsolutePath());
        intent.putExtra("diagnostic", diagnostic);
        startActivity(intent);
    }

    @Override
    public void onResume() {
        super.onResume();
        File report = new File(getFilesDir(), "runtime-check.txt");
        if (status != null && report.isFile()) {
            try {
                status.append("\n\nLast diagnostic:\n"
                    + new String(Files.readAllBytes(report.toPath()), StandardCharsets.UTF_8));
            } catch (IOException error) {
                Log.w("GemRB", "Cannot read diagnostic", error);
            }
        }
    }
}
