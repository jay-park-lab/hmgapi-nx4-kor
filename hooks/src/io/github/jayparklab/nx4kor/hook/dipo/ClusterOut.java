package io.github.jayparklab.nx4kor.hook.dipo;
// NX4 KOR (jay-park-lab/hmgapi-nx4-kor), 2026-11-26 (#77).

import android.os.SystemClock;
import hmgapi.hook.Cluster;

/**
 * CpTurnsFit's cluster: HMG-API's Cluster, less a call this mod doesn't need to make because the official mod's
 * call of the same kind just carried this mod's same values (TbtGate.skipOurs). Each call's key is its values in
 * this mod's own form (the official mod's call carries framework objects for names and the turn list, which can't
 * be compared). The key is noted only for a call that goes out.
 */
final class ClusterOut {
    private final Cluster c;
    private final TbtGate gate;

    ClusterOut(Cluster c, TbtGate gate) {
        this.c = c;
        this.gate = gate;
    }

    private boolean skip(String point, Object[] key) {
        return gate.skipOurs(point, key, SystemClock.elapsedRealtime());
    }

    void tbtInfo(int type, int sideStreet, float direction, float distance, int distanceErr, int combiSideStreet,
            int unit, int barGraph, int barGraphErr) {
        if (skip("update_tbt_info", new Object[] { type, sideStreet, direction, distance, distanceErr, combiSideStreet,
                unit, barGraph, barGraphErr })) return;
        c.tbtInfo(type, sideStreet, direction, distance, distanceErr, combiSideStreet, unit, barGraph, barGraphErr);
    }

    void tbtSubInfo(float distance, int distanceErr, int unit, int hour, int minute, int timeType, int timeFormat,
            float direction, int directionErr, int estPoint) {
        if (skip("update_tbt_sub_info_b", new Object[] { distance, distanceErr, unit, hour, minute, timeType, timeFormat,
                direction, directionErr, estPoint })) return;
        c.tbtSubInfo(distance, distanceErr, unit, hour, minute, timeType, timeFormat, direction, directionErr, estPoint);
    }

    void tbtSubInfo2C(int a, int b, int cc, int d, int e, int f, int g, int h, int i) {
        if (skip("update_tbt_sub_info_2c", new Object[] { a, b, cc, d, e, f, g, h, i })) return;
        c.tbtSubInfo2C(a, b, cc, d, e, f, g, h, i);
    }

    void turnListNew(byte[] frame) {
        if (skip("update_tp_turn_list_new", new Object[] { frame })) return;
        c.turnListNew(frame);
    }

    void laneInfo(byte[] frame) {
        if (skip("update_lane_info", new Object[] { frame })) return;
        c.laneInfo(frame);
    }

    void destinationName(int type, String name) {
        if (skip("update_tp_destination_name", new Object[] { type, name })) return;
        c.destinationName(type, name);
    }

    void crossroadName(String name) {
        if (skip("update_tp_crossroad_name", new Object[] { name })) return;
        c.crossroadName(name);
    }

    void turnList(Cluster.Turn[] turns) {
        Object[] key = new Object[turns.length];
        for (int k = 0; k < turns.length; k++) {
            Cluster.Turn t = turns[k];
            key[k] = new Object[] { t.type, t.direction, t.traffic, t.no, t.unit, t.name, t.exitNumber, t.distance };
        }
        if (skip("update_tp_turn_list", key)) return;
        c.turnList(turns);
    }
}
