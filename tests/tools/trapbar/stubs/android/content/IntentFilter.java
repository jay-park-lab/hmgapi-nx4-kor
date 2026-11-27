package android.content;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/tools/trapbar/stubs/android/content/IntentFilter.java
// (Korea Projection, AGPL-3.0): a PC test stub for TrapBarTest (#96).

import java.util.ArrayList;
import java.util.List;

/** PC 시험용 가짜 */
public class IntentFilter {
    public final List<String> actions = new ArrayList<String>();

    public IntentFilter() {}

    public IntentFilter(String a) { actions.add(a); }

    public void addAction(String a) { actions.add(a); }
}
