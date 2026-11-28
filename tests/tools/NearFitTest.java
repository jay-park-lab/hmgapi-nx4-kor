package io.github.jayparklab.nx4kor.hook.dipo;

import java.util.Arrays;

/**
 * tests/mod-test.sh (#67, PR #74 review 6): runs the near-turn picture choices KP's mod 2.4.10 added
 * (CpTurnsFit.nearDisplay roundabout 32 and the on-ramp default, onRampDefault, facilityNear), CpIcons, and the
 * near-turn distance (PR #87: near() itself with ordinary roads at 600 m, out past 650 m, expressway exits at 1050 m;
 * dynamicD and bar) and far turns as the picture too (#89, farBig: bar 90 past D, the put-off hold, the stale-dist
 * picture, a jump held whatever its distance, the icon for kinds with no picture and no distance; off is KP's way) on the PC.
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

        // 먼 회전도 큰 그림(#89, 2026-11-27): farBig이면 D 밖도 같은 그림에 막대 90, D부터 줄어듦. 끄면 위처럼 먼 회전 칸(KP)
        CpTurnsFit g = new CpTurnsFit(null, null, null);
        g.farBig = true;
        g.clock = 1000L;
        CpTurnsFit.Update ub = new CpTurnsFit.Update(0, null);
        int[] far = nearAt(g, ub, turn, 2400);
        is(far != null && far[0] == 13 && far[3] == 90 && far[4] == 600 && "far-big".equals(g.nearWhy),
                "farBig, left turn 2400 m: near view 13, bar 90, D 600 (far-big)");
        int[] at = nearAt(g, ub, turn, 600), below = nearAt(g, ub, turn, 539);
        is(at != null && at[3] == 90 && "in-d".equals(g.nearWhy) && below != null && below[3] == 80,
                "farBig: in D from 600 m as before, bar 80 at 539 m");
        is(Arrays.equals(Arrays.copyOf(far, 3), Arrays.copyOf(at, 3)), "farBig: the far picture is the same picture (display, side, slot) as the near one");
        CpTurnsFit.Update ube = new CpTurnsFit.Update(0, null);
        int[] fex = nearAt(g, ube, exit, 5000);
        is(fex != null && fex[0] == 17 && fex[3] == 90 && fex[4] == 1050, "farBig, expressway exit 5000 m: near view 17, bar 90, D 1050");
        CpTurnsFit.Maneuver dest = new CpTurnsFit.Maneuver(0, 0, null);
        dest.type = 12;   // arrive at destination: no near-turn picture
        is(nearAt(g, new CpTurnsFit.Update(0, null), dest, 900) == null && "type".equals(g.nearWhy),
                "farBig, destination 900 m: the icon still (no picture for the kind)");
        CpTurnsFit.Update un = new CpTurnsFit.Update(0, null);
        g.clock += 1000L;
        int[] nd = g.near(7, un, turn, 70);
        is(nd != null && nd[0] == 13 && nd[3] == 90 && nd[4] == 600 && "no-dist".equals(g.nearWhy),
                "farBig, no distance yet (a guidance start, #109): the picture, bar 90, D 600, not the icon card");
        is(g.near(7, new CpTurnsFit.Update(0, null), dest, 70) == null, "farBig, no distance, destination: the icon still (no picture for the kind)");
        g.farBig = false;
        is(g.near(7, new CpTurnsFit.Update(0, null), turn, 70) == null && "no-dist".equals(g.nearWhy), "farBig off, no distance: the icon (KP)");
        g.farBig = true;
        // 회전이 바뀌는 갱신(네이버 지도 꼴): 새 회전의 첫 거리가 앞 회전의 마지막 값과 같으면 put-off. farBig이고 이미 그린 것이
        // 있으면 계기판을 그대로 둔다(nearHeld). 그 뒤 refresh가 같은 묵은 거리로 다시 물으면(stale-dist) 새 회전의 그림, 막대 90
        CpTurnsFit h = new CpTurnsFit(null, null, null);
        h.farBig = true;
        h.shown = true;
        h.clock = 1000L;
        CpTurnsFit.Update uc = new CpTurnsFit.Update(0, null);
        uc.list = new int[] { 30 };
        is(nearAt(h, uc, turn, 93) != null && "in-d".equals(h.nearWhy), "turn 30 at 93 m: near view");
        uc.list = new int[] { 33 };
        CpTurnsFit.Maneuver rturn = new CpTurnsFit.Maneuver(0, 0, null);
        rturn.type = 2;   // right turn
        int[] po = nearAt(h, uc, rturn, 93);
        is(po == null && "put-off".equals(h.nearWhy) && h.nearHeld, "next turn 33 with the last value 93 m: put-off, the frame kept (nearHeld)");
        h.clock += 1000L;
        int[] st = h.near(7, uc, rturn, 67);
        is(st != null && st[0] == 13 && st[3] == 90 && !h.nearHeld && "stale-dist".equals(h.nearWhy),
                "refresh with the same old distance: stale-dist, turn 33's picture with bar 90 (no icon card)");
        int[] real = nearAt(h, uc, rturn, 61);
        is(real != null && real[3] == 90 && real[4] == 61 && "in-d".equals(h.nearWhy), "the real 61 m: in D, D 61, bar 90");
        // PR #94 리뷰 4: 아직 그린 것이 없으면(shown false) 미루기는 붙잡지 않는다(붙잡을 그림이 없음). #109(2026-11-28): 그때 아이콘 칸
        // 대신 새 회전의 그림(막대 90)을 보낸다
        CpTurnsFit s = new CpTurnsFit(null, null, null);
        s.farBig = true;
        s.clock = 1000L;
        CpTurnsFit.Update us = new CpTurnsFit.Update(0, null);
        us.list = new int[] { 30 };
        nearAt(s, us, turn, 93);
        us.list = new int[] { 33 };
        int[] ps = nearAt(s, us, rturn, 93);
        is(ps != null && ps[0] == 13 && ps[3] == 90 && "put-off".equals(s.nearWhy) && !s.nearHeld,
                "farBig, nothing shown yet: put-off is not held, turn 33's picture with bar 90 instead of the icon card (#109)");
        CpTurnsFit k = new CpTurnsFit(null, null, null);
        k.shown = true;
        k.clock = 1000L;
        CpTurnsFit.Update uk = new CpTurnsFit.Update(0, null);
        uk.list = new int[] { 30 };
        nearAt(k, uk, turn, 93);
        uk.list = new int[] { 33 };
        is(nearAt(k, uk, rturn, 93) == null && "put-off".equals(k.nearWhy) && !k.nearHeld, "farBig off: put-off is the far card, not held (KP)");
        k.clock += 1000L;
        is(k.near(7, uk, rturn, 67) == null && "stale-dist".equals(k.nearWhy), "farBig off: stale-dist is the far card (KP)");
        // 같은 회전에서 거리가 뛸 때(카카오내비 꼴): farBig이면 D 밖으로 뛰어도 한 번 붙잡는다(앞 회전 그림을 새 거리로 그리지 않게)
        CpTurnsFit j = new CpTurnsFit(null, null, null);
        j.farBig = true;
        j.clock = 1000L;
        CpTurnsFit.Update uj = new CpTurnsFit.Update(0, null);
        nearAt(j, uj, turn, 20);
        is(nearAt(j, uj, turn, 900) == null && j.nearHeld && "jump-hold".equals(j.nearWhy), "farBig, 20 m then 900 m on the same turn: held once (jump-hold)");
        int[] after = nearAt(j, uj, turn, 900);
        is(after != null && after[3] == 90 && "far-big".equals(j.nearWhy), "the next 900 m: far-big, bar 90");

        // #108(2026-11-28): 같은 회전 번호에서 종류만 바뀌면(고속도로 출구 23 → 오른쪽 유지 14, 약 600 m) 같은 회전이다. 처음 거리와
        // D(본 종류 중 큰 기준 1050 m)를 이어 가 막대가 다시 가득 차지 않는다. 번호가 바뀐 회전은 전처럼 그 자리에서 새로 시작한다
        CpTurnsFit t8 = new CpTurnsFit(null, null, null);
        t8.farBig = true;
        t8.clock = 1000L;
        CpTurnsFit.Update u8 = new CpTurnsFit.Update(0, null);
        u8.list = new int[] { 40 };
        nearAt(t8, u8, exit, 1900);
        int[] e8 = nearAt(t8, u8, exit, 700);
        is(e8 != null && e8[3] == 60 && e8[4] == 1050, "exit 23 at 700 m: bar 60, D 1050");
        CpTurnsFit.Maneuver keep = new CpTurnsFit.Maneuver(0, 0, null);
        keep.type = 14;   // keep right
        int[] k8 = nearAt(t8, u8, keep, 600);
        is(k8 != null && k8[0] == 13 && k8[3] == 50 && k8[4] == 1050 && "in-d".equals(t8.nearWhy),
                "same turn 40 becomes keep right 14 at 600 m: D stays 1050, bar 50 (no refill to 90)");
        int[] k8b = nearAt(t8, u8, keep, 300);
        is(k8b != null && k8b[3] == 20 && k8b[4] == 1050, "keep right 14 at 300 m: still D 1050, bar 20");
        int[] k8c = nearAt(t8, u8, exit, 250);
        is(k8c != null && k8c[3] == 20 && k8c[4] == 1050, "back to exit 23 on the same turn at 250 m: D 1050, bar 20");
        u8.list = new int[] { 41 };
        int[] n8 = nearAt(t8, u8, turn, 400);
        is(n8 != null && n8[3] == 90 && n8[4] == 400, "the next turn number 41 at 400 m: a new turn, D 400, bar 90");
        CpTurnsFit t8g = new CpTurnsFit(null, null, null);
        t8g.clock = 1000L;
        CpTurnsFit.Update u8g = new CpTurnsFit.Update(0, null);
        u8g.list = new int[] { 50 };
        nearAt(t8g, u8g, turn, 500);
        int[] g8 = nearAt(t8g, u8g, rturn, 350);
        is(g8 != null && g8[3] == 70 && g8[4] == 500, "farBig off, left 1 becomes right 2 on the same turn: D stays 500, bar 70");

        System.out.println(n + " cases");
        System.out.println("ok");
    }
}
