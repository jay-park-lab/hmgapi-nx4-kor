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

        System.out.println(n + " cases");
        System.out.println("ok");
    }
}
