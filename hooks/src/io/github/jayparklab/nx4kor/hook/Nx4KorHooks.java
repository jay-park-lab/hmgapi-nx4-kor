package io.github.jayparklab.nx4kor.hook;

import hmgapi.hook.LoadedApp;
import hmgapi.hook.ModContext;
import hmgapi.hook.ModEntry;

/**
 * The nx4-kor mod's hooks (#67). HMG-API loads this class in the zygote; when DiPO (the
 * CarPlay app) starts, it opens the DiPO part (KorTbt), which takes CarPlay turn-by-turn
 * beside the official Wireless CarPlay + Android Auto mod and fits it to the Korean
 * cluster as Korea Projection did. Setting kor_tbt off: nothing here runs.
 *
 * The DiPO part lives in a package of its own (HMG-API appPart): it links against DiPO's
 * iAP2 library. No direct reference either way; it is reached by reflection.
 *
 * #96 (2026-11-27): in the car navigation (com.mnsoft.navi) TrapBar puts the near-turn bar
 * that the DiPO part broadcasts (dipo.PhoneBarOut) into the stock trap frame's bar slot, as
 * Korea Projection did: the cluster draws the near-turn gauge from that slot, so with the bar
 * in the turn frame only the gauge stayed empty.
 */
public final class Nx4KorHooks extends ModEntry {
    static final String DIPO = "com.daudio.app.dipo";
    static final String DIPO_PART = "io.github.jayparklab.nx4kor.hook.dipo.KorTbt";
    static final String NAVIGATION = "com.mnsoft.navi";

    @Override
    public void appLoaded(ModContext mod, LoadedApp app) {
        if (NAVIGATION.equals(app.packageName)) {
            if (!mod.settingBoolean("kor_tbt", true)) return;   // the DiPO side says it is off
            try {
                TrapBar.install(mod, app);
            } catch (Throwable t) {
                mod.error("navigation (NX4 KOR): the near-turn bar in the trap frame didn't start", t);
            }
            return;
        }
        if (!DIPO.equals(app.packageName)) return;   // as the official mod (Wireless.appLoaded)
        if (!mod.settingBoolean("kor_tbt", true)) {
            mod.log("CarPlay (NX4 KOR): Korean turn-by-turn off (setting kor_tbt): the official mod's as it is");
            return;
        }
        try {
            Class<?> c = mod.appPart(app, DIPO_PART);
            c.getMethod("start", ModContext.class, LoadedApp.class).invoke(null, mod, app);
        } catch (Throwable t) {
            mod.error("CarPlay (NX4 KOR): Korean turn-by-turn didn't start", t);
        }
    }
}
