package io.github.jayparklab.nx4kor.hook.dipo;

import java.util.Arrays;

/**
 * tests/mod-test.sh (#67, PR #74 review 6): runs the near-turn picture choices KP's mod 2.4.10 added
 * (CpTurnsFit.nearDisplay roundabout 32 and the on-ramp default, onRampDefault, facilityNear) and CpIcons on the PC.
 * Compiled with hooks/src against the same classpath as scripts/build-hooks.sh (HMG-API runtime, iAP2 stubs, android.jar).
 * Prints one line per case and "ok" at the end; exits 1 on the first failure.
 */
public class NearFitTest {
    static int n;

    static void is(boolean c, String what) {
        n++;
        if (!c) {
            System.out.println("FAIL " + what);
            System.exit(1);
        }
        System.out.println("ok " + what);
    }

    static boolean eq(int[] got, int... want) {
        return Arrays.equals(got, want);
    }

    /** one phone update with distNext m for the maneuver (same turn, a fresh item 10), then near() as turn() asks it */
    static int[] nearAt(CpTurnsFit f, CpTurnsFit.Update u, CpTurnsFit.Maneuver x, int m) {
        f.clock += 1000L;
        u.distNext = m;
        u.distNextSeen = true;
        u.distNextFresh = true;
        return f.near(7, u, x, x.type == 23 ? 164 : 70);
    }

    public static void main(String[] a) {
        // roundabout 32 (2.4.10 L-1): right-hand traffic (side 0) with an exit angle, not when entering (type 6)
        is(eq(CpTurnsFit.nearDisplay(33, 0, 1, 90, 105), 32, 4, 12), "roundabout, side 0, exit 90: 32, bit 4, slot 12");
        is(eq(CpTurnsFit.nearDisplay(33, 0, 1, -90, 105), 32, 11, 36), "roundabout, side 0, exit -90: 32, bit 11, slot 36");
        is(eq(CpTurnsFit.nearDisplay(6, 0, 1, 90, 105), 105, 4, 12), "entering a roundabout (type 6): the exit icon stays");
        is(eq(CpTurnsFit.nearDisplay(33, 0, 1, 0, 105), 105, 0, 0), "roundabout without an exit angle: the exit icon stays");
        is(eq(CpTurnsFit.nearDisplay(33, 1, 1, 90, 105), 105, 4, 12), "left-hand traffic (side 1): the exit icon stays");
        is(CpTurnsFit.nearDisplay(33, 0, 1, 90, CpTurnsFit.NO_ICON) == null, "roundabout with no icon: no near-turn picture");

        // on-ramp without an angle (2.4.10 L-2): the stock right on-ramp shape, its mirror for left-hand traffic
        is(eq(CpTurnsFit.nearDisplay(9, 0, 0, 0, 160), 13, 1, 3), "on-ramp, no angle, side 0: 13, bit 1, slot 3 (22.5 degrees)");
        is(eq(CpTurnsFit.nearDisplay(9, 1, 0, 0, 160), 13, 14, 45), "on-ramp, no angle, side 1: 13, bit 14, slot 45 (337.5 degrees)");
        is(eq(CpTurnsFit.nearDisplay(9, 0, 0, 45, 0), 13, 2, 6), "on-ramp with an angle: that angle, as before");
        is(CpTurnsFit.onRampDefault(9, 0) && !CpTurnsFit.onRampDefault(9, 45) && !CpTurnsFit.onRampDefault(3, 0),
                "onRampDefault: only an on-ramp without an angle");

        // underpass 46 (left or right) and overpass 44 (left only), 2.4.10 T1-1
        int[] left = CpTurnsFit.nearDisplay(1, 0, 0, -90, 70), right = CpTurnsFit.nearDisplay(2, 0, 0, 90, 67);
        is(eq(left, 13, 11, 36) && eq(right, 13, 4, 12), "left / right turn: 13 at slot 36 / 12");
        is(eq(CpTurnsFit.facilityNear(1, null, "해찬나래지하차도", left), 46, 36), "left turn into an underpass (road name): 46, slot 36");
        is(eq(CpTurnsFit.facilityNear(2, "지하도로 이용", null, right), 46, 12), "right turn into an underpass (guidance text): 46, slot 12");
        is(eq(CpTurnsFit.facilityNear(1, "", "서부고가도로", left), 44, 36), "left turn onto an overpass: 44, slot 36");
        is(CpTurnsFit.facilityNear(2, "", "서부고가도로", right) == null, "right turn onto an overpass: unchanged (no stock value seen)");
        is(eq(CpTurnsFit.facilityNear(13, null, "OO지하차도", CpTurnsFit.nearDisplay(13, 0, 0, 0, 0)), 46, 36),
                "keep left (fork, slot 45) into an underpass: 46, slot 36");
        is(CpTurnsFit.facilityNear(2, null, "해찬나래지하차도 방면", right) == null, "\"해찬나래지하차도 방면\" (the one name a phone sent): unchanged");
        is(CpTurnsFit.facilityNear(1, "측도 이용", "OO지하차도", left) == null, "a not-into word in the other text: unchanged");
        is(CpTurnsFit.facilityNear(1, "OO지하차도", "OO고가도로", left) == null, "both facility words: unchanged");
        is(CpTurnsFit.facilityNear(1, "좌회전", "OO로", left) == null && CpTurnsFit.facilityNear(1, null, null, left) == null,
                "no facility word: unchanged");
        is(CpTurnsFit.facilityNear(3, null, "OO지하차도", CpTurnsFit.nearDisplay(3, 0, 0, 0, 65)) == null, "straight ahead: unchanged");
        is(CpTurnsFit.facilityNear(23, null, "OO지하차도", CpTurnsFit.nearDisplay(23, 0, 0, 0, 164)) == null, "highway exit (17): unchanged");
        is(CpTurnsFit.facilityNear(1, null, "OO지하차도", null) == null, "no near-turn picture: unchanged");
        is(CpTurnsFit.FACILITY_NOT_WORDS.length == 18, "18 not-into words");

        // CpIcons: KP's exactIcon (spot checks of the stock Korean table) and distStrState (log only)
        is(CpIcons.exactIcon(1, 0, 0, -90, 0) == 70 && CpIcons.exactIcon(2, 0, 0, 90, 0) == 67, "exactIcon left / right turn: 70 / 67");
        is(CpIcons.exactIcon(9, 0, 0, 0, 0) == 160 && CpIcons.exactIcon(22, 0, 0, 0, 0) == 165 && CpIcons.exactIcon(23, 0, 0, 0, 0) == 164,
                "exactIcon on-ramp 160, highway exit left 165 / right 164 (Korean stock)");
        is(CpIcons.exactIcon(12, 0, 0, 0, 2) == 3 && CpIcons.exactIcon(1, 0, 1, -90, 0) == 0, "exactIcon arrived 3, not in the table 0");
        is(CpIcons.distStrState(null) == 0 && CpIcons.distStrState("") == 0, "distStrState: none 0");
        is(CpIcons.distStrState("300") == 1 && CpIcons.distStrState("1.2") == 1, "distStrState: a number 1");
        is(CpIcons.distStrState("-1") == 2 && CpIcons.distStrState("NaN") == 2 && CpIcons.distStrState("Infinity") == 2
                && CpIcons.distStrState("1,2") == 2 && CpIcons.distStrState("abc") == 2, "distStrState: negative, NaN, infinite or not a number 2");

        // 곧 회전 거리(2026-11-26, PR #87 리뷰 5): 일반 600m, 고속도로 출구 1050m, 들어갈 때 D, 나갈 때 D + 50. near()를 직접 부른다
        is(CpTurnsFit.D_GENERAL == 600 && CpTurnsFit.D_EXPRESSWAY == 1050, "D: ordinary roads 600 m, expressway exits 1050 m");
        is(CpTurnsFit.dynamicD(CpTurnsFit.D_GENERAL, 900) == 600 && CpTurnsFit.dynamicD(CpTurnsFit.D_GENERAL, 450) == 450
                && CpTurnsFit.dynamicD(CpTurnsFit.D_GENERAL, 10) == CpTurnsFit.D_MIN, "dynamicD: 600 at most, the first distance when shorter, D_MIN at least");
        is(CpTurnsFit.bar(600, 600) == 90 && CpTurnsFit.bar(540, 600) == 90 && CpTurnsFit.bar(539, 600) == 80
                && CpTurnsFit.bar(300, 600) == 50 && CpTurnsFit.bar(59, 600) == 10, "bar over 600 m: 90 down to 10, a step every 60 m");
        CpTurnsFit f = new CpTurnsFit(null, null, null);
        f.clock = 1000L;
        CpTurnsFit.Update u = new CpTurnsFit.Update(0, null);
        CpTurnsFit.Maneuver turn = new CpTurnsFit.Maneuver(0, 0, null);
        turn.type = 1;   // left turn, no exit angle
        is(nearAt(f, u, turn, 900) == null && nearAt(f, u, turn, 601) == null, "left turn 900 m, 601 m: far card");
        int[] in = nearAt(f, u, turn, 600);
        is(in != null && in[0] == 13 && in[3] == 90 && in[4] == 600, "left turn at 600 m: near view 13, bar 90, D 600");
        is(nearAt(f, u, turn, 650) != null && nearAt(f, u, turn, 651) == null, "on the way back: near up to 650 m (D + 50), far at 651 m");
        CpTurnsFit.Update ue = new CpTurnsFit.Update(0, null);
        CpTurnsFit.Maneuver exit = new CpTurnsFit.Maneuver(0, 0, null);
        exit.type = 23;   // right expressway exit
        is(nearAt(f, ue, exit, 2000) == null && nearAt(f, ue, exit, 1051) == null, "expressway exit 2000 m, 1051 m: far card");
        int[] ex = nearAt(f, ue, exit, 1050);
        is(ex != null && ex[0] == 17 && ex[4] == 1050, "expressway exit at 1050 m: near view 17, D 1050 (unchanged)");

        System.out.println(n + " cases");
        System.out.println("ok");
    }
}
