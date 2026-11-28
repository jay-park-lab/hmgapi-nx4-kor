package io.github.jayparklab.nx4kor;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;

/**
 * NX4 KOR 관리 앱의 화면. HMG-API 앱의 모드 실행 항목(mod.json provides.launcher)으로 연다. 열릴 때 HMG-API 서비스 "launch"를
 * 불러 bin/status.sh(root)가 상태 파일을 새로 쓰게 하고, 이 화면은 그것을 읽어 판정·요약·상태표를 보여 준다. 판단은 Report에 있다.
 * 설치가 진행 중이면(서비스의 진행 기록 state=run) 먼저 진행 막대(0~100%)와 단계·경과 시간을 보여 준다.
 * 1초마다 다시 읽고, 끝나면(그리고 status.sh가 상태 파일을 새로 쓰면) 결과 화면으로 바뀐다.
 * 설치는 서비스가 하므로 이 화면을 닫아도 계속된다.
 * 모양(색·크기·부품)은 순정 내비 화면에 맞춘 Ui에 있다(#28).
 */
public class StatusActivity extends Activity implements View.OnClickListener, Runnable, android.content.DialogInterface.OnClickListener {
    /** bin/status.sh가 쓰는 파일 (644, 비밀값 없음) */
    static final String STATUS = "/data/local/tmp/nx4-kor-status.txt";
    /** USB 설치기가 쓰는 설치 진행 기록 (644, 비밀값 없음, 형식은 svc/lib.sh PROG) */
    static final String PROG = "/data/local/tmp/nx4-kor-progress.txt";
    static final String BOOT_ID = "/proc/sys/kernel/random/boot_id";
    /** 알림 기록(644, 토스트 대신). 이번 부팅의 줄만 보인다 */
    static final String NOTICE = "/data/local/tmp/nx4-kor-notice.txt";
    /** 2.0.x 서비스(svc/hotspot.sh hint_write)가 쓰던 상태 안내(644, 코드와 시각뿐). 2.1.0에는 쓰는 곳이 없다. 이번 부팅의 것만 보인다 */
    static final String HINT = "/data/local/tmp/nx4-kor-hint.txt";
    /** 알림을 보여 주는 시간(초): 그보다 오래된 안내는 지난 단계의 것이다 */
    static final long NOTICE_SHOW = 1800;
    /** 설치가 끝난 뒤 status.sh가 상태 파일을 다시 쓰기를 기다리는 최대 시간(초). 넘으면 있는 대로 보인다. */
    static final int AFTER_WAIT = 25;
    /** [지금 재부팅] 요청 파일 이름(앱 개인 폴더). root 쪽(svc/lib.sh RBREQ)과 같아야 한다. 앱을 지우면 폴더째 지워진다 */
    static final String RB_NAME = "reboot.req";
    /** root 감시자가 재부팅 요청을 받지 않았거나 명령이 돌아왔을 때 남기는 결과(id·boot·code, 644) */
    static final String RBRES = "/data/local/tmp/nx4-kor-reboot-result.txt";
    /** root 감시자가 끝나는 시각(boot=…, until=부팅 뒤 초, 644) */
    static final String WATCHF = "/data/local/tmp/nx4-kor-watch.txt";
    /** [동글 켜기] 요청 파일 이름(앱 개인 폴더, #60). root 쪽(svc/lib.sh DGREQ)과 같아야 한다. 꼴은 reboot.req와 같다 */
    static final String DG_NAME = "dongle.req";
    /**
     * [동글 켜기] 기다림 기록(앱 개인 폴더, dongle.req와 같은 꼴). root는 요청을 받자마자 dongle.req를 지우므로, 화면을 다시 그리거나
     * 다시 열어도 기다림을 이어 가도록 앱이 따로 남긴다. 결과가 오거나 DG_WAIT초가 지나면 지운다(PR #100 리뷰 1)
     */
    static final String DG_WAIT_NAME = "dongle.wait";
    /** root(svc/dongle.sh --now, 받지 않으면 status.sh --watch)가 남기는 [동글 켜기] 결과(id·boot·code·usb·drv, 644) */
    static final String DGRES = "/data/local/tmp/nx4-kor-dongle-result.txt";

    final Handler handler = new Handler();
    /** 화면 부품(그릴 때마다 지금 화면 크기로 새로 만든다) */
    Ui ui;
    String boot;
    boolean watching;
    /** [지금 재부팅] 바로 위 안내 한 줄(보냄·거절 이유·실패) */
    TextView msgText;
    /** [지금 재부팅] 버튼과 요청을 보낸 때(부팅 뒤 밀리초, 0이면 없음) */
    TextView rebootBtn;
    long rbEl;
    /** [동글 켜기] 버튼(상태 파일이 dongle_btn=yes일 때만), 요청을 보낸 때(부팅 뒤 밀리초, 0이면 없음)와 그 id */
    TextView dongleBtn;
    long dgEl, dgId;
    /**
     * 화면을 다시 그린 뒤(상태 파일이 새로 써짐) 버튼 위에 다시 올릴 마지막 안내 한 칸: [동글 켜기] 결과(PR #100 리뷰 6)와
     * [지금 재부팅]의 답(리뷰 9). 늦게 온 안내가 앞의 것을 바꾼다
     */
    String reShow;
    int reShowBg, reShowFg;
    /** 띄운 확인 창이 무엇인가(확인 창의 버튼을 이 화면이 받으므로): 1 재부팅, 2 동글 켜기 */
    int dialogFor;
    /** 기다리는 재부팅 요청의 id(요청 파일 첫 칸). 결과 파일과 맞춰 본다 */
    long rbId;
    /**
     * 이어진 install·sysw 거절 기록 파일(앱 폴더, "<boot_id> <처음 거절 부팅 뒤 초> <마지막 거절 부팅 뒤 초>").
     * 파일로 두어 화면을 다시 열어도 이어진다. 앱을 지우면 함께 지워진다
     */
    static final String RB_STUCK_NAME = "reboot-stuck.txt";
    /** 기록 파일을 쓰지 못했을 때 대신 쓰는 화면 안 값(같은 3칸 한 줄, 화면을 다시 열면 사라짐). 있으면 파일보다 먼저 본다 */
    String rbStuckMem;
    long finishedAt;
    Ui.Bar bar;
    TextView pctText, stageText, timeText, noticeText, hintText;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        start();
    }

    /** 화면을 다시 열면(singleTask) 같은 화면을 새 상태로 다시 그린다 */
    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        setIntent(i);
        handler.removeCallbacks(this);
        start();
    }

    /**
     * 화면을 열 때 root의 bin/status.sh를 HMG-API 서비스 "launch"(mod.json, start=manual)로 돌린다. hmgapid는 이 앱을
     * 모드의 앱(mod.json apps)으로 알 때만 받는다(종료 코드 0). status.sh는 상태 파일을 새로 쓰고 [지금 재부팅]을 받는 감시자를
     * 10분 동안 띄운다. 받았으면 상태 파일이 새로 쓰일 때까지(최대 KICK_WAIT초) 1초마다 보고, 바뀌면 화면을 다시 그린다.
     */
    static final String HMGAPID = "/system/bin/hmgapid";
    static final int KICK_WAIT = 40;
    /** 서비스를 부른 때(부팅 뒤 밀리초, 0이면 아직)와 그때 상태 파일의 수정 시각 */
    long kickEl, kickMtime;

    final Runnable kickWatch = new Runnable() {
        @Override
        public void run() {
            if (isFinishing()) return;
            if (new File(STATUS).lastModified() != kickMtime) {
                handler.removeCallbacks(StatusActivity.this);
                render();
                return;
            }
            if (android.os.SystemClock.elapsedRealtime() - kickEl < KICK_WAIT * 1000L) handler.postDelayed(this, 1000);
        }
    };

    void kickStatus() {
        long el = android.os.SystemClock.elapsedRealtime();
        // 화면을 빠르게 여러 번 열면 한 번만(돌고 있는 status.sh를 service-start가 멈추고 다시 띄우지 않게)
        if (kickEl > 0 && el - kickEl < 10000) return;
        if (!new File(HMGAPID).exists()) return;
        kickEl = el;
        kickMtime = new File(STATUS).lastModified();
        new Thread(new Runnable() {
            @Override
            public void run() {
                int rc;
                try {
                    Process pr = new ProcessBuilder(HMGAPID, "service-start", "launch").redirectErrorStream(true).start();
                    InputStream in = pr.getInputStream();
                    byte[] buf = new byte[256];
                    while (in.read(buf) >= 0) { }
                    rc = pr.waitFor();
                } catch (Exception e) {
                    rc = -1;
                }
                if (rc != 0) return;
                handler.post(new Runnable() {
                    @Override
                    public void run() {
                        handler.removeCallbacks(kickWatch);
                        handler.postDelayed(kickWatch, 1000);
                    }
                });
            }
        }).start();
    }

    void start() {
        kickStatus();
        render();
    }

    void render() {
        String bid = read(BOOT_ID);
        boot = bid == null ? null : bid.trim();
        finishedAt = 0;
        Report p = Report.parse(read(PROG));
        if (p.progRunning(boot, System.currentTimeMillis() / 1000)) {
            showProgress(p);
            watching = true;
            handler.postDelayed(this, 1000);
        } else {
            watching = false;
            showStatus();
        }
    }

    /** 화면이 가려지면 읽기를 멈추고, 다시 보이면 이어서 */
    @Override
    protected void onPause() {
        handler.removeCallbacks(this);
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (watching || rbEl > 0 || dgEl > 0) {
            handler.removeCallbacks(this);
            handler.postDelayed(this, 1000);
        }
    }

    @Override
    protected void onDestroy() {
        watching = false;
        handler.removeCallbacks(this);
        handler.removeCallbacks(kickWatch);
        super.onDestroy();
    }

    /** 1초마다: 진행 기록을 다시 읽어 막대를 고치고, 끝났으면 결과 화면으로. 결과 화면에서는 재부팅 기다림만 */
    @Override
    public void run() {
        if (!watching) {
            boolean more = false;
            if (rbEl > 0 && rebootTick()) more = true;
            if (dgEl > 0 && dongleTick()) more = true;
            if (more) {
                handler.removeCallbacks(this);
                handler.postDelayed(this, 1000);
            }
            return;
        }
        Report p = Report.parse(read(PROG));
        long now = System.currentTimeMillis() / 1000;
        if (p.progRunning(boot, now)) {
            update(p, now);
            handler.postDelayed(this, 1000);
            return;
        }
        // 끝남: status.sh(--wait)가 상태 파일을 새로 쓸 때까지 잠시(최대 AFTER_WAIT초) "결과 정리 중"
        if (finishedAt == 0) finishedAt = now;
        long t = 0;
        try { t = Long.parseLong(p.get("t")); } catch (NumberFormatException e) { t = 0; }
        long st = new File(STATUS).lastModified() / 1000;
        if (st >= t || now - finishedAt >= AFTER_WAIT) {
            watching = false;
            showStatus();
            return;
        }
        if (bar != null) bar.setProgress(100);
        if (pctText != null) pctText.setText("100%");
        if (stageText != null) stageText.setText("끝났습니다. 결과를 정리하는 중입니다…");
        handler.postDelayed(this, 1000);
    }

    /**
     * 설치 진행 화면(본보기: 순정의 화면 전체를 쓰는 안내 화면). 가운데에 제목·단계·막대·%·경과 시간·알림·안내,
     * 아래에 [닫기] 버튼 블록
     */
    void showProgress(Report p) {
        ui = new Ui(this);
        LinearLayout root = ui.screen();
        LinearLayout mid = ui.vertical();
        mid.setGravity(Gravity.CENTER);
        mid.setPadding(ui.px(Ui.PROG_PAD_X), 0, ui.px(Ui.PROG_PAD_X), 0);
        root.addView(mid, new LinearLayout.LayoutParams(-1, 0, 1f));

        TextView title = ui.text("NX4 KOR " + appVersion() + " 설치 중", Ui.PROG_TITLE, Ui.TEXT);
        title.setGravity(Gravity.CENTER);
        mid.addView(title, new LinearLayout.LayoutParams(-1, -2));
        stageText = ui.text(p.get("stage"), Ui.PROG_STAGE, Ui.TEXT);
        stageText.setGravity(Gravity.CENTER);
        mid.addView(stageText, ui.lp(-1, -2, 28));

        bar = new Ui.Bar(this);
        mid.addView(bar, ui.lp(-1, ui.px(Ui.BAR_H), 36));

        LinearLayout line = new LinearLayout(this);
        line.setOrientation(LinearLayout.HORIZONTAL);
        pctText = ui.text("", Ui.PROG_PCT, Ui.ACCENT);
        line.addView(pctText, new LinearLayout.LayoutParams(0, -2, 1f));
        timeText = ui.text("", Ui.PROG_TIME, Ui.TEXT_SUB);
        line.addView(timeText);
        mid.addView(line, ui.lp(-1, -2, 14));

        // 설치 중 알림(토스트 대신)은 단계 아래에 최근 것 하나(연노랑 띠). 없으면 숨긴다(update)
        noticeText = ui.band("", Ui.SMALL_TEXT, Ui.NOTICE, Color.BLACK);
        noticeText.setVisibility(View.GONE);
        mid.addView(noticeText, ui.lp(-1, -2, 24));

        // 안내는 두 문장. 10분이 넘으면 "평소보다 오래 걸립니다" 문구로 바꾼다(update)
        hintText = ui.text(Report.PROGRESS_HINT, Ui.INFO_TEXT, Ui.TEXT_SUB);
        hintText.setGravity(Gravity.CENTER);
        mid.addView(hintText, ui.lp(-1, -2, 28));

        // 익명 클래스 대신 이 화면이 직접 받는다 (JDK 21 + d8 8.2가 익명 클래스에서 멈춤)
        root.addView(ui.button("닫기", false, this), new LinearLayout.LayoutParams(-1, ui.px(Ui.BTN_H)));

        setContentView(root);
        update(p, System.currentTimeMillis() / 1000);
    }

    void update(Report p, long now) {
        int pct = p.progPct();
        if (bar != null) bar.setProgress(pct);
        if (pctText != null) pctText.setText(pct + "%");
        String step = p.progStep();
        if (stageText != null) stageText.setText(step.isEmpty() ? p.get("stage") : step + " · " + p.get("stage"));
        if (timeText != null) timeText.setText("경과 " + Report.mmss(p.progElapsed(now)));
        if (hintText != null) {
            String slow = p.progSlow(now, Report.upSec(read("/proc/uptime")));
            hintText.setText(slow.isEmpty() ? Report.PROGRESS_HINT : slow);
            hintText.setTextColor(slow.isEmpty() ? Ui.TEXT_SUB : Ui.NOTICE);
        }
        if (noticeText != null) {
            java.util.List<String[]> ns = Report.notices(read(NOTICE), boot, 1, now, NOTICE_SHOW);
            noticeText.setText(ns.isEmpty() ? "" : "알림 " + clock(ns.get(0)[0]) + "  " + ns.get(0)[1]);
            noticeText.setVisibility(ns.isEmpty() ? View.GONE : View.VISIBLE);
        }
    }

    /** 알림 시각(초) → "HH:MM". 읽지 못하면 빈 값 */
    static String clock(String sec) {
        try {
            java.util.Calendar c = java.util.Calendar.getInstance();
            c.setTimeInMillis(Long.parseLong(sec) * 1000L);
            return String.format(java.util.Locale.US, "%02d:%02d", c.get(java.util.Calendar.HOUR_OF_DAY), c.get(java.util.Calendar.MINUTE));
        } catch (Exception e) {
            return "";
        }
    }

    String appVersion() {
        try {
            return getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
        } catch (Exception e) {
            return "";
        }
    }

    /**
     * 결과 화면(본보기: 순정 설정 상세 화면). 위에 제목 줄(가운데 제목만. 닫기는 차 화면 맨 위 시스템 줄의 `<`), 아래는 두 칸이다.
     * 왼쪽(1280): 요약 3줄과 "자세히" 표를 목록 줄로, 맨 아래 정보 줄. 오른쪽(640, 분할 칸): 판정, 지우는 법, 상태 안내, 알림,
     * 버튼 안내, [지금 재부팅]. 설치 결과가 재부팅 필요·실패면 판정을 그 문구로 바꾼다
     */
    void showStatus() {
        // 이 화면에서 보낸 재부팅 기다림: 감시자가 reboot.req를 받자마자 지우므로, 다시 그릴 때(상태 파일이 새로 써짐) 파일이 없어도
        // 메모리의 값으로 이어 간다(PR #100 리뷰 8)
        long keepRb = rbEl, keepRbId = rbId;
        bar = null; pctText = null; stageText = null; timeText = null; noticeText = null; hintText = null; rebootBtn = null; rbEl = 0;
        msgText = null; dongleBtn = null; dgEl = 0;
        Report r = Report.parse(read(STATUS));
        Report p = Report.parse(read(PROG));
        ui = new Ui(this);

        LinearLayout root = ui.screen();
        root.addView(ui.header("NX4 KOR " + r.get("pkgver")), new LinearLayout.LayoutParams(-1, ui.px(Ui.HEAD_H)));
        root.addView(ui.line(Ui.LINE_HEAD), new LinearLayout.LayoutParams(-1, ui.thin()));
        LinearLayout body = new LinearLayout(this);
        body.setOrientation(LinearLayout.HORIZONTAL);
        root.addView(body, new LinearLayout.LayoutParams(-1, 0, 1f));

        // 왼쪽: 차주용 요약 3줄을 위에("설치: 끝남"은 제목 "설치", 설명 "끝남"), 상태표는 "자세히" 아래
        LinearLayout left = ui.vertical();
        body.addView(left, new LinearLayout.LayoutParams(0, -1, Ui.LIST_W));
        LinearLayout list = ui.vertical();
        java.util.List<String> sum = r.summary();
        for (String sl : sum) {
            int i = sl.indexOf(": ");
            ui.addRow(list, i > 0 ? ui.row2(sl.substring(0, i), sl.substring(i + 2)) : ui.row2(sl, null));
        }
        if (!sum.isEmpty()) {
            TextView dt = ui.text("자세히", Ui.SECTION_TEXT, Ui.TEXT_DIM);
            dt.setPadding(ui.px(Ui.PAD_X), ui.px(28), ui.px(Ui.PAD_X), ui.px(8));
            list.addView(dt);
        }
        for (String[] row : r.rows()) ui.addRow(list, ui.row1(row[0], row[1]));
        left.addView(ui.scroll(list), new LinearLayout.LayoutParams(-1, 0, 1f));
        left.addView(ui.line(Ui.LINE_PANEL), new LinearLayout.LayoutParams(-1, ui.thin()));
        android.util.DisplayMetrics dm = getResources().getDisplayMetrics();
        TextView made = ui.text("확인 " + r.get("made") + " · 앱 " + appVersion() + " · 화면 " + dm.widthPixels + "x" + dm.heightPixels
            + " (밀도 " + dm.density + ")", Ui.FOOT_TEXT, Ui.TEXT_DIM);
        made.setGravity(Gravity.CENTER_VERTICAL);
        made.setSingleLine(true);
        made.setPadding(ui.px(Ui.PAD_X), 0, ui.px(Ui.PAD_X), 0);
        left.addView(made, new LinearLayout.LayoutParams(-1, ui.px(Ui.FOOT_H)));

        body.addView(ui.line(Ui.LINE_PANEL), new LinearLayout.LayoutParams(ui.thin(), -1));

        // 오른쪽(분할 칸)
        LinearLayout right = ui.vertical();
        body.addView(right, new LinearLayout.LayoutParams(0, -1, Ui.PANEL_W));
        LinearLayout info = ui.vertical();
        info.setPadding(ui.px(Ui.PANEL_PAD), ui.px(Ui.PANEL_PAD), ui.px(Ui.PANEL_PAD), ui.px(Ui.GAP));
        // 상태 파일의 판정(status.sh st_verdict)을 쓴다. 판정 문구가 없으면 이번 부팅의 진행 결과(재부팅 필요·실패)가 대신한다.
        // 정상은 순정처럼 표시와 시안 글자만, 확인 필요·문제는 노랑·빨강 띠(Ui.WARN·BAD)
        String pv = r.get("verdict_msg").isEmpty() ? p.progVerdict(boot) : null;
        int lv = pv != null ? p.progLevel() : r.level();
        info.addView(ui.verdict(pv != null ? pv : r.verdict(), lv), new LinearLayout.LayoutParams(-1, -2));
        // "안 됨"으로 끝나면(verdict_end=yes) 지우는 법(회색). 설치 진행 결과가 판정을 대신할 때는 보이지 않는다
        if (pv == null && !r.endHint().isEmpty()) info.addView(ui.text(r.endHint(), Ui.SMALL_TEXT, Ui.TEXT_SUB), ui.lp(-1, -2, Ui.GAP));

        // 서비스가 정한 상태 안내(폰 블루투스 다시 켜기·아이폰 Wi-Fi·설정 바뀜). 화면을 열 때 읽는다. 좋은 소식은 표시만, 할 일은 노란 띠
        for (String[] h : Report.hints(read(HINT), boot, System.currentTimeMillis() / 1000)) {
            String msg = h[1] + (h[2].isEmpty() ? "" : " (" + clock(h[2]) + ")");
            View hv = "0".equals(h[0]) ? ui.marked(msg, Ui.INFO_TEXT, Ui.TEXT) : ui.band(msg, Ui.INFO_TEXT, Ui.WARN, Color.BLACK);
            info.addView(hv, ui.lp(-1, -2, Ui.GAP));
        }

        // 알림(토스트 대신, 연노랑 띠): 이번 부팅의 최근 3개, 새것이 위. 진행이 끝난 시각보다 앞선 알림(지난 단계의 "재부팅하지 마세요" 등)은 숨긴다
        for (String[] n: Report.notices(read(NOTICE), boot, 3, System.currentTimeMillis() / 1000, NOTICE_SHOW, p.progEndedAt(boot))) {
            info.addView(ui.band("알림 " + clock(n[0]) + "  " + n[1], Ui.SMALL_TEXT, Ui.NOTICE, Color.BLACK), ui.lp(-1, -2, Ui.GAP));
        }
        right.addView(ui.scroll(info), new LinearLayout.LayoutParams(-1, 0, 1f));

        // 버튼을 누른 뒤의 안내(보냄·거절 이유·실패). 버튼 바로 위에 둔다. 위 목록이 넘쳐도 맨 아래 띠와 붙어 한 덩어리로
        // 보이지 않게 위에도 틈을 둔다(목록의 아래 여백은 스크롤 안에 있어 넘치면 밀려난다, PR #34 리뷰 1)
        msgText = ui.band("", Ui.INFO_TEXT, Ui.MSG_BG, Color.WHITE);
        msgText.setVisibility(View.GONE);
        LinearLayout.LayoutParams mp = new LinearLayout.LayoutParams(-1, -2);
        mp.setMargins(ui.px(Ui.PANEL_PAD), ui.px(Ui.GAP), ui.px(Ui.PANEL_PAD), ui.px(Ui.GAP));
        right.addView(msgText, mp);

        // [동글 켜기](#60)는 묶음에 동글 드라이버가 있고 칩이 없는 내비에서만 [지금 재부팅] 위에 둔다(보조 버튼)
        if (r.dongleButton()) {
            dongleBtn = ui.button("동글 켜기", false, this);
            right.addView(dongleBtn, new LinearLayout.LayoutParams(-1, ui.px(Ui.BTN_H)));
        }

        // [지금 재부팅]은 늘 둔다(오른쪽 칸 아래 주 버튼 블록). 누르면 확인 창을 띄우고(운행 중에도 막지 않음), root가 설치 중·마무리 중이면 거절한다.
        // busybox를 실행하지 못한 내비(nobb)는 status.sh가 감시자를 띄우지 않으므로 버튼이 없다.
        if (!r.nobb()) {
            rebootBtn = ui.button("지금 재부팅", true, this);
            right.addView(rebootBtn, new LinearLayout.LayoutParams(-1, ui.px(Ui.BTN_H)));
        }

        // 화면을 다시 그릴 때 남은 재부팅 요청: 이번 부팅·RB_WAIT초 안이면 기다림을 이어 보이고, 아니면 지운다
        // (감시자가 늦게 받아 예고 없이 재부팅하지 않게. root도 40초 넘은 요청은 받지 않는다)
        File rbf = new File(getFilesDir(), RB_NAME);
        long[] rbq = Report.rbParse(read(rbf.getPath()), boot);
        long el = android.os.SystemClock.elapsedRealtime();
        if (rbq == null && keepRb > 0) rbq = new long[] { keepRbId, keepRb };
        if (rbq != null && rebootBtn != null && el >= rbq[1] && (el - rbq[1]) / 1000 < Report.RB_WAIT) {
            rbEl = rbq[1]; rbId = rbq[0];
            rebootBtn.setEnabled(false);
            showMsg(Report.RB_SENT, Ui.MSG_BG, Color.WHITE);
            handler.removeCallbacks(this);
            handler.postDelayed(this, 1000);
        } else if (rbf.exists()) {
            try { rbf.delete(); } catch (Exception ignored) { }
        }
        // 남은 [동글 켜기] 기다림(dongle.wait): 이번 부팅·DG_WAIT초 안이면 이어 보이고, 아니면 지운다. dongle.req는 root가 받자마자
        // 지우므로 기다림은 앱의 dongle.wait로 되살린다(PR #100 리뷰 1). 재부팅 기다림 안내가 있으면 그 안내를 덮지 않는다
        File dgw = new File(getFilesDir(), DG_WAIT_NAME);
        long[] dgq = Report.rbParse(read(dgw.getPath()), boot);
        if (dgq != null && dongleBtn != null && el >= dgq[1] && (el - dgq[1]) / 1000 < Report.DG_WAIT) {
            dgEl = dgq[1]; dgId = dgq[0];
            dongleBtn.setEnabled(false);
            if (rbEl == 0) showMsg(Report.DG_SENT, Ui.MSG_BG, Color.WHITE);
            handler.removeCallbacks(this);
            handler.postDelayed(this, 1000);
        } else if (dgw.exists()) {
            try { dgw.delete(); } catch (Exception ignored) { }
        }
        // 방금 받은 [동글 켜기] 결과나 재부팅 답 안내(dongleTick·rebootTick): 상태를 새로 읽어 다시 그린 화면에 한 번 다시 올린다(PR #100 리뷰 6·9)
        if (reShow != null) {
            if (rbEl == 0 && dgEl == 0) showMsg(reShow, reShowBg, reShowFg);
            reShow = null;
        }
        setContentView(root);
    }

    @Override
    public void onClick(View v) {
        if (v == rebootBtn) {
            // 받을 감시자가 끝났으면(화면을 연 뒤 10분) 요청을 보내지 않고 바로 알린다(RB_WAIT 기다린 뒤 RESET 안내 대신)
            if (Report.watchGone(read(WATCHF), boot, android.os.SystemClock.elapsedRealtime() / 1000)) {
                showMsg(Report.RB_NOWATCH, Ui.WARN, Color.BLACK);
                return;
            }
            // 확인 창. 익명 클래스 대신 이 화면이 직접 받는다(JDK 21 + d8 8.2가 익명 클래스에서 멈춤)
            dialogFor = 1;
            new android.app.AlertDialog.Builder(this)
                .setTitle("지금 재부팅")
                .setMessage(Report.RB_CONFIRM)
                .setPositiveButton("재부팅", this)
                .setNegativeButton("취소", this)
                .show();
            return;
        }
        if (v == dongleBtn) {
            if (Report.watchGone(read(WATCHF), boot, android.os.SystemClock.elapsedRealtime() / 1000)) {
                showMsg(Report.RB_NOWATCH, Ui.WARN, Color.BLACK);
                return;
            }
            dialogFor = 2;
            new android.app.AlertDialog.Builder(this)
                .setTitle("동글 켜기")
                .setMessage(Report.DG_CONFIRM)
                .setPositiveButton("켜기", this)
                .setNegativeButton("취소", this)
                .show();
            return;
        }
        finish();
    }

    /** 확인 창의 버튼: 띄운 창에 따라 재부팅이나 동글 켜기를 요청한다(취소는 닫기만) */
    @Override
    public void onClick(android.content.DialogInterface d, int which) {
        d.dismiss();
        if (which != android.content.DialogInterface.BUTTON_POSITIVE) return;
        if (dialogFor == 2) requestDongle();
        else requestReboot();
    }

    /**
     * [동글 켜기](#60): 앱은 dongle.req만 쓴다. root 감시자(status.sh --watch)가 받아 svc/dongle.sh --now를 돌리고(동글 드라이버를
     * 순정 자리에 걸고, 먼저 올라 있는 순정 bcmdhd를 내리고, 무선 연결용 Wi-Fi를 다시 켬) 결과를 DGRES에 남긴다
     */
    void requestDongle() {
        long el = android.os.SystemClock.elapsedRealtime();
        String line = Report.rbLine(el, boot);
        // 기다림 기록을 먼저 쓴다(root가 요청을 받아 지운 뒤에도 화면이 기다림을 이어 가게, PR #100 리뷰 1)
        if (!writeText(new File(getFilesDir(), DG_WAIT_NAME), line) || !writeText(new File(getFilesDir(), DG_NAME), line)) {
            try { new File(getFilesDir(), DG_WAIT_NAME).delete(); } catch (Exception ignored) { }
            showMsg(Report.DG_WRITE_FAILED, Ui.WARN, Color.BLACK);
            return;
        }
        dgEl = el; dgId = el;
        if (dongleBtn != null) dongleBtn.setEnabled(false);
        showMsg(Report.DG_SENT, Ui.MSG_BG, Color.WHITE);
        handler.removeCallbacks(this);
        handler.postDelayed(this, 1000);
    }

    /** [동글 켜기] 결과 기다림. 더 기다려야 하면 true. 결과가 오거나 DG_WAIT초가 지나면 안내를 보이고 상태를 다시 읽는다 */
    boolean dongleTick() {
        long el = android.os.SystemClock.elapsedRealtime();
        if (el < dgEl) dgEl = el;
        Report res = Report.parse(read(DGRES));
        String ans = Report.dgAnswer(res, boot, dgId);
        if (ans == null && (el - dgEl) / 1000 < Report.DG_WAIT) return true;
        dgEl = 0;
        try { new File(getFilesDir(), DG_NAME).delete(); } catch (Exception ignored) { }
        try { new File(getFilesDir(), DG_WAIT_NAME).delete(); } catch (Exception ignored) { }
        if (dongleBtn != null) dongleBtn.setEnabled(true);
        // 재부팅 기다림 중이면 그 안내를 덮지 않는다
        if (rbEl > 0) return false;
        if (ans == null) { reShow = Report.DG_TIMEOUT; reShowBg = Ui.WARN; reShowFg = Color.BLACK; }
        else if (Report.dgGood(res)) { reShow = ans; reShowBg = Ui.MSG_BG; reShowFg = Color.WHITE; }
        else { reShow = ans; reShowBg = Ui.WARN; reShowFg = Color.BLACK; }
        showMsg(reShow, reShowBg, reShowFg);
        if (ans != null) {
            // 판정 띠와 표(동글·Wi-Fi 칸)를 결과에 맞춘다. root(svc/dongle.sh --now)가 결과를 쓰기 바로 앞에 상태 파일을 새로 썼으므로
            // 그것을 다시 읽어 그리고, showStatus가 이 안내를 다시 올린다(#111. 예전에는 hmgapid로 새로 쓰게 하고 바뀌기를 기다렸는데,
            // 띠가 "꺼져 있습니다"로 남은 일이 있었음, PR #100 리뷰 6)
            showStatus();
        } else {
            // 답이 없으면(시간 초과) root가 상태를 새로 쓰지 않았으므로 hmgapid로 새로 쓰게 하고 바뀌면 다시 그린다
            kickEl = 0;
            kickStatus();
        }
        return false;
    }

    /**
     * 앱은 reboot.req만 쓴다. root 감시자(status.sh --watch)가 막는 조건(설치 중·설치 마무리·시스템 영역을 바꾸는 작업·
     * HMG-API 부팅 보호·다른 부팅·40초 지남)을 다시 보고 재부팅한다. RB_WAIT초 뒤에도 이 화면이 살아 있으면 재부팅하지 못한 것으로 알린다.
     */
    void requestReboot() {
        long el = android.os.SystemClock.elapsedRealtime();
        if (!writeText(new File(getFilesDir(), RB_NAME), Report.rbLine(el, boot))) {
            showMsg(Report.RB_WRITE_FAILED, Ui.BAD, Color.WHITE);
            return;
        }
        rbEl = el; rbId = el;
        if (rebootBtn != null) rebootBtn.setEnabled(false);
        showMsg(Report.RB_SENT, Ui.MSG_BG, Color.WHITE);
        handler.removeCallbacks(this);
        handler.postDelayed(this, 1000);
    }

    /** 재부팅 기다림. 더 기다려야 하면 true */
    boolean rebootTick() {
        long el = android.os.SystemClock.elapsedRealtime();
        if (el < rbEl) rbEl = el;
        // root가 받지 않았다고 답했으면(설치 마무리 중 등) RB_WAIT초를 기다리지 않고 그 이유에 맞게 알린다
        Report res = Report.parse(read(RBRES));
        File sf = new File(getFilesDir(), RB_STUCK_NAME);
        long nowS = el / 1000;
        // 화면 안 값이 있으면(파일 쓰기가 실패했던 경우) 그것이 가장 새 값이다
        String st = rbStuckMem != null ? rbStuckMem : read(sf.getPath());
        long since = Report.stuckSince(st, boot, nowS);
        String ans = Report.rbAnswer(res, boot, rbId, since, nowS);
        if (ans == null && (el - rbEl) / 1000 < Report.RB_WAIT) return true;
        // 답이 install·sysw 거절이면 처음 거절 시각(없으면 지금)과 이번 거절 시각을 남기고, 다른 답·답 없음이면 지운다.
        // 파일을 쓰지 못하면 화면 안 값으로 대신한다. guard(시간이 지나면 풀림)는 기록을 만들지도 지우지도 않는다
        if (ans != null && Report.rbStuckCode(res)) {
            String line = Report.stuckLine(boot, since < 0 ? nowS : since, nowS);
            if (writeText(sf, line)) rbStuckMem = null;
            else {
                // 쓰지 못했으면 옛 파일이 다음에 앞서지 않게 지우고 화면 안 값으로 이어 간다
                rbStuckMem = line;
                try { sf.delete(); } catch (Exception ignored) { }
            }
        } else if (!"guard".equals(res.get("code").trim()) || ans == null) {
            rbStuckMem = null;
            try { sf.delete(); } catch (Exception ignored) { }
        }
        rbEl = 0;
        try { new File(getFilesDir(), RB_NAME).delete(); } catch (Exception ignored) { }
        // 아무도 답하지 않았으면(감시자 없음) RESET 안내
        if (ans == null) ans = Report.RB_FAILED;
        reShow = ans;
        if (Report.RB_FAILED.equals(ans)) { reShowBg = Ui.BAD; reShowFg = Color.WHITE; }
        else { reShowBg = Ui.WARN; reShowFg = Color.BLACK; }
        // 늦게 오는 다시 그리기(동글 결과 뒤 상태 새로 쓰기)가 이 답을 지우고 동글 안내를 다시 올리지 않게, 다시 올릴 안내를 이 답으로 바꾼다(리뷰 9)
        showMsg(reShow, reShowBg, reShowFg);
        if (rebootBtn != null) rebootBtn.setEnabled(true);
        return false;
    }

    /** 앱 폴더의 작은 파일 쓰기(임시 파일 → 이름 바꾸기: root 쪽이 반쯤 쓴 파일을 읽지 않게). 실패하면 아무것도 남기지 않고 false */
    static boolean writeText(File f, String text) {
        File tmp = new File(f.getPath() + ".tmp");
        java.io.FileOutputStream out = null;
        boolean ok = false;
        try {
            out = new java.io.FileOutputStream(tmp);
            out.write(text.getBytes("UTF-8"));
            out.close();
            out = null;
            ok = tmp.renameTo(f);
        } catch (Exception e) {
            ok = false;
        } finally {
            if (out != null) try { out.close(); } catch (Exception ignored) { }
        }
        if (!ok) tmp.delete();
        return ok;
    }

    /** 버튼 위 안내 한 줄(바탕색·글자색). 보냄은 중립 상자(Ui.MSG_BG), 거절·실패는 노랑·빨강 띠 */
    void showMsg(String msg, int bg, int fg) {
        if (msgText == null || ui == null) return;
        msgText.setText(msg);
        msgText.setBackground(ui.box(bg));
        msgText.setTextColor(fg);
        msgText.setVisibility(View.VISIBLE);
    }

    static String read(String path) {
        InputStream in = null;
        try {
            in = new FileInputStream(path);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[4096];
            for (int n; (n = in.read(buf)) > 0; ) out.write(buf, 0, n);
            return out.toString("UTF-8");
        } catch (Exception e) {
            return null;
        } finally {
            if (in != null) try { in.close(); } catch (Exception ignored) { }
        }
    }

}
