package io.github.jayparklab.nx4kor.hook.dipo;
// The interface of Korea Projection's PhoneBarOut (StopDragon/HMG-API korea-build 6258357, AGPL-3.0),
// kept so CpTurnsFit stays as KP wrote it.
// Modified by NX4 KOR (jay-park-lab/hmgapi-nx4-kor), 2026-11-25 (#67): sends nothing. KP broadcasts the
// near-turn bar to its TrapBar hook in the car navigation (com.mnsoft.navi), which this mod doesn't have.

import android.content.Context;

/** KP's near-turn bar broadcast, here a no-op (no receiver in this mod). */
final class PhoneBarOut {
    static final int NONE = -1;

    /** always false: nothing is sent */
    boolean send(Context c, int bar, long now) {
        return false;
    }
}
