package video.divine.widgetlab;

public final class LabStateTest {
    public static void main(String[] args) {
        LabState state = new LabState();
        state.next();
        check(state.index == 1 && state.nextCount == 1);
        state.toggleLike();
        check(state.isLiked() && state.likeCount == 1);
        state.next();
        check(!state.isLiked());
        state.next();
        check(state.index == 0);
        state.next();
        check(state.isLiked());
        state.toggleLike();
        check(!state.isLiked() && state.likeCount == 2);
        state.open();
        check(state.openCount == 1);
        int previousRevision = state.revision;
        state.reset();
        check(state.index == 0 && !state.isLiked() && state.nextCount == 0);
        check(state.revision > previousRevision);
        System.out.println("Java state: navigation, per-clip likes, counters passed");
    }

    private static void check(boolean value) {
        if (!value) throw new AssertionError("Unexpected widget state");
    }
}
