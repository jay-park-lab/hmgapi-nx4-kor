# Korea Projection

> [!NOTE]
> **이 문서의 USB Wi-Fi 동글 구매 링크는 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.**
>
> 동글이 필요하신 분은 [아래 쿠팡 링크](#usb-wi-fi-동글-180-준비-중)로 구매해 주시면 개발에 큰 응원이 됩니다.
>
> 퇴근 후와 주말에 만들고 있습니다. [커피 한 잔](https://ko-fi.com/stopdragon)이나 [GitHub Sponsors](https://github.com/sponsors/StopDragon) 후원은 시험용 부품을 사는 데 씁니다.
>
> [![GitHub Sponsors](https://img.shields.io/badge/GitHub%20Sponsors-%ED%9B%84%EC%9B%90%ED%95%98%EA%B8%B0-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/StopDragon) [![Ko-fi](https://img.shields.io/badge/Ko--fi-%EC%BB%A4%ED%94%BC%20%ED%95%9C%20%EC%9E%94-FF5E5B?style=for-the-badge&logo=kofi&logoColor=white)](https://ko-fi.com/stopdragon)

한국 현대·기아 내비(Gen5W 헤드유닛)에서 **무선 카플레이**와 **무선 안드로이드 오토**를 쓸 수 있게 해 주는 NEMESIS 패키지입니다.

- 한국 5W 펌웨어에서는 wifi 모듈을 사용할 수 없어 무선 카플레이 혹은 무선 안드로이드 오토를 무선으로 사용할 수 없습니다.
- HMG-API 무선 모드와 그 차의 지도도 **자동으로 설치**하므로 HMG-API 앱에서 따로 설정하지 않아도 됩니다.

> ⚠️ 취미 목적으로 개발된 차량 소프트웨어를 바꾸는 일입니다. 모든 책임은 설치하신 차주 본인에게 있습니다.

> [!IMPORTANT]
> **이 저장소는 [StopDragon/korea-projection](https://github.com/StopDragon/korea-projection)의 포크입니다.** 원본과 다른 점은 다음과 같습니다.
> - **NEMESIS 없이 설치할 수 있습니다(투싼 NX4 전용).** 같은 스크립트를 HMG-API 모드로 감싸, HMG-API(1.0.2 이상)만 있으면 Engineering Mode의 USB 설치(DSP Update OTA)로 설치·업데이트·삭제합니다. [아래 설치](#nemesis-없이-설치-투싼-nx4-이-포크)를 보시고, 자세한 동작은 [`standalone/README.md`](standalone/README.md)에 있습니다.
> - **NEMESIS 버전 판정을 뺐습니다.** 상태 화면·리포트·QR이 NEMESIS 버전을 보지 않습니다("NEMESIS를 1.16 이상으로" 안내가 나오지 않습니다).
> - HMG-API를 먼저 지웠어도 USB `UNINSTALL`로 이 패키지가 바꾼 Wi-Fi 설정을 되돌립니다.
> - **차에서 아직 확인하지 않았습니다**(PC 시험만). 이 포크에는 릴리스 묶음이 없어 직접 만듭니다([만들기](standalone/README.md#만들기)).
> - 차량 제보·질문·릴리스는 원본 저장소의 것입니다. 이 문서의 이슈·릴리스 링크는 원본으로 갑니다.
<br>

## 지원 차량

> 이 표는 원본(NEMESIS판)의 차주 제보 기준입니다. 이 포크의 **NEMESIS 없는 설치는 투싼 NX4·NX4 하이브리드(`NX4`·`NX4HEV`, 260902)만** 받습니다.

**✅ 확인 46종** (현대 그랜저·쏘나타·아반떼·싼타페·팰리세이드·투싼·캐스퍼·벨로스터 N·코나 EV·아이오닉 5, 기아 니로·K5·K7 프리미어·K8·쏘렌토·스팅어·K3·쏘울 부스터 EV·셀토스·EV6·카니발·레이·모하비, 제네시스 G70) · **🧪 시험 중 9종**. 

목록에 없는 한국 차(`*.KOR.*`)도 설치하면 **자동으로 시도**합니다. 

<details>
<summary><b>차종별 지원 목록 펼치기</b></summary>

내비 소프트웨어는 대부분 `<코드>.KOR.0000.V039.001.260902`입니다. 표에는 앞의 코드만 적었습니다.

**현대**

| 차종 | 연식·세부 | 코드 | 상태 |
|---|---|---|---|
| 그랜저 | 2021 2.5 가솔린 (IG PE) | `IGPE` | ✅ 확인 ([#70](https://github.com/StopDragon/korea-projection/issues/70)) |
| | 2021 3.0 LPI (IG PE) | `IGPE21` | ✅ 확인 ([#71](https://github.com/StopDragon/korea-projection/issues/71)) |
| | 2022 하이브리드 (IG PE) | `IGPE21HEV` | ✅ 확인 ([#324](https://github.com/StopDragon/korea-projection/issues/324)) |
| | 2020 하이브리드 (IG) | `IGPEHEV` | ✅ 확인 ([#72](https://github.com/StopDragon/korea-projection/issues/72)) |
| 쏘나타 | 2021 하이브리드 (DN8) | `DN822HEV` | ✅ 확인 ([#67](https://github.com/StopDragon/korea-projection/issues/67)) |
| 벨로스터 N | 2021 (JS) | `JSN` | ✅ 확인 ([#73](https://github.com/StopDragon/korea-projection/issues/73)) |
| 팰리세이드 | 2019 (LX2) | `LX2` | ✅ 확인 ([#74](https://github.com/StopDragon/korea-projection/issues/74)) |
| 아이오닉 | 2020 플러그인 하이브리드 (AE PE) | `AEPEPHEV` | 🧪 시험 중 ([#59](https://github.com/StopDragon/korea-projection/issues/59)) |
| | 2019 하이브리드 (AE PE) | `AEPEHEV` | 🧪 시험 중 ([#303](https://github.com/StopDragon/korea-projection/issues/303)) |
| 아이오닉 5 | 2022 (NE) | `NEEV` | ✅ 확인 ([#301](https://github.com/StopDragon/korea-projection/issues/301)) |
| 아반떼 | 2021 가솔린 (CN7) | `CN7` | ✅ 확인 ([#124](https://github.com/StopDragon/korea-projection/issues/124)) |
| | 2021 하이브리드 (CN7) | `CN7HEV` | ✅ 확인 ([#103](https://github.com/StopDragon/korea-projection/issues/103)) |
| | N 2021 (CN7 N) | `CN7N` | ✅ 확인 ([#299](https://github.com/StopDragon/korea-projection/issues/299)) |
| 싼타페 | 2021 (TM PE) | `TMFL` | ✅ 확인 (무선 안드로이드 오토, [#104](https://github.com/StopDragon/korea-projection/issues/104)) |
| 캐스퍼 | 2021 (AX1) | `AX1` | ✅ 확인 ([#105](https://github.com/StopDragon/korea-projection/issues/105)) |
| 쏘나타 | 2021 2.0 가솔린 (DN8) | `DN8` | ✅ 확인 (무선 안드로이드 오토, [#127](https://github.com/StopDragon/korea-projection/issues/127)) |
| | 2022 LPI (DN8) | `DN822` | 🧪 시험 중 ([#233](https://github.com/StopDragon/korea-projection/issues/233)) |
| 투싼 | 2021 하이브리드 (NX4) | `NX4HEV` | ✅ 확인 ([#125](https://github.com/StopDragon/korea-projection/issues/125)) |
| | 2021 가솔린 (NX4) | `NX4` | ✅ 확인 (순정 핫스팟을 쓰는 차, [#126](https://github.com/StopDragon/korea-projection/issues/126)) |
| 코나 | 2021 EV (OS) | `OSEV` | ✅ 확인 ([#227](https://github.com/StopDragon/korea-projection/issues/227)) |
| | 2020 하이브리드 (OS) | `OSHEV` | 🧪 시험 중 ([#304](https://github.com/StopDragon/korea-projection/issues/304)) |
| 포터2 | 2024 EV (HR) | `HREV24` | 🧪 시험 중 ([#230](https://github.com/StopDragon/korea-projection/issues/230)) |
| 베뉴 | 2025 (QX) | `QX23` | 🧪 시험 중 ([#307](https://github.com/StopDragon/korea-projection/issues/307)) |

**기아**

| 차종 | 연식·세부 | 코드 | 상태 |
|---|---|---|---|
| 니로 | 2020 하이브리드 (DE PE) | `DEPEHEV` | ✅ 확인 (개발 차, 무선 안드로이드 오토, [#64](https://github.com/StopDragon/korea-projection/issues/64)) |
| | 2020 플러그인 하이브리드 (DE) | `DEPEPHEV` | ✅ 확인 (무선 안드로이드 오토, [#65](https://github.com/StopDragon/korea-projection/issues/65)) |
| | 2023 하이브리드 (SG2) | `SG2HEV` | ✅ 확인 ([#78](https://github.com/StopDragon/korea-projection/issues/78)) |
| | 2021 EV (DE) | `DE22EV` | ✅ 확인 (무선 안드로이드 오토, [#309](https://github.com/StopDragon/korea-projection/issues/309)) |
| | 2023 EV (SG2) | `SG2EV` | ✅ 확인 (순정 핫스팟을 쓰는 차, [#128](https://github.com/StopDragon/korea-projection/issues/128)) |
| K5 | 2020 하이브리드 (DL3) | `DL3HEV` | ✅ 확인 ([#66](https://github.com/StopDragon/korea-projection/issues/66)) |
| | 2020 가솔린 (DL3) | `DL3` | ✅ 확인 (무선 안드로이드 오토, [#130](https://github.com/StopDragon/korea-projection/issues/130)) |
| | 2022 하이브리드 (DL3) | `DL3HEV22` | ✅ 확인 (무선 안드로이드 오토, [#135](https://github.com/StopDragon/korea-projection/issues/135)) |
| | 2022 가솔린 (DL3) | `DL322` | ✅ 확인 (무선 안드로이드 오토, [#226](https://github.com/StopDragon/korea-projection/issues/226)) |
| K7 프리미어 | 2021 (YG) | `YGPE` | ✅ 확인 ([#79](https://github.com/StopDragon/korea-projection/issues/79)) |
| | 2019 하이브리드 (YG PE) | `YGPEHEV` | ✅ 확인 ([#80](https://github.com/StopDragon/korea-projection/issues/80)) |
| 쏘렌토 | 2022 하이브리드 (MQ4) | `MQ422HEV` | ✅ 확인 ([#76](https://github.com/StopDragon/korea-projection/issues/76)) |
| | 2022 디젤 (MQ4) | `MQ422` | ✅ 확인 ([#134](https://github.com/StopDragon/korea-projection/issues/134)) |
| | 2021 하이브리드 (MQ4) | `MQ4HEV` | ✅ 확인 (무선 안드로이드 오토, [#97](https://github.com/StopDragon/korea-projection/issues/97)) |
| | 2021 가솔린·디젤 (MQ4) | `MQ4` | ✅ 확인 ([#300](https://github.com/StopDragon/korea-projection/issues/300)) |
| K3 | BD PE | `BDPE` | ✅ 확인 ([#60](https://github.com/StopDragon/korea-projection/issues/60)) |
| K8 | 2023 하이브리드 (GL3) | `GL3HEV` | ✅ 확인 ([#69](https://github.com/StopDragon/korea-projection/issues/69)) |
| | 2023 2.5 가솔린 (GL3) | `GL3` | ✅ 확인 (무선 안드로이드 오토, [#68](https://github.com/StopDragon/korea-projection/issues/68)) |
| EV6 | 2022 (CV) | `CVEV` | ✅ 확인 ([#63](https://github.com/StopDragon/korea-projection/issues/63)) |
| 스포티지 | 2020 가솔린 (NQ5) | `NQ5` | 🧪 시험 중 ([#77](https://github.com/StopDragon/korea-projection/issues/77)) |
| | 2022 하이브리드 (NQ5) | `NQ5HEV` | ✅ 확인 ([#379](https://github.com/StopDragon/korea-projection/issues/379)) |
| 스팅어 | 2021 (CK PE) | `CKPE` | ✅ 확인 ([#61](https://github.com/StopDragon/korea-projection/issues/61)) |
| | 마이스터 2022 (CK PE) | `CKPE22` | ✅ 확인 ([#228](https://github.com/StopDragon/korea-projection/issues/228)) |
| 쏘울 부스터 | 2019 EV (SK3) | `SK3EV` | ✅ 확인 ([#129](https://github.com/StopDragon/korea-projection/issues/129)) |
| 셀토스 | 2020 (SP2) | `SP221` | ✅ 확인 ([#229](https://github.com/StopDragon/korea-projection/issues/229)) |
| | 2022 (SP2) | `SP222` | ✅ 확인 ([#305](https://github.com/StopDragon/korea-projection/issues/305)) |
| 카니발 | 2022 (KA4) | `KA422` | ✅ 확인 ([#232](https://github.com/StopDragon/korea-projection/issues/232)) |
| | 2021 (KA4) | `KA4` | ✅ 확인 (무선 안드로이드 오토, [#302](https://github.com/StopDragon/korea-projection/issues/302)) |
| 레이 | 2022 (TAM) | `TAM22` | ✅ 확인 (내비 `V038 260604`에서 확인, [#234](https://github.com/StopDragon/korea-projection/issues/234)) |
| | 2023 (TAM PE) | `TAMPE` | 🧪 시험 중 ([#306](https://github.com/StopDragon/korea-projection/issues/306)) |
| 모하비 | 더 마스터 2022 (HM) | `HM22` | 🧪 시험 중 ([#231](https://github.com/StopDragon/korea-projection/issues/231)) |
| | 더 마스터 2021 (HM) | `HM21` | ✅ 확인 ([#308](https://github.com/StopDragon/korea-projection/issues/308)) |

**제네시스**

| 차종 | 연식·세부 | 코드 | 상태 |
|---|---|---|---|
| G70 | 2021 (IK FL) | `IKFL` | ✅ 확인 (순정 핫스팟을 쓰는 차, [#225](https://github.com/StopDragon/korea-projection/issues/225)) |

**상태 뜻**
- ✅ **확인:** 차주 제보로 **무선 카플레이 또는 무선 안드로이드 오토 연결**을 확인한 차입니다. 계기판 안내 같은 부가 기능의 문제는 차종 이슈에서 따로 고칩니다.
- 🧪 **시험 중:** 설치하면 무선 설정을 시도하지만, 아직 무선 카플레이·안드로이드 오토 연결이 확인되지 않은 차입니다. 되든 안 되든 [제보](docs/car-report-guide.md)해 주세요.
- **순정 핫스팟을 쓰는 차:** 내비에 무선 카플레이용 핫스팟이 원래 들어 있어, Korea Projection이 그 핫스팟을 쓰는 차입니다. 순정 상태로 무선 카플레이가 되는 차라는 뜻은 아닙니다.

</details>

내 차에서 되는지 알려 주시면 지원 목록에 추가합니다. [차량 제보 양식](https://github.com/StopDragon/korea-projection/issues/new?template=car-report.yml)으로 올리시면 **같은 차종의 [차종별 제보 이슈](https://github.com/StopDragon/korea-projection/issues?q=label%3A%22%F0%9F%93%8C+%EC%B0%A8%EC%A2%85+%EC%9D%B4%EC%8A%88%22)로 자동으로 모입니다.** 설치 방법 같은 질문은 [설치·사용 질문](https://github.com/StopDragon/korea-projection/issues/new?template=question.yml)으로 받습니다.

작동 여부를 떠나 꼭 제보를 해주세요.
[내 차 제보 가이드](docs/car-report-guide.md)대로 USB를 꽂고 Launch 화면의 **[제보 파일 만들기]**를 눌러, USB의 `KoreaProjection-report` 폴더 안 **파일 3개**를 내 차종 이슈에 댓글로 보내 주세요. 된다고 알려 주시면 그 차를 **✅ 확인됨**으로 올리고, 안 되면 파일 속 기록으로 원인을 찾습니다.

<br>

### USB Wi-Fi 동글 (1.8.0 준비 중)

내비에 Wi-Fi 부품이 없거나 모종의 이유로 Wi-Fi 칩이 켜지지 않는 차를 위해 **1.8.0에서 USB Wi-Fi 동글 지원을 준비하고 있습니다.**

> ⚠️ **지금 판(1.7.x)은 동글을 쓰지 않습니다.** 동글을 꽂아도 무선 카플레이·안드로이드 오토가 켜지지 않습니다. 아래는 1.8.0에서 지원할 예정인 동글이며, **아직 차에서 확인하지 않았습니다.** 1.8.0이 나오고 차에서 확인되면 이 표에 ✅로 표시합니다.

| 제품 | 상태 | 구매 |
|---|---|---|
| ipTIME A3000MINI | 🧪 1.8.0 준비 중 | [link.coupang.com/a/izqnJc9AJg](https://link.coupang.com/a/izqnJc9AJg) |
| TP-Link Archer T3U | 🧪 1.8.0 준비 중 | [link.coupang.com/a/izqs0SMtaK](https://link.coupang.com/a/izqs0SMtaK) |
| 리버네트워크 NEXI NX-AC1300 | 🧪 1.8.0 준비 중 | [link.coupang.com/a/izq0opYmQe](https://link.coupang.com/a/izq0opYmQe) |


> 이 링크를 통해 구매하시면, 개발자가 소정의 수수료를 쿠팡에게 제공받습니다. 개발에 큰 도움이 됩니다.

<br>

## 질문·제보는 GitHub에서, 사용자끼리 이야기는 오픈 카톡방에서

- **공식 질문과 차량 제보·버그 신고는 GitHub 이슈로만 받습니다.** [차량 제보](https://github.com/StopDragon/korea-projection/issues/new?template=car-report.yml)와 [설치·사용 질문](https://github.com/StopDragon/korea-projection/issues/new?template=question.yml) 양식을 써 주세요.
- **사용자끼리 이야기하는 곳:** [Korea Projection 오픈 카톡방](https://open.kakao.com/o/p58zKvWi). 사용 후기와 팁을 나누는 방입니다. 제작자가 답하는 공식 창구가 아닙니다.
- 카톡방에 올린 질문·제보는 처리하지 않습니다. 기록이 남지 않고 제보 파일을 확인할 수 없기 때문입니다. 도움이 필요하면 GitHub 이슈로 올려 주세요.
- 카톡방에는 제보 파일·로그·차대번호 같은 개인정보를 올리지 마세요.
<br>
## 필요한 것

| | NEMESIS 없이 (이 포크, 투싼 NX4) | NEMESIS로 (원래 방식) |
|---|---|---|
| **NEMESIS** | 필요 없음 | 필요(원본 안내는 1.16 이상. 이 포크의 상태 화면은 NEMESIS 버전을 보지 않습니다) |
| **HMG-API** | 1.0.2 이상, USB로 설치(NEMESIS 필요 없음) | 1.0.2 이상 |
| **Korea Projection** | `korea-projection-버전-standalone-usb.zip`(직접 만듦) | `korea-projection-버전-usb.zip`(원본 릴리스) |

나머지는 Korea Projection이 알아서 갖춥니다(두 방식 같음).
- **HMG-API 무선 모드**(1.7.4부터 이름 `Korea Projection: Wireless CarPlay + Android Auto`, 1.7.3까지는 `Wireless CarPlay + Android Auto`로 보입니다. HMG-API 공식 모드와 헷갈리지 않게 이름을 바꿨습니다): 없으면 설치하고, 이 패키지가 넣은 모드가 예전 판이면 새 판으로 바꿉니다. 차주가 일부러 지우거나 꺼 둔 것은 다시 설치하지 않습니다.
- 넣는 무선 모드는 HMG-API 공식 모드에 한국 차를 더한 **"한국 차 빌드"**입니다. HMG-API 공식판에 한국 차 지원이 아직 없기 때문입니다([VysseCodes/HMG-API#22](https://github.com/VysseCodes/HMG-API/pull/22)). 공식판이 지원하면 공식 모드로 옮깁니다.
- Korea Projection을 삭제하면 함께 설치했던 무선 모드도 지웁니다.
- 그 차의 HMG-API 지도가 없으면 넣거나 그 차에서 만들고 확인합니다. NX4는 HMG-API와 이 패키지 어디에도 지도가 없어 그 차에서 만듭니다.

`wireless.projection` 패키지는 **필요 없습니다.** 설치되어 있으면 먼저 삭제해 주세요.

<br>

## 설치

### NEMESIS 없이 설치 (투싼 NX4, 이 포크)

HMG-API의 모드 기능(서비스·앱·앱 메뉴 타일)으로 돌립니다. NEMESIS가 하던 일을 무엇이 대신하는지, 지우기·만들기는 [`standalone/README.md`](standalone/README.md)에 있습니다.

1. **HMG-API 설치(NEMESIS 필요 없음):** HMG-API [릴리스](https://github.com/Open-HMG/HMG-API/releases)의 `hmgapi-버전-usb.zip`을 FAT32 USB 맨 위에 풀고 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다. 재부팅될 때까지 기다립니다.
   - USB의 `HMGAPI/install.log`에 `isn't a known stock build`가 있으면 HMG-API 설치기가 이 차의 `app_process`를 모르는 것입니다(설치기가 아는 것은 EV6 미국 260507 하나). NEMESIS로 설치해도 같은 확인을 거칩니다. 그때는 `HMGAPI/FORCE` 빈 파일을 만들고 다시 합니다(자기 책임).
2. **Korea Projection 설치:** `korea-projection-버전-standalone-usb.zip`(`scripts/build-standalone.sh`로 만듦)을 USB 맨 위에 풀고 다시 Update OTA를 누릅니다.
   ```
   USB
   ├─ ota_package.tar
   ├─ README.txt
   └─ KoreaProjection
       └─ install (korea-projection.zip, payload)
   ```
   - HMG-API USB 묶음을 함께 넣어 만들었으면(`HMGAPI_USB_ZIP`) 같은 USB로 두 번 하면 됩니다. 첫 번째에 HMG-API를 설치하고 재부팅, 두 번째에 Korea Projection을 설치합니다.
3. 상태 화면이 열리고 설정 진행이 보입니다. OTA 화면의 오류 684는 정상입니다. NX4에는 HMG-API 지도가 없어 HMG-API가 그 차의 파일로 지도를 만들고 확인합니다. **3~5분 동안 끄지 마세요.**
4. "무선 카플레이 설정을 마쳤습니다"가 나오면 **[지금 재부팅]**을 누릅니다(또는 RESET 버튼).
5. 폰에서 무선 카플레이(또는 무선 안드로이드 오토)를 연결합니다.

- 같은 USB로 Update OTA를 다시 누르면 다시 설치하지 않고 상태 화면만 엽니다. 업데이트는 새 판 USB로 같은 방법으로 하고, 같은 판을 다시 설치하려면 `KoreaProjection/REINSTALL` 빈 파일을 만듭니다.
- NEMESIS판 Korea Projection과 함께 쓰지 않습니다. 둘 다 있으면 이 판은 아무것도 하지 않고, 설치기도 설치하지 않습니다.
- 차에서 확인할 것(재부팅 없이 끝내는 DSP OTA, 상태 화면 열기 등)은 [`standalone/README.md`](standalone/README.md#차에서-확인할-것)에 있습니다.

### NEMESIS로 설치 (원래 방식)

처음이시면 **[설치 가이드](docs/install-guide.md)**를 따라 하세요. 포맷부터 폰 연결, 잘 안 될 때까지 한 단계씩 적었습니다.

1. USB를 **FAT32**로 포맷합니다(32GB 이하 USB 권장).
2. [릴리스](https://github.com/StopDragon/korea-projection/releases/latest)에서 **`korea-projection-가장 최신 버전-usb.zip`**을 받습니다.
3. 압축을 풀고, 풀린 폴더 **안에 있는 것**을 USB **맨 위**에 복사합니다.
   ```
   USB
   ├─ NEMESIS.data
   ├─ README.txt
   └─ packages
       └─ korea.projection.zip   ← 이 파일은 압축을 풀지 마세요
   ```
4. 내비 화면이 다 뜬 뒤 USB를 꽂고, 설치할지 물으면 **예**를 누릅니다.
5. USB를 빼고 **3~5분 기다립니다.** 이 동안 재부팅하지 마세요.
   - NAV 버튼을 3번 연속 눌러 NEMESIS Manager에서 이 패키지(Korea Projection: Wireless for Korean Cars)의 **Launch**를 누르면 설치 진행 막대와 알림이 보입니다(뜰 때까지 약10초 소요).
   - "설정을 마쳤습니다" 알림이 뜨면 **내비를 재부팅합니다**. ([자세히](docs/install-guide.md#내비-재부팅하는-법)). 시동만 끄면 내비가 꺼지지 않을 수 있습니다.
6. 폰에서 무선 카플레이(또는 무선 안드로이드 오토)를 연결합니다.

예전 버전에서 업데이트할 때도 같은 방법으로 설치하면 됩니다. 단 **1.7.4는 1.7.3 이상에서만 바로 업데이트**됩니다. 1.7.2 이하는 먼저 삭제 → 재부팅 → 설치하세요([업데이트하는 법](docs/install-guide.md#업데이트하는-법)).

NEMESIS Manager의 Package Store에 올라간 판은 최신이 아닐 수 있습니다. 최신 판은 위 방법대로 릴리스의 USB 묶음으로 설치하세요.

<br>

## 상태 확인과 제보

NEMESIS Manager → My Packages → **Korea Projection: Wireless for Korean Cars** → **Launch**를 누르세요.

**NEMESIS 없이 설치했으면** 앱 메뉴의 **Korea Projection** 타일을 누릅니다. 타일은 HMG-API 훅이 켜진 뒤(지도 확인 후 재부팅)에 생깁니다. 그 전에는 설치 USB로 Update OTA를 다시 누르면 상태 화면이 열립니다. 화면이 열릴 때 HMG-API가 상태를 새로 쓰므로 아래 설명은 같습니다("Launch를 다시 누르면"은 "화면을 다시 열면"으로 읽으세요).

- 내비 화면에 **상태 화면**이 뜹니다. 제목의 숫자가 설치된 판입니다(예: Korea Projection 1.7.3).
  - 맨 위에 한 줄 판정이 색으로 나옵니다(초록: 준비됨/연결됨, 노랑: 확인 필요, 빨강: 문제). 1.7.3부터는 "Wi-Fi를 켜는 중", "Wi-Fi 부품이 없어…", "설치 중입니다" 같은 판정과 남은 재부팅 횟수도 여기에 나옵니다. 준비되면 "무선 카플레이·안드로이드 오토 준비됨.", 연결되면 "무선 카플레이 연결됨, 안드로이드 오토 준비됨"처럼 카플레이와 안드로이드 오토를 한 줄로 알려 줍니다. Wi-Fi는 하나라서 한쪽이 연결되면 다른 쪽은 "준비됨"으로 보입니다.
  - 그 아래에 **요약 3줄**(설치 / 무선 Wi-Fi / 폰 연결)이 나오고, 자세한 상태표는 "자세히(제보용)" 아래에 있습니다.
  - 노란 **알림** 줄에는 설치 중 안내가 나옵니다(이번 부팅, 최근 30분 안의 것). 아이폰이 붙지 않으면 노란 안내 줄에 "아이폰이 차 Wi-Fi에 오지 않습니다…" 또는 "폰이 차 Wi-Fi에 연결됐지만 카플레이가 시작되지 않았습니다. 내비를 재부팅해 주세요."가 나옵니다.
- 오른쪽 **QR을 폰 카메라로 찍으면** 내용이 채워진 [차량 제보](https://github.com/StopDragon/korea-projection/issues/new?template=car-report.yml) 양식이 열립니다. 제출하면 같은 차종 이슈로 자동으로 옮겨집니다. 차종과 결과만 고르고 제출하면 됩니다.
  - 설치 중이거나 재부팅이 필요할 때는 QR 대신 "제보 QR은 설정이 끝난 뒤 Launch를 다시 누르면 나옵니다."가 나옵니다.
- **[지금 재부팅]** 버튼은 늘 **[제보 파일 만들기]** 옆에 있습니다. 차를 세운 상태에서만 누르세요. 설치 중이면 "설정을 마무리하는 중입니다. 잠시 뒤 다시 눌러 주세요.", 켜진 지 3분이 안 됐으면 "3분 안에 재부팅을 반복하면 HMG-API가 무선 기능을 끕니다. 내비가 켜지고 3~5분 뒤에 다시 눌러 주세요."가 나옵니다. **재부팅을 짧게 여러 번 하지 말고 3분 넘게 켜 두세요**(HMG-API 부팅 보호, [자세히](docs/install-guide.md#내비-재부팅하는-법)).
- 폴더 안 파일 3개를 [내 차 제보 가이드](docs/car-report-guide.md)대로 내 차종 이슈에 첨부해 주세요.

  
<br>

## 알아 두실 점


- 설치 뒤 약 5분 동안 재부팅하지 마세요.
- 차 설정에서 ADB TCP가 켜져 있으면 HMG-API가 경고를 띄웁니다. 이 패키지는 `192.168.43.x` 대역을 써서 영향이 없었습니다.
- **계기판 안내의 한계:** 계기판·HUD 길안내는 **폰의 지도 앱이 보내 주는 정보까지만** 나와서 순정 내비와 똑같지는 않습니다. 폰이 보내는 것은 다음 회전의 종류·방향·남은 거리·도로 이름 정도라, 지하차도·고가차도 구분, 일부 갈림길(Y자)·회전교차로 모양, 방면 표시는 순정과 다르거나 안 나올 수 있습니다. **지도 앱마다 보내는 정보가 달라서**(애플 지도·T맵·카카오내비·네이버 지도·구글 지도) 같은 길도 앱에 따라 그림이 다르고, 앱이 안내를 보내지 않으면(정차 중, 앱·iOS 판에 따라) 나오지 않습니다. 순정과 다르게 나오는 곳은 **지도 앱 이름, 어떤 길(지하차도·회전교차로 등), 그때 만든 제보 파일**과 함께 알려 주세요.

<br>

## 삭제

### NEMESIS 없이 설치한 경우

설치 USB의 `KoreaProjection` 폴더에 빈 파일 `UNINSTALL`을 만들고 Engineering Mode → USB Copy → DSP → Update OTA를 누릅니다. 아래 NEMESIS판 삭제와 같은 것을 되돌린 뒤 HMG-API에서 이 모드를 지우고 재부팅합니다(상태 화면 앱도 함께 지워집니다).

- **HMG-API 앱에서 모드만 지우거나 HMG-API를 먼저 지우면** 이 패키지가 직접 바꾼 것(Wi-Fi 설정 파일 잠금, 순정 AP 저장값, 권한 파일)은 그대로 남습니다. HMG-API 삭제는 HMG-API를 통해 바꾼 것만 되돌리기 때문입니다. 그때도 USB `UNINSTALL`을 하면 됩니다. HMG-API가 없어도 남은 모드 폴더나 USB의 사본으로 되돌리고, 남은 모드 폴더와 상태 화면 앱도 지웁니다.
- 둘 다 지울 때는 **Korea Projection을 먼저, HMG-API를 나중에** 지우는 것을 권합니다.
- HMG-API 일반 삭제(`HMGAPI/UNINSTALL`)는 모드 파일·설정을 남기고 모드 앱을 꺼 두기만 합니다. 모두 지우려면 `HMGAPI/UNINSTALL-PURGE`를 씁니다.

### NEMESIS로 설치한 경우

NEMESIS Manager → My Packages → **Korea Projection: Wireless for Korean Cars** → **Uninstall**을 누르면 다음과 같이 정리됩니다.
- 이 패키지가 켠 핫스팟과 DHCP를 멈춥니다.
- 이 패키지가 설치한 HMG-API 무선 모드를 지우고 적용합니다. 차주가 직접 넣은 모드와 지도는 남깁니다.
- 설정 파일, 작업 폴더, 백업을 지웁니다.
- 설치 전에 Wi-Fi가 꺼져 있던 차는 다시 끕니다.
- 잠갔던 Wi-Fi 설정 파일의 소유자·권한과 함께 치운 파일을 원래대로 되돌립니다.
- 삭제가 끝나면 **내비를 재부팅해 주세요**([재부팅하는 법](docs/install-guide.md#내비-재부팅하는-법)). 일반 Wi-Fi가 원래대로 돌아옵니다.

삭제할 때 Wi-Fi를 껐다 켜지 않는 이유가 있습니다. 니로에서 확인해 보니 Wi-Fi를 껐다 켜면 Wi-Fi·블루투스 모듈이 다시 시작되고, 블루투스 카플레이가 재부팅 전까지 되지 않았습니다.

<br>

## 만들기와 시험 (이 포크)

- NEMESIS 없이 설치하는 HMG-API 모드판: `standalone/`(mod.json, 서비스 래퍼, USB 설치기). NEMESIS판 스크립트(`nemesis-pkg/korea.projection/`)는 그대로 쓰고, 환경 변수가 있을 때만 다르게 돕니다.
- 묶음 만들기: `scripts/build-standalone.sh`. HMG-API 소스(`HMGAPI_SRC`)와 모드 작성자 키(`KP_MOD_KEY`)가 필요합니다([`standalone/README.md`](standalone/README.md#만들기)). 상태 화면 앱은 `scripts/build-app.sh`(Android SDK)로 이 포크의 소스에서 빌드한 것을 써야 합니다. 화면이 열릴 때 `hmgapid service-start launch`를 불러 상태를 새로 쓰는 것이 이 포크에서 더한 부분입니다.
- PC 시험:
  - `sh tests/standalone-test.sh`: 서비스 래퍼·USB 설치기·지우기(HMG-API를 먼저 지운 경우 포함). `HMGAPI_SRC`를 주면 빌드와 HMG-API 엔진(PC) 설치·차종 제한까지 봅니다.
  - `sh tests/stub-test.sh`: NEMESIS판 시험. 공개 저장소에 없는 파일을 보는 시험 등 36개는 원본에서도 실패합니다(이 포크에서 늘거나 줄지 않음).

<br>

## 라이선스

[GNU AGPL-3.0](LICENSE). NEMESIS(xwtk)와 HMG-API(VysseCodes)와 같은 라이선스입니다. 제조사 파일은 넣지 않습니다.

- 함께 배포하는 HMG-API 무선 모드(한국 차 빌드)의 대응 소스와 직접 다시 만드는 방법은 [`hmgapi-mod/`](hmgapi-mod/README.md)에 있습니다.
- 다른 프로젝트에서 가져온 부분과 원저작권은 [`NOTICE.md`](NOTICE.md)에 적었습니다.
- 1.7.0부터 패키지에 함께 넣는 `bin/busybox`(K3·K8 등 busybox 없는 내비용)는 Korea Projection과 별개 프로그램이며 **GPL-2.0**입니다. 출처와 대응 소스는 [`NOTICE.md`](NOTICE.md#busybox-gpl-20)에 있습니다.

## 감사의 인사
### 5W 자유도를 선사하신 분들
- [Korea Projection](https://github.com/StopDragon/korea-projection) — StopDragon (이 포크의 원본)
- [NEMESIS](https://github.com/xwtk/hmg_nemesis) — xwtk
- [HMG-API](https://github.com/Open-HMG/HMG-API) — VysseCodes
  
### 후원 해주신 분
- 아이리어펠님 - 야밤에 출출할때 먹기 좋은 맥도날드 교환권
- RYUEK님 - 비오늘 날 너무 맛있게 먹으면서 개발했습니다, 뿌링클콤보와 콜라
