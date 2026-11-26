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

        System.out.println(n + " cases");
        System.out.println("ok");
    }
}
