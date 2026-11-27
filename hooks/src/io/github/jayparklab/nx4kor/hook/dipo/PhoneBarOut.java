package io.github.jayparklab.nx4kor.hook.dipo;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/src/hmgapi/mods/wireless/dipo/PhoneBarOut.java
// (Korea Projection, 2026-11-09, mod 2.3.3, AGPL-3.0; the same file as 6258357). Its own notes below are Korea Projection's.
// Modified by NX4 KOR (jay-park-lab/hmgapi-nx4-kor), 2026-11-25 (#67): sent nothing (no receiver in this mod then).
// Modified by NX4 KOR, 2026-11-27 (#96: the near-turn gauge on the cluster stayed empty): sends again, as KP's, to this
//   mod's TrapBar in the car navigation; the action is this mod's own (io.github.jayparklab.nx4kor.PHONE_BAR).

import android.content.Context;
import android.content.Intent;

/**
 * 카플레이 막대를 순정 내비 프로세스로 알린다(io.github.jayparklab.nx4kor.hook.PhoneBar의 보내는 쪽).
 * DiPO 앱 파트는 진입 클래스와 클래스 로더가 달라 PhoneBar를 쓰지 못해 같은 값을 두었다.
 * 이름·값·간격은 PhoneBar와 같아야 한다(PC 시험 TrapBarTest가 비교한다).
 */
final class PhoneBarOut {
    static final String ACTION = "io.github.jayparklab.nx4kor.PHONE_BAR";
    static final String EXTRA_BAR = "bar";
    static final int NONE = -1;
    static final long RESEND_MS = 10000;

    private int last = Integer.MIN_VALUE;
    private long at;

    /** 값이 바뀌었거나, 막대가 있는 동안 RESEND_MS가 지났을 때만 true(그 값을 기억한다) */
    boolean due(int bar, long now) {
        if (bar == last && (bar == NONE || now - at < RESEND_MS)) return false;
        last = bar;
        at = now;
        return true;
    }

    /** 방송 보내기(실패해도 회전 보내기에는 영향 없음). 보낸 값이면 true */
    boolean send(Context c, int bar, long now) {
        if (c == null || !due(bar, now)) return false;
        try {
            Intent i = new Intent(ACTION);
            i.addFlags(Intent.FLAG_RECEIVER_FOREGROUND);
            i.putExtra(EXTRA_BAR, bar);
            c.sendBroadcast(i);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }
}
