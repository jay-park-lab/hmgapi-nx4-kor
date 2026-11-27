package io.github.jayparklab.nx4kor.hook.dipo;
// NX4 KOR (jay-park-lab/hmgapi-nx4-kor), 2026-11-26 (#67, PR #68 review 1-4).
// Modified by NX4 KOR, 2026-11-26 (2.1.2-beta.4, #67): the other sender's call held for this mod's (hold, held, done);
//   PR #85 review 1, 3, 4: waits for all the listener heard, no wait for a hear while guidance is on, argument count;
//   PR #85 review 6: held-call log lines counted per call and in all, again from each guidance's end (heldLog).

import java.util.Arrays;
import java.util.HashMap;
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
 * - Fewer cluster calls (2026-11-26, #77): the official mod's call already carries this mod's
 *   arguments, so this mod skips its own call when its values are the ones it last sent
 *   and the official mod carried exactly those within CARRIED_MS (skipOurs). A call the
 *   official mod doesn't make (#67's stalled turn) or a resend while the phone is quiet
 *   (the official mod sends nothing then) still goes out.
 * - Holding the other sender's call (2026-11-26, 2.1.2-beta.4, #67): both listeners get the
 *   same update, and when the official mod's thread draws it first while this mod has
 *   nothing for that call yet (its guidance not on yet: a start, or on again after a Stop,
 *   a source change or the end of a route; or no value of its own for that call), that
 *   whole set went to the cluster as the official mod's, and stayed there until this mod's
 *   thread sent its own (the official mod has no resend timer). So such a call waits
 *   (held), at most HOLD_MS, for this mod's thread to finish all its listener has heard,
 *   also what it hears meanwhile (PR #85 review 1: a 121 done while the 120 that turns
 *   guidance on is still to come isn't the end); if this mod then has its values, the
 *   call carries them. With this mod's guidance off, a listener that hasn't heard the
 *   update yet gets HEAR_MS to hear it; with it on, a call this mod never made (lanes
 *   from an app without lanes, the official mod's HUD clear) waits only for what was
 *   already heard, not for an update that may not come (PR #85 review 3). If this mod
 *   still has nothing, the call passes as before, and the next ones don't wait until its
 *   listener hears something new (one wait per update at most, none for a listener that
 *   hears nothing after the first HEAR_MS: the official mod alone). A call held for an
 *   argument count other than this mod's passes after the wait (PR #85 review 4). Only
 *   that call's thread waits (Object.wait, woken by done); this mod's thread never waits
 *   for it.
 */
final class TbtGate {
    static final long QUIET_MS = 3000L;
    static final long STOP_WAIT_MS = 2000L;
    /**
     * How long the official mod's call that carried this mod's latest arguments stands in for this mod's own call
     * of the same values: within REFRESH's resend (it resends after 900 ms without an update, CpTurnsFit)
     */
    static final long CARRIED_MS = 900L;
    /**
     * What arrives this soon after a Stop was sent before it (the phone's last update on its way): not an
     * ask-again. Both mods ask again with Stop, 200 ms, Start, so a real resend comes later (PR #68 review 12).
     */
    static final long STOP_RESEND_MIN_MS = 150L;
    /**
     * How long the other sender's call waits at most for this mod's thread (held): well under the phone's update
     * (about a second) and the official mod's next call, long enough for this mod's thread to finish an update
     */
    static final long HOLD_MS = 250L;
    /** Within HOLD_MS, how long it waits for this mod's listener to hear the update at all (it may be just behind) */
    static final long HEAR_MS = 50L;
    /** held calls logged with kor_tbt_log, in all and for one call, until guidance goes off or the connection ends */
    static final int HELD_LOGS_MAX = 100, HELD_LOGS_PER_POINT = 20;

    private final Map<String, Object[]> last = new ConcurrentHashMap<String, Object[]>();
    /** per call: this mod's arguments (the very array in last) when the official mod last carried them, and when */
    private final Map<String, Carried> carried = new ConcurrentHashMap<String, Carried>();
    /** per call: the values this mod last asked to send, in its own form (ClusterOut), before the cluster call */
    private final Map<String, Object[]> asked = new ConcurrentHashMap<String, Object[]>();
    /** this mod's guidance is on (CpTurnsFit.active) */
    private volatile boolean active;
    /** when this mod's listener last heard the phone (-1: never) */
    private volatile long heardAt = -1L;
    /** when another sender first called while this mod's listener was quiet (-1: not now) */
    private volatile long otherSince = -1L;
    /** when another sender last called while this mod's listener was quiet (-1: not now) */
    private volatile long otherLast = -1L;
    /** when another's Stop was seen and its clear is pending (-1: none) */
    private volatile long stopAt = -1L;
    /** updates this mod's listener heard, the last one its thread finished, and heardSeq when a held call last passed */
    private long heardSeq, doneSeq, passedSeq = -1L;
    /** held calls logged since guidance last went off or the connection ended: per call, and in all (heldLog) */
    private final Map<String, Integer> heldLogs = new HashMap<String, Integer>();
    private int heldLogsAll;

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
            otherLast = now;
            if (now - s >= QUIET_MS) {
                // the phone sends, this mod doesn't hear it: give way. This call carries the official mod's own
                // values, so what it carried of ours before no longer stands (PR #78 review 4)
                carried.remove(point);
                return null;
            }
        }
        carried.put(point, new Carried(o, now));
        return copy(o);
    }

    /**
     * this mod is about to make cluster call point with values key (its own form of the arguments): true to skip it,
     * when key is what it last asked to send and the official mod carried those arguments (still this mod's latest
     * for that call) within CARRIED_MS. Otherwise it notes key and the call goes out.
     */
    boolean skipOurs(String point, Object[] key, long now) {
        Object[] was = asked.get(point);
        if (was != null && Arrays.deepEquals(was, key)) {
            Carried c = carried.get(point);
            Object[] l = last.get(point);
            if (c != null && l != null && c.args == l && now - c.at < CARRIED_MS) return true;
        }
        asked.put(point, copy(key));
        return false;
    }

    /** while yielding: when the yield ends unless the other sender calls again (ms from now, at least 0) */
    long yieldEndsIn(long now) {
        long l = otherLast;
        return l < 0L ? 0L : Math.max(0L, l + QUIET_MS - now);
    }

    /**
     * this mod gives way: its listener quiet while another sender has been calling for QUIET_MS and
     * still is (its last call within QUIET_MS: one call, then silence for everyone, isn't "keeps
     * calling", PR #68 review 13)
     */
    boolean yielding(long now) {
        long s = otherSince, l = otherLast;
        return quiet(now) && s >= 0L && now - s >= QUIET_MS && l >= 0L && now - l < QUIET_MS;
    }

    private boolean quiet(long now) {
        long h = heardAt;
        return h < 0L || now - h >= QUIET_MS;
    }

    /** this mod's listener heard the phone (120, 121, 122): the update's number, for done once this mod's thread is through */
    synchronized long heard(long now) {
        heardAt = now;
        otherSince = -1L;
        otherLast = -1L;
        return ++heardSeq;
    }

    /** this mod's thread is through with update seq (and noted whether its guidance is on): held calls look again */
    synchronized void done(long seq) {
        if (seq > doneSeq) doneSeq = seq;
        notifyAll();
    }

    /** time and waiting for a held call (KorTbt: elapsedRealtime and Object.wait; the PC tests their own) */
    interface Waits {
        long now();

        /** waits on lock, whose monitor the caller holds, at most ms (or until done notifies) */
        void await(Object lock, long ms) throws InterruptedException;
    }

    /** a held call: when it came, and the update of this mod's listener it waits for this mod's thread to be through with */
    static final class Hold {
        final long start, target;

        Hold(long start, long target) {
            this.start = start;
            this.target = target;
        }
    }

    /** this mod has nothing to give the other sender's call: its guidance is off, or it never made that call since */
    private boolean lacks(String point) {
        return !active || last.get(point) == null;
    }

    /**
     * the other sender's call that forOther gave nothing: hold it (non-null) only when this mod lacks it (its guidance is
     * off, or it never made that call since: not when giving way, nor for another argument count while it has a value),
     * and either its thread hasn't finished what its listener heard, or, with its guidance off, its listener may be just
     * about to hear that update (PR #85 review 3: with it on, a call it never made isn't one it's about to make: no wait
     * for a hear); not again after a held call passed, until the listener hears something new
     */
    synchronized Hold hold(String point, long now) {
        if (!lacks(point) || passedSeq == heardSeq) return null;
        if (doneSeq < heardSeq) return new Hold(now, heardSeq);
        return active ? null : new Hold(now, heardSeq + 1);
    }

    /**
     * how much longer the held call waits (ms, 0: no longer): until this mod has its values, or its thread is through with
     * the update waited for and all its listener heard meanwhile (PR #85 review 1), at most HOLD_MS from the start, or
     * HEAR_MS while the listener hasn't heard that update
     */
    synchronized long holdLeft(Hold h, String point, long now) {
        if (!lacks(point) || doneSeq >= Math.max(h.target, heardSeq)) return 0L;
        long limit = heardSeq >= h.target ? HOLD_MS : HEAR_MS;
        return Math.max(0L, h.start + limit - now);
    }

    /** a held call passed after all: don't hold again until this mod's listener hears something new */
    synchronized void holdPassed() {
        passedSeq = heardSeq;
    }

    /** held, without telling how long it waited */
    Object[] held(String point, int argc, boolean enabled, Waits w) {
        return held(point, argc, enabled, w, null);
    }

    /**
     * for a call forOther gave nothing: forOther again after waiting for this mod's thread, if hold says so. This mod's
     * arguments for it, or null to let it pass as it is (also at once when there's nothing to wait for; and after the
     * wait for an argument count other than this mod's). waited[0] (if given): ms it waited, or -1 when it wasn't held.
     * Only the calling thread waits, without spinning (done wakes it).
     */
    Object[] held(String point, int argc, boolean enabled, Waits w, long[] waited) {
        if (waited != null) waited[0] = -1L;
        if (!enabled) return null;
        long start = w.now();
        Hold h = hold(point, start);
        if (h == null) return null;
        synchronized (this) {
            for (long left; (left = holdLeft(h, point, w.now())) > 0L;) {
                try {
                    w.await(this, left);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
        long now = w.now();
        if (waited != null) waited[0] = Math.max(0L, now - start);
        Object[] c = forOther(point, argc, now, enabled);
        if (c == null) holdPassed();
        return c;
    }

    /** this mod's guidance on or off after a step: 1 turned on, -1 turned off (its calls forgotten), 0 the same */
    int setActive(boolean a) {
        boolean was = active;
        active = a;
        if (a == was) return 0;
        if (!a) {
            last.clear();
            carried.clear();
            asked.clear();
            // PR #85 review 6: the next start's held calls get lines of their own
            heldLogsReset();
        }
        return a ? 1 : -1;
    }

    boolean active() {
        return active;
    }

    /**
     * a held call may be logged (kor_tbt_log): at most HELD_LOGS_MAX lines, and HELD_LOGS_PER_POINT for one call, until
     * this mod's guidance goes off or the connection ends (heldLogsReset), so the next start's always show, and one call
     * this mod never makes (lanes the official mod's HUD clear sends, say) can't take them all (PR #85 review 6)
     */
    synchronized boolean heldLog(String point) {
        if (heldLogsAll >= HELD_LOGS_MAX) return false;
        Integer n = heldLogs.get(point);
        int k = n == null ? 0 : n;
        if (k >= HELD_LOGS_PER_POINT) return false;
        heldLogs.put(point, k + 1);
        heldLogsAll++;
        return true;
    }

    /** held calls get lines again (guidance off, the connection ended) */
    synchronized void heldLogsReset() {
        heldLogs.clear();
        heldLogsAll = 0;
    }

    /** a Stop of the phone's route guidance that wasn't this mod's own */
    void stopSeen(long now) {
        stopAt = now;
    }

    /**
     * the pending Stop's clear is due: STOP_WAIT_MS passed and the phone sent nothing since, apart from
     * what arrived within STOP_RESEND_MIN_MS of the Stop (sent before it) (then it's done)
     */
    boolean stopDue(long now) {
        long s = stopAt;
        if (s < 0L || now - s < STOP_WAIT_MS) return false;
        stopAt = -1L;
        long h = heardAt;
        return h < s + STOP_RESEND_MIN_MS;
    }

    /** an argument array of this mod's that the official mod's call carried, and when */
    static final class Carried {
        final Object[] args;
        final long at;

        Carried(Object[] args, long at) {
            this.args = args;
            this.at = at;
        }
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
