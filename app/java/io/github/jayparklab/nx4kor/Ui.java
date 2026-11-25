package io.github.jayparklab.nx4kor;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/**
 * 관리 앱의 모양: 투싼 NX4 순정 내비(표준형 5세대 와이드)의 타입1(어두운 화면)에 맞춘다(#28).
 * 색·글자 크기·여백은 이 파일 한 곳에 둔다. 문구와 판정은 여기 없다(Report).
 *
 * 값은 현대 국내형 Gen5W 웹 매뉴얼의 화면 그림(945x354)을 1920x720으로 환산해 잰 근사값이다(2026-11-20, #28 댓글의
 * 그림 10장: 홈, 설정, 디스플레이·내비게이션·일반·차량 설정, 기기 연결, 장소 검색, 블루링크 첫 화면, 후석 취침 모드).
 * #28 본문의 "색(근사)" 표는 그 전에 다른 그림으로 잰 첫 조사라 몇 값이 다르다. 이 파일의 값이 다시 잰 것이다.
 * 차에서 캡처하면 여기만 고친다.
 *
 * 크기는 1920x720 화면의 px로 적고 실제 화면 폭에 맞춰 늘이거나 줄인다(px). 차의 화면 밀도와 관계없이
 * 순정 화면과 같은 비율이 되게 하려는 것이다.
 */
final class Ui {
    // ---- 색 ----
    /** 바탕: 위는 검정, 아래로 갈수록 아주 약한 남색 */
    static final int BG_TOP = 0xFF000000, BG_BOTTOM = 0xFF000A18;
    /** 주 글자 */
    static final int TEXT = 0xFFFFFFFF;
    /** 설명 글자(목록 둘째 줄, 안내 본문) */
    static final int TEXT_SUB = 0xFFB6B5B6;
    /** 작은 회색 글자(구역 이름, 아래 정보 줄) */
    static final int TEXT_DIM = 0xFFA7A7A7;
    /** 누를 수 없는 버튼 글자 */
    static final int TEXT_OFF = 0xFF646464;
    /** 강조 글자(순정의 선택한 분류, 연결된 기기, 주 버튼) */
    static final int ACCENT = 0xFF32E2FF;
    /** 켜짐 표시(순정 후석 취침 모드의 세로 캡슐) */
    static final int ACCENT_MARK = 0xFF2FB7E7;
    /** 제목 줄 아래 선 */
    static final int LINE_HEAD = 0xFF111111;
    /** 오른쪽 칸(분할 화면) 앞 세로선 */
    static final int LINE_PANEL = 0xFF121316;
    /**
     * 목록 줄 사이 선의 가운데 색(양끝은 바탕으로 흐려짐). 그림의 목록 구분선은 거의 보이지 않는 회색(#0D0E12~#101010)이라
     * 조금 밝게 잡았다. #28 본문의 청록 선(#146C8C 쯤)은 왼쪽 분류 목록에서 고른 줄 아래 선(#062D41)으로 보인다
     */
    static final int LINE_ROW = 0xFF1C2229;
    /** 보통 버튼 블록(위→아래), 누를 때 */
    static final int BTN_TOP = 0xFF0B151B, BTN_BOTTOM = 0xFF060D13, BTN_PRESSED = 0xFF16242F;
    /** 주 버튼 블록(위→아래), 누를 때 */
    static final int PRI_TOP = 0xFF143041, PRI_BOTTOM = 0xFF0C1E28, PRI_PRESSED = 0xFF1D4760;
    /** 진행 막대: 바닥, 채움(왼쪽→오른쪽) */
    static final int BAR_TRACK = 0xFF15202B, BAR_FROM = 0xFF1A7FB0, BAR_TO = 0xFF32E2FF;
    /** 중립 안내 상자(재부팅 요청을 보냄) */
    static final int MSG_BG = 0xFF0C1A26;
    /**
     * 문제일 때만 쓰는 색 띠(#28 "정할 것" 2, 2026-11-20 결정). 정상은 순정처럼 어두운 바탕에 시안 글자와 작은 표시만 쓰고,
     * 확인 필요(노랑)·문제(빨강)와 알림(연노랑)은 운전 중 한눈에 보이게 색을 채운 띠로 둔다.
     */
    static final int WARN = 0xFFF9A825, BAD = 0xFFC62828, NOTICE = 0xFFFFE082;

    // ---- 크기(1920x720 px) ----
    /** 제목 줄 높이, 제목 글자, 왼쪽 위 [닫기](뒤로) 누르는 칸 폭 */
    static final int HEAD_H = 96, HEAD_TEXT = 34, BACK_W = 120;
    /** 왼쪽 목록 칸과 오른쪽 칸의 폭(1920 = 1280 + 640) */
    static final int LIST_W = 1280, PANEL_W = 640;
    /** 목록 왼쪽·오른쪽 여백 */
    static final int PAD_X = 48;
    /** 두 줄 목록(요약): 제목, 설명, 위아래 여백 */
    static final int ROW_TITLE = 32, ROW_SUB = 26, ROW_PAD_Y = 20;
    /** 한 줄 목록("자세히" 표): 글자, 위아래 여백 */
    static final int DETAIL_TEXT = 26, DETAIL_PAD_Y = 14;
    /** 구역 이름("자세히") */
    static final int SECTION_TEXT = 24;
    /** 오른쪽 칸: 여백, 판정 글자, 안내 글자, 작은 글자, 줄 사이 */
    static final int PANEL_PAD = 40, VERDICT_TEXT = 30, INFO_TEXT = 26, SMALL_TEXT = 24, GAP = 16;
    /** 켜짐 표시 폭·높이 */
    static final int MARK_W = 8, MARK_H = 40;
    /** 버튼 블록 높이, 글자 */
    static final int BTN_H = 96, BTN_TEXT = 32;
    /** 아래 정보 줄 높이, 글자 */
    static final int FOOT_H = 56, FOOT_TEXT = 22;
    /** 띠·상자 모서리 */
    static final int RADIUS = 4;
    /** 스크롤 끝을 흐리는 길이 */
    static final int FADE = 48;
    /** 설치 진행 화면: 좌우 여백, 제목, 단계, 막대 높이, %, 경과 시간 */
    static final int PROG_PAD_X = 200, PROG_TITLE = 40, PROG_STAGE = 30, BAR_H = 12, PROG_PCT = 30, PROG_TIME = 26;

    final Context c;
    /** 1920 폭 기준 px → 이 화면의 px */
    final float k;

    Ui(Context c) {
        this.c = c;
        int w = c.getResources().getDisplayMetrics().widthPixels;
        k = w > 0 ? w / 1920f : 1f;
    }

    int px(int v) {
        return (int) (v * k + 0.5f);
    }

    /** 1px 선(줄여도 1px 아래로는 내리지 않음) */
    int thin() {
        return Math.max(1, px(1));
    }

    /** 폭·높이(-1·-2 또는 이미 바꾼 px)와 위 여백(1920 px) */
    LinearLayout.LayoutParams lp(int w, int h, int top) {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(w, h);
        p.topMargin = px(top);
        return p;
    }

    TextView text(String s, int size, int color) {
        TextView t = new TextView(c);
        t.setText(s);
        t.setTextSize(TypedValue.COMPLEX_UNIT_PX, size * k);
        t.setTextColor(color);
        return t;
    }

    LinearLayout vertical() {
        LinearLayout l = new LinearLayout(c);
        l.setOrientation(LinearLayout.VERTICAL);
        return l;
    }

    /** 화면 바탕(세로 그러데이션)을 깐 맨 바깥 틀 */
    LinearLayout screen() {
        LinearLayout root = vertical();
        root.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, new int[] { BG_TOP, BG_BOTTOM }));
        return root;
    }

    /**
     * 순정처럼 끝에서 당겨도 파란 빛이 번지지 않는 스크롤. 위나 아래에 더 있으면 그쪽 끝을 바탕으로 흐려서 보인다
     * (넘친 줄이 칼로 자른 듯 잘려 다음 띠와 붙어 보이지 않게, PR #34 리뷰 1)
     */
    ScrollView scroll(View content) {
        ScrollView sv = new ScrollView(c);
        sv.setOverScrollMode(View.OVER_SCROLL_NEVER);
        sv.setVerticalFadingEdgeEnabled(true);
        sv.setFadingEdgeLength(px(FADE));
        sv.setFillViewport(true);
        sv.addView(content);
        return sv;
    }

    Drawable box(int color) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(px(RADIUS));
        return d;
    }

    /** 색 하나로 채운 가로선(폭은 붙이는 쪽이 정함) */
    View line(int color) {
        View v = new View(c);
        v.setBackgroundColor(color);
        return v;
    }

    /** 목록 줄 사이 선: 가운데가 밝고 양끝은 바탕으로 흐려진다 */
    View fadeLine() {
        View v = new View(c);
        v.setBackground(new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
            new int[] { LINE_ROW & 0x00FFFFFF, LINE_ROW, LINE_ROW, LINE_ROW & 0x00FFFFFF }));
        return v;
    }

    /** 제목 줄: 가운데 제목, 왼쪽 위 뒤로(닫기) 버튼. back은 그 버튼을 누를 때 받는 쪽 */
    FrameLayout header(String title, View.OnClickListener back) {
        FrameLayout f = new FrameLayout(c);
        TextView t = text(title, HEAD_TEXT, TEXT);
        t.setGravity(Gravity.CENTER);
        t.setSingleLine(true);
        f.addView(t, new FrameLayout.LayoutParams(-1, -1));
        Back b = new Back(c, k);
        b.setContentDescription("닫기");
        b.setBackground(pressable(new ColorDrawable(0), new ColorDrawable(BTN_PRESSED)));
        b.setOnClickListener(back);
        f.addView(b, new FrameLayout.LayoutParams(px(BACK_W), -1, Gravity.LEFT));
        return f;
    }

    static StateListDrawable pressable(Drawable normal, Drawable pressed) {
        StateListDrawable s = new StateListDrawable();
        s.addState(new int[] { android.R.attr.state_pressed }, pressed);
        s.addState(new int[] {}, normal);
        return s;
    }

    /**
     * 순정 버튼 블록(블루링크 첫 화면 아래 버튼과 같은 모양). primary면 남청 블록에 시안 글자(주 버튼), 아니면 어두운 블록에 흰 글자.
     * 누를 수 없을 때(setEnabled(false)) 글자가 회색이 된다.
     */
    TextView button(String label, boolean primary, View.OnClickListener l) {
        TextView b = text(label, BTN_TEXT, TEXT);
        b.setGravity(Gravity.CENTER);
        b.setSingleLine(true);
        b.setTextColor(new ColorStateList(new int[][] { { -android.R.attr.state_enabled }, {} },
            new int[] { TEXT_OFF, primary ? ACCENT : TEXT }));
        int top = primary ? PRI_TOP : BTN_TOP, bottom = primary ? PRI_BOTTOM : BTN_BOTTOM;
        int pressed = primary ? PRI_PRESSED : BTN_PRESSED;
        b.setBackground(pressable(
            new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, new int[] { top, bottom }),
            new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, new int[] { pressed, bottom })));
        b.setClickable(true);
        b.setFocusable(true);
        b.setOnClickListener(l);
        return b;
    }

    /** 색을 채운 띠(확인 필요·문제·알림) */
    TextView band(String s, int size, int bg, int fg) {
        TextView t = text(s, size, fg);
        t.setBackground(box(bg));
        t.setPadding(px(20), px(12), px(20), px(12));
        return t;
    }

    /** 켜짐 표시(시안 세로 캡슐)를 앞에 둔 글자: 정상인 판정·안내 */
    LinearLayout marked(String s, int size, int color) {
        LinearLayout l = new LinearLayout(c);
        l.setOrientation(LinearLayout.HORIZONTAL);
        View mark = new View(c);
        GradientDrawable d = new GradientDrawable();
        d.setColor(ACCENT_MARK);
        d.setCornerRadius(px(MARK_W) / 2f);
        mark.setBackground(d);
        LinearLayout.LayoutParams mp = new LinearLayout.LayoutParams(px(MARK_W), px(MARK_H));
        mp.rightMargin = px(18);
        mp.topMargin = px(2);
        l.addView(mark, mp);
        l.addView(text(s, size, color), new LinearLayout.LayoutParams(0, -2, 1f));
        return l;
    }

    /** 판정 한 줄: 0 정상(표시와 시안 글자), 1 확인 필요(노란 띠), 2 문제(빨간 띠) */
    View verdict(String s, int level) {
        if (level == 0) return marked(s, VERDICT_TEXT, ACCENT);
        return level == 1 ? band(s, VERDICT_TEXT, WARN, 0xFF000000) : band(s, VERDICT_TEXT, BAD, TEXT);
    }

    /** 두 줄 목록 줄(본보기: 순정 설정 상세의 "시간 표기 방식 / 12시간"). sub가 비면 한 줄 */
    LinearLayout row2(String title, String sub) {
        LinearLayout r = vertical();
        r.setPadding(px(PAD_X), px(ROW_PAD_Y), px(PAD_X), px(ROW_PAD_Y));
        r.addView(text(title, ROW_TITLE, TEXT));
        if (sub != null && !sub.isEmpty()) r.addView(text(sub, ROW_SUB, TEXT_SUB), lp(-1, -2, 4));
        return r;
    }

    /** 한 줄 목록 줄: 왼쪽 이름(흰색), 오른쪽 값(회색) */
    LinearLayout row1(String name, String value) {
        LinearLayout r = new LinearLayout(c);
        r.setOrientation(LinearLayout.HORIZONTAL);
        r.setPadding(px(PAD_X), px(DETAIL_PAD_Y), px(PAD_X), px(DETAIL_PAD_Y));
        r.addView(text(name, DETAIL_TEXT, TEXT), new LinearLayout.LayoutParams(0, -2, 1.1f));
        r.addView(text(value, DETAIL_TEXT, TEXT_SUB), new LinearLayout.LayoutParams(0, -2, 1f));
        return r;
    }

    /** 목록에 줄 하나와 그 아래 흐려지는 선을 붙인다 */
    void addRow(LinearLayout list, View row) {
        list.addView(row);
        list.addView(fadeLine(), new LinearLayout.LayoutParams(-1, thin()));
    }

    /** 순정 뒤로 버튼의 "<" 모양. 익명 클래스 대신 이름 있는 클래스로 둔다(StatusActivity의 [닫기] 주석) */
    static final class Back extends View {
        final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        final Path path = new Path();
        final float k;

        Back(Context c, float k) {
            super(c);
            this.k = k;
            p.setColor(TEXT);
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(4 * k);
            p.setStrokeCap(Paint.Cap.ROUND);
            p.setStrokeJoin(Paint.Join.ROUND);
            setClickable(true);
            setFocusable(true);
        }

        @Override
        protected void onDraw(Canvas cv) {
            float cx = PAD_X * k + 6 * k, cy = getHeight() / 2f, half = 17 * k, w = 9 * k;
            path.reset();
            path.moveTo(cx + w, cy - half);
            path.lineTo(cx - w, cy);
            path.lineTo(cx + w, cy + half);
            cv.drawPath(path, p);
        }
    }

    /** 진행 막대: 어두운 바닥 위에 시안 그러데이션으로 채운다(Holo 막대 대신) */
    static final class Bar extends View {
        final Paint track = new Paint(Paint.ANTI_ALIAS_FLAG), fill = new Paint(Paint.ANTI_ALIAS_FLAG);
        final RectF r = new RectF();
        int pct;

        Bar(Context c) {
            super(c);
            track.setColor(BAR_TRACK);
        }

        void setProgress(int p) {
            pct = p < 0 ? 0 : p > 100 ? 100 : p;
            invalidate();
        }

        @Override
        protected void onSizeChanged(int w, int h, int ow, int oh) {
            super.onSizeChanged(w, h, ow, oh);
            fill.setShader(new LinearGradient(0, 0, w, 0, BAR_FROM, BAR_TO, Shader.TileMode.CLAMP));
        }

        @Override
        protected void onDraw(Canvas cv) {
            float w = getWidth(), h = getHeight(), rad = h / 2f;
            r.set(0, 0, w, h);
            cv.drawRoundRect(r, rad, rad, track);
            if (pct <= 0) return;
            r.set(0, 0, Math.max(h, w * pct / 100f), h);
            cv.drawRoundRect(r, rad, rad, fill);
        }
    }
}
