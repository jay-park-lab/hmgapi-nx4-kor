package android.os;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/tools/trapbar/stubs/android/os/Looper.java
// (Korea Projection, AGPL-3.0): a PC test stub for TrapBarTest (#96).

/** PC 시험용 가짜(모든 Handler가 한 줄 대기열을 쓴다) */
public final class Looper {
    static final Looper MAIN = new Looper();

    public static Looper getMainLooper() { return MAIN; }
}
