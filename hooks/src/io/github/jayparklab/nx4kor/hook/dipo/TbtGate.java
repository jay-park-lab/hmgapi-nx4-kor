package io.github.jayparklab.nx4kor.hook.dipo;
// NX4 KOR (jay-park-lab/hmgapi-nx4-kor), 2026-11-26 (#67, PR #68 review 1-4).

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * KorTbt's decisions, with no Android or HMG-API in them so the PC tests run them
 * (tests/tools/TbtGateTest.java). Times are elapsedRealtime milliseconds, passed in.
 *
 * - Cluster calls: what this mod's thread sent is remembered per call (ours). A call from
 *   another sender (the official mod) gets this mod's last arguments for that call
 *   (forOther) only while the mod is on, its guidance is on and its listener is heard.
 * - Giving way: if the other sender keeps calling for QUIET_MS while this mod's listener
 *   has heard nothing for QUIET_MS, the phone is plainly sending and only this mod misses
 *   it: its calls pass, and this mod stops resending (yielding) until it hears again.
 *   (A long stop at a light, when nothing is sent to anyone, isn't that: the first
 *   other call after it starts the count, and this mod hears the same update at once.)
 * - Another's Stop of the phone's route guidance: the official mod asks again with
 *   Stop then Start (a source change, its watchdog), DiPO stops for good when CarPlay
 *   ends. Both look the same here, so the clear waits STOP_WAIT_MS: if the phone sends
 *   again meanwhile, it was an ask-again and nothing is cleared (stopDue).
 */
final class TbtGate {
    static final long QUIET_MS = 3000L;
    static final long STOP_WAIT_MS = 2000L;

    private final Map<String, Object[]> last = new ConcurrentHashMap<String, Object[]>();
    /** this mod's guidance is on (CpTurnsFit.active) */
    private volatile boolean active;
    /** when this mod's listener last heard the phone (-1: never) */
    private volatile long heardAt = -1L;
    /** when another sender first called while this mod's listener was quiet (-1: not now) */
    private volatile long otherSince = -1L;
    /** when another's Stop was seen and its clear is pending (-1: none) */
    private volatile long stopAt = -1L;

    /** a cluster call from this mod's thread */
    void ours(String point, Object[] args) {
        last.put(point, copy(args));
    }

    /** the arguments to give another sender's call, or null to let it pass as it is */
    Object[] forOther(String point, int argc, long now, boolean enabled) {
        if (!enabled || !active) return null;
        Object[] o = last.get(point);
        if (o == null || o.length != argc) return null;
        if (quiet(now)) {
            long s = otherSince;
            if (s < 0L) otherSince = s = now;
            if (now - s >= QUIET_MS) return null;   // the phone sends, this mod doesn't hear it: give way
        }
        return copy(o);
    }

    /** this mod gives way: its listener quiet while another sender has been calling for QUIET_MS */
    boolean yielding(long now) {
        long s = otherSince;
        return quiet(now) && s >= 0L && now - s >= QUIET_MS;
    }

    private boolean quiet(long now) {
        long h = heardAt;
        return h < 0L || now - h >= QUIET_MS;
    }

    /** this mod's listener heard the phone (120, 121, 122) */
    void heard(long now) {
        heardAt = now;
        otherSince = -1L;
    }

    /** this mod's guidance on or off after a step: 1 turned on, -1 turned off (its calls forgotten), 0 the same */
    int setActive(boolean a) {
        boolean was = active;
        active = a;
        if (a == was) return 0;
        if (!a) last.clear();
        return a ? 1 : -1;
    }

    boolean active() {
        return active;
    }

    /** a Stop of the phone's route guidance that wasn't this mod's own */
    void stopSeen(long now) {
        stopAt = now;
    }

    /** the pending Stop's clear is due: STOP_WAIT_MS passed and the phone sent nothing since (then it's done) */
    boolean stopDue(long now) {
        long s = stopAt;
        if (s < 0L || now - s < STOP_WAIT_MS) return false;
        stopAt = -1L;
        long h = heardAt;
        return h < s;
    }

    /** the arguments, with byte frames copied (a frame must not change under the other sender) */
    static Object[] copy(Object[] a) {
        Object[] c = a.clone();
        for (int i = 0; i < c.length; i++) {
            if (c[i] instanceof byte[]) c[i] = ((byte[]) c[i]).clone();
        }
        return c;
    }
}
