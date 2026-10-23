package video.divine.widgetlab;

import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Intent;
import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import android.net.Uri;
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
        text("Create: give an ordinary object a dramatic entrance.", 18);
        button("Open Divine camera", () -> {
            Intent camera = new Intent(Intent.ACTION_VIEW, Uri.parse("divine://quick-action/camera"));
            try { startActivity(camera); }
            catch (android.content.ActivityNotFoundException exception) { text("Install Divine to try the camera shortcut.", 16); }
        });
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

    @Override protected void onResume() { super.onResume(); refreshCounters(); }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    @Override protected void onStop() {
        super.onStop();
        if (player != null) { player.release(); player = null; }
    }

    private void handleIntent(Intent intent) {
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

    private void watch(int clip) {
        if (player != null) { player.release(); player = null; }
        SurfaceView surface = new SurfaceView(this);
        content.addView(surface, new LinearLayout.LayoutParams(-1, 420));
        surface.getHolder().addCallback(new SurfaceHolder.Callback() {
            public void surfaceCreated(SurfaceHolder holder) {
                try (AssetFileDescriptor file = getAssets().openFd("clip_" + clip + ".mp4")) {
                    player = new MediaPlayer();
                    player.setDataSource(file.getFileDescriptor(), file.getStartOffset(), file.getLength());
                    player.setDisplay(holder);
                    player.setOnPreparedListener(MediaPlayer::start);
                    player.prepareAsync();
                } catch (IOException exception) { text("Could not load sample: " + exception.getMessage(), 16); }
            }
            public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) { }
            public void surfaceDestroyed(SurfaceHolder holder) {
                if (player != null) { player.release(); player = null; }
            }
        });
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
