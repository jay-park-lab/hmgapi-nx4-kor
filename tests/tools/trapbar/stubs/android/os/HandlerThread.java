package android.os;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/tools/trapbar/stubs/android/os/HandlerThread.java
// (Korea Projection, AGPL-3.0): a PC test stub for TrapBarTest (#96).

/** PC 시험용 가짜: 스레드를 만들지 않는다 */
public class HandlerThread {
    public static int started;

    public HandlerThread(String name) {}

    public void start() { started++; }

    public Looper getLooper() { return Looper.MAIN; }
}
