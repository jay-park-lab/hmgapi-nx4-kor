package io.github.jayparklab.nx4kor.hook.dipo;

/**
 * tests/mod-test.sh (#67, PR #68 review 4): runs KorTbt's decisions (TbtGate) on the PC.
 *   javac -d <dir> hooks/src/io/github/jayparklab/nx4kor/hook/dipo/TbtGate.java tests/tools/TbtGateTest.java
 *   java -cp <dir> io.github.jayparklab.nx4kor.hook.dipo.TbtGateTest
 * Prints one line per case and "ok" at the end; exits 1 on the first failure.
 */
public class TbtGateTest {
    static int n;

    static void is(boolean c, String what) {
        n++;
        if (!c) {
            System.out.println("FAIL " + what);
            System.exit(1);
        }
        System.out.println("ok " + what);
    }

    static final String TBT = "update_tbt_info";
    static final String LANE = "update_lane_info";

    /**
     * A held call's clock and wait on the PC (2.1.2-beta.4): each wait runs the next of runs (what this mod's thread or
     * listener does meanwhile, step ms in; done wakes the call) or, with none left, times out (the clock moves ms).
     */
    static final class Waits implements TbtGate.Waits {
        long t;
        long step;
        int waits;
        boolean interrupt;
        final java.util.ArrayDeque<Runnable> runs = new java.util.ArrayDeque<Runnable>();

        Waits(long t, long step, Runnable... runs) {
            this.t = t;
            this.step = step;
            for (Runnable r : runs) this.runs.add(r);
        }

        @Override
        public long now() {
            return t;
        }

        @Override
        public void await(Object lock, long ms) throws InterruptedException {
            waits++;
            if (!Thread.holdsLock(lock)) throw new IllegalStateException("waits without the lock");
            if (interrupt) throw new InterruptedException();
            Runnable r = runs.poll();
            if (r == null) {
                t += ms;
                return;
            }
            t += Math.min(step, ms);
            r.run();
        }
    }

    public static void main(String[] a) {
        // off until this mod's guidance is on; then the other sender gets ours
        TbtGate g = new TbtGate();
        Object[] ours = { 70, 65535, 270f, 0f, 0, 0, 0, 15, -1 };
        g.ours(TBT, ours);
        g.heard(1000);
        is(g.forOther(TBT, 9, 1000, true) == null, "guidance off: the other sender's call passes");
        is(g.setActive(true) == 1, "setActive(true) reports turning on");
        Object[] got = g.forOther(TBT, 9, 1500, true);
        is(got != null && (Integer) got[0] == 70 && got != ours, "guidance on, heard: the other call gets a copy of ours");
        is(g.forOther(TBT, 9, 1500, false) == null, "mod turned off in the HMG-API app: the other call passes (review 2)");
        is(g.forOther(TBT, 8, 1500, true) == null, "another argument count: passes as it is");
        is(g.forOther("update_tp_crossroad_name", 1, 1500, true) == null, "a call this mod never made: passes");

        // byte frames are copied both ways
        byte[] f = { (byte) 0xF1, 1, 2 };
        g.ours(LANE, new Object[] { f });
        f[1] = 9;
        Object[] lane = g.forOther(LANE, 1, 1600, true);
        is(((byte[]) lane[0])[1] == 1, "a frame remembered is a copy (later changes don't show)");
        ((byte[]) lane[0])[2] = 7;
        is(((byte[]) g.forOther(LANE, 1, 1600, true)[0])[2] == 2, "a frame given out is a copy");

        // review 3: the official mod keeps sending, this mod's listener hears nothing
        g.heard(2000);
        is(g.forOther(TBT, 9, 4000, true) != null && !g.yielding(4000), "heard 2 s ago: still ours");
        is(g.forOther(TBT, 9, 5500, true) != null && !g.yielding(5500), "quiet 3.5 s, the other's first call: still ours (counting starts)");
        is(g.forOther(TBT, 9, 7000, true) != null && !g.yielding(7000), "other calls for 1.5 s while quiet: still ours");
        is(g.forOther(TBT, 9, 8500, true) == null, "other calls for 3 s while this mod hears nothing: they pass");
        is(g.yielding(8600), "and this mod gives way (stops resending)");
        g.heard(9000);
        is(!g.yielding(9000) && g.forOther(TBT, 9, 9000, true) != null, "heard again: ours again");

        // a long red light: nothing to anyone; then the first update
        g.heard(10000);
        is(g.forOther(TBT, 9, 70000, true) != null && !g.yielding(70000), "after a minute of silence the other's first call still gets ours");
        g.heard(70050);
        is(g.forOther(TBT, 9, 73000, true) != null, "this mod heard the same update: no giving way later");

        // turning off forgets this mod's calls
        is(g.setActive(false) == -1, "setActive(false) reports turning off");
        is(g.forOther(TBT, 9, 73100, true) == null, "guidance off: passes");
        g.setActive(true);
        is(g.forOther(TBT, 9, 73200, true) == null, "on again: the old calls are forgotten (nothing to give until ours sends)");
        is(g.setActive(true) == 0, "setActive with no change reports 0");

        // review 1: another's Stop waits; an ask-again (the phone sends again) clears nothing
        TbtGate s = new TbtGate();
        s.heard(100);
        s.stopSeen(1000);
        is(!s.stopDue(2500), "another's Stop: not cleared before 2 s");
        s.heard(1800);
        is(!s.stopDue(3100), "the phone sent again within 2 s (ask-again): no clear");
        is(!s.stopDue(6000), "and that Stop is done with");
        s.stopSeen(7000);
        is(!s.stopDue(8000), "DiPO's Stop: waiting");
        is(s.stopDue(9100), "nothing from the phone for 2 s: clear");
        is(!s.stopDue(9200), "cleared once");
        is(!new TbtGate().stopDue(99999), "no Stop seen: nothing due");

        // review 12: the phone's last update arriving just after DiPO's Stop isn't an ask-again
        TbtGate d = new TbtGate();
        d.heard(9500);
        d.stopSeen(10000);
        d.heard(10030);
        is(d.stopDue(12100), "an update 30 ms after the Stop (sent before it), then quiet: clear");
        d.heard(19000);
        d.stopSeen(20000);
        d.heard(20500);
        is(!d.stopDue(22100), "the phone sends again 500 ms after the Stop (Stop, 200 ms, Start): no clear");

        // review 13: one call from the other sender, then silence for everyone: no giving way
        TbtGate y = new TbtGate();
        y.ours(TBT, ours);
        y.setActive(true);
        y.heard(1000);
        is(y.forOther(TBT, 9, 6000, true) != null, "quiet, one other call: still ours");
        is(!y.yielding(9100), "no more calls from the other sender: no giving way (this mod keeps resending)");
        is(y.forOther(TBT, 9, 9200, true) == null && y.yielding(9300), "the other calls again after 3 s: give way now");
        is(!y.yielding(12300), "the other went quiet for 3 s: this mod resends again");

        // #77: this mod skips its own call when the official mod's call just carried its same, latest values
        TbtGate k = new TbtGate();
        k.setActive(true);
        k.heard(1000);
        Object[] a1 = { 70, 65535, 270f, 300f, 0, 0, 0, 15, -1 };
        Object[] key1 = { 70, 65535, 270f, 300f, 0, 0, 0, 15, -1 };
        is(!k.skipOurs(TBT, key1, 1000), "first call: goes out");
        k.ours(TBT, a1);
        is(!k.skipOurs(TBT, key1.clone(), 1100), "same values, the official mod hasn't carried them: goes out");
        k.ours(TBT, a1);
        is(k.forOther(TBT, 9, 1200, true) != null, "the official mod's call carries ours");
        is(k.skipOurs(TBT, key1.clone(), 1500), "same values, carried 300 ms ago: skipped");
        is(!k.skipOurs(TBT, key1.clone(), 1200 + TbtGate.CARRIED_MS), "same values, carried 900 ms ago: goes out (the resend)");
        k.ours(TBT, a1);
        Object[] key2 = { 70, 65535, 270f, 250f, 0, 0, 0, 15, -1 };
        is(k.forOther(TBT, 9, 2200, true) != null && !k.skipOurs(TBT, key2, 2250), "new values: goes out though the official mod just called");
        k.ours(TBT, new Object[] { 70, 65535, 270f, 250f, 0, 0, 0, 15, -1 });
        is(!k.skipOurs(TBT, key2.clone(), 2300), "the official mod carried the older values, not the latest: goes out");
        // byte frames compare by content
        byte[] fr = { (byte) 0xF2, 1, 3, 0, 0 };
        is(!k.skipOurs(LANE, new Object[] { fr.clone() }, 3000), "lane frame, first: goes out");
        k.ours(LANE, new Object[] { fr.clone() });
        is(k.forOther(LANE, 1, 3010, true) != null && k.skipOurs(LANE, new Object[] { fr.clone() }, 3100),
                "the same lane frame (another array), carried: skipped");
        // nothing carried while the official mod's call passes (mod off, guidance off, giving way): never skipped
        TbtGate p = new TbtGate();
        p.setActive(true);
        p.heard(1000);
        p.skipOurs(TBT, key1, 1000);
        p.ours(TBT, a1);
        is(p.forOther(TBT, 9, 1100, false) == null && !p.skipOurs(TBT, key1.clone(), 1200), "mod off: its call passes, ours still goes out");
        p.setActive(false);
        p.setActive(true);
        is(!p.skipOurs(TBT, key1.clone(), 1300), "guidance off and on again: what was carried is forgotten");
        // PR #78 review 4: giving way, the official call carries its own values: what it carried of ours before no longer stands
        TbtGate y2 = new TbtGate();
        y2.setActive(true);
        y2.heard(1000);
        y2.skipOurs(TBT, key1, 1000);
        y2.ours(TBT, a1);
        y2.forOther(TBT, 9, 5000, true);
        y2.forOther(TBT, 9, 7500, true);
        is(y2.forOther(TBT, 9, 8000, true) == null && !y2.skipOurs(TBT, key1.clone(), 8100),
                "carried 600 ms before giving way: ours still goes out after (the cluster got the official mod's values)");
        // the official mod stops calling for a turn it has no icon for (#67): ours always goes out
        TbtGate q = new TbtGate();
        q.setActive(true);
        q.heard(1000);
        q.skipOurs(TBT, key1, 1000);
        q.ours(TBT, a1);
        is(!q.skipOurs(TBT, key1.clone(), 1500) && !q.skipOurs(TBT, key1.clone(), 2500), "no call from the official mod: ours goes out every time");
        // giving way: the next look is when the way ends unless the official mod calls again
        TbtGate w = new TbtGate();
        w.ours(TBT, ours);
        w.setActive(true);
        w.heard(1000);
        w.forOther(TBT, 9, 5000, true);
        w.forOther(TBT, 9, 8000, true);
        is(w.yielding(8100) && w.yieldEndsIn(8100) == 2900, "giving way: ends 3 s after the official mod's last call");
        is(w.yieldEndsIn(12000) == 0 && !w.yielding(12000), "the official mod quiet 3 s: the way has ended");

        held(ours);

        System.out.println(n + " cases");
        System.out.println("ok");
    }

    /** 2.1.2-beta.4: the official mod's call this mod has nothing for yet waits for this mod's thread (hold, held, done) */
    static void held(final Object[] ours) {
        // a start: this mod's listener heard the update, its thread is 20 ms from through (and turns guidance on)
        final TbtGate a = new TbtGate();
        final long a1 = a.heard(1000);
        is(a.forOther(TBT, 9, 1000, true) == null, "a start: nothing of ours yet for the official mod's call");
        Waits w = new Waits(1000, 20, () -> {
            a.ours(TBT, ours);
            a.setActive(true);
            a.done(a1);
        });
        Object[] got = a.held(TBT, 9, true, w);
        is(got != null && (Integer) got[0] == 70 && got != ours && w.waits == 1 && w.t == 1020,
                "a start: the call waits 20 ms for this mod's thread and carries ours");
        Waits w0 = new Waits(1030, 0);
        is(a.forOther(TBT, 9, 1030, true) != null && a.held(TBT, 9, true, w0) == null && w0.waits == 0,
                "guidance on: the next call gets ours from forOther at once (held has nothing to wait for)");

        // this mod's thread through, still nothing (a maneuver it doesn't know yet): pass once through, then don't wait
        final TbtGate b = new TbtGate();
        final long b1 = b.heard(1000);
        w = new Waits(1000, 10, () -> b.done(b1));
        is(b.held(TBT, 9, true, w) == null && w.waits == 1 && w.t == 1010,
                "this mod's thread through with no guidance: the call passes then (10 ms)");
        w = new Waits(1020, 10);
        is(b.held(TBT, 9, true, w) == null && w.waits == 0, "the rest of that update's calls pass without waiting");
        final long b2 = b.heard(2000);
        w = new Waits(2000, 15, () -> {
            b.ours(TBT, ours);
            b.setActive(true);
            b.done(b2);
        });
        is(b.held(TBT, 9, true, w) != null && w.t == 2015, "the listener heard something new: the next call waits again (and gets ours)");

        // this mod's thread not through within HOLD_MS: the call passes then
        final TbtGate c = new TbtGate();
        c.heard(1000);
        w = new Waits(1000, 0);
        is(c.held(TBT, 9, true, w) == null && w.t == 1000 + TbtGate.HOLD_MS, "this mod's thread not through in 250 ms: passes after 250 ms");
        w = new Waits(1300, 0);
        is(c.held(TBT, 9, true, w) == null && w.waits == 0, "and the next calls don't wait for that update again");

        // the official mod's listener got the update first: this mod's listener hears it within HEAR_MS
        final TbtGate d = new TbtGate();
        d.done(d.heard(1000));
        w = new Waits(5000, 20, () -> {
            final long s = d.heard(5020);
            d.ours(TBT, ours);
            d.setActive(true);
            d.done(s);
        });
        is(d.held(TBT, 9, true, w) != null && w.t == 5020, "this mod's listener hears the update 20 ms after the call: it waits and gets ours");
        final TbtGate e = new TbtGate();
        e.done(e.heard(1000));
        w = new Waits(5000, 30, () -> e.heard(5030));
        is(e.held(TBT, 9, true, w) == null && w.waits == 2 && w.t == 5000 + TbtGate.HOLD_MS,
                "heard 30 ms after the call, not through: the wait goes on to 250 ms, then passes");

        // nothing coming (the official mod clears the HUD on a Stop, say): HEAR_MS, then no more waiting
        final TbtGate f = new TbtGate();
        f.done(f.heard(1000));
        w = new Waits(5000, 0);
        is(f.held(TBT, 9, true, w) == null && w.waits == 1 && w.t == 5000 + TbtGate.HEAR_MS,
                "this mod's listener hears nothing within 50 ms: passes after 50 ms");
        w = new Waits(5100, 0);
        is(f.held(TBT, 9, true, w) == null && w.waits == 0, "then none waits until the listener hears again");
        // a listener that never hears: one 50 ms wait, then the official mod's calls pass as they are
        TbtGate never = new TbtGate();
        w = new Waits(1000, 0);
        is(never.held(TBT, 9, true, w) == null && w.t == 1000 + TbtGate.HEAR_MS, "a listener that never heard: one 50 ms wait");
        w = new Waits(2000, 0);
        is(never.held(TBT, 9, true, w) == null && w.waits == 0, "then never again (the official mod alone)");

        // guidance on, but a call this mod hasn't made since (lanes): waits for this mod's lanes of the same update
        final TbtGate g = new TbtGate();
        g.ours(TBT, ours);
        g.setActive(true);
        final long g1 = g.heard(1000);
        is(g.forOther(LANE, 1, 1000, true) == null, "guidance on, no lanes of ours yet: forOther gives nothing");
        w = new Waits(1000, 5, () -> {
            g.ours(LANE, new Object[] { new byte[] { (byte) 0xF1, 2 } });
            g.done(g1);
        });
        got = g.held(LANE, 1, true, w);
        is(got != null && ((byte[]) got[0])[1] == 2 && w.t == 1005, "guidance on, a call ours hasn't made yet: waits and gets ours");

        // never held: mod off, giving way, another argument count
        final TbtGate h = new TbtGate();
        h.ours(TBT, ours);
        h.setActive(true);
        h.heard(1000);
        w = new Waits(1000, 0);
        is(h.held(TBT, 9, false, w) == null && w.waits == 0, "mod off in the HMG-API app: passes without waiting");
        w = new Waits(1000, 0);
        is(h.held(TBT, 8, true, w) == null && w.waits == 0, "another argument count: passes without waiting");
        h.forOther(TBT, 9, 5000, true);
        is(h.forOther(TBT, 9, 8500, true) == null && h.yielding(8500), "giving way (this mod hears nothing for 3 s)");
        w = new Waits(8500, 0);
        is(h.held(TBT, 9, true, w) == null && w.waits == 0, "giving way: the official mod's call passes without waiting");

        // interrupted while waiting: passes, the interrupt kept for the thread
        TbtGate i = new TbtGate();
        i.heard(1000);
        w = new Waits(1000, 0);
        w.interrupt = true;
        is(i.held(TBT, 9, true, w) == null && Thread.interrupted(), "interrupted while waiting: passes and keeps the interrupt");

        // updates numbered; a late done of an earlier one doesn't move back
        TbtGate o = new TbtGate();
        long o1 = o.heard(1000), o2 = o.heard(1001);
        o.done(o2);
        o.done(o1);
        TbtGate.Hold hh = o.hold(TBT, 1002);
        is(o2 == o1 + 1 && hh != null && hh.target == o2 + 1 && o.holdLeft(hh, TBT, 1002) == TbtGate.HEAR_MS,
                "updates are numbered; a late done of an earlier one doesn't move back (waits for the next one)");
        is(o.holdLeft(hh, TBT, 1002 + TbtGate.HEAR_MS) == 0, "HEAR_MS after the call with nothing heard: no longer");

        // PR #85 review 1: held on a 121 this mod's thread hasn't finished; meanwhile the listener hears the 120 that turns
        // guidance on. The 121 done isn't the end: the call waits for the 120 too and carries ours
        final TbtGate m = new TbtGate();
        final long m1 = m.heard(1000);
        final long[] m2 = { 0L };
        w = new Waits(1000, 10, () -> {
            m2[0] = m.heard(1010);
            m.done(m1);
        }, () -> {
            m.ours(TBT, ours);
            m.setActive(true);
            m.done(m2[0]);
        });
        long[] waited = { 0L };
        got = m.held(TBT, 9, true, w, waited);
        is(got != null && (Integer) got[0] == 70 && w.waits == 2 && waited[0] == 20,
                "review 1: the listener hears the 120 while the 121 is being done: the call waits for both and carries ours");
        final TbtGate m3 = new TbtGate();
        final long m31 = m3.heard(1000);
        w = new Waits(1000, 10, () -> {
            m3.heard(1010);
            m3.done(m31);
        });
        is(m3.held(TBT, 9, true, w) == null && w.t == 1000 + TbtGate.HOLD_MS,
                "review 1: and if that 120 isn't done within 250 ms, the call passes then");

        // PR #85 review 3: guidance on, a call this mod never makes (lanes from an app without lanes, the official mod's
        // HUD clear): no 50 ms wait for an update that may not come, on any update
        final TbtGate q = new TbtGate();
        q.ours(TBT, ours);
        q.setActive(true);
        q.done(q.heard(1000));
        w = new Waits(1100, 0);
        waited[0] = 0L;
        is(q.held(LANE, 1, true, w, waited) == null && w.waits == 0 && waited[0] == -1L,
                "review 3: guidance on, this mod's thread through, a call it never made: passes without waiting");
        q.done(q.heard(2000));
        w = new Waits(2100, 0);
        is(q.held(LANE, 1, true, w) == null && w.waits == 0, "review 3: the next update too (not 50 ms each time)");
        final long q3 = q.heard(3000);
        w = new Waits(3000, 5, () -> q.done(q3));
        is(q.held(LANE, 1, true, w) == null && w.waits == 1 && w.t == 3005,
                "review 3: still waits for what the listener already heard (this mod's thread 5 ms behind), then passes");

        // PR #85 review 4: an argument count other than this mod's isn't known before ours is there: held, then passes
        final TbtGate k = new TbtGate();
        final long k1 = k.heard(1000);
        w = new Waits(1000, 10, () -> {
            k.ours(TBT, ours);
            k.setActive(true);
            k.done(k1);
        });
        waited[0] = -1L;
        is(k.held(TBT, 8, true, w, waited) == null && waited[0] == 10,
                "review 4: another argument count while this mod had nothing: held 10 ms, then passes as it is");
        w = new Waits(1020, 0);
        is(k.held(TBT, 8, true, w, waited) == null && w.waits == 0 && waited[0] == -1L,
                "review 4: once this mod has a value, another argument count passes without waiting");

        // real threads, KorTbt's way of waiting (Object.wait): done on this mod's thread wakes the held call well before
        // HOLD_MS, and that thread never waits for the held one
        final TbtGate r = new TbtGate();
        final long r1 = r.heard(System.nanoTime() / 1000000L);
        final long[] doneTook = { -1L };
        Thread mine = new Thread(() -> {
            try {
                Thread.sleep(30);
            } catch (InterruptedException x) {
                return;
            }
            long t0 = System.nanoTime();
            r.ours(TBT, ours);
            r.setActive(true);
            r.done(r1);
            doneTook[0] = (System.nanoTime() - t0) / 1000000L;
        });
        TbtGate.Waits real = new TbtGate.Waits() {
            @Override
            public long now() {
                return System.nanoTime() / 1000000L;
            }

            @Override
            public void await(Object lock, long ms) throws InterruptedException {
                lock.wait(ms);
            }
        };
        long t0 = System.nanoTime();
        mine.start();
        got = r.held(TBT, 9, true, real);
        long took = (System.nanoTime() - t0) / 1000000L;
        try {
            mine.join(2000);
        } catch (InterruptedException x) {
            Thread.currentThread().interrupt();
        }
        is(got != null && took >= 25 && took < TbtGate.HOLD_MS - 50 && doneTook[0] >= 0 && doneTook[0] < 50,
                "real threads: done wakes the held call (took " + took + " ms, under 200), and done itself doesn't wait");
    }
}
