package io.github.jayparklab.nx4kor.hook.dipo;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/src/hmgapi/mods/wireless/dipo/CpTbt.java (AGPL-3.0).
// Modified by NX4 KOR (jay-park-lab/hmgapi-nx4-kor), 2026-11-25 (#67): package only (the nx4-kor mod's DiPO part).
// Updated by NX4 KOR, 2026-11-26: taken again from KP's mod 2.4.10 (Korea Projection 1.8.1), the file itself unchanged.
// Korea Projection 1.7.4(2026-11-15, 모드 2.4.3, 계획 D-20).

import com.tcc.iap2.Iap2NotiMsg;

/**
 * 카플레이 길안내 관리자. Dipo가 부른다(한 스레드).
 *   - CpTurns: 순정 DiPO e/u와 같게 전달(2.4.2, 설정 tbt_fit 끔)
 *   - CpTurnsFit: 그 위에 현대·기아 순정 내비 화면에 맞춘 보정(2.4.1의 보정을 되살림, 설정 tbt_fit 켬·기본)
 */
interface CpTbt {
    void routeGuidance(Iap2NotiMsg msg);

    void maneuver(Iap2NotiMsg msg);

    void lanes(Iap2NotiMsg msg);

    void refresh();

    boolean active();

    void disconnected();

    void stop();
}
