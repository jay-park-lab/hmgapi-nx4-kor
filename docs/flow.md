# NX4 KOR 2.1.0 처리 흐름

2.1.0에서 설치부터 무선 연결, 상태 화면, 지우기까지 무엇이 어떤 차례로 도는지 그림으로 모았습니다. 자세한 규칙과 근거는 [`design.md`](design.md)에 있고, 이 문서는 그 요약입니다. 둘이 다르면 `design.md`와 코드가 맞습니다.

> ⚠️ 2.1.0 흐름은 차에서 아직 확인하지 않았습니다. PC 테스트(`tests/mod-test.sh`)와 HMG-API 1.1.0-rc.8 엔진(PC)에서만 확인했습니다([#23](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/23), [#45](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/45)).

## 1. 누가 무엇을 하나

| 맡는 곳 | 하는 일 |
|---|---|
| USB 설치기(`usb/troubleShooter`, root) | HMG-API 확인·업데이트 넘기기, 옛 2.0.x 되돌리기, 공식 무선 모드 설치(`--any-car`), nx4-kor 설치, NX4 map 만들기·확인, 적용, 진행 기록, 지우기 |
| HMG-API(`hmgapid`, 엔진, zygote 훅) | 모드 설치·계획·적용, map, 부팅 때 훅 올리기, 프로젝션 AP 지기(Wi-Fi), 앱·서비스·타일 |
| 공식 무선 모드(`wireless-carplay-aa`, 고치지 않음) | 무선 카플레이·안드로이드 오토 훅, 계기판·HUD 길안내, 프로젝션 AP 요청(`"wifi": {"projection": true}`) |
| nx4-kor 모드(이 저장소) | 상태 화면 앱과 앱 메뉴 타일, 앱이 부르는 `launch` 서비스(`bin/status.sh`). 훅·시스템 파일·Wi-Fi 설정은 건드리지 않음 |

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
    APP["상태 화면 앱<br/>+ launch 서비스(status.sh)"]
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

같은 판도 같은 차례로 돌고, 이미 된 단계는 건너뜁니다. 설치기는 재부팅하지 않고 상태 화면의 [지금 재부팅]을 안내합니다. 단계별 규칙은 `design.md` "설치·업데이트 순서"에 있습니다.

```mermaid
flowchart TD
  S(["Update OTA 누름"]) --> DIAG["진단 기록을 모을지 화면에서 물음<br/>(DiagActivity, 60초, 아무것도 바꾸기 전)"]
  DIAG --> UN{"NX4/UNINSTALL<br/>또는 UNINSTALL-ALL?"}
  UN -->|"예"| DEL["아래 5절 지우기로"]
  UN -->|"아니요"| H{"HMG-API가 있고<br/>1.1.0-rc.8 이상?"}
  H -->|"없거나 낮음 +<br/>스틱의 HMG-API가 충분"| HU["스틱의 HMG-API 설치기로 넘김<br/>→ 재부팅 → Update OTA 한 번 더"]
  H -->|"없거나 낮음 +<br/>스틱에 없음"| STOP1["멈춤: HMG-API를 먼저 올려 주세요<br/>(아무것도 바꾸지 않음)"]
  H -->|"예"| S0{"0. 스틱의 nx4-kor가<br/>2.1.0 꼴?"}
  S0 -->|"아니요(2.0.x 꼴)"| STOP2["멈춤(아무것도 바꾸지 않음)"]
  S0 -->|"예"| SAME{"같은 판이고<br/>상태 화면 앱 있음?"}
  SAME -->|"예"| OPEN0["상태 화면을 먼저 엶"]
  SAME -->|"아니요"| P1
  OPEN0 --> P1{"1. 시작 전 계획<br/>(engine plan)"}
  P1 -->|"다른 모드의 적용 안 한 변경,<br/>모르는 되돌리기, 계획 실패"| STOP3["멈춤: HMG-API 앱에서 적용<br/>(아무것도 바꾸지 않음)"]
  P1 -->|"괜찮음"| KP["한국 차 빌드 무선 모드(Korea Projection 2.4.x)가<br/>있으면 먼저 engine remove"]
  KP --> OLD["2. 옛 NX4 KOR 2.0.x 되돌리기<br/>engine remove → apply →<br/>옛 판 uninstall.sh(사본, 또는 스틱의 legacy-2.0)"]
  OLD --> WM["3. 공식 무선 모드<br/>없거나 낮으면 engine install --any-car,<br/>꺼져 있으면 enable"]
  WM --> NK["4. nx4-kor<br/>새 판이면 uninstall.sh --update → engine install<br/>→ 상태 화면 엶"]
  NK --> MAP{"5. 이 차의 map<br/>(state/local-map.json)?"}
  MAP -->|"없음"| MW["engine map-car --write<br/>(1~2분)"]
  MAP -->|"있음"| MV
  MW --> MV["engine verify-map"]
  MV -->|"실패"| MF["이번에 만든 map만 지움(map-car --forget)<br/>→ 실패로 끝(적용 안 함)"]
  MV -->|"통과"| AP{"6. 끝 계획이 우리 두 모드의 변경·되돌리기뿐이고<br/>훅이 켜지나?"}
  AP -->|"아니요"| AF["적용하지 않고 끝<br/>(HMG-API 앱에서 보라고 안내)"]
  AP -->|"예"| APPLY["engine apply"]
  APPLY --> R{"7. 무엇이 바뀌었나?"}
  R -->|"예"| RB["진행 기록 state=reboot<br/>상태 화면: [지금 재부팅]"]
  R -->|"아니요"| DONE["state=done<br/>설정이 끝나 있습니다"]
```

- 진행 기록 `/data/local/tmp/nx4-kor-progress.txt`(`state`: `run`·`done`·`reboot`·`fail`)는 1단계 뒤 무엇을 바꾸기 시작할 때부터 씁니다. 상태 화면이 이 파일로 막대와 결과를 그립니다.
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
  H->>H: map 확인(state/map-check.json)과 부팅 보호(hook/starts) 확인
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

## 4. 상태 화면

```mermaid
sequenceDiagram
  autonumber
  actor U as 운전자
  participant App as 상태 화면 앱
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

판정은 `bin/status.sh`의 `st_verdict` 한 곳에서 정하고, 앞에서부터 처음 맞는 것이 판정입니다. 읽기만 하고 아무것도 바꾸지 않습니다(전체 표는 `design.md` "상태 화면").

```mermaid
flowchart LR
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
  Q -->|"USB NX4/UNINSTALL"| U1["설치기: nx4-kor의 bin/uninstall.sh<br/>(모드 폴더가 없으면 스틱의 사본)"]
  Q -->|"USB NX4/UNINSTALL-ALL"| U1
  Q -->|"HMG-API 앱에서 모드만 지움"| AR["engine remove nx4-kor<br/>앱·서비스·타일이 내려감"]
  U1 --> PR["preun.sh: 감시자 멈춤, 상태 화면 작업 파일 지움<br/>→ engine remove nx4-kor(적용할 것 없음)"]
  PR --> RM["기록 폴더 /data/nx4-kor 지움<br/>(2.0.x backup이 있으면 스틱의 legacy-2.0으로 마저 되돌림)"]
  RM --> ALL{"UNINSTALL-ALL?"}
  ALL -->|"예"| WR["공식 무선 모드도 engine remove<br/>→ 계획이 되돌리기뿐이면 apply"]
  ALL -->|"아니요"| FIN
  WR --> FIN(["재부팅<br/>HMG-API와 이 차의 map은 남음"])
  AR --> LEFT["기록 파일만 남음<br/>(/data/nx4-kor, /data/local/tmp/nx4-kor*)<br/>→ USB UNINSTALL로 정리"]
```

- 상태 화면에는 지우기 버튼을 두지 않습니다([#44](https://github.com/jay-park-lab/hmgapi-nx4-kor/issues/44)). 2.1.0의 nx4-kor는 시스템 파일·Wi-Fi 설정을 바꾸지 않아 HMG-API 앱에서 지워도 기록 파일만 남기 때문입니다.
- USB 설치기 자신의 기록(`nx4-kor-usb.log`, 차에서는 `nx4-kor-ota-finish.sh`)은 지우기 뒤에도 남습니다.
- 둘 다 지울 때는 NX4 KOR를 먼저, HMG-API를 나중에 지웁니다(README "삭제").
