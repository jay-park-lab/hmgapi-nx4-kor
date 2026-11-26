package io.github.jayparklab.nx4kor.hook.dipo;
// exactIcon and distStrState from StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/src/hmgapi/mods/wireless/dipo/CpTurns.java (AGPL-3.0):
// the Korean stock DiPO table on top of the official mod's icon() (VysseCodes, AGPL-3.0), and the shown-distance
// string state for the maneuver log. Unchanged.
// Modified by NX4 KOR (jay-park-lab/hmgapi-nx4-kor), 2026-11-25 (#67): only these two, in a class of its own.

/** KP CpTurns.exactIcon (the stock Korean DiPO icon for a CarPlay maneuver, 0 when the table has none) and distStrState. */
final class CpIcons {
    private CpIcons() {}

    /**
     * 순정 DiPO 표(e/u.a의 ManeuverType 스위치, 1.7.4에서 한 줄씩 대조: drafts/1.7.4-tbt-diff.md 1장). 0이면 표에 없음 →
     * 순정처럼 updateTBTInfo를 보내지 않는다. 좌측통행(side 1) 회전교차로는 순정 B 계열(192~203).
     * 예외 하나(판단 대기, mod.md 1.7.4 "판단 필요" 1): 좌회전(1)·우회전(2)이 교차로(junction 0)에서 각도 없이(0) 오면
     * 지금처럼 70·67을 보낸다(순정 표에는 없음. 애플 지도·네이버 지도는 카플레이로 각도를 보내지 않는다).
     */
    static int exactIcon(int type, int side, int junction, int exit, int state) {
        switch (type) {
            case 1:   // left turn
                if (junction == 0 && exit == -120) return 69;
                if (side == 0 && junction == 0 && exit == -90) return 70;
                if (junction == 0 && exit == -60) return 71;
                if (junction == 0 && exit == -45) return 145;
                if (side == 1 && junction == 1 && exit == -120) return 200;
                if (side == 1 && junction == 1 && exit == -90) return 201;
                if (side == 1 && junction == 1 && exit == -30) return 203;
                if ((side == 0 || side == 1) && junction == 0 && exit == 0) return 70;   // 판단 대기(위 예외)
                return 0;
            case 2:   // right turn
                if (junction == 0 && exit == 60) return 66;
                if (side == 0 && junction == 0 && exit == 90) return 67;
                if (junction == 0 && exit == 120) return 68;
                if (side == 0 && junction == 1 && exit == 0) return 96;
                if (side == 1 && junction == 1 && exit == 0) return 193;
                if (side == 1 && junction == 1 && exit == 90) return 195;
                if (side == 1 && junction == 1 && exit == 120) return 196;
                if (side == 1 && junction == 1 && exit == 180) return 198;
                if (side == 0 && junction == 0 && exit == 45) return 144;
                if ((side == 0 || side == 1) && junction == 0 && exit == 0) return 67;   // 판단 대기(위 예외)
                return 0;
            case 3:   // straight
                return side == 0 && junction == 0 && exit == 0 ? 65 : 0;
            case 4:   // U-turn
                if (side == 0 && junction == 0) return 72;
                if (side == 1 && junction == 0) return 73;
                return 0;
            case 5:   // follow road
                return side == 0 && junction == 0 && exit == 0 ? 172 : 0;
            case 9:   // on-ramp: 160 in the Korean stock DiPO (the US build had 172)
                return side == 0 && junction == 0 && exit == 0 ? 160 : 0;
            case 12: {   // arrive; state 2 (arrived): 3
                int i = side == 0 && junction == 0 ? 112 : 0;
                return state == 2 ? 3 : i;
            }
            case 15: return side == 0 && junction == 0 && exit == 0 ? 176 : 0;
            case 19: return side == 0 && junction == 1 && exit == -180 ? 102 : 0;
            // highway off-ramp left / right: 165 / 164 in the Korean stock DiPO (the US build had 82 / 81)
            case 22: return side == 0 && junction == 0 && exit == 0 ? 165 : 0;
            case 23: return side == 0 && junction == 0 && exit == 0 ? 164 : 0;
            case 24: return side == 0 && junction == 0 && exit == 0 ? 114 : 0;
            case 25: return side == 0 && junction == 0 && exit == 0 ? 113 : 0;
            case 28: return side == 0 && junction == 1 && exit == 135 ? 100 : 0;
            case 29: return side == 0 && junction == 1 && exit == 90 ? 99 : 0;
            case 31:
                if (side == 0 && junction == 1 && exit == 0) return 97;
                if (side == 1 && junction == 1 && exit == 0) return 192;
                return 0;
            case 32: return side == 0 && junction == 1 && exit == -45 ? 104 : 0;
            case 33: return side == 0 && junction == 1 && exit == -90 ? 105 : 0;
            case 34: return side == 0 && junction == 1 && exit == -135 ? 104 : 0;
            case 35: return side == 0 && junction == 1 && exit == -180 ? 102 : 0;
            case 47:
                if (junction == 0 && exit <= -135 && exit >= -150) return 69;
                if (junction == 0 && exit == -30) return 71;
                return 0;
            case 48:
                if (junction == 0 && exit == 30) return 66;
                if (junction == 0 && exit >= 135 && exit <= 150) return 68;
                return 0;
            case 49: return junction == 0 && exit == -45 ? 71 : 0;
            case 50: return junction == 0 && exit == 45 ? 66 : 0;
            case 52: return side == 0 && junction == 0 && exit == 0 ? 174 : 0;
            case 53: return side == 0 && junction == 0 && exit == 0 ? 173 : 0;
            default: return 0;
        }
    }

    /** 2.4.10(1.8.1 T1-4): 표시 거리 문자열의 상태(로그용, CpTurnsFit도 씀): 0 없음·빈 값, 1 숫자(0 이상), 2 숫자 아님 */
    static int distStrState(String s) {
        if (s == null || s.length() == 0) return 0;
        try {
            float f = Float.parseFloat(s);
            return Float.isNaN(f) || Float.isInfinite(f) || f < 0f ? 2 : 1;
        } catch (NumberFormatException e) {
            return 2;
        }
    }
}
