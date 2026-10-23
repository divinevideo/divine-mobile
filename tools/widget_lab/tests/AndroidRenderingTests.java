package video.divine.widgetlab;

import android.app.Instrumentation;
import android.appwidget.AppWidgetHost;
import android.appwidget.AppWidgetHostView;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.ViewFlipper;

public final class AndroidRenderingTests extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            LabActivity activity = (LabActivity) startActivitySync(
                new Intent(getTargetContext(), LabActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            LabState original = LabStore.load(activity);
            try {
                runOnMainSync(() -> {
                    LabStore.save(activity, new LabState());
                    LabState state = LabStore.load(activity);
                    FrameLayout parent = new FrameLayout(activity);
                    View card = HighlightProvider.card(activity, state, true).apply(activity, parent);
                    parent.addView(card);
                    activity.setContentView(parent);
                    ViewFlipper flipper = card.findViewById(R.id.frames);
                    require(flipper.getChildCount() == HighlightProvider.FRAME_COUNT, "16 frame children");
                    require(card.findViewById(R.id.poster).getVisibility() == View.GONE, "poster hidden during motion");
                    require(((TextView) card.findViewById(R.id.title)).getText().toString().equals(HighlightProvider.TITLES[0]), "correct title");
                });
                waitForIdleSync();
                runOnMainSync(() -> {
                    ViewFlipper flipper = activity.findViewById(R.id.frames);
                    require(flipper.isFlipping(), "launcher-compatible ViewFlipper starts when attached");
                    activity.findViewById(R.id.next).performClick();
                });
                await(() -> LabStore.load(activity).nextCount == 1, "Next broadcast");
                runOnMainSync(() -> {
                    LabState state = LabStore.load(activity);
                    require(state.index == 1, "Next selects another video");
                    FrameLayout parent = new FrameLayout(activity);
                    View card = HighlightProvider.card(activity, state, false).apply(activity, parent);
                    parent.addView(card);
                    activity.setContentView(parent);
                    require(card.findViewById(R.id.frames).getVisibility() == View.GONE, "resting frame hides flipper");
                    require(card.findViewById(R.id.poster).getVisibility() == View.VISIBLE, "resting poster shown");
                    card.findViewById(R.id.like).performClick();
                });
                await(() -> LabStore.load(activity).isLiked(), "Like broadcast persists");
                checkSystemHost(activity);
                runOnMainSync(() -> activity.findViewById(R.id.open).performClick());
                await(() -> LabStore.load(activity).openCount == 1, "Open pending intent");
                result.putString("stream", "PASS: RemoteViews inflation, Next, Like, Open, system widget host animation, two-second stop.\n");
            } finally {
                runOnMainSync(() -> { LabStore.save(activity, original); HighlightProvider.render(activity, false); });
            }
            finish(-1, result);
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + failure + "\n");
            finish(0, result);
        }
    }

    private void checkSystemHost(LabActivity activity) throws InterruptedException {
        AppWidgetHost host = new AppWidgetHost(activity, 707);
        int widgetId = host.allocateAppWidgetId();
        try {
            AppWidgetManager manager = AppWidgetManager.getInstance(activity);
            require(manager.bindAppWidgetIdIfAllowed(widgetId, new ComponentName(activity, HighlightProvider.class)),
                "Grant the test app binding with adb shell appwidget grantbind --package video.divine.widgetlab");
            runOnMainSync(() -> {
                host.startListening();
                AppWidgetHostView view = host.createView(activity, widgetId, manager.getAppWidgetInfo(widgetId));
                activity.setContentView(view);
                HighlightProvider.render(activity, false);
            });
            waitForIdleSync();
            final String[] initial = {""};
            try { await(() -> {
                final boolean[] ready = {false};
                runOnMainSync(() -> {
                    TextView title = activity.findViewById(R.id.title);
                    ready[0] = title != null && title.getText().toString().equals(HighlightProvider.TITLES[LabStore.load(activity).index]);
                    initial[0] = "destroyed=" + activity.isDestroyed() + ", title=" + (title == null ? "missing" : title.getText())
                        + ", ids=" + java.util.Arrays.toString(manager.getAppWidgetIds(new ComponentName(activity, HighlightProvider.class)));
                });
                return ready[0];
            }, "system host receives initial card"); }
            catch (AssertionError failure) {
                final String[] tree = {""};
                runOnMainSync(() -> tree[0] = describe(activity.getWindow().getDecorView()));
                throw new AssertionError(failure.getMessage() + ": " + initial[0] + "\n" + tree[0]);
            }
            activity.sendBroadcast(new Intent(activity, HighlightProvider.class).setAction(HighlightProvider.NEXT));
            final String[] diagnostic = {""};
            try { await(() -> {
                final boolean[] playing = {false};
                runOnMainSync(() -> {
                    ViewFlipper frames = activity.findViewById(R.id.frames);
                    playing[0] = frames != null && frames.getVisibility() == View.VISIBLE && frames.isFlipping();
                    diagnostic[0] = frames == null ? "no frame view" : "visible=" + frames.getVisibility()
                        + ", flipping=" + frames.isFlipping() + ", frames=" + frames.getChildCount()
                        + ", attached=" + frames.isAttachedToWindow() + ", animations=" + android.animation.ValueAnimator.areAnimatorsEnabled();
                });
                return playing[0];
            }, "system host starts animation"); }
            catch (AssertionError failure) { throw new AssertionError(failure.getMessage() + ": " + diagnostic[0]); }
            final int[] firstFrame = {-1};
            runOnMainSync(() -> firstFrame[0] = ((ViewFlipper) activity.findViewById(R.id.frames)).getDisplayedChild());
            await(() -> {
                final boolean[] changed = {false};
                runOnMainSync(() -> changed[0] = ((ViewFlipper) activity.findViewById(R.id.frames)).getDisplayedChild() != firstFrame[0]);
                return changed[0];
            }, "frame advances in system host");
            await(() -> {
                final boolean[] resting = {false};
                runOnMainSync(() -> resting[0] = activity.findViewById(R.id.frames).getVisibility() == View.GONE
                    && activity.findViewById(R.id.poster).getVisibility() == View.VISIBLE);
                return resting[0];
            }, "preview stops and returns to poster");
        } finally {
            runOnMainSync(host::stopListening);
            host.deleteAppWidgetId(widgetId);
        }
    }

    private void await(java.util.function.BooleanSupplier condition, String description) throws InterruptedException {
        long deadline = android.os.SystemClock.uptimeMillis() + 5000;
        while (!condition.getAsBoolean() && android.os.SystemClock.uptimeMillis() < deadline) Thread.sleep(25);
        require(condition.getAsBoolean(), description);
    }

    private void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    private String describe(View view) {
        String value = view.getClass().getSimpleName() + " id=" + view.getId();
        if (view instanceof TextView) value += " text=" + ((TextView) view).getText();
        if (view instanceof android.view.ViewGroup) {
            android.view.ViewGroup group = (android.view.ViewGroup) view;
            for (int index = 0; index < group.getChildCount(); index++) value += "\n" + describe(group.getChildAt(index));
        }
        return value;
    }
}
