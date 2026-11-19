package io.github.jayparklab.nx4kor;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 상태 파일(bin/status.sh가 root로 쓰는 key=value 줄)을 읽어 화면에 보일 줄을 만든다.
 * 안드로이드 클래스를 쓰지 않아 PC에서 시험할 수 있다(tests/ReportTest.java).
 * 상태 파일에는 SSID, 비밀번호, 휴대폰 이름, MAC, IP가 없다. 이 클래스도 그런 값을 만들지 않는다.
 * 판정(verdict·verdict_lv·verdict_msg·verdict_end)과 요약(s1~s3)은 status.sh(st_verdict) 한 곳에서 정하고, 앱은 그대로 보인다.
 */
final class Report {
    final Map<String, String> v = new LinkedHashMap<String, String>();

    static Report parse(String text) {
        Report r = new Report();
        if (text == null) return r;
        for (String line : text.split("\n")) {
            int i = line.indexOf('=');
            if (i <= 0) continue;
            r.v.put(line.substring(0, i).trim(), line.substring(i + 1).trim());
        }
        return r;
    }

    String get(String k) { String s = v.get(k); return s == null ? "" : s; }
    boolean yes(String k) { return "yes".equals(v.get(k)); }
    boolean empty() { return v.isEmpty(); }

    /**
     * busybox를 실행하지 못한 내비인가. 그때 status.sh는 짧은 상태 파일(support=nobb, product, platform, pkgver, made)만 쓰고
     * 무선 설정은 하지 않는다.
     */
    boolean nobb() { return "nobb".equals(v.get("support")); }

    /** mod.json "hmgapi"와 같은 최소 버전 (바꾸면 mod.json·svc/hotspot.sh HMG_MIN·README도 함께 고친다) */
    static final String MIN_HMGAPI = "1.1.0-rc.4";

    /** 순정이 카플레이 AP를 직접 띄운 차(ap_mode=stock). 이때 우리 핫스팟·DHCP가 꺼져 있는 것이 정상이다 */
    boolean stockAp() { return "stock".equals(get("ap_mode")); }

    static final String NO_STATUS = "상태를 읽지 못했습니다. 잠시 뒤 화면을 닫았다가 다시 열어 주세요.";
    static final String NOBB_MSG = "이 내비에서는 동작하지 않습니다(busybox를 실행하지 못함). 무선 설정은 하지 않았습니다.";
    /** 상태 파일에 판정 문구가 없을 때(status.sh가 아직 쓰는 중이거나 판정을 쓰지 못함) */
    static final String NO_VERDICT = "상태를 읽는 중입니다. 잠시 뒤 화면을 다시 열어 주세요.";

    /** 맨 위 한 줄: status.sh가 정한 판정 문구를 그대로 */
    String verdict() {
        if (empty()) return NO_STATUS;
        if (nobb()) return NOBB_MSG;
        String m = get("verdict_msg");
        return m.isEmpty() ? NO_VERDICT : m;
    }

    /** "이 차는 안 됨"으로 끝나는 판정(verdict_end=yes) 아래 회색 한 줄 */
    static final String UNINSTALL_HINT = "지우려면 USB의 NX4 폴더에 UNINSTALL 파일을 넣고 Engineering Mode의 Update OTA를 다시 실행한 뒤 재부팅하세요. 유선 카플레이는 그대로입니다.";

    /** 판정 아래 회색 한 줄(없으면 "") */
    String endHint() {
        return yes("verdict_end") ? UNINSTALL_HINT : "";
    }

    /** 차주용 요약 3줄(설치·무선 Wi-Fi·폰 연결). 없으면 빈 목록 */
    List<String> summary() {
        List<String> out = new ArrayList<String>();
        for (String k : new String[] { "s1", "s2", "s3" }) if (!get(k).isEmpty()) out.add(get(k));
        return out;
    }

    /** 0: 좋음, 1: 확인 필요, 2: 문제 (화면 색). status.sh의 verdict_lv, 판정이 없거나 값이 깨졌으면 1 */
    int level() {
        if (empty()) return 2;
        if (nobb()) return 1;
        if (get("verdict_msg").isEmpty()) return 1;
        try {
            int lv = Integer.parseInt(get("verdict_lv"));
            return lv < 0 ? 0 : lv > 2 ? 2 : lv;
        } catch (NumberFormatException e) {
            return 1;
        }
    }

    // --- 설치 진행 기록(서비스가 쓰는 /data/local/tmp/nx4-kor-progress.txt) ---
    // 이 Report를 진행 기록 파일로 만들었을 때 쓴다. boot는 지금 부팅 id(/proc/sys/kernel/random/boot_id):
    // 지난 부팅의 기록은 무시한다(재부팅 전 "진행 중"이 남아 있어도 막대를 보이지 않게).

    /** 이번 부팅의 기록인가 */
    boolean progThisBoot(String boot) {
        return !empty() && boot != null && boot.trim().equals(get("boot"));
    }

    /** 진행 기록이 이만큼(초) 새로 쓰이지 않으면 멈춘 것으로 본다(status.sh --wait의 15분과 같다) */
    static final long STALE = 900;

    /** 이번 부팅에 설치가 진행 중인가(진행 막대를 보일지) */
    boolean progRunning(String boot) {
        return progThisBoot(boot) && "run".equals(get("state"));
    }

    /** progRunning이면서 최근(STALE초 안)에 쓰인 기록인가. now: 지금 시각(초) */
    boolean progRunning(String boot, long now) {
        if (!progRunning(boot)) return false;
        try {
            // 시계가 뒤로 바뀌어 기록 시각이 한참 미래면 멈춘 기록으로 본다
            long d = now - Long.parseLong(get("t"));
            return d <= STALE && d >= -STALE;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    /** 진행률 0~100 (읽지 못하면 0) */
    int progPct() {
        try {
            int p = Integer.parseInt(get("pct"));
            return p < 0 ? 0 : p > 100 ? 100 : p;
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** 시작한 지 몇 초 (now: 지금 시각 초). 읽지 못하면 -1 */
    long progElapsed(long now) {
        try {
            long s = Long.parseLong(get("start"));
            return now >= s ? now - s : -1;
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    /** "3분 05초" */
    static String mmss(long sec) {
        if (sec < 0) return "-";
        long m = sec / 60, ss = sec % 60;
        return (m > 0 ? m + "분 " : "") + (ss < 10 && m > 0 ? "0" : "") + ss + "초";
    }

    /**
     * 설치가 끝난 결과가 맨 위 판정을 대신할 때의 문구. 재부팅 필요·실패만(이번 부팅 기록일 때). 아니면 null.
     * 상태 파일에 판정 문구가 없을 때만 쓰인다.
     */
    String progVerdict(String boot) {
        if (!progThisBoot(boot)) return null;
        String st = get("state");
        if ("reboot".equals(st) || "fail".equals(st)) return get("stage").isEmpty() ? null : get("stage");
        return null;
    }

    /** 이번 부팅에 "재부팅 필요"(state=reboot)인가. [지금 재부팅] 버튼은 늘 보이므로 화면은 이것을 쓰지 않는다(시험용으로 둠) */
    boolean progReboot(String boot) {
        return progThisBoot(boot) && "reboot".equals(get("state"));
    }

    /** 진행 기록의 단계(step=N/M)를 "단계 N/M"으로. 줄이 없거나 깨진 값이면 "" */
    String progStep() {
        String st = get("step");
        int i = st.indexOf('/');
        if (i <= 0 || i == st.length() - 1) return "";
        try {
            int n = Integer.parseInt(st.substring(0, i)), m = Integer.parseInt(st.substring(i + 1));
            return n >= 1 && n <= m && m <= 20 ? "단계 " + n + "/" + m : "";
        } catch (NumberFormatException e) {
            return "";
        }
    }

    /** 이만큼(초) 넘게 걸리면 "평소보다 오래" 안내(STALE 900초 = 15분과 맞춤) */
    static final long SLOW = 600;
    static final String SLOW_MSG = "평소보다 오래 걸립니다. 15분이 지나도 그대로면 내비를 재부팅해 주세요.";
    static final String PROGRESS_HINT = "보통 5분 안에 끝납니다. 끝날 때까지 내비를 끄지 마세요.";

    /** 진행이 오래 걸리면 SLOW_MSG, 아니면 "" (now: 지금 시각 초) */
    String progSlow(long now) {
        return progSlow(now, -1);
    }

    /**
     * nowUp(지금 부팅 뒤 초, /proc/uptime)을 주고 진행 기록에 시작한 부팅 뒤 초(ust)가 있으면 그것으로 잰다(시계가 앞당겨져도
     * 설치 초반에 "재부팅해 주세요"가 나오지 않게). 없거나 잴 수 없으면 시각(start)으로 잰다.
     */
    String progSlow(long now, long nowUp) {
        long ust = num("ust");
        if (nowUp >= 0 && !get("ust").isEmpty() && nowUp >= ust) return nowUp - ust >= SLOW ? SLOW_MSG : "";
        return progElapsed(now) >= SLOW ? SLOW_MSG : "";
    }

    /** /proc/uptime 내용 → 부팅 뒤 초. 읽지 못하면 -1 */
    static long upSec(String uptime) {
        if (uptime == null) return -1;
        String t = uptime.trim();
        int i = t.indexOf('.');
        if (i < 0) i = t.indexOf(' ');
        try { return Long.parseLong(i < 0 ? t : t.substring(0, i)); } catch (NumberFormatException e) { return -1; }
    }

    /** 이번 부팅 진행이 재부팅 필요·실패로 끝난 시각(초). 이보다 앞선 알림은 지난 단계의 것이라 숨긴다. 없으면 0 */
    long progEndedAt(String boot) {
        // 끝난 차(done)는 서비스가 부팅마다 "준비됨"을 다시 쓴다. 그 시각으로 숨기면 그 앞의 다른 안내가 가려지므로
        // 진행이 재부팅 필요·실패로 끝났을 때만 숨긴다
        if (!progThisBoot(boot) || !("reboot".equals(get("state")) || "fail".equals(get("state")))) return 0;
        return num("t");
    }

    /** progVerdict의 색: 재부팅 필요는 노랑(1), 실패는 빨강(2) */
    int progLevel() {
        return "fail".equals(get("state")) ? 2 : 1;
    }

    // --- [지금 재부팅] ---
    // 앱은 일반 앱 권한이라 직접 재부팅하지 못한다. 앱 폴더에 reboot.req만 쓰고, root 감시자(status.sh --watch, 화면을 연 뒤
    // 10분 동안 돎)가 받아 재부팅한다. 받지 않으면 이유(code)를 RBRES 파일에 남긴다.
    static final String RB_CONFIRM = "차를 세운 상태에서만 누르세요. 화면이 1~2분 꺼졌다 켜집니다.";
    static final String RB_SENT = "재부팅합니다…";
    static final String RB_FAILED = "재부팅하지 못했습니다. RESET 버튼으로 재부팅해 주세요.";
    /** 설치 중·설치 마무리 중·바깥 /system 작업 중(root가 일부러 막음) */
    static final String RB_FINISHING = "설정을 마무리하는 중입니다. 잠시 뒤 다시 눌러 주세요.";
    /** 요청이 늦게 닿았거나 이번 부팅의 새 요청으로 받지 못함(감시자는 있음) */
    static final String RB_RETRY = "재부팅 요청을 받지 못했습니다. 다시 눌러 주세요.";
    /** 요청을 받을 감시자(화면을 연 뒤 10분)가 이미 끝났을 때. 요청을 보내지 않고 바로 보인다(화면을 다시 열면 감시자가 다시 뜬다) */
    static final String RB_NOWATCH = "상태 화면을 닫았다가 다시 연 뒤 눌러 주세요.";
    /** 앱 폴더에 요청 파일을 쓰지 못했을 때 */
    static final String RB_WRITE_FAILED = "재부팅 요청을 저장하지 못했습니다. RESET 버튼으로 재부팅해 주세요.";

    /**
     * 요청 파일(reboot.req) 내용: "<요청 id> <boot_id> <부팅 뒤 초>" 한 줄. id는 부팅 뒤 밀리초(숫자만), 부팅 뒤 초는 root가
     * 오래된 요청을 버리는 데 쓴다(svc/hotspot.sh req_peek). 다른 값(이름·주소)은 넣지 않는다.
     */
    static String rbLine(long elapsedMs, String boot) {
        return elapsedMs + " " + (boot == null ? "" : boot.trim()) + " " + (elapsedMs / 1000) + "\n";
    }

    /** 요청 파일에서 {요청 id, 보낸 때의 부팅 뒤 밀리초}. 이번 부팅의 요청이 아니거나 읽지 못하면 null */
    static long[] rbParse(String text, String boot) {
        if (text == null || boot == null || boot.trim().isEmpty()) return null;
        String[] f = text.trim().split("\\s+");
        if (f.length < 3 || !boot.trim().equals(f[1])) return null;
        try {
            long id = Long.parseLong(f[0]);
            Long.parseLong(f[2]);
            return id < 0 ? null : new long[] { id, id };
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * 감시자가 끝났는가. text: root가 쓰는 감시자 파일(boot=…, until=부팅 뒤 초), upSec: 지금 부팅 뒤 초
     * (SystemClock.elapsedRealtime, 요청 파일과 같은 기준). 이번 부팅 것이 아니거나 읽지 못하면 끝난 것으로 본다(보내도 받을 쪽이 없음).
     * 끝나기 3초 전부터도 끝난 것으로 본다(요청을 받는 데 1초쯤 걸림)
     */
    static boolean watchGone(String text, String boot, long upSec) {
        Report w = parse(text);
        if (boot == null || boot.trim().isEmpty() || !boot.trim().equals(w.get("boot").trim())) return true;
        long until;
        try { until = Long.parseLong(w.get("until").trim()); } catch (NumberFormatException e) { return true; }
        return upSec + 3 >= until;
    }

    /**
     * root 감시자가 남긴 재부팅 결과(res: id·boot·code)에서 내 요청(reqId)에 대한 안내. 이번 부팅의 내 요청이 아니거나 아직 답이
     * 없으면 null(계속 기다림). install·fix·sysw → RB_FINISHING, old·bad → RB_RETRY, guard(HMG-API 부팅 보호) → RB_GUARD,
     * cmd(재부팅 명령이 돌아옴)와 모르는 값 → RB_FAILED.
     */
    static String rbAnswer(Report res, String boot, long reqId) {
        if (boot == null || boot.trim().isEmpty() || reqId <= 0) return null;
        if (!boot.trim().equals(res.get("boot").trim()) || !String.valueOf(reqId).equals(res.get("id").trim())) return null;
        String c = res.get("code").trim();
        if (c.isEmpty()) return null;
        if ("install".equals(c) || "fix".equals(c) || "sysw".equals(c)) return RB_FINISHING;
        if ("old".equals(c) || "bad".equals(c)) return RB_RETRY;
        if ("guard".equals(c)) return RB_GUARD;
        return RB_FAILED;
    }

    /**
     * root가 HMG-API 부팅 보호를 부추기지 않으려고 거절함(부팅 직후이고 HMG-API 시작 횟수가 2·3).
     * 시간이 지나면 풀리므로 이어진 거절 세기(rbStuckCode)에 넣지 않는다
     */
    static final String RB_GUARD = "3분 안에 재부팅을 반복하면 HMG-API가 무선 기능을 끕니다. 내비가 켜지고 3~5분 뒤에 다시 눌러 주세요.";

    /**
     * 같은 이유(설치 중·바깥 /system 작업)로 이어진 거절이 처음 거절부터 이만큼(초) 지나도 계속되면 RESET 안내로 넘긴다.
     * 900초는 root가 설치 진행 기록(run)을 멈춘 것으로 보는 시각(status.sh RB_STALE)과 같다
     */
    static final long RB_STUCK_SECS = 900;
    /**
     * 거절과 다음 거절 사이가 이만큼(초, RB_STUCK_SECS의 2배) 넘게 비면 이어진 거절로 보지 않고 기록을 새로 시작한다
     * (한참 전의 거절 하나 때문에 다음 거절에서 바로 RESET 안내가 나오지 않게)
     */
    static final long RB_STUCK_GAP = 2 * RB_STUCK_SECS;
    /** 이어진 거절 기록(앱 폴더의 작은 파일) 한 줄: "<boot_id> <처음 거절 부팅 뒤 초> <마지막 거절 부팅 뒤 초>" */
    static String stuckLine(String boot, long sinceSec, long lastSec) {
        return (boot == null ? "" : boot.trim()) + " " + sinceSec + " " + lastSec + "\n";
    }
    /**
     * 기록에서 이번 부팅(boot)의 처음 거절 시각(부팅 뒤 초). 없거나 다른 부팅·깨진 값이면 -1.
     * 마지막 거절에서 nowSec까지 RB_STUCK_GAP 넘게 비었거나 시각이 거꾸로면 -1(새로 시작)
     */
    static long stuckSince(String text, String boot, long nowSec) {
        if (text == null || boot == null || boot.trim().isEmpty()) return -1;
        String[] f = text.trim().split("\\s+");
        if (f.length != 3 || !f[0].equals(boot.trim())) return -1;
        long since, last;
        try { since = Long.parseLong(f[1]); last = Long.parseLong(f[2]); } catch (NumberFormatException e) { return -1; }
        if (since < 0 || last < since || nowSec < last) return -1;
        if (nowSec - last >= RB_STUCK_GAP) return -1;
        return since;
    }

    /** 오래 풀리지 않을 수 있는 거절(install 설치 중, sysw 바깥 /system 작업)인가. 우리 설치 마무리(fix)는 끝나면 풀리므로 넣지 않는다 */
    static boolean rbStuckCode(Report res) {
        String c = res.get("code").trim();
        return "install".equals(c) || "sysw".equals(c);
    }

    /**
     * stuckSince는 이번 부팅에 이어진 install·sysw 거절이 처음 난 부팅 뒤 초(없으면 -1), nowSec는 지금 부팅 뒤 초.
     * 이번도 그렇고 처음 거절부터 RB_STUCK_SECS가 지났으면 "잠시 뒤 다시" 대신 RESET 안내(RB_FAILED)를 준다(root 판단이 틀려 영영
     * 막혀도 빠져나갈 길). 그 밖에는 rbAnswer와 같다
     */
    static String rbAnswer(Report res, String boot, long reqId, long stuckSince, long nowSec) {
        String a = rbAnswer(res, boot, reqId);
        if (a != null && rbStuckCode(res) && stuckSince >= 0 && nowSec - stuckSince >= RB_STUCK_SECS) return RB_FAILED;
        return a;
    }

    /** 요청 뒤 이만큼(초) 지나도 화면이 살아 있으면 재부팅하지 못한 것으로 본다(root 쪽 최악: 요청 나이 40초 + sync + 재부팅 명령 기다림 30초) */
    static final long RB_WAIT = 80;

    /**
     * 알림 기록(svc/hotspot.sh notice, 토스트 대신). 한 줄에 "<시각(초)> <부팅 id> <문구>".
     * 이번 부팅의 줄만, 새것부터 최대 max개. 돌려주는 값은 {시각(초), 문구}.
     * now·maxAge(초)를 주면 그보다 오래된 줄은 뺀다(지난 단계의 안내가 계속 남아 오해하지 않게).
     */
    static List<String[]> notices(String text, String boot, int max) {
        return notices(text, boot, max, 0, 0);
    }

    static List<String[]> notices(String text, String boot, int max, long now, long maxAge) {
        return notices(text, boot, max, now, maxAge, 0);
    }

    /** 앞의 "NX4 KOR: "을 뗀다(화면 위에 이미 이름이 있다) */
    static String plain(String msg) {
        String p = "NX4 KOR: ";
        return msg.startsWith(p) ? msg.substring(p.length()).trim() : msg;
    }

    /**
     * minT(초)를 주면 그보다 앞선 알림은 뺀다. 진행이 끝난 시각(progEndedAt)을 주면 "재부팅하지 마세요"(설치 중)와
     * "재부팅해 주세요"(설치 끝)가 함께 보이지 않는다.
     */
    static List<String[]> notices(String text, String boot, int max, long now, long maxAge, long minT) {
        List<String[]> out = new ArrayList<String[]>();
        if (text == null || boot == null || boot.isEmpty()) return out;
        String[] lines = text.split("\n");
        for (int i = lines.length - 1; i >= 0 && out.size() < max; i--) {
            String l = lines[i].trim();
            int a = l.indexOf(' ');
            int b = a < 0 ? -1 : l.indexOf(' ', a + 1);
            if (b < 0) continue;
            if (!boot.equals(l.substring(a + 1, b))) continue;
            String msg = plain(l.substring(b + 1).trim());
            if (msg.isEmpty()) continue;
            if (maxAge > 0 || minT > 0) {
                long t;
                try { t = Long.parseLong(l.substring(0, a)); } catch (NumberFormatException e) { continue; }
                if (maxAge > 0 && now - t > maxAge) continue;
                if (minT > 0 && t < minT) continue;
            }
            out.add(new String[] { l.substring(0, a), msg });
        }
        return out;
    }

    /** 안내가 이만큼(초) 지나면 보이지 않는다(서비스도 10분 뒤 지운다. 서비스가 멈춰 남은 안내를 가리려고) */
    static final long HINT_SHOW = 600;

    /**
     * 서비스(svc/hotspot.sh hint_write)가 30초마다 정하는 상태 안내(/data/local/tmp/nx4-kor-hint.txt, key=value).
     * 이번 부팅의 것만 보인다. 돌려주는 값은 {수준(0 좋음·1 확인 필요), 문구, 시각(초, 문구 옆에 HH:MM로 붙일 때만, 아니면 "")}.
     * 확인이 필요한 것(설정 바뀜·아이폰·AA 안내)을 먼저 둔다. 문구는 내비 화면에서 읽기 좋게 한두 문장.
     */
    static List<String[]> hints(String text, String boot, long now) {
        List<String[]> out = new ArrayList<String[]>();
        Report h = parse(text);
        if (boot == null || boot.isEmpty() || !boot.trim().equals(h.get("boot"))) return out;
        if ("wait".equals(h.get("conf")))
            out.add(new String[] { "1", "Wi-Fi 설정이 바뀌었습니다. 카플레이 연결이 끝나면 핫스팟을 다시 시작합니다.", "" });
        if ("wifi".equals(h.get("iph")) && h.fresh("iph_t", now))
            out.add(new String[] { "1", "아이폰이 차 Wi-Fi에 오지 않습니다. 아이폰 설정 → Wi-Fi에서 차 네트워크를 지우고 다시 연결하세요.", "" });
        // 우리 Wi-Fi에 기기는 붙었는데 카플레이가 60초 동안 안 열림. 아이폰인지 가릴 수 없어 "폰"이라고 쓴다
        if ("nocp".equals(h.get("iph")) && h.fresh("iph_t", now))
            out.add(new String[] { "1", "폰이 차 Wi-Fi에 연결됐지만 카플레이가 시작되지 않았습니다. 내비를 재부팅해 주세요.", "" });
        String aa = h.get("aa");
        boolean aaNow = h.fresh("aa_t", now);
        if ("bt".equals(aa) && aaNow)
            out.add(new String[] { "1", "안드로이드 폰의 블루투스를 껐다 켜 주세요(또는 내비 블루투스 화면에서 폰을 다시 연결).", "" });
        if ("cpwait".equals(aa) && aaNow)
            out.add(new String[] { "1", "카플레이가 연결되어 있어 안드로이드 오토는 기다립니다.", "" });
        // 무선 안드로이드 오토 준비됨·연결됨은 따로 줄을 두지 않는다. 판정 줄(status.sh st_verdict)이 카플레이와 함께 한 줄로 말한다
        return out;
    }

    /** 숫자 값(초). 없거나 숫자가 아니면 0 */
    long num(String k) {
        try { return Long.parseLong(get(k)); } catch (NumberFormatException e) { return 0; }
    }

    /** 시각 k가 있고 HINT_SHOW초 안인가 */
    boolean fresh(String k, long now) {
        long t = num(k);
        return t > 0 && now - t <= HINT_SHOW;
    }

    /** status.sh의 hmgapi 값("version 1.1.0-rc.4 build 180185d 2026-11-04")에서 버전만. 없으면 "" */
    String hmgapiVer() {
        String s = get("hmgapi");
        int i = s.indexOf("version ");
        if (i < 0) return "";
        String rest = s.substring(i + 8).trim();
        int sp = rest.indexOf(' ');
        return sp < 0 ? rest : rest.substring(0, sp);
    }

    /**
     * have가 need보다 낮은가: 0 아니요(같거나 높음), 1 낮음, 2 숫자로 읽지 못함.
     * svc/hotspot.sh ver_lt와 같게 major.minor.patch 숫자만 비교하고 "-태그"는 무시한다("1.1.0-rc.4"는 1.1.0). 빈 값도 2.
     */
    static int older(String have, String need) {
        int[] a = nums(have), b = nums(need);
        if (a == null || b == null) return 2;
        for (int i = 0; i < 3; i++) {
            int x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
            if (x != y) return x < y ? 1 : 0;
        }
        return 0;
    }

    private static int[] nums(String s) {
        if (s == null) return null;
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("^\\s*(\\d+(?:\\.\\d+)*)").matcher(s);
        if (!m.find()) return null;
        String[] p = m.group(1).split("\\.");
        int[] r = new int[p.length];
        try {
            for (int i = 0; i < p.length; i++) r[i] = Integer.parseInt(p[i]);
        } catch (NumberFormatException e) {
            return null;
        }
        return r;
    }

    /** 버전 칸: 값 옆에 필요 조건을 붙인다 */
    private static String ver(String have, String need) {
        if (have == null || have.isEmpty()) return "없음 (" + need + " 이상 필요)";
        int o = older(have, need);
        if (o == 1) return have + " (지원 안 함, " + need + " 이상 필요)";
        if (o == 2) return have + " (버전 확인 안 됨, " + need + " 이상 필요)";
        return have;
    }

    /** NX4 KOR 모드 칸(HMG-API 앱에서 켜고 끔): 꺼짐 / 켜짐(무선 카플레이 설정 꺼짐) / 켜짐(훅이 안 켜짐) / 켜짐 */
    private String modCell() {
        if ("no".equals(get("mod_on"))) return "꺼짐 (켜야 함)";
        if ("off".equals(get("bridge"))) return "켜짐, Wireless CarPlay 설정 꺼짐";
        if ("off".equals(get("mod_hooks"))) return "켜짐, 훅이 안 켜짐";
        return yes("mod_on") ? "켜짐" : yn("mod_on");
    }

    /** 화면 표: {제목, 값}. 필요한 것(버전·모드·훅)을 위에 둔다 */
    List<String[]> rows() {
        List<String[]> out = new ArrayList<String[]>();
        if (nobb()) {
            out.add(new String[] { "내비 소프트웨어", get("product") });
            out.add(new String[] { "내비 종류(플랫폼)", get("platform") });
            out.add(new String[] { "NX4 KOR", get("pkgver") });
            out.add(new String[] { "지원", "안 됨 (busybox를 실행하지 못함)" });
            out.add(new String[] { "무선 설정", "하지 않았습니다 (차의 파일을 바꾸지 않음)" });
            return out;
        }
        out.add(new String[] { "내비 소프트웨어", get("product") });
        out.add(new String[] { "지원 차종", yn("tested") });
        out.add(new String[] { "NX4 KOR", get("pkgver") });
        out.add(new String[] { "HMG-API", ver(hmgapiVer(), MIN_HMGAPI) });
        out.add(new String[] { "NX4 KOR 모드", modCell() });
        out.add(new String[] { "무선 기능 적용", yn("applied") });
        // 따로 설치된 예전 무선 모드(wireless-carplay-aa)가 있는 차만 한 줄
        if (yes("oldmod")) out.add(new String[] { "예전 무선 모드", "있음 (지워야 함)" });
        String h = get("hooks");
        out.add(new String[] { "HMG-API 훅", "on".equals(h) ? "켜짐" : "off".equals(h) ? "꺼짐 (" + (get("hookmap").isEmpty() ? "?" : get("hookmap")) + ", 마지막 부팅 기록)" : "-" });
        out.add(new String[] { "무선 카플레이 기능", yn("feat_carplay") });
        out.add(new String[] { "무선 안드로이드 오토 기능", yn("feat_aa") });
        out.add(new String[] { "Wi-Fi 장치", yn("wlan0") });
        String am = get("ap_mode");
        if (!am.isEmpty())
            out.add(new String[] { "무선 카플레이 Wi-Fi", "stock".equals(am) ? "내비 순정 Wi-Fi" : "ours".equals(am) ? "NX4 KOR 핫스팟" : "없음" });
        out.add(new String[] { "핫스팟 (hostapd)", yn("our_ap") + (stockAp() ? " (순정 Wi-Fi를 쓰므로 꺼 둠)" : "") });
        out.add(new String[] { "IP 나눠 주기 (DHCP)", yn("our_dhcp") });
        out.add(new String[] { "순정 핫스팟", yn("other_ap") });
        out.add(new String[] { "카플레이 연결", get("cp_conn").isEmpty() ? "-" : get("cp_conn") + "개" });
        if (!get("verdict").isEmpty()) out.add(new String[] { "판정 코드", get("verdict") });
        return out;
    }

    private String yn(String k) {
        String s = v.get(k);
        if ("yes".equals(s)) return "예";
        if ("no".equals(s)) return "아니요";
        return s == null || s.isEmpty() ? "-" : s;
    }
}
