package android.os;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/tools/trapbar/stubs/android/os/SystemClock.java
// (Korea Projection, AGPL-3.0): a PC test stub for TrapBarTest (#96).

/** PC 시험용 가짜 시계: 시험이 now를 정한다(Handler.runUntil이 앞으로 돌림) */
public final class SystemClock {
    public static long now = 1000000L;

    public static long elapsedRealtime() { return now; }
}
