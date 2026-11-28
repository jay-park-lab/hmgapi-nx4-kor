package io.github.jayparklab.nx4kor;

/**
 * PC에서 관리 앱의 판단(Report)을 테스트한다. tests/mod-test.sh가 javac로 컴파일해 돌린다.
 * 실패하면 "FAIL ..."을 찍고 종료 코드 1.
 */
public class ReportTest {
    static int fails = 0;

    static void check(String name, boolean ok) {
        System.out.println((ok ? "ok   " : "FAIL ") + name);
        if (!ok) fails++;
    }

    /** bin/status.sh status_kv가 쓰는 키(준비됨 상태, 2.1.0: HMG-API + 공식 무선 모드 + 이 모드) */
    static final String GOOD =
        "product=NX4.KOR.0000.V039.001.260902\n" +
        "targetdir=/system/onebin/nx4_kr\n" +
        "pkgver=2.0.0\ntested=yes\nhmgapi=version 1.1.0-rc.10 build daa0837 2026-11-26\n" +
        "wm=yes\nwm_ver=2.2.0-rc.9\nwm_on=yes\nwm_hooks=on\nbridge=on\nhooks=on\nhookmap=mapped\n" +
        "kor_hooks=on\nkor_hooks_why=\nkor_tbt=on\nkor_tbt_log=off\n" +
        "feat_carplay=yes\nfeat_aa=yes\nfeat_hotspot=yes\nfeat_wifi=no\nchip=yes\nwlan0=yes\n" +
        "proj=yes\nap_boot=yes\nap_fail=no\nap=yes\nap_mode=projection\nother_ap=no\nwpa=no\n" +
        "cp_conn=0\nstate=done\nmade=2026-11-23 06:00\n" +
        "verdict=ready\nverdict_lv=0\nverdict_msg=무선 카플레이·안드로이드 오토 준비됨.\nverdict_end=no\n" +
        "s1=설치: 끝남\ns2=무선 Wi-Fi: 켜짐(HMG-API)\ns3=폰 연결: 지금 연결된 폰 없음\n";

    static String row(Report r, String title) {
        for (String[] x : r.rows()) if (x[0].equals(title)) return x[1];
        return null;
    }

    /** 이 화면에 보이면 안 되는 낱말(이 파일도 grep 검사를 받으므로 이어 붙여 만든다) */
    static final String[] BANNED = { "NEM" + "ESIS", "Lau" + "nch", "Korea " + "Projection", "Q" + "R", "제" + "보" };

    static String banned(String s) {
        if (s == null) return null;
        for (String b : BANNED) if (s.contains(b)) return b;
        return null;
    }

    static boolean hasMember(String name) {
        for (java.lang.reflect.Method m : Report.class.getDeclaredMethods()) if (m.getName().equals(name)) return true;
        for (java.lang.reflect.Field f : Report.class.getDeclaredFields()) if (f.getName().equals(name)) return true;
        return false;
    }

    public static void main(String[] a) throws Exception {
        Report r = Report.parse(GOOD);
        check("상태 파일 해석", "NX4.KOR.0000.V039.001.260902".equals(r.get("product")) && r.yes("ap"));

        // --- 판정: status.sh(st_verdict)가 정한 문구·수준을 그대로 ---
        check("판정 문구·수준은 상태 파일 값 그대로(준비됨 → 수준 0)", r.verdict().equals("무선 카플레이·안드로이드 오토 준비됨.") && r.level() == 0);
        String V3 = GOOD.replace("verdict=ready", "verdict=nocar").replace("verdict_lv=0", "verdict_lv=2")
            .replace("verdict_msg=무선 카플레이·안드로이드 오토 준비됨.", "verdict_msg=지원하지 않는 차입니다(투싼 NX4 한국 내수 260902 전용). 아무것도 바꾸지 않았습니다.")
            .replace("verdict_end=no", "verdict_end=yes").replace("s1=설치: 끝남", "s1=설치: 안 됨(오른쪽 안내를 보세요)")
            .replace("s2=무선 Wi-Fi: 켜짐(HMG-API)", "s2=무선 Wi-Fi: 꺼짐");
        Report v3 = Report.parse(V3);
        check("  nocar → 그 문구, 빨강", v3.verdict().startsWith("지원하지 않는 차입니다") && v3.level() == 2);
        check("  수준 값이 깨졌으면 1(확인 필요), 범위 밖은 0~2로", Report.parse(V3.replace("verdict_lv=2", "verdict_lv=x")).level() == 1
            && Report.parse(V3.replace("verdict_lv=2", "verdict_lv=9")).level() == 2 && Report.parse(V3.replace("verdict_lv=2", "verdict_lv=-3")).level() == 0);
        Report nov = Report.parse(GOOD.replace("verdict_msg=무선 카플레이·안드로이드 오토 준비됨.", "verdict_msg="));
        check("  판정 문구가 비었으면 '상태를 읽는 중' 안내, 노랑(verdict_lv를 믿지 않음)", nov.verdict().equals(Report.NO_VERDICT)
            && Report.NO_VERDICT.equals("상태를 읽는 중입니다. 잠시 뒤 화면을 다시 열어 주세요.") && nov.level() == 1);
        check("파일 없음 → '상태를 읽지 못했습니다', 빨강", Report.parse(null).verdict().startsWith("상태를 읽지 못했습니다") && Report.parse(null).level() == 2);
        // 판정 코드(2.1.0)도 앱은 따로 판정하지 않고 그대로 보인다
        String[][] codes = { { "bootguard", "2" }, { "installing", "1" }, { "nocar", "2" }, { "nohmgapi", "2" }, { "oldhmgapi", "2" },
            { "reboot", "1" }, { "failed", "2" }, { "nowireless", "2" }, { "wirelessoff", "2" }, { "oldwireless", "2" }, { "hooksoff", "1" },
            { "wmhooksoff", "2" }, { "bridgeoff", "2" }, { "nofeat", "2" }, { "noproj", "2" }, { "connected", "0" }, { "otherwifi", "2" },
            { "aphotspot", "1" }, { "ready", "0" }, { "wificlient", "1" }, { "nowifipart", "1" }, { "apoff", "1" }, { "apfail", "1" }, { "apwait", "1" } };
        boolean allSame = true;
        for (String[] c : codes) {
            Report x = Report.parse(GOOD.replace("verdict=ready", "verdict=" + c[0]).replace("verdict_lv=0", "verdict_lv=" + c[1])
                .replace("verdict_msg=무선 카플레이·안드로이드 오토 준비됨.", "verdict_msg=문구 " + c[0]));
            if (!x.verdict().equals("문구 " + c[0]) || x.level() != Integer.parseInt(c[1]) || !c[0].equals(row(x, "판정 코드"))) allSame = false;
        }
        check("  판정 코드(bootguard·installing·nocar·…·nowifipart·apwait)마다 문구·수준·표의 판정 코드가 상태 파일 그대로", allSame);
        check("'안 됨'으로 끝나면(verdict_end=yes) 지우는 법 한 줄, 아니면 없음", Report.UNINSTALL_HINT.equals(v3.endHint())
            && Report.UNINSTALL_HINT.equals("지우려면 USB의 NX4 폴더에 UNINSTALL 파일을 넣고 Engineering Mode의 Update OTA를 다시 실행한 뒤 재부팅하세요. 유선 카플레이는 그대로입니다.")
            && "".equals(r.endHint()));
        check("요약 3줄(설치·무선 Wi-Fi·폰 연결), 없으면 빈 목록", v3.summary().size() == 3 && v3.summary().get(1).equals("무선 Wi-Fi: 꺼짐")
            && r.summary().get(2).equals("폰 연결: 지금 연결된 폰 없음") && Report.parse("product=x\n").summary().isEmpty());

        // --- 없어진 키(2.0.x 우리 핫스팟·합친 무선 모드, 그 전의 mod·modver 등)는 읽지 않는다 ---
        Report extra = Report.parse(GOOD + "mod=no\nmodver=2.2.0\nmod_pending=yes\nmod_pin=2.4.1\nmod_foreign=yes\nwp=yes\nfirst=먼저 할 일: x\nusb=saved\n"
            + "applied=no\noldmod=yes\nmod_on=no\nmod_hooks=off\nour_ap=no\nour_dhcp=no\nstock_ssid=carplay\nstock_seen=yes\nnowlan=yes\n");
        boolean sameRows = extra.rows().size() == r.rows().size();
        for (int i = 0; sameRows && i < r.rows().size(); i++)
            sameRows = r.rows().get(i)[0].equals(extra.rows().get(i)[0]) && r.rows().get(i)[1].equals(extra.rows().get(i)[1]);
        check("없어진 키가 남아 있어도 판정·색·표가 같음", sameRows && extra.verdict().equals(r.verdict()) && extra.level() == r.level()
            && row(extra, "무선 모드 고정") == null && row(extra, "wireless.projection") == null && row(extra, "예전 무선 모드") == null
            && row(extra, "NX4 KOR 모드") == null && row(extra, "핫스팟 (hostapd)") == null && row(extra, "IP 나눠 주기 (DHCP)") == null);
        check("  없어진 기능의 멤버가 없음(링크·요청·USB·먼저 할 일·다른 판 모드·우리 핫스팟)", !hasMember("issueUrl") && !hasMember("fit") && !hasMember("enc")
            && !hasMember("qrBlocked") && !hasMember("reqLine") && !hasMember("reqParse") && !hasMember("reqBlock") && !hasMember("reqPhase")
            && !hasMember("usbMounted") && !hasMember("rbBusy") && !hasMember("RB_BUSY") && !hasMember("firstTodo") && !hasMember("foreign")
            && !hasMember("MAX_URL") && !hasMember("ISSUES") && !hasMember("hooksOffAdvice") && !hasMember("stockAp") && !hasMember("modCell"));

        // --- 상태표 ---
        check("표는 15줄(#71로 \"한국 카플레이 길안내\" 줄을 더함), 예/아니요로 표시, 'NX4 KOR' 줄은 pkgver", r.rows().size() == 15 && "예".equals(row(r, "지원 차종"))
            && "2.0.0".equals(row(r, "NX4 KOR")) && "예".equals(row(r, "무선 카플레이 기능")) && "예".equals(row(r, "순정 핫스팟 기능 (Wi-Fi 칩 전원)")));
        check("  판정 코드 줄(verdict), 카플레이 연결 수", "ready".equals(row(r, "판정 코드")) && "0개".equals(row(r, "카플레이 연결"))
            && "-".equals(row(Report.parse(GOOD.replace("cp_conn=0\n", "")), "카플레이 연결")));
        check("정상이면 HMG-API 칸은 버전만 (1.1.0-rc.10), 최소 판은 rc.10·공식 모드 2.2.0-rc.9", "1.1.0-rc.10".equals(row(r, "HMG-API"))
            && Report.MIN_HMGAPI.equals("1.1.0-rc.10") && Report.MIN_WIRELESS.equals("2.2.0-rc.9"));
        Report old = Report.parse(GOOD.replace("version 1.1.0-rc.10 build", "version 1.0.2 build"));
        check("  HMG-API 1.0.2 → '지원 안 함, 1.1.0-rc.10 이상 필요'", "1.0.2 (지원 안 함, 1.1.0-rc.10 이상 필요)".equals(row(old, "HMG-API")));
        check("  HMG-API 1.1.0-rc.7(2.0.x가 받던 판) → 지원 안 함(rc 꼬리까지 비교)",
            "1.1.0-rc.7 (지원 안 함, 1.1.0-rc.10 이상 필요)".equals(row(Report.parse(GOOD.replace("version 1.1.0-rc.10 build", "version 1.1.0-rc.7 build")), "HMG-API")));
        check("  HMG-API 1.1.0-rc.8(2.1.0이 받던 판, NEMESIS 1.17에서 지우면 위험 Open-HMG/HMG-API#397) → 지원 안 함",
            "1.1.0-rc.8 (지원 안 함, 1.1.0-rc.10 이상 필요)".equals(row(Report.parse(GOOD.replace("version 1.1.0-rc.10 build", "version 1.1.0-rc.8 build")), "HMG-API")));
        check("  HMG-API 1.1.0-rc.9(FORCE로 설치한 NEMESIS 1.17 차를 올리면 위험, rc.10이 고침) → 지원 안 함(rc.9 < rc.10, 숫자로 비교)",
            "1.1.0-rc.9 (지원 안 함, 1.1.0-rc.10 이상 필요)".equals(row(Report.parse(GOOD.replace("version 1.1.0-rc.10 build", "version 1.1.0-rc.9 build")), "HMG-API")));
        check("  판 비교는 HMG-API Version·셸 ver_lt와 같음: rc.4 < rc.8 < rc.10 < 정식, beta < rc, 꼬리 없는 최소 판",
            Report.older("1.1.0-rc.4", "1.1.0-rc.8") == 1 && Report.older("1.1.0-rc.8", "1.1.0-rc.8") == 0 && Report.older("1.1.0-rc.10", "1.1.0-rc.8") == 0
            && Report.older("1.1.0", "1.1.0-rc.8") == 0 && Report.older("1.1.0-rc.8", "1.1.0") == 1 && Report.older("1.1.0-beta.9", "1.1.0-rc.1") == 1
            && Report.older("1.2.0-beta.1", "1.1.0-rc.8") == 0 && Report.older("1.1.1", "1.1.0-rc.8") == 0 && Report.older("1.0.9", "1.1.0-rc.8") == 1
            && Report.older("1.0.10", "1.0.2") == 0 && Report.older("1.0.1", "1.0.10") == 1 && Report.older("1.1", "1.1.0") == 0
            && Report.older("2.2.0-rc.5", "2.2.0-rc.9") == 1 && Report.older("2.2.0", "2.2.0-rc.9") == 0 && Report.older("1.1.0-rc", "1.1.0-rc.1") == 1
            && Report.older("1.1.0-rc.8+abc", "1.1.0-rc.8") == 0);
        check("  1.1.0-rc.11·1.1.0·1.2.0은 지원(버전만 보임)", "1.1.0-rc.11".equals(row(Report.parse(GOOD.replace("1.1.0-rc.10 build", "1.1.0-rc.11 build")), "HMG-API"))
            && "1.1.0".equals(row(Report.parse(GOOD.replace("1.1.0-rc.10 build", "1.1.0 build")), "HMG-API"))
            && "1.2.0".equals(row(Report.parse(GOOD.replace("1.1.0-rc.10 build", "1.2.0 build")), "HMG-API")));
        Report none = Report.parse(GOOD.replace("hmgapi=version 1.1.0-rc.10 build daa0837 2026-11-26\n", ""));
        check("  HMG-API 없음 → '없음 (1.1.0-rc.10 이상 필요)'", "없음 (1.1.0-rc.10 이상 필요)".equals(row(none, "HMG-API")));
        Report odd = Report.parse(GOOD.replace("version 1.1.0-rc.10 build", "version dev build"));
        check("  숫자가 아닌 버전·모르는 꼬리 → '버전 확인 안 됨'(멈추지 않음)", row(odd, "HMG-API").contains("버전 확인 안 됨") && Report.older("dev", "1.1.0") == 2
            && Report.older("1.1.0-dev", "1.1.0-rc.8") == 2 && Report.older("", "1.1.0") == 2 && Report.older(null, "1.1.0") == 2);
        check("공식 무선 모드 칸: 정상 '판, 켜짐', 없음, 꺼짐, 낮은 판, 훅이 안 켜짐, Wireless CarPlay 설정 꺼짐",
            "2.2.0-rc.9, 켜짐".equals(row(r, "공식 무선 모드"))
            && "없음 (설치 필요)".equals(row(Report.parse(GOOD.replace("wm=yes", "wm=no")), "공식 무선 모드"))
            && "2.2.0-rc.9, 꺼짐 (켜야 함)".equals(row(Report.parse(GOOD.replace("wm_on=yes", "wm_on=no")), "공식 무선 모드"))
            && "2.2.0-rc.5 (지원 안 함, 2.2.0-rc.9 이상 필요), 켜짐".equals(row(Report.parse(GOOD.replace("wm_ver=2.2.0-rc.9", "wm_ver=2.2.0-rc.5")), "공식 무선 모드"))
            && "2.2.0-rc.9, 훅이 안 켜짐".equals(row(Report.parse(GOOD.replace("wm_hooks=on", "wm_hooks=off")), "공식 무선 모드"))
            && row(Report.parse(GOOD.replace("bridge=on", "bridge=off")), "공식 무선 모드").contains("Wireless CarPlay 설정 꺼짐")
            && "-".equals(row(Report.parse(GOOD.replace("wm=yes\n", "")), "공식 무선 모드")));
        // #71: 이 모드의 한국 카플레이 길안내(훅·설정). 판정은 바꾸지 않고 표에만 보인다
        Report koff = Report.parse(GOOD.replace("kor_hooks=on", "kor_hooks=off").replace("kor_hooks_why=", "kor_hooks_why=hook point framework.navigation_cluster.update_lane_info isn't mapped on this car (none): its hooks are off here, its other parts still apply"));
        check("한국 카플레이 길안내 칸(#71): 켜짐, 진단 기록 켬, 설정으로 꺼 둠(훅이 켜졌어도), 훅이 안 켜짐(rc.10의 이유 그대로), HMG-API 훅 꺼짐이면 안 돎, 기록 없음 '-', 판정은 그대로",
            "켜짐".equals(row(r, "한국 카플레이 길안내"))
            && "켜짐 (진단 기록 켬)".equals(row(Report.parse(GOOD.replace("kor_tbt_log=off", "kor_tbt_log=on")), "한국 카플레이 길안내"))
            && "꺼 둠 (설정, 공식 모드 길안내로 동작)".equals(row(Report.parse(GOOD.replace("kor_tbt=on", "kor_tbt=off")), "한국 카플레이 길안내"))
            && "훅이 안 켜짐 (공식 모드 길안내로 동작: hook point framework.navigation_cluster.update_lane_info isn't mapped on this car (none): its hooks are off here, its other parts still apply)".equals(row(koff, "한국 카플레이 길안내"))
            && "안 돎 (HMG-API 훅 꺼짐)".equals(row(Report.parse(GOOD.replace("\nhooks=on", "\nhooks=off")), "한국 카플레이 길안내"))
            && "훅이 안 켜짐 (공식 모드 길안내로 동작)".equals(row(Report.parse(GOOD.replace("kor_hooks=on", "kor_hooks=off")), "한국 카플레이 길안내"))
            && "-".equals(row(Report.parse(GOOD.replace("kor_hooks=on\n", "").replace("kor_tbt=on\n", "")), "한국 카플레이 길안내"))
            && "ready".equals(koff.get("verdict")));
        Report hoff = Report.parse(GOOD.replace("hooks=on", "hooks=off").replace("hookmap=mapped", "hookmap=mismatch"));
        check("훅 칸: 꺼짐이면 map 상태와 '마지막 부팅 기록', 기록 없음 '-'", row(hoff, "HMG-API 훅").startsWith("꺼짐 (mismatch")
            && "-".equals(row(Report.parse(GOOD.replace("hooks=on\n", "hooks=\n")), "HMG-API 훅")) && "켜짐".equals(row(r, "HMG-API 훅")));
        check("무선 연결용 Wi-Fi 칸: 켜짐, 일반 핫스팟, 다른 SSID·확인 못 함(영문 코드 없이), 요청 없음, 켰다가 꺼짐, 못 켬(다시 시도), 꺼짐",
            "켜짐".equals(row(r, "무선 연결용 Wi-Fi (HMG-API)"))
            && "켜짐 (일반 핫스팟)".equals(row(Report.parse(GOOD.replace("ap_mode=projection", "ap_mode=hotspot")), "무선 연결용 Wi-Fi (HMG-API)"))
            && "켜짐 (SSID 확인 못 함)".equals(row(Report.parse(GOOD.replace("ap_mode=projection", "ap_mode=unknown")), "무선 연결용 Wi-Fi (HMG-API)"))
            && "켜짐 (다른 SSID)".equals(row(Report.parse(GOOD.replace("ap_mode=projection", "ap_mode=other")), "무선 연결용 Wi-Fi (HMG-API)"))
            && "켜짐 (SSID 확인 못 함)".equals(row(Report.parse(GOOD.replace("ap_mode=projection\n", "")), "무선 연결용 Wi-Fi (HMG-API)"))
            && "꺼짐 (HMG-API에 요청 없음)".equals(row(Report.parse(GOOD.replace("ap=yes", "ap=no").replace("proj=yes", "proj=no")), "무선 연결용 Wi-Fi (HMG-API)"))
            && "꺼짐 (이번 부팅에 켰다가 꺼짐)".equals(row(Report.parse(GOOD.replace("ap=yes", "ap=no")), "무선 연결용 Wi-Fi (HMG-API)"))
            && "꺼짐 (켜지 못함, 다시 시도 중)".equals(row(Report.parse(GOOD.replace("ap=yes", "ap=no").replace("ap_boot=yes", "ap_boot=no").replace("ap_fail=no", "ap_fail=yes")), "무선 연결용 Wi-Fi (HMG-API)"))
            && "꺼짐".equals(row(Report.parse(GOOD.replace("ap=yes", "ap=no").replace("ap_boot=yes", "ap_boot=no")), "무선 연결용 Wi-Fi (HMG-API)")));
        check("Wi-Fi 칩 칸: 보임·안 보임, 다른 패키지의 Wi-Fi가 있는 차만 한 줄", "보임".equals(row(r, "Wi-Fi 칩"))
            && "안 보임".equals(row(Report.parse(GOOD.replace("chip=yes", "chip=no")), "Wi-Fi 칩")) && row(r, "다른 패키지의 Wi-Fi") == null
            && "있음 (지워야 함)".equals(row(Report.parse(GOOD.replace("other_ap=no", "other_ap=yes")), "다른 패키지의 Wi-Fi")));
        String STOCK = GOOD.replace("ap=yes\nap_mode=projection", "ap=no\nap_mode=none").replace("chip=yes", "chip=no").replace("wlan0=yes", "wlan0=no")
            .replace("ap_boot=yes", "ap_boot=no").replace("ap_fail=no", "ap_fail=yes").replace("verdict=ready", "verdict=nowifipart");

        // --- busybox를 실행하지 못한 내비: status.sh가 짧은 상태 파일만 쓴다 ---
        String NB = "support=nobb\nproduct=NX4.KOR.0000.V039.001.260902\nplatform=tcc803x\npkgver=2.0.0\nmade=11-19 03:00\n";
        Report nb = Report.parse(NB);
        check("busybox 없음 → '동작하지 않습니다', 노랑", nb.nobb() && nb.verdict().equals(Report.NOBB_MSG)
            && nb.verdict().startsWith("이 내비에서는 동작하지 않습니다") && nb.level() == 1);
        check("  표는 5줄: 플랫폼, NX4 KOR, 지원 안 됨, 무선 설정 안 함", nb.rows().size() == 5 && "tcc803x".equals(row(nb, "내비 종류(플랫폼)"))
            && "2.0.0".equals(row(nb, "NX4 KOR")) && row(nb, "무선 설정").startsWith("하지 않았습니다") && !r.nobb());

        // --- 설치 진행 기록 ---
        String PR = "pct=40\nstate=run\nstage=이 차의 map을 만드는 중입니다(1~2분)\nstart=1000\nt=1100\nboot=abc-123\n";
        Report pr = Report.parse(PR);
        check("진행 기록: 이번 부팅이면 진행 중, 40%, 경과 2분 05초", pr.progRunning("abc-123\n") && pr.progPct() == 40
            && "2분 05초".equals(Report.mmss(pr.progElapsed(1125))));
        check("  지난 부팅의 기록이면 진행 막대를 보이지 않음", !pr.progRunning("other") && !pr.progRunning(null));
        check("  15분 넘게 새로 쓰이지 않은 기록은 멈춘 것으로 봄, 한참 미래 시각도", pr.progRunning("abc-123", 1100 + 900) && !pr.progRunning("abc-123", 1100 + 901)
            && !pr.progRunning("abc-123", 1100 - 901));
        check("  진행 중이면 판정을 바꾸지 않음", pr.progVerdict("abc-123") == null);
        Report rb = Report.parse(PR.replace("state=run", "state=reboot").replace("stage=이 차의 map을 만드는 중입니다(1~2분)", "stage=무선 카플레이 설정을 마쳤습니다. [지금 재부팅]을 눌러 내비를 재부팅해 주세요."));
        check("  재부팅 필요 → 그 문구가 판정, 노랑", "무선 카플레이 설정을 마쳤습니다. [지금 재부팅]을 눌러 내비를 재부팅해 주세요.".equals(rb.progVerdict("abc-123")) && rb.progLevel() == 1);
        Report rf = Report.parse(PR.replace("state=run", "state=fail").replace("stage=이 차의 map을 만드는 중입니다(1~2분)", "stage=HMG-API가 없습니다."));
        check("  실패 → 그 문구가 판정, 빨강", "HMG-API가 없습니다.".equals(rf.progVerdict("abc-123")) && rf.progLevel() == 2);
        check("  준비됨(done)은 판정을 바꾸지 않음", Report.parse(PR.replace("state=run", "state=done")).progVerdict("abc-123") == null);
        check("  진행률이 이상하면 0~100으로", Report.parse("pct=250").progPct() == 100 && Report.parse("pct=x").progPct() == 0 && Report.parse("pct=-5").progPct() == 0);
        check("  시간: 59초, 1분 00초, 시작 기록 없으면 -", "59초".equals(Report.mmss(59)) && "1분 00초".equals(Report.mmss(60)) && "-".equals(Report.mmss(Report.parse("").progElapsed(5))));
        Report pRun = Report.parse("pct=40\nstate=run\nstage=무선 기능을 적용하는 중입니다\nstart=1700000000\nt=1700000990\nboot=boot-A\nstep=5/5\n");
        Report pRb = Report.parse("pct=100\nstate=reboot\nstage=x\nt=1700000990\nboot=boot-A\nstep=\n");
        Report pDone = Report.parse("pct=100\nstate=done\nstage=x\nt=1700000990\nboot=boot-A\n");
        check("  재부팅 필요(state=reboot)는 이번 부팅 것만", pRb.progReboot("boot-A") && !pRun.progReboot("boot-A") && !pDone.progReboot("boot-A") && !pRb.progReboot("boot-B"));
        check("  단계 표시 'step=5/5' → '단계 5/5', 줄 없음·빈 값·깨진 값은 ''", "단계 5/5".equals(pRun.progStep())
            && "".equals(pRb.progStep()) && "".equals(pDone.progStep()) && "".equals(Report.parse("step=6/5\n").progStep())
            && "".equals(Report.parse("step=x/5\n").progStep()) && "".equals(Report.parse("step=3/\n").progStep()));
        check("  10분(600초) 넘으면 '평소보다 오래 걸립니다…', 그 전은 ''",
            "".equals(pRun.progSlow(1700000599L)) && Report.SLOW_MSG.equals(pRun.progSlow(1700000600L))
            && Report.SLOW_MSG.equals("평소보다 오래 걸립니다. 15분이 지나도 그대로면 내비를 재부팅해 주세요.")
            && Report.PROGRESS_HINT.equals("보통 5분 안에 끝납니다. 끝날 때까지 내비를 끄지 마세요.") && Report.SLOW < Report.STALE);
        Report pUp = Report.parse("pct=40\nstate=run\nstage=x\nstart=1700000000\nt=1700000990\nboot=boot-A\nust=100\nut=150\n");
        check("  진행 기록에 부팅 뒤 초(ust)가 있으면 경과를 그것으로(시계가 앞당겨져도 안내 없음)",
            "".equals(pUp.progSlow(1700000660L, 400)) && Report.SLOW_MSG.equals(pUp.progSlow(1700000000L, 700))
            && Report.SLOW_MSG.equals(pUp.progSlow(1700000660L, -1)) && Report.SLOW_MSG.equals(pUp.progSlow(1700000660L, 50)));
        check("  /proc/uptime 읽기('123.45 67.8' → 123), 못 읽으면 -1", Report.upSec("123.45 67.8\n") == 123 && Report.upSec(null) == -1 && Report.upSec("x") == -1);
        check("  끝난(done) 기록은 알림 숨기기 기준이 아님, 실패(fail)·재부팅 필요는 기준",
            pDone.progEndedAt("boot-A") == 0 && Report.parse("pct=100\nstate=fail\nt=1700000990\nboot=boot-A\n").progEndedAt("boot-A") == 1700000990L
            && pRb.progEndedAt("boot-A") == 1700000990L && pRun.progEndedAt("boot-A") == 0 && pRb.progEndedAt("boot-B") == 0);

        // --- 알림 기록(토스트 대신) ---
        long now = 1700001000L;
        String nt = "1700000000 boot-A 첫 안내\n1700000100 boot-B 지난 부팅 안내\n1700000200 boot-A 두 번째 안내\n1700000300 boot-A 세 번째\n1700000400 boot-A 네 번째\nbroken\n1700000500 boot-A \n";
        java.util.List<String[]> ns = Report.notices(nt, "boot-A", 3);
        check("알림: 이번 부팅 줄만, 새것부터 최대 3개, 빈 문구·깨진 줄은 건너뜀", ns.size() == 3 && "네 번째".equals(ns.get(0)[1]) && "1700000400".equals(ns.get(0)[0])
            && "두 번째 안내".equals(ns.get(2)[1]));
        check("  부팅 id를 모르거나 기록이 없으면 없음", Report.notices(nt, null, 3).isEmpty() && Report.notices(null, "boot-A", 3).isEmpty() && Report.notices(nt, "boot-C", 3).isEmpty());
        java.util.List<String[]> fresh = Report.notices(nt, "boot-A", 3, 1700000500L, 250);
        check("  보여 주는 시간이 지난 줄은 뺌", fresh.size() == 2 && "네 번째".equals(fresh.get(0)[1]) && "세 번째".equals(fresh.get(1)[1]));
        check("  문구 안의 띄어쓰기는 그대로", "지난 부팅 안내".equals(Report.notices(nt, "boot-B", 1).get(0)[1]));
        String nt2 = "1700000100 boot-A NX4 KOR: 무선 카플레이를 설정하는 중입니다. 약 5분 동안 내비를 재부팅하거나 끄지 마세요.\n"
            + "1700000995 boot-A 무선 기능 적용에 실패했습니다.\n";
        java.util.List<String[]> n0 = Report.notices(nt2, "boot-A", 3, now, 1800, pRb.progEndedAt("boot-A"));
        check("  진행이 끝난 시각보다 앞선 알림은 숨김, 뒤의 알림은 보임", n0.size() == 1 && n0.get(0)[1].equals("무선 기능 적용에 실패했습니다."));
        java.util.List<String[]> n1 = Report.notices(nt2, "boot-A", 3, now, 1800);
        check("  알림 앞의 'NX4 KOR: '은 뗌", n1.size() == 2 && n1.get(1)[1].startsWith("무선 카플레이를 설정하는 중입니다")
            && "x".equals(Report.plain("NX4 KOR: x")) && "y".equals(Report.plain("y")));

        // --- 상태 안내 파일(hint_write) ---
        String hb = "boot=boot-A\naa_ready=1700000900\naa=\naa_t=\niph=\niph_t=\nconf=\nconf_t=\n";
        check("안내: 신호가 켜져도 '무선 안드로이드 오토 준비됨' 줄을 따로 두지 않음(판정 줄이 말함)", Report.hints(hb, "boot-A", now).isEmpty());
        check("  지난 부팅·부팅 id 모름·파일 없음이면 없음", Report.hints(hb, "boot-B", now).isEmpty() && Report.hints(hb, null, now).isEmpty()
            && Report.hints(null, "boot-A", now).isEmpty());
        java.util.List<String[]> h1 = Report.hints(hb.replace("aa=\naa_t=", "aa=bt\naa_t=1700000950"), "boot-A", now);
        check("  aa=bt → '안드로이드 폰의 블루투스를 껐다 켜 주세요(…다시 연결)' 노랑 한 줄", h1.size() == 1 && "1".equals(h1.get(0)[0])
            && h1.get(0)[1].startsWith("안드로이드 폰의 블루투스를 껐다 켜 주세요") && h1.get(0)[1].contains("내비 블루투스 화면에서 폰을 다시 연결"));
        check("  aa=cpwait → '카플레이가 연결되어 있어 안드로이드 오토는 기다립니다'",
            Report.hints(hb.replace("aa=\naa_t=", "aa=cpwait\naa_t=1700000950"), "boot-A", now).get(0)[1].equals("카플레이가 연결되어 있어 안드로이드 오토는 기다립니다."));
        check("  aa=ok여도 '연결됨' 줄을 따로 두지 않음", Report.hints(hb.replace("aa=\naa_t=", "aa=ok\naa_t=1700000980"), "boot-A", now).isEmpty());
        check("  10분 지난 AA·아이폰 안내는 보이지 않음",
            Report.hints(hb.replace("aa=\naa_t=", "aa=bt\naa_t=1700000000").replace("iph=\niph_t=", "iph=wifi\niph_t=1700000000"), "boot-A", now).isEmpty());
        java.util.List<String[]> h3 = Report.hints(hb.replace("iph=\niph_t=", "iph=wifi\niph_t=1700000990").replace("conf=\nconf_t=", "conf=wait\nconf_t=1700000990"), "boot-A", now);
        check("  conf=wait·iph=wifi 문구(설정 바뀜이 맨 위, 아이폰 Wi-Fi 지우고 다시 연결)", h3.size() == 2
            && h3.get(0)[1].startsWith("Wi-Fi 설정이 바뀌었습니다") && h3.get(1)[1].contains("아이폰 설정 → Wi-Fi에서 차 네트워크를 지우고 다시 연결하세요"));
        java.util.List<String[]> hn = Report.hints("boot=boot-A\naa_ready=\naa=\naa_t=\niph=nocp\niph_t=1700000990\nconf=\nconf_t=\n", "boot-A", now);
        check("  iph=nocp → '폰이 차 Wi-Fi에 연결됐지만 카플레이가 시작되지 않았습니다. 내비를 재부팅해 주세요.' 노랑",
            hn.size() == 1 && "1".equals(hn.get(0)[0]) && "폰이 차 Wi-Fi에 연결됐지만 카플레이가 시작되지 않았습니다. 내비를 재부팅해 주세요.".equals(hn.get(0)[1]));
        check("  안내 문구에 SSID·비밀번호 같은 값이 들어갈 자리가 없음(코드만 읽음)",
            Report.hints(hb.replace("aa=\n", "aa=MyNet secret\n"), "boot-A", now).isEmpty());

        // --- 진단 기록 확인 창(DiagActivity) ---
        check("진단 답 파일은 '<id> <답>' 한 줄(usb/troubleShooter diag_ans가 첫 두 칸을 읽음), id 앞뒤 공백은 뺌",
            "1700000000123 yes\n".equals(Report.diagLine(" 1700000000123\n", "yes")) && " shown\n".equals(Report.diagLine(null, "shown")));
        check("  확인 창 문구: 1~2분·USB를 빼지 말 것·건너뛰어도 설치는 이어짐·기다리는 초, 버튼 [모으기]·[건너뛰기]",
            Report.diagAsk(60).contains("1~2분") && Report.diagAsk(60).contains("USB를 빼지 마세요") && Report.diagAsk(60).contains("설치는 그대로 이어집니다")
            && Report.diagAsk(45).contains("45초 안에 고르지 않으면 건너뜁니다") && "모으기".equals(Report.DIAG_YES) && "건너뛰기".equals(Report.DIAG_NO));
        check("  설치기가 창을 기다리는 시각(until)이 지난 뒤 열린 창은 늦음(쓰지 않고 닫음), 그 시각까지·until 없음은 늦지 않음",
            Report.diagLate(1700000016L, 1700000015L) && !Report.diagLate(1700000015L, 1700000015L)
            && !Report.diagLate(1700000010L, 1700000015L) && !Report.diagLate(1700000016L, 0L));

        // --- [지금 재부팅] ---
        check("재부팅 요청 파일 내용은 '요청 id(부팅 뒤 밀리초) boot_id 부팅 뒤 초' 한 줄뿐(svc/lib.sh req_peek과 같은 꼴)",
            "123456789 boot-A 123456\n".equals(Report.rbLine(123456789L, " boot-A\n")));
        long[] rq = Report.rbParse("123456789 boot-A 123456\n", "boot-A\n");
        check("  요청 파일 읽기: 이번 부팅만, 다른 부팅·깨진 값·두 칸이면 null", rq != null && rq[0] == 123456789L && rq[1] == 123456789L
            && Report.rbParse("123456789 boot-B 123456", "boot-A") == null && Report.rbParse("x boot-A 1", "boot-A") == null
            && Report.rbParse("1 boot-A x", "boot-A") == null && Report.rbParse(null, "boot-A") == null
            && Report.rbParse("1700001000 boot-A", "boot-A") == null && Report.rbParse("1 boot-A 1", null) == null);
        check("  재부팅 문구: 확인 창·보냄·실패(RESET 버튼)·저장 실패, 기다림 80초", Report.RB_CONFIRM.equals("차를 세운 상태에서만 누르세요. 화면이 1~2분 꺼졌다 켜집니다.")
            && Report.RB_SENT.equals("재부팅합니다…") && Report.RB_FAILED.equals("재부팅하지 못했습니다. RESET 버튼으로 재부팅해 주세요.")
            && Report.RB_WRITE_FAILED.contains("RESET 버튼") && Report.RB_WAIT == 80);
        Report rr = Report.parse("id=12345\nboot=boot-A\ncode=fix\n");
        check("설치 중(install)·설치 마무리 중(fix) → '마무리하는 중' 안내(RESET 아님)",
            Report.RB_FINISHING.equals(Report.rbAnswer(rr, "boot-A", 12345))
            && Report.RB_FINISHING.equals(Report.rbAnswer(Report.parse("id=12345\nboot=boot-A\ncode=install\n"), "boot-A", 12345))
            && Report.RB_FINISHING.equals("설정을 마무리하는 중입니다. 잠시 뒤 다시 눌러 주세요."));
        Report gd = Report.parse("id=6\nboot=boot-A\ncode=guard\n");
        check("guard → HMG-API rc.6 이후 규칙(2분 전 재부팅이 6번 이어지면 끔) 문구(HMG-API를 문장 앞에), 새 줄에 '3~5분 뒤에 다시 눌러 주세요.', 이어져도 RESET 안내로 넘기지 않음",
            Report.RB_GUARD.equals(Report.rbAnswer(gd, "boot-A", 6)) && Report.RB_GUARD.equals(Report.rbAnswer(gd, "boot-A", 6, 0, 5000)) && !Report.rbStuckCode(gd)
            && Report.RB_GUARD.equals("HMG-API는 내비가 켜지고 2분 안의 재부팅이 6번 이어지면 무선 기능을 끕니다.\n3~5분 뒤에 다시 눌러 주세요.")
            && !Report.RB_GUARD.contains("3분 안에"));
        Report m2s = Report.parse("id=5\nboot=boot-A\ncode=sysw\n"), m2i = Report.parse("id=5\nboot=boot-A\ncode=install\n"),
            m2f = Report.parse("id=5\nboot=boot-A\ncode=fix\n");
        check("sysw → '마무리하는 중', install·sysw 거절이 처음 거절부터 900초 지나면 RESET 안내, 시작 기록 없음(-1)·fix는 그대로",
            Report.RB_FINISHING.equals(Report.rbAnswer(m2s, "boot-A", 5)) && Report.RB_STUCK_SECS == 900
            && Report.RB_FINISHING.equals(Report.rbAnswer(m2s, "boot-A", 5, -1, 99999)) && Report.RB_FINISHING.equals(Report.rbAnswer(m2i, "boot-A", 5, 100, 999))
            && Report.RB_FAILED.equals(Report.rbAnswer(m2s, "boot-A", 5, 100, 1000)) && Report.RB_FAILED.equals(Report.rbAnswer(m2i, "boot-A", 5, 0, 5000))
            && Report.RB_FINISHING.equals(Report.rbAnswer(m2f, "boot-A", 5, 0, 99999)) && Report.rbAnswer(m2s, "boot-B", 5, 0, 99999) == null);
        check("  거절 기록은 이번 부팅 것만 읽음(다른 부팅·깨진 값·음수·칸 수 틀림·빈 값 → -1), 쓴 줄을 그대로 다시 읽음",
            Report.stuckSince(Report.stuckLine("boot-A", 123, 200), "boot-A", 300) == 123 && Report.stuckSince("boot-A 123 200", "boot-B", 300) == -1
            && Report.stuckSince("boot-A x 200", "boot-A", 300) == -1 && Report.stuckSince("boot-A -5 200", "boot-A", 300) == -1
            && Report.stuckSince(null, "boot-A", 300) == -1 && Report.stuckSince("boot-A 123", "boot-A", 300) == -1
            && Report.stuckSince("boot-A 7 8", null, 300) == -1 && Report.stuckLine(" boot-A ", 9, 10).equals("boot-A 9 10\n"));
        check("  마지막 거절에서 1800초(900의 2배) 넘게 비면 새로 시작(-1), 그 전이면 이어짐, 시각이 거꾸로면 -1",
            Report.RB_STUCK_GAP == 1800 && Report.stuckSince("boot-A 100 200", "boot-A", 1999) == 100
            && Report.stuckSince("boot-A 100 200", "boot-A", 2000) == -1 && Report.stuckSince("boot-A 300 200", "boot-A", 400) == -1
            && Report.stuckSince("boot-A 100 200", "boot-A", 150) == -1);
        check("  늦은·받지 못한 요청 → 다시 누르기, 명령이 돌아옴·모르는 값(없어진 collect·rw·state 포함) → RESET 안내",
            Report.RB_RETRY.equals(Report.rbAnswer(Report.parse("id=7\nboot=boot-A\ncode=old\n"), "boot-A", 7))
            && Report.RB_RETRY.equals(Report.rbAnswer(Report.parse("id=7\nboot=boot-A\ncode=bad\n"), "boot-A", 7))
            && Report.RB_FAILED.equals(Report.rbAnswer(Report.parse("id=7\nboot=boot-A\ncode=cmd\n"), "boot-A", 7))
            && Report.RB_FAILED.equals(Report.rbAnswer(Report.parse("id=7\nboot=boot-A\ncode=collect\n"), "boot-A", 7))
            && Report.RB_FAILED.equals(Report.rbAnswer(Report.parse("id=7\nboot=boot-A\ncode=rw\n"), "boot-A", 7))
            && Report.RB_FAILED.equals(Report.rbAnswer(Report.parse("id=7\nboot=boot-A\ncode=state\n"), "boot-A", 7))
            && Report.RB_FAILED.equals(Report.rbAnswer(Report.parse("id=7\nboot=boot-A\ncode=zzz\n"), "boot-A", 7))
            && Report.RB_RETRY.equals("재부팅 요청을 받지 못했습니다. 다시 눌러 주세요."));
        check("  다른 요청 id·다른 부팅·코드 없음·결과 없음이면 답 없음(계속 기다림, RB_WAIT 뒤에만 RESET 안내)",
            Report.rbAnswer(rr, "boot-A", 12346) == null && Report.rbAnswer(rr, "boot-B", 12345) == null
            && Report.rbAnswer(Report.parse("id=12345\nboot=boot-A\n"), "boot-A", 12345) == null
            && Report.rbAnswer(Report.parse(null), "boot-A", 12345) == null && Report.rbAnswer(rr, null, 12345) == null
            && Report.rbAnswer(rr, "boot-A", 0) == null);
        // [동글 켜기](#60): 결과 해석, 버튼을 보일 때, 표 칸
        Report dok = Report.parse("id=900\nboot=boot-A\ncode=ok\nusb=0bda:b831\ndrv=rtl8831bu\n");
        check("동글 켜기: ok·restarted면 좋은 소식(드라이버 화면 이름 RTL8831BU), noap·nowlan은 '걸었지만 아직', 이번 부팅의 내 요청이 아니거나 코드가 없으면 답 없음",
            Report.dgAnswer(dok, "boot-A", 900).startsWith("동글(RTL8831BU)을 켰습니다.") && Report.dgGood(dok)
            && Report.dgGood(Report.parse("id=900\nboot=boot-A\ncode=restarted\n"))
            && Report.dgAnswer(Report.parse("id=900\nboot=boot-A\ncode=noap\ndrv=rtl88x2bu\n"), "boot-A", 900).startsWith("동글 드라이버(RTL88x2BU)는 걸었지만")
            && Report.dgAnswer(Report.parse("id=900\nboot=boot-A\ncode=nowlan\ndrv=rtl88x2bu\n"), "boot-A", 900).contains("아직 뜨지 않았습니다")
            && !Report.dgGood(Report.parse("id=900\nboot=boot-A\ncode=noap\n"))
            && Report.dgAnswer(dok, "boot-A", 901) == null && Report.dgAnswer(dok, "boot-B", 900) == null
            && Report.dgAnswer(Report.parse("id=900\nboot=boot-A\n"), "boot-A", 900) == null && Report.dgAnswer(dok, null, 900) == null
            && Report.dgAnswer(dok, "boot-A", 0) == null);
        check("  코드마다 안내: nodongle·nodrivers·chip·other·gone·busy·old·bad·noproj, 모르는 코드는 코드와 함께 재부팅 안내",
            Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=nodongle\n"), "b", 9).startsWith("꽂힌 동글을 찾지 못했습니다.")
            && Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=nodrivers\n"), "b", 9).contains("동글 드라이버가 없습니다")
            && Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=chip\n"), "b", 9).contains("Wi-Fi 칩이 있어")
            && Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=other\n"), "b", 9).contains("다른 모드가")
            && Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=gone\n"), "b", 9).startsWith("동글이 빠졌습니다.")
            && Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=busy\n"), "b", 9).contains("이미 도는 중")
            && Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=old\n"), "b", 9).equals(Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=bad\n"), "b", 9))
            && Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=noproj\ndrv=rtl8831bu\n"), "b", 9).contains("요청하지 않아")
            && Report.dgAnswer(Report.parse("id=9\nboot=b\ncode=zzz\n"), "b", 9).equals("동글을 켜지 못했습니다(zzz). 재부팅한 뒤 다시 눌러 주세요."));
        Report dgs = Report.parse("support=ok\ndongle_drivers=yes\ndongle=0bda:b831 rtl8831bu\ndongle_on=rtl8831bu\ndongle_btn=yes\n");
        boolean dgRow = false;
        for (String[] row : dgs.rows()) if ("USB Wi-Fi 동글".equals(row[0]) && "RTL8831BU (0bda:b831), 드라이버 걸림".equals(row[1])) dgRow = true;
        boolean noRow = true;
        for (String[] row : Report.parse("support=ok\ndongle_drivers=no\n").rows()) if ("USB Wi-Fi 동글".equals(row[0])) noRow = false;
        check("  표: 묶음에 드라이버가 있으면 'USB Wi-Fi 동글' 줄(걸림·안 걸림·안 꽂힘), 없으면 줄 없음. 버튼은 dongle_btn=yes·busybox 있을 때만",
            dgRow && noRow && dgs.dongleButton()
            && "RTL88x2BU (2357:012d), 드라이버 안 걸림".equals(Report.parse("dongle=2357:012d rtl88x2bu\ndongle_on=none\n").dongleCell())
            && "안 꽂힘".equals(Report.parse("dongle=none\n").dongleCell()) && "안 꽂힘".equals(Report.parse("").dongleCell())
            && !Report.parse("dongle_btn=no\n").dongleButton() && !Report.parse("support=nobb\ndongle_btn=yes\n").dongleButton());
        String wf = "boot=boot-A\nuntil=700\n";
        check("감시자 끝 시각 전이면 보냄, 끝났거나(3초 여유) 다른 부팅·파일 없음·깨진 값이면 '끝남'",
            !Report.watchGone(wf, "boot-A", 600) && Report.watchGone(wf, "boot-A", 697) && Report.watchGone(wf, "boot-A", 800)
            && Report.watchGone(wf, "boot-B", 600) && Report.watchGone(null, "boot-A", 600) && Report.watchGone("boot=boot-A\nuntil=x\n", "boot-A", 600)
            && Report.watchGone(wf, null, 600));
        check("  감시자가 끝났을 때 안내: 화면을 다시 열면 감시자가 다시 뜸", Report.RB_NOWATCH.equals("관리 앱을 닫았다가 다시 연 뒤 눌러 주세요."));

        // --- 보이는 문구에 없어진 이름·기능이 남지 않음 ---
        String bad = null;
        for (java.lang.reflect.Field f : Report.class.getDeclaredFields()) {
            if (!java.lang.reflect.Modifier.isStatic(f.getModifiers()) || f.getType() != String.class) continue;
            f.setAccessible(true);
            String b = banned((String) f.get(null));
            if (b != null) { bad = f.getName() + " (" + b + ")"; break; }
        }
        check("Report의 문구 상수에 옛 이름·없어진 기능 낱말이 없음" + (bad == null ? "" : ": " + bad), bad == null);
        String[] samples = { GOOD, V3, NB, STOCK, "", GOOD.replace("verdict_msg=무선 카플레이·안드로이드 오토 준비됨.", "verdict_msg="),
            GOOD.replace("wm=yes", "wm=no").replace("hooks=on", "hooks=off"), GOOD.replace("other_ap=no", "other_ap=yes") };
        String badOut = null;
        for (String s : samples) {
            Report x = Report.parse(s);
            StringBuilder all = new StringBuilder(x.verdict()).append(x.endHint());
            for (String[] rw : x.rows()) all.append(rw[0]).append(rw[1]);
            if (banned(all.toString()) != null) { badOut = banned(all.toString()); break; }
        }
        check("  판정·표에도 없음" + (badOut == null ? "" : ": " + badOut), badOut == null);

        System.out.println(fails == 0 ? "Java 모두 통과" : "Java 실패 " + fails + "개");
        System.exit(fails == 0 ? 0 : 1);
    }
}
