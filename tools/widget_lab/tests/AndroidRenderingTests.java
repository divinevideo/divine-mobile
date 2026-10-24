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
import android.widget.LinearLayout;
import android.graphics.Bitmap;
import java.io.File;
import java.io.FileOutputStream;

public final class AndroidRenderingTests extends Instrumentation {
    private boolean screenshots;
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        screenshots = arguments != null && "true".equals(arguments.getString("screenshots"));
        start();
    }

    @Override public void runOnMainSync(Runnable action) {
        // Report assertions on the instrumentation thread so finally blocks
        // still restore state and release the widget-host binding.
        final Throwable[] failure = {null};
        super.runOnMainSync(() -> {
            try { action.run(); } catch (Throwable error) { failure[0] = error; }
        });
        if (failure[0] != null) throw new AssertionError("Main-thread test failed", failure[0]);
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            AssertionError sentinel = new AssertionError("test failure transport");
            Throwable delivered = null;
            try { runOnMainSync(() -> { throw sentinel; }); }
            catch (AssertionError error) { delivered = error.getCause(); }
            require(delivered == sentinel, "main-thread assertions reach the runner");
            LabActivity activity = (LabActivity) startActivitySync(
                new Intent(getTargetContext(), LabActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            LabState original = LabStore.load(activity);
            final View[] dashboard = {null};
            try {
                checkShapes(activity);
                ComponentName divine = new ComponentName("co.openvine.app", "co.openvine.app.MainActivity");
                Intent camera = LabActivity.cameraIntent(divine);
                require(divine.equals(camera.getComponent()), "camera intent targets the installed Divine activity");
                require("co.openvine.divine_quick_actions.ACTION_QUICK_ACTION".equals(camera.getAction()), "Android camera action contract");
                require("camera".equals(camera.getStringExtra("co.openvine.divine_quick_actions.extra.ACTION_TYPE")), "camera action type");
                require(camera.getBundleExtra("co.openvine.divine_quick_actions.extra.ACTION_PAYLOAD") != null, "camera payload bundle");
                runOnMainSync(() -> {
                    dashboard[0] = ((android.view.ViewGroup) activity.findViewById(android.R.id.content)).getChildAt(0);
                    View watch = findText(activity.getWindow().getDecorView(), "Watch selected sample");
                    require(watch != null, "host watch control exists");
                    watch.performClick();
                    watch.performClick();
                    require(countSurfaces(activity.getWindow().getDecorView()) == 1,
                        "repeated Open reuses one playback surface");
                });
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
                checkSystemHost(activity, dashboard[0]);
                await(() -> LabStore.load(activity).openCount == 1, "Open pending intent");
                if (screenshots) captureShapes(activity);
                result.putString("stream", "PASS: square/tall control bounds, 48 dp targets, mixed-height resize, Next, Like, Open, system widget host animation, two-second stop.\n");
            } finally {
                runOnMainSync(() -> { LabStore.save(activity, original); HighlightProvider.render(activity, false); });
            }
            finish(-1, result);
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + android.util.Log.getStackTraceString(failure) + "\n");
            finish(0, result);
        }
    }

    private void checkShapes(LabActivity activity) {
        runOnMainSync(() -> {
            for (boolean expanded : new boolean[] {false, true}) {
                FrameLayout parent = new FrameLayout(activity);
                View card = HighlightProvider.card(activity, new LabState(), false, expanded).apply(activity, parent);
                parent.addView(card);
                int width = dp(activity, 160);
                int height = dp(activity, expanded ? 280 : 160);
                card.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY));
                card.layout(0, 0, width, height);
                require(card.findViewById(R.id.context).getVisibility() == (expanded ? View.VISIBLE : View.GONE),
                    "only the tall card shows extra context");
                for (int id : new int[] {R.id.like, R.id.next, R.id.open}) {
                    View control = card.findViewById(id);
                    require(control.getWidth() >= dp(activity, 48) && control.getHeight() >= dp(activity, 48),
                        "square and tall controls retain 48 dp touch targets");
                    android.graphics.Rect bounds = new android.graphics.Rect();
                    control.getDrawingRect(bounds);
                    ((android.view.ViewGroup) card).offsetDescendantRectToMyCoords(control, bounds);
                    require(bounds.left >= 0 && bounds.top >= 0 && bounds.right <= width && bounds.bottom <= height,
                        "all controls fit inside each card: expanded=" + expanded + ", id=" + id
                            + ", bounds=" + bounds + ", card=" + width + "x" + height);
                }
            }
        });
    }

    private void captureShapes(LabActivity activity) throws Exception {
        final LinearLayout[] preview = {null};
        runOnMainSync(() -> {
            LinearLayout page = new LinearLayout(activity);
            preview[0] = page;
            page.setOrientation(LinearLayout.VERTICAL);
            page.setPadding(dp(activity, 16), dp(activity, 24), dp(activity, 16), 0);
            page.setBackgroundColor(0xFFF8F8F8);
            TextView heading = new TextView(activity);
            heading.setText("Divine · widget shapes");
            heading.setTextSize(24);
            heading.setTextColor(0xFF202020);
            page.addView(heading);
            LinearLayout row = new LinearLayout(activity);
            for (boolean expanded : new boolean[] {false, true}) {
                LinearLayout column = new LinearLayout(activity);
                column.setOrientation(LinearLayout.VERTICAL);
                TextView label = new TextView(activity);
                label.setText(expanded ? "Tall · 2 × 3" : "Square · 2 × 2");
                label.setTextColor(0xFF202020);
                label.setPadding(0, dp(activity, 20), 0, dp(activity, 12));
                column.addView(label);
                View card = HighlightProvider.card(activity, new LabState(), false, expanded).apply(activity, column);
                column.addView(card, new LinearLayout.LayoutParams(dp(activity, 160), dp(activity, expanded ? 280 : 160)));
                LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(dp(activity, 160), -2);
                params.setMarginEnd(dp(activity, 12));
                row.addView(column, params);
            }
            page.addView(row);
            activity.setContentView(page);
        });
        waitForIdleSync();
        final Bitmap[] snapshot = {null};
        runOnMainSync(() -> {
            LinearLayout page = preview[0];
            int bottom = page.getChildAt(page.getChildCount() - 1).getBottom() + dp(activity, 16);
            snapshot[0] = Bitmap.createBitmap(page.getWidth(), bottom, Bitmap.Config.ARGB_8888);
            page.draw(new android.graphics.Canvas(snapshot[0]));
        });
        Bitmap image = snapshot[0];
        File file = new File(activity.getFilesDir(), "widget-shapes.png");
        try (FileOutputStream stream = new FileOutputStream(file)) {
            image.compress(Bitmap.CompressFormat.PNG, 100, stream);
        }
        image.recycle();
    }

    private int dp(LabActivity activity, int value) {
        return Math.round(value * activity.getResources().getDisplayMetrics().density);
    }

    private void checkSystemHost(LabActivity activity, View dashboard) throws InterruptedException {
        AppWidgetHost host = new AppWidgetHost(activity, 707);
        final AppWidgetHostView[] hosted = {null};
        int widgetId = host.allocateAppWidgetId();
        try {
            AppWidgetManager manager = AppWidgetManager.getInstance(activity);
            require(manager.bindAppWidgetIdIfAllowed(widgetId, new ComponentName(activity, HighlightProvider.class)),
                "Grant the test app binding with adb shell appwidget grantbind --package video.divine.widgetlab");
            runOnMainSync(() -> {
                host.startListening();
                AppWidgetHostView view = host.createView(activity, widgetId, manager.getAppWidgetInfo(widgetId));
                hosted[0] = view;
                FrameLayout parent = new FrameLayout(activity);
                parent.addView(view, new FrameLayout.LayoutParams(dp(activity, 160), dp(activity, 160)));
                activity.setContentView(parent);
                view.updateAppWidgetSize(new Bundle(), 160, 160, 160, 160);
                HighlightProvider.render(activity, false);
            });
            waitForIdleSync();
            final String[] initial = {""};
            try { await(() -> {
                final boolean[] ready = {false};
                runOnMainSync(() -> {
                    // AppWidgetHostView is a root namespace: Activity lookup
                    // intentionally cannot traverse into its remote children.
                    TextView title = hosted[0].findViewById(R.id.title);
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
                    ViewFlipper frames = hosted[0].findViewById(R.id.frames);
                    playing[0] = frames != null && frames.getVisibility() == View.VISIBLE && frames.isFlipping();
                    diagnostic[0] = frames == null ? "no frame view" : "visible=" + frames.getVisibility()
                        + ", flipping=" + frames.isFlipping() + ", frames=" + frames.getChildCount()
                        + ", attached=" + frames.isAttachedToWindow() + ", animations=" + android.animation.ValueAnimator.areAnimatorsEnabled();
                });
                return playing[0];
            }, "system host starts animation"); }
            catch (AssertionError failure) { throw new AssertionError(failure.getMessage() + ": " + diagnostic[0]); }
            final int[] firstFrame = {-1};
            runOnMainSync(() -> firstFrame[0] = ((ViewFlipper) hosted[0].findViewById(R.id.frames)).getDisplayedChild());
            await(() -> {
                final boolean[] changed = {false};
                runOnMainSync(() -> changed[0] = ((ViewFlipper) hosted[0].findViewById(R.id.frames)).getDisplayedChild() != firstFrame[0]);
                return changed[0];
            }, "frame advances in system host");
            await(() -> {
                final boolean[] resting = {false};
                runOnMainSync(() -> resting[0] = hosted[0].findViewById(R.id.frames).getVisibility() == View.GONE
                    && hosted[0].findViewById(R.id.poster).getVisibility() == View.VISIBLE);
                return resting[0];
            }, "preview stops and returns to poster");
            for (int height : new int[] {280, 160}) {
                Bundle size = new Bundle();
                size.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 160);
                size.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 160);
                // Portrait can be tall while the landscape minimum stays square.
                size.putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160);
                size.putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, height);
                runOnMainSync(() -> {
                    hosted[0].setLayoutParams(new FrameLayout.LayoutParams(dp(activity, 160), dp(activity, height)));
                    hosted[0].updateAppWidgetSize(size, 160, 160, 160, height);
                });
                await(() -> {
                    final boolean[] resized = {false};
                    runOnMainSync(() -> {
                        View context = hosted[0].findViewById(R.id.context);
                        resized[0] = context != null && context.getVisibility() == (height >= 240 ? View.VISIBLE : View.GONE);
                    });
                    return resized[0];
                }, "system host switches square/tall context on resize");
            }
            runOnMainSync(() -> {
                activity.setContentView(dashboard);
                hosted[0].findViewById(R.id.open).performClick();
            });
            await(() -> LabStore.load(activity).openCount == 1, "system host Open pending intent");
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

    private View findText(View view, String text) {
        if (view instanceof TextView && text.contentEquals(((TextView) view).getText())) return view;
        if (view instanceof android.view.ViewGroup) {
            android.view.ViewGroup group = (android.view.ViewGroup) view;
            for (int index = 0; index < group.getChildCount(); index++) {
                View found = findText(group.getChildAt(index), text);
                if (found != null) return found;
            }
        }
        return null;
    }

    private int countSurfaces(View view) {
        int count = view instanceof android.view.SurfaceView ? 1 : 0;
        if (view instanceof android.view.ViewGroup) {
            android.view.ViewGroup group = (android.view.ViewGroup) view;
            for (int index = 0; index < group.getChildCount(); index++) count += countSurfaces(group.getChildAt(index));
        }
        return count;
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
