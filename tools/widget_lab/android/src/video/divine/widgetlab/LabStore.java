package video.divine.widgetlab;

import android.content.Context;
import android.content.SharedPreferences;

final class LabStore {
    static LabState load(Context context) {
        SharedPreferences prefs = context.getSharedPreferences("widget_lab", Context.MODE_PRIVATE);
        LabState state = new LabState();
        state.index = Math.floorMod(prefs.getInt("index", 0), LabState.CLIP_COUNT);
        state.likedMask = prefs.getInt("liked", 0);
        state.nextCount = prefs.getInt("next", 0);
        state.likeCount = prefs.getInt("like", 0);
        state.openCount = prefs.getInt("open", 0);
        state.revision = prefs.getInt("revision", 0);
        state.motion = prefs.getBoolean("motion", true);
        return state;
    }

    static void save(Context context, LabState state) {
        context.getSharedPreferences("widget_lab", Context.MODE_PRIVATE).edit()
            .putInt("index", state.index).putInt("liked", state.likedMask)
            .putInt("next", state.nextCount).putInt("like", state.likeCount)
            .putInt("open", state.openCount).putInt("revision", state.revision)
            .putBoolean("motion", state.motion).apply();
    }
}
