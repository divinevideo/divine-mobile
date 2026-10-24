package video.divine.widgetlab;

import android.animation.ValueAnimator;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.os.Bundle;
import android.os.Build;
import android.util.SizeF;
import android.view.View;
import android.widget.RemoteViews;
import java.util.LinkedHashMap;
import java.util.Map;

public final class HighlightProvider extends AppWidgetProvider {
    static final String NEXT = "video.divine.widgetlab.NEXT";
    static final String LIKE = "video.divine.widgetlab.LIKE";
    static final int FRAME_COUNT = 16;
    static final int PREVIEW_MS = 2000;
    static final String[] TITLES = {"A little weirdness", "Six seconds of joy", "Look what people make"};

    @Override public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        render(context, false);
    }

    @Override public void onAppWidgetOptionsChanged(Context context, AppWidgetManager manager,
            int widgetId, Bundle options) {
        render(context, false);
    }

    @Override public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (!NEXT.equals(action) && !LIKE.equals(action)) {
            super.onReceive(context, intent);
            return;
        }
        LabState state = LabStore.load(context);
        if (NEXT.equals(action)) state.next(); else state.toggleLike();
        LabStore.save(context, state);
        boolean animate = NEXT.equals(action) && state.motion && ValueAnimator.areAnimatorsEnabled();
        render(context, animate);
        if (animate) {
            final int revision = state.revision;
            final PendingResult pending = goAsync();
            // Keep the receiver alive until the launcher gets the resting poster.
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                try {
                    if (LabStore.load(context).revision == revision) render(context, false);
                } finally {
                    pending.finish();
                }
            }, PREVIEW_MS);
        }
    }

    static void render(Context context, boolean animate) {
        LabState state = LabStore.load(context);
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        for (int id : manager.getAppWidgetIds(new ComponentName(context, HighlightProvider.class))) {
            RemoteViews views;
            if (Build.VERSION.SDK_INT >= 31) {
                // The launcher chooses for its displayed size, including rotation.
                // MIN_HEIGHT alone can describe the smaller landscape footprint.
                Map<SizeF, RemoteViews> sizes = new LinkedHashMap<>();
                sizes.put(new SizeF(144, 144), card(context, state, animate, false));
                sizes.put(new SizeF(144, 240), card(context, state, animate, true));
                views = new RemoteViews(sizes);
            } else {
                Bundle options = manager.getAppWidgetOptions(id);
                int minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 144);
                int maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeight);
                views = new RemoteViews(card(context, state, animate, minHeight >= 240),
                    card(context, state, animate, maxHeight >= 240));
            }
            manager.updateAppWidget(id, views);
        }
    }

    static RemoteViews card(Context context, LabState state, boolean animate) {
        return card(context, state, animate, false);
    }

    static RemoteViews card(Context context, LabState state, boolean animate, boolean expanded) {
        RemoteViews views = new RemoteViews(context.getPackageName(), expanded ? R.layout.highlight_widget_tall : R.layout.highlight_widget);
        views.setViewVisibility(R.id.context, expanded ? View.VISIBLE : View.GONE);
        views.setTextViewText(R.id.title, TITLES[state.index]);
        views.setTextViewText(R.id.like, state.isLiked() ? "♥" : "♡");
        views.setContentDescription(R.id.like, state.isLiked() ? "Liked" : "Like");
        views.setTextColor(R.id.like, state.isLiked() ? 0xFF27C58B : 0xFFFFFFFF);
        views.setImageViewResource(R.id.poster, frameResource(context, state.index, FRAME_COUNT - 1));
        views.setViewVisibility(R.id.frames, animate ? View.VISIBLE : View.GONE);
        views.setViewVisibility(R.id.poster, animate ? View.GONE : View.VISIBLE);
        views.removeAllViews(R.id.frames);
        if (animate) {
            for (int frame = 0; frame < FRAME_COUNT; frame++) {
                RemoteViews child = new RemoteViews(context.getPackageName(), R.layout.frame);
                child.setImageViewResource(R.id.frame_image, frameResource(context, state.index, frame));
                views.addView(R.id.frames, child);
            }
            views.setInt(R.id.frames, "setFlipInterval", PREVIEW_MS / FRAME_COUNT);
        }
        views.setOnClickPendingIntent(R.id.next, action(context, NEXT, 1));
        views.setOnClickPendingIntent(R.id.like, action(context, LIKE, 2));
        Intent divine = context.getPackageManager().getLaunchIntentForPackage("co.openvine.app");
        PendingIntent camera = PendingIntent.getActivity(context, 4,
            cameraIntent(context, divine == null ? null : divine.getComponent()),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.camera, camera);
        Intent open = new Intent(context, LabActivity.class).setAction("watch")
            .putExtra("clip", state.index).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent watch = PendingIntent.getActivity(context, 3, open,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.open, watch);
        views.setOnClickPendingIntent(R.id.poster, watch);
        views.setOnClickPendingIntent(R.id.frames, watch);
        return views;
    }

    static Intent cameraIntent(Context context, ComponentName divine) {
        if (divine != null) return LabActivity.cameraIntent(divine).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return new Intent(context, LabActivity.class).setAction("camera")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
    }

    private static PendingIntent action(Context context, String action, int request) {
        Intent intent = new Intent(context, HighlightProvider.class).setAction(action);
        return PendingIntent.getBroadcast(context, request, intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static int frameResource(Context context, int clip, int frame) {
        return context.getResources().getIdentifier(
            String.format(java.util.Locale.ROOT, "clip_%d_frame_%02d", clip, frame),
            "drawable", context.getPackageName());
    }
}
