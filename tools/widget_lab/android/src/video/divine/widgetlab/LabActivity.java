package video.divine.widgetlab;

import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Intent;
import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import android.os.Bundle;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;
import java.io.IOException;

public final class LabActivity extends Activity {
    private LinearLayout content;
    private TextView counters;
    private MediaPlayer player;
    private SurfaceView playbackSurface;
    private int selectedClip = -1;
    private boolean resumed;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        ScrollView scroll = new ScrollView(this);
        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(32, 48, 32, 32);
        scroll.addView(content);
        setContentView(scroll);
        text("Divine Widget Lab", 28);
        text("A moment of joy, right on your home screen", 18);
        text("Add the widget below, return home, then tap Next on the widget. The motion test uses 16 sampled frames over two seconds and then rests on a poster.", 16);
        button("Add home-screen widget", () -> {
            AppWidgetManager manager = getSystemService(AppWidgetManager.class);
            if (manager.isRequestPinAppWidgetSupported()) {
                manager.requestPinAppWidget(new ComponentName(this, HighlightProvider.class), null, null);
            } else text("Long-press your home screen, choose Widgets, then Divine Widget Lab.", 16);
        });
        Switch motion = new Switch(this);
        motion.setText("Try two-second frame sequence");
        motion.setChecked(LabStore.load(this).motion);
        motion.setOnCheckedChangeListener((view, checked) -> {
            LabState current = LabStore.load(this);
            current.motion = checked;
            LabStore.save(this, current);
            HighlightProvider.render(this, false);
        });
        content.addView(motion);
        button("Highlight another sample", () -> {
            LabState current = LabStore.load(this);
            current.next();
            LabStore.save(this, current);
            HighlightProvider.render(this, false);
            refreshCounters();
        });
        button("Watch selected sample", () -> watch(LabStore.load(this).index));
        playbackSurface = new SurfaceView(this);
        playbackSurface.setVisibility(android.view.View.GONE);
        content.addView(playbackSurface, new LinearLayout.LayoutParams(-1, 420));
        playbackSurface.getHolder().addCallback(new SurfaceHolder.Callback() {
            public void surfaceCreated(SurfaceHolder holder) { startPlayback(); }
            public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) { }
            public void surfaceDestroyed(SurfaceHolder holder) { releasePlayer(); }
        });
        text("Create: give an ordinary object a dramatic entrance.", 18);
        button("Open Divine camera", this::openCamera);
        counters = text("", 16);
        text("Local demo only. Likes are not published. Rendering the widget is not counted as a view or an active user. No network requests or analytics uploads.", 16);
        button("Reset experiment", () -> {
            LabState current = LabStore.load(this);
            current.reset();
            LabStore.save(this, current);
            motion.setChecked(true);
            HighlightProvider.render(this, false);
            refreshCounters();
        });
        handleIntent(getIntent());
    }

    @Override protected void onResume() {
        super.onResume();
        resumed = true;
        refreshCounters();
        if (player == null) startPlayback();
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    @Override protected void onStop() {
        super.onStop();
        resumed = false;
        releasePlayer();
    }

    private void handleIntent(Intent intent) {
        if ("camera".equals(intent.getAction())) {
            intent.setAction(null);
            openCamera();
            return;
        }
        if (!"watch".equals(intent.getAction())) return;
        int clip = intent.getIntExtra("clip", -1);
        if (clip < 0 || clip >= LabState.CLIP_COUNT) return;
        LabState state = LabStore.load(this);
        state.open();
        LabStore.save(this, state);
        watch(clip);
        intent.setAction(null);
        refreshCounters();
    }

    private void openCamera() {
        Intent launch = getPackageManager().getLaunchIntentForPackage("co.openvine.app");
        if (launch != null) {
            try { startActivity(cameraIntent(launch.getComponent())); return; }
            catch (android.content.ActivityNotFoundException exception) { /* App was removed after lookup. */ }
        }
        TextView notice = text("Install Divine to open the camera.", 16);
        notice.post(() -> notice.requestRectangleOnScreen(
            new android.graphics.Rect(0, 0, notice.getWidth(), notice.getHeight()), false));
    }

    private void watch(int clip) {
        selectedClip = clip;
        playbackSurface.setVisibility(android.view.View.VISIBLE);
        startPlayback();
        playbackSurface.post(() -> playbackSurface.requestRectangleOnScreen(
            new android.graphics.Rect(0, 0, playbackSurface.getWidth(), playbackSurface.getHeight()), false));
    }

    private void startPlayback() {
        if (!resumed || selectedClip < 0 || !playbackSurface.getHolder().getSurface().isValid()) return;
        releasePlayer();
        try (AssetFileDescriptor file = getAssets().openFd("clip_" + selectedClip + ".mp4")) {
            MediaPlayer current = new MediaPlayer();
            player = current;
            current.setDataSource(file.getFileDescriptor(), file.getStartOffset(), file.getLength());
            current.setDisplay(playbackSurface.getHolder());
            current.setOnPreparedListener(prepared -> {
                if (resumed && player == prepared) prepared.start();
            });
            current.setOnErrorListener((failed, what, extra) -> {
                if (player == failed) releasePlayer();
                text("Could not play sample.", 16);
                return true;
            });
            current.prepareAsync();
        } catch (IOException exception) {
            releasePlayer();
            text("Could not load sample: " + exception.getMessage(), 16);
        }
    }

    private void releasePlayer() {
        if (player == null) return;
        player.release();
        player = null;
    }

    static Intent cameraIntent(ComponentName component) {
        // Match Divine's Android QuickActionContract, not the iOS-only URL.
        return new Intent("co.openvine.divine_quick_actions.ACTION_QUICK_ACTION")
            .setComponent(component)
            .putExtra("co.openvine.divine_quick_actions.extra.ACTION_TYPE", "camera")
            .putExtra("co.openvine.divine_quick_actions.extra.ACTION_PAYLOAD", new Bundle())
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    }

    private void refreshCounters() {
        if (counters == null) return;
        LabState state = LabStore.load(this);
        counters.setText("Local actions · Next " + state.nextCount + " · Like/unlike " + state.likeCount + " · Open " + state.openCount);
    }

    private TextView text(String value, int size) {
        TextView label = new TextView(this);
        label.setText(value);
        label.setTextSize(size);
        label.setPadding(0, 12, 0, 12);
        content.addView(label);
        return label;
    }

    private void button(String title, Runnable action) {
        Button button = new Button(this);
        button.setText(title);
        button.setOnClickListener(view -> action.run());
        content.addView(button);
    }
}
