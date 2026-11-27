package hmgapi.hook;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/tools/trapbar/stubs/hmgapi/hook/LoadedApp.java
// (Korea Projection, AGPL-3.0): a PC test stub for TrapBarTest (#96).

import android.content.Context;

/** PC 시험용 가짜 LoadedApp */
public final class LoadedApp {
    public final String packageName;
    public final String processName;
    public final ClassLoader classLoader;
    public final Context context;

    public LoadedApp(String packageName, ClassLoader cl, Context context) {
        this.packageName = packageName;
        this.processName = packageName;
        this.classLoader = cl;
        this.context = context;
    }
}
