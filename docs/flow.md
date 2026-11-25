# NX4 KOR 2.1.0 처리 흐름

2.1.0에서 설치부터 무선 연결, 관리 앱, 지우기까지 무엇이 어떤 차례로 도는지 그림으로 모았습니다. 자세한 규칙과 근거는 [`design.md`](design.md)에 있고, 이 문서는 그 요약입니다. 둘이 다르면 `design.md`와 코드가 맞습니다.

> ⚠️ 2.1.0 흐름은 차에서 아직 확인하지 않았습니다. PC 테스트(`tests/mod-test.sh`)와 HMG-API 1.1.0-rc.8 엔진(PC)에서만 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23), [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45)).

## 1. 누가 무엇을 하나

| 맡는 곳 | 하는 일 |
|---|---|
| USB 설치기(`usb/troubleShooter`, root) | HMG-API 확인·업데이트 넘기기, 옛 2.0.x 되돌리기, 공식 무선 모드 설치(`--any-car`), nx4-kor 설치, NX4 map 만들기·확인, 적용, 진행 기록, 지우기 |
| HMG-API(`hmgapid`, 엔진, zygote 훅) | 모드 설치·계획·적용, map, 부팅 때 훅 올리기, 프로젝션 AP 지기(Wi-Fi), 앱·서비스·타일 |
| 공식 무선 모드(`wireless-carplay-aa`, 고치지 않음) | 무선 카플레이·안드로이드 오토 훅, 계기판·HUD 길안내, 프로젝션 AP 요청(`"wifi": {"projection": true}`) |
| nx4-kor 모드(이 저장소) | 관리 앱과 앱 메뉴 타일, 앱이 부르는 `launch` 서비스(`bin/status.sh`). 훅·시스템 파일·Wi-Fi 설정은 건드리지 않음 |

```mermaid
flowchart LR
  subgraph USB["USB 스틱"]
    NX4["NX4/<br/>install/payload, wireless/,<br/>legacy-2.0/, hmgapi/"]
  end
  subgraph HU["내비(투싼 NX4 260902)"]
    TS["USB 설치기<br/>troubleShooter(root)"]
    HD["hmgapid / HMG-API 엔진"]
    DATA[("/data/hmgapi<br/>mods/nx4-kor<br/>mods/wireless-carplay-aa<br/>state/local-map.json")]
    ZY["zygote 훅<br/>(공식 무선 모드 훅)"]
    WK["HMG-API Wi-Fi 지기<br/>프로젝션 AP"]
    APP["관리 앱<br/>+ launch 서비스(status.sh)"]
    PROG[("/data/local/tmp<br/>nx4-kor-progress.txt<br/>nx4-kor-status.txt")]
  end
  PHONE["휴대폰<br/>카플레이·AA"]

  NX4 -->|"Engineering Mode → USB Copy →<br/>DSP → Update OTA"| TS
  TS -->|"engine install / map-car /<br/>verify-map / plan / apply"| HD
  HD --> DATA
  TS -->|"진행 기록"| PROG
  DATA -->|"재부팅 뒤 map이 맞으면"| ZY
  DATA -->|"projection 요청"| WK
  WK -->|"Wi-Fi AP"| PHONE
  ZY <-->|"무선 카플레이·AA"| PHONE
  APP -->|"읽기만"| DATA
  APP <--> PROG
```

## 2. 설치·업데이트 (USB Update OTA)

같은 판도 같은 차례로 돌고, 이미 된 단계는 건너뜁니다. 설치기는 재부팅하지 않고 관리 앱의 [지금 재부팅]을 안내합니다. 단계별 규칙은 `design.md` "HMG-API 확인"과 "설치·업데이트 순서"에 있습니다. 그림은 시작 전 확인과 바꾸는 단계로 나눴습니다.

### 시작 전 확인

이 그림의 멈춤은 모두 아무것도 바꾸지 않고, 진행 기록도 쓰지 않습니다. 차례는 설치기(`usb/troubleShooter`)가 도는 차례입니다(스틱 확인, Korea Projection 패키지 확인, HMG-API 확인 순). Korea Projection 패키지는 HMG-API 설치기로 넘기기(HMG-API를 설치·업데이트하고 재부팅) 전에 봅니다.

```mermaid
flowchart TD
  S(["Update OTA 누름"]) --> DIAG["진단 기록을 모을지 화면에서 물음<br/>(DiagActivity, 60초, 아무것도 바꾸기 전)"]
  DIAG --> UN{"NX4/UNINSTALL<br/>또는 UNINSTALL-ALL?"}
  UN -->|"예"| DEL["아래 5절 지우기로"]
  UN -->|"아니요"| S0{"0. 스틱 확인<br/>묶음(install·wireless)이 있고<br/>nx4-kor가 2.1.0 꼴?"}
  S0 -->|"아니요<br/>(묶음 없음, 2.0.x 꼴)"| STOP0["멈춤: 2.1.0 이후의<br/>USB 묶음을 써 주세요"]
  S0 -->|"예"| KPKG{"NEMESIS의 Korea Projection 패키지<br/>(/data/nemesis/apps/korea.projection)가 있나?"}
  KPKG -->|"예"| STOPK["멈춤: NEMESIS에서 Korea Projection을 지우고<br/>내비를 재부팅한 뒤 다시(KORPROJ_MSG)"]
  KPKG -->|"아니요"| H{"HMG-API가 있나?"}
  H -->|"없음 +<br/>스틱에 HMG-API 묶음 있음"| HU["스틱의 HMG-API 설치기로 넘김<br/>→ 재부팅 → Update OTA 한 번 더"]
  H -->|"없음 +<br/>스틱에도 없음"| STOP1["멈춤: HMG-API를 먼저<br/>설치하거나 올려 주세요"]
  H -->|"있지만<br/>응답 없음"| STOP2["멈춤: 재부팅하고 다시"]
  H -->|"있고 응답함"| VER{"최소 판 이상?<br/>(1.1.0-rc.8과 두 모드의 hmgapi 중 높은 것)"}
  VER -->|"낮음 +<br/>스틱의 HMG-API가 그 판 이상"| HU
  VER -->|"낮음 +<br/>스틱에 없거나 낮음"| STOP1
  VER -->|"예"| BK{"2.0.x 기록(backup)이 남았는데<br/>스틱에 legacy-2.0이 없음?"}
  BK -->|"예"| STOP3["멈춤: 2.0.x 릴리스 USB의<br/>NX4/UNINSTALL로 먼저 되돌려 주세요"]
  BK -->|"아니요"| SAME{"같은 판이고<br/>관리 앱 있음?"}
  SAME -->|"예"| OPEN0["관리 앱을 먼저 엶"]
  SAME -->|"아니요"| P1
  OPEN0 --> P1{"1. 시작 전 계획<br/>(engine plan)"}
  P1 -->|"계획 실패<br/>(종료 코드가 0·3이 아님)"| STOP4["멈춤: 내비를 재부팅한 뒤 다시<br/>(PLANFAIL_MSG)"]
  P1 -->|"다른 모드의 적용 안 한 변경,<br/>모르는 되돌리기"| STOP5["멈춤: HMG-API 앱에서 먼저 적용"]
  P1 -->|"괜찮음"| GO(["아래 바꾸는 단계로"])
```

- Korea Projection 패키지 확인은 그 패키지 폴더만 봅니다. 다른 NEMESIS 패키지는 막지 않고, 지우기(5절)도 막지 않습니다([#13](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/13)). 이 멈춤은 같은 판의 관리 앱 열기보다 앞이라 관리 앱을 열지 않습니다.
- HMG-API의 판을 읽지 못하거나 비교할 수 없으면 기록만 하고 지나갑니다. 엔진이 설치할 때 다시 봅니다.
- 설치된 nx4-kor가 2.0.x 자체면 아래 2단계에서 그 판의 것으로 되돌립니다. 그래서 `legacy-2.0` 멈춤(`OLDLEFT_MSG`)에 걸리지 않습니다.
- "같은 판"은 `NX4/REINSTALL`이 없고 2.0.x 기록도 없을 때입니다.

### 바꾸는 단계

```mermaid
flowchart TD
  GO(["시작 전 확인 통과<br/>진행 기록 시작(state=run)"]) --> KP["한국 차 빌드 무선 모드(Korea Projection 2.4.x)가<br/>있으면 먼저 engine remove"]
  KP --> OLD["2. 옛 NX4 KOR 2.0.x나 그 기록(backup)이 있으면 되돌림<br/>(모드가 있으면) engine remove → apply →<br/>옛 판 uninstall.sh(사본, 또는 스틱의 legacy-2.0)"]
  OLD --> WM["3. 공식 무선 모드<br/>없거나 낮으면 engine install --any-car,<br/>꺼져 있으면 enable"]
  WM --> NK["4. nx4-kor(같은 판이면 건너뜀)<br/>업데이트면 uninstall.sh --update 뒤, 처음이면 바로<br/>engine install → 관리 앱 엶"]
  NK --> MAP{"5. 이 차의 map<br/>(state/local-map.json)?"}
  MAP -->|"없음"| MW["engine map-car --write<br/>(1~2분)"]
  MW -->|"만듦, 또는<br/>HMG-API에 이미 있음"| MV["engine verify-map"]
  MW -->|"못 만듦"| NOMAP["실패로 끝(NOMAP_MSG)<br/>확인·적용 안 함"]
  MAP -->|"있음"| MV
  MV -->|"실패"| MF["이번에 만든 map만 지움(map-car --forget)<br/>→ 실패로 끝(MAPFAIL_MSG, 적용 안 함)"]
  MV -->|"통과"| AP{"6. 끝 계획이 우리 두 모드의 변경·되돌리기뿐이고<br/>훅이 켜지나?"}
  AP -->|"아니요, 또는 계획 실패"| AF["실패로 끝, 적용 안 함<br/>(HMG-API 앱에서 보라고 안내.<br/>계획 실패면 재부팅 뒤 다시)"]
  AP -->|"예"| TODO{"적용할 줄이 있나?"}
  TODO -->|"있음"| APPLY["engine apply"]
  APPLY -->|"실패"| APF["실패로 끝(APPLYFAIL_MSG)"]
  APPLY -->|"성공"| R{"7. 무엇이 바뀌었나?"}
  TODO -->|"없음(적용 건너뜀)"| R
  R -->|"예"| RB["진행 기록 state=reboot<br/>관리 앱: [지금 재부팅]"]
  R -->|"아니요"| DONE["state=done<br/>설정이 끝나 있습니다"]
```

- 진행 기록 `/data/local/tmp/nx4-kor-progress.txt`(`state`: `run`·`done`·`reboot`·`fail`)는 1단계 뒤 무엇을 바꾸기 시작할 때부터 씁니다. 관리 앱이 이 파일로 막대와 결과를 그립니다.
- 그림에서 뺀 실패 갈래입니다. 모두 진행 기록을 `state=fail`로 끝내고 뒤 단계는 하지 않습니다.
  - 한국 차 빌드를 지우지 못함, 공식 무선 모드 설치 실패(`WFAIL_MSG`)
  - 옛 2.0.x 되돌리기 실패(`OLDFAIL_MSG`). 뺀 뒤 계획에 다른 변경이 있으면 적용하지 않고 끝 계획과 같은 안내로 끝납니다
  - nx4-kor 설치 거절(`INSTFAIL_MSG`). 예전 판에서 돌던 서비스를 다시 띄웁니다
- 2단계에서 nx4-kor 없이 2.1.0 이후의 기록(`/data/nx4-kor`)만 남은 차는 스틱의 사본(`payload/bin/uninstall.sh`)으로 정리만 합니다. 실패해도 계속합니다.
- map 만들기·확인과 적용은 USB 설치기만 합니다(2026-11-23 결정, [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45)). 차에 남는 nx4-kor는 부팅 때 아무것도 설정하지 않습니다.
- 설치기 기록은 스틱의 `NX4/install.log`에 이어 씁니다.

## 3. 재부팅 뒤 무선 연결

```mermaid
sequenceDiagram
  autonumber
  participant K as 커널·zygote
  participant H as HMG-API(hmgapid)
  participant W as 공식 무선 모드 훅
  participant A as HMG-API Wi-Fi 지기
  participant P as 휴대폰

  K->>H: 부팅, zygote 시작
  H->>H: map 확인(state/map-check.json)과 부팅 보호 확인<br/>(이번 부팅 3번, 재부팅을 넘어 6번: hook/boot, hook/starts)
  alt map이 맞고 부팅 보호에 걸리지 않음
    H->>W: 훅 올림(공식 무선 모드, 앱 메뉴 타일)
  else map 없음·맞지 않음·부팅 보호
    H-->>K: 훅 꺼짐(타일 없음, 앱·서비스는 그대로)
  end
  A->>A: Android Wi-Fi 서비스가 뜨면 프로젝션 AP를 한 번 띄움<br/>(공식 모드의 projection 요청)
  alt AP가 뜸
    A->>A: wifi/ap.boot에 이번 부팅 id
    P->>W: 블루투스로 시작 → 프로젝션 AP에 접속
    W-->>P: 무선 카플레이·안드로이드 오토
  else 칩이 없거나 AP를 못 띄움
    A->>A: wifi/ap.fail, 30초마다 다시 시도
  end
```

- Wi-Fi 부품이 없는 차(2026-11-23 NX4HEV 260902)는 AP가 뜨지 않습니다. 유선 카플레이·안드로이드 오토와 계기판 길안내는 그대로이고, 무선은 USB Wi-Fi 동글([#48](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/48))을 기다립니다.
- HMG-API "집 Wi-Fi"를 켜면 주차한 동안만 HMG-API가 AP를 끄고 집 Wi-Fi에 붙습니다.

## 4. 관리 앱

```mermaid
sequenceDiagram
  autonumber
  actor U as 운전자
  participant App as 관리 앱
  participant H as hmgapid
  participant S as status.sh(root)
  participant F as 상태 파일

  U->>App: 앱 메뉴 타일(또는 USB 설치기가 엶)
  App->>H: service-start launch
  H->>S: svc/launch.sh → bin/status.sh
  S->>F: /data/local/tmp/nx4-kor-status.txt<br/>(판정 verdict, 자세히 표)
  S->>S: --watch 감시자 10분 띄움
  F-->>App: 새로 쓰이면 다시 그림
  opt [지금 재부팅]
    U->>App: 누름 → 확인
    App->>App: 앱 개인 폴더에 reboot.req
    S->>S: 감시자가 받음
    alt 설치 중·/system 쓰는 중·부팅 보호에 걸림
      S-->>App: 거절(이유 코드) → 버튼 위에 안내
    else 받음
      S->>U: 재부팅
    end
  end
```

판정은 `bin/status.sh`의 `st_verdict` 한 곳에서 정하고, 앞에서부터 처음 맞는 것이 판정입니다. 읽기만 하고 아무것도 바꾸지 않습니다(전체 표는 `design.md` "관리 앱").

```mermaid
flowchart TD
  A["1 bootguard<br/>부팅 보호"] --> B["2 installing<br/>설치 중"]
  B --> C["3 nocar<br/>다른 차"]
  C --> D["4 nohmgapi·oldhmgapi<br/>HMG-API 없음·낮음"]
  D --> E["5 reboot·failed<br/>설치기 결과"]
  E --> F["6 nowireless·wirelessoff·oldwireless<br/>공식 모드"]
  F --> G["7 hooksoff<br/>HMG-API 훅 꺼짐"]
  G --> H["8 wmhooksoff<br/>공식 모드 훅 꺼짐"]
  H --> I["9 bridgeoff · 10 nofeat ·<br/>11 noproj"]
  I --> J["12 connected<br/>무선 연결됨"]
  J --> K["13 otherwifi · 14 aphotspot ·<br/>15 ready · 16 wificlient"]
  K --> L["17 apoff · 18 apwait ·<br/>19 nowifipart · 20 apfail"]
```

## 5. 지우기

```mermaid
flowchart TD
  Q{"어떻게 지우나"}
  Q -->|"USB NX4/UNINSTALL<br/>또는 UNINSTALL-ALL"| WHAT{"설치기: 무엇이 있나"}
  Q -->|"HMG-API 앱에서 모드만 지움"| AR["engine remove nx4-kor<br/>앱·서비스·타일이 내려감"]
  WHAT -->|"2.1.0 이후 nx4-kor<br/>(또는 그 기록만)"| U1["bin/uninstall.sh<br/>(모드 폴더의 것, 없으면 스틱의 사본)"]
  WHAT -->|"옛 2.0.x nx4-kor,<br/>또는 2.0.x 기록(backup)만"| OLDR["old_revert: (모드가 있으면) engine remove →<br/>되돌리기만 적용 →<br/>옛 판 uninstall.sh 사본(또는 스틱의 legacy-2.0)"]
  WHAT -->|"nx4-kor 없음 +<br/>UNINSTALL-ALL이고 공식 무선 모드만 있음"| WR["공식 무선 모드 engine remove<br/>→ 계획이 되돌리기뿐이면 apply"]
  WHAT -->|"아무것도 없음"| NONE["멈춤: 설치되어 있지 않습니다<br/>(아무것도 바꾸지 않음)"]
  U1 --> PR["preun.sh: 감시자 멈춤, 관리 앱 작업 파일 지움<br/>→ engine remove nx4-kor(적용할 것 없음)"]
  PR --> RM["기록 폴더 /data/nx4-kor 지움<br/>(2.0.x backup이 있으면 스틱의 legacy-2.0으로 마저 되돌림)"]
  RM --> ALL{"UNINSTALL-ALL이고<br/>공식 무선 모드가 있나?"}
  OLDR --> ALL
  ALL -->|"예"| WR
  ALL -->|"아니요"| FIN(["재부팅<br/>HMG-API와 이 차의 map은 남음"])
  WR --> FIN
  AR --> LEFT["기록 파일만 남음<br/>(/data/nx4-kor, /data/local/tmp/nx4-kor*)<br/>→ USB UNINSTALL로 정리"]
```

- 자세한 갈래는 `design.md` "설치·업데이트·지우기"의 "지우기"에 있습니다.
- 그림에서 뺀 멈춤이 둘 있습니다. HMG-API가 있는데 응답하지 않을 때("재부팅하고 다시"), 모드 폴더 없이 2.0.x 기록만 남았는데 스틱에 `legacy-2.0`이 없을 때(`OLDLEFT_MSG`)입니다. 이 둘과 "설치되어 있지 않습니다", 스틱의 사본을 `/data`로 복사하지 못할 때("USB에서 복사하지 못했습니다")는 아무것도 바꾸지 않고 재부팅하지 않습니다. 그 밖에는 지우기가 실패해도 끝에 재부팅합니다.
- HMG-API를 먼저 지운 차는 `old_revert` 없이(계획·적용 없이) 그 `uninstall.sh`만 돌립니다. 2.0.x 기록만 남았으면 스틱의 `legacy-2.0` 사본을 돌립니다.
- 공식 무선 모드를 뺀 뒤 계획에 다른 변경이 있으면 적용하지 않고 "HMG-API 앱에서 변경 사항을 적용해 주세요(무선 모드 삭제)"로 알립니다.
- 2.1.0의 `uninstall.sh`가 남긴 2.0.x 기록을 이 스틱으로 되돌리지 못하면(`legacy-2.0` 없음) 그 폴더를 남기고 화면에 알립니다.
- 관리 앱에는 지우기 버튼을 두지 않습니다([#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)). 2.1.0의 nx4-kor는 시스템 파일·Wi-Fi 설정을 바꾸지 않아 HMG-API 앱에서 지워도 기록 파일만 남기 때문입니다.
- USB 설치기 자신의 기록(`nx4-kor-usb.log`, 차에서는 `nx4-kor-ota-finish.sh`)은 지우기 뒤에도 남습니다.
- 둘 다 지울 때는 NX4 KOR를 먼저, HMG-API를 나중에 지웁니다(README "삭제").
