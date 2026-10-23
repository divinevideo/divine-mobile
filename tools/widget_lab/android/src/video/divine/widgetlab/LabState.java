package video.divine.widgetlab;

public final class LabState {
    static final int CLIP_COUNT = 3;
    int index;
    int likedMask;
    int nextCount;
    int likeCount;
    int openCount;
    int revision;
    boolean motion = true;

    boolean isLiked() { return (likedMask & (1 << index)) != 0; }

    void next() {
        index = (index + 1) % CLIP_COUNT;
        nextCount++;
        revision++;
    }

    void toggleLike() { likedMask ^= 1 << index; likeCount++; }

    void open() { openCount++; }

    void reset() {
        index = 0;
        likedMask = 0;
        nextCount = 0;
        likeCount = 0;
        openCount = 0;
        motion = true;
        revision++;
    }
}
