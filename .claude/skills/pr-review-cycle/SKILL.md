---
name: pr-review-cycle
description: 이 저장소(jay-park-lab/hmgapi-nx4-kor, github.com)의 작업을 Git Flow 규칙대로 커밋·푸시해 PR 로 올리고, 리뷰 서브에이전트에게 리뷰를 맡겨 PR 에 직접 코멘트를 달게 한 뒤, 수정 → 답글 → 같은 리뷰어에게 재리뷰 요청을 지적이 없어질 때까지 반복하고, 사용자가 고르면 merge commit 으로 합치고 브랜치를 정리하는 워크플로. "PR 올리고 리뷰 사이클 돌려줘", "리뷰 에이전트 띄워서 리뷰", "리뷰 반영하고 재리뷰 요청해", "리뷰해서 머지까지" 같은 요청이나, 이미 자동 리뷰가 달린 PR 을 이어서 진행할 때 쓴다.
argument-hint: "[PR 번호 | PR URL]"
---

# PR 리뷰 사이클

```
커밋·푸시 → PR → 리뷰 → 수정 여부 확인 → 수정 → 답글 → 재리뷰 ─┐
                   ↑                                          │ 지적이 남으면
                   └──────────────────────────────────────────┘
       지적이 없으면 → 머지 여부 확인 → merge commit 으로 합치기 → 정리
```

## 언제 쓰나

- 사용자가 PR 을 올리고 리뷰 사이클을 돌리라고 할 때. 인자로 PR 번호나 URL 을 받는다. 없으면 지금
  체크아웃의 브랜치로 정한다.
- 이 스킬을 부른 것이 커밋·푸시·PR 열기까지의 요청이다. 머지·태그·브랜치 삭제는 6 단계에서 따로 묻는다.
- 이미 자동 리뷰가 달린 PR 이면 "0. 이어받기" 부터 한다.

## 원칙

- **브랜치·머지·태그 규칙의 단일 출처는 [`docs/git-flow.md`](../../../docs/git-flow.md) 다.** 이 문서와
  다르면 그쪽을 따른다. 요점:
  - `feature/<주제>` 는 `develop` 으로, `release/<판>`·`hotfix/<판>` 은 `main` 으로 PR 을 열고, 합친 뒤
    `develop` 에도 합친다.
  - `main`·`develop` 에 직접 커밋·푸시하지 않는다.
  - 판 번호(`mod/mod.json` `version`, `app/AndroidManifest.xml` `versionName`·`versionCode`)는
    `release/`·`hotfix/` 에서만 바꾼다.
  - 합치기는 merge commit 만(`gh pr merge --merge`). squash·rebase 합치기를 쓰지 않는다.
  - PR 을 연 뒤에는 강제 푸시하지 않는다. 뒤처지면 rebase 가 아니라 base 를 merge 해서 맞춘다.
- GitHub 작업(PR 생성·조회·리뷰·답글)은 `gh` 와 `gh api` 로 한다. 저장소는
  `jay-park-lab/hmgapi-nx4-kor` 다. 아래 `<R>` 은 이 값이다(`gh repo view --json nameWithOwner -q .nameWithOwner`).
- 사용자에게 묻는 곳은 지적 반영 범위(4 단계), 머지·태그·브랜치 삭제(6 단계), 되돌리기 어려운 git 작업,
  "예외" 절의 경우뿐이다. 사용자가 반영 범위를 미리 정했으면 4 단계에서 다시 묻지 않는다.
- 질문은 `AskUserQuestion` 으로 하고, 권장안을 첫 번째 선택지에 둔다.
- 리뷰어는 이 대화를 모르는 서브에이전트다. 내 결론이나 예상 문제가 아니라 PR 과 범위를 준다.
- 리뷰·답글·댓글·보고는 존댓말 한국어로 쓴다.
- 자동 리뷰는 PR 작성자와 같은 계정으로 달린다. 리뷰어의 글은 첫 줄 머리말 `(자동 리뷰 — ` 로, 내 반영
  답글은 커밋 SHA 로 구분한다. `user.login` 으로 가르지 않는다.
- 이 저장소에는 PR 때 도는 CI 가 없다(release 워크플로는 `v*` 태그에서만 돈다). `gh pr checks` 는 필요한 때 한 번만 보고, 검사가 없거나 진행
  중이면 로컬 검증 결과를 근거로 삼는다. 주기적으로 조회하지 않는다.
- 비밀값을 지킨다. `.env.local`, 서명 키(`NX4_APP_KEYS` 폴더, `NX4_MOD_KEY`)는 커밋하지 않고, 그 내용과
  비밀번호를 화면·PR·로그에 남기지 않는다. `git add -f` 를 쓰지 않는다.
- 셸 명령은 `&&`·`||`·`;` 로 잇지 않고 하나씩 실행한다. git 은 `-C` 없이, 대상 트리로 `cd` 한 뒤 실행한다.
- 이번 작업과 무관한 커밋하지 않은 변경은 건드리지 않는다.
- **작업은 워크트리에서 한다**([`docs/git-flow.md`](../../../docs/git-flow.md) 규칙 11, "워크트리"). 메인 체크아웃은
  `develop` 에 두고 고치지도, 브랜치를 바꾸지도 않는다.
  - 그래서 `develop`·`main` 은 메인 체크아웃에 열려 있어 다른 트리에서 `git switch` 할 수 없다.
  - 워크트리에는 `.env.local` 이 없다. 메인 체크아웃의 것을 `NX4_ENV_FILE` 로 가리킨다.
  - 로컬 `develop`·`main`·`release/*` 를 `git fetch origin <브랜치>:<브랜치>` 나 `git update-ref` 로 옮기지 않는다
    (다른 트리에 열린 브랜치면 그 트리의 HEAD 만 옮겨져 어긋난다. "예외" 참고).
  - 어느 트리에 무엇이 열려 있는지는 `git worktree list` 로 본다. 첫 줄이 메인 체크아웃이다.

진행하면서 PR 번호, base 브랜치, 리뷰어 이름, 리뷰 라운드, 지적 번호와 처리 상태(반영 / 미룸 / 해소),
리뷰어가 마지막으로 본 커밋을 계속 기억해 둔다. 세션이 끊겨도 이 정보는 PR 에 올린 리뷰와 답글에서
다시 읽을 수 있다("0. 이어받기").

## PR 코멘트 조회 규칙

PR 의 리뷰·코멘트를 읽을 때는 아래 세 가지를 각각 `--paginate` 로 마지막 페이지까지 읽는다. 하나만 보거나
한 페이지만 보면 새 지적을 놓친다.

| 명령 | 담는 것 |
| --- | --- |
| `gh api repos/<R>/pulls/<PR>/reviews --paginate` | 리뷰 목록(리뷰 본문, 리뷰가 본 `commit_id`) |
| `gh api repos/<R>/pulls/<PR>/comments --paginate` | 인라인 스레드(파일·라인에 달린 지적과 답글) |
| `gh api repos/<R>/issues/<PR>/comments --paginate` | PR 일반 코멘트 |

- 새 커밋을 올리면 기존 인라인 스레드의 줄이 옮겨지거나 outdated 가 된다. 이는 "라인이 옮겨짐" 이지
  "해결됨" 이 아니다.

## 0. 이어받기

PR 에 첫 줄이 `(자동 리뷰 — ` 로 시작하는 리뷰가 이미 있으면, 처음부터 하지 않고 PR 에 남은 기록으로
상태를 되살려 이어 간다.

1. 리뷰 목록에서 자동 리뷰만 고른다. 가장 최근 자동 리뷰의 `commit_id` 가 리뷰어가 마지막으로 본 커밋이다.
   리뷰 본문에서 지적 번호·등급과, 재리뷰라면 지난 지적별 판정을 읽고, 지금까지 쓴 가장 큰 지적 번호와
   리뷰어 이름(머리말의 `— ` 뒤)을 기억한다.
2. 인라인 스레드와 PR 코멘트를 읽어 지적별 처리 상태를 정한다.
   - 첫 줄이 `(자동 리뷰 — ` 인 답글은 리뷰어 판정이므로 반영 답글로 세지 않는다.
   - 반영 답글은 마지막 자동 리뷰 뒤의 커밋 SHA(앞 7자 이상)를 적은 답글이나 PR 코멘트다.
   - 반영하지 않기로 했다는 답글이 있는 지적은 "미룸" 으로 둔다.
3. 어디서 이어 갈지 정한다.
   - 마지막 자동 리뷰 뒤에 커밋이 있는데 그 SHA 를 적은 반영 답글이 없으면 5 단계 3(PR 본문)·4(답글)부터
     하고 재리뷰로 간다.
   - 마지막 자동 리뷰 뒤에 커밋과 반영 답글이 모두 있으면 5 단계 5(재리뷰)로 간다. 리뷰어가 이어지지 않으면
     새 리뷰어를 띄우고 지난 리뷰 링크와 "지적 번호는 <가장 큰 번호 + 1> 부터" 를 함께 준다.
   - 커밋이 없고 판단할 지적이 남았으면 4 단계로 간다.
   - 판단할 지적이 없으면 6 단계로 간다.
4. 4·5 단계(수정)로 가면 고치기 전에 1 단계 2 의 "이미 있는 브랜치를 고칠 때" 대로 그 PR 브랜치의 워크트리에 들어간다.
   메인 체크아웃에서 고치지 않는다.

## 1. 커밋·푸시

1. `git branch --show-current` 와 `git status --short` 로 브랜치와 남은 변경을 본다.
2. 브랜치와 트리를 맞춘다(`docs/git-flow.md` 규칙 1–3, 11).
   - 이 세션이 메인 체크아웃에서 돌면 여기서 브랜치를 만들거나 커밋하지 않는다. 메인 체크아웃인지는
     `git worktree list` 첫 줄의 경로와 `git rev-parse --show-toplevel` 이 같은지로 본다.
     - `git fetch origin`, `git worktree add --no-track -b feature/<주제> .claude/worktrees/<주제> origin/develop` 로
       워크트리를 만든다.
     - `EnterWorktree` 의 `path` 로 그 워크트리에 들어간다. `name` 으로 만들지 않는다(`main` 에서 규칙에 맞지 않는
       브랜치를 만든다).
     - 메인 체크아웃에 이번 작업의 커밋하지 않은 변경이 있으면 데려갈지 사용자에게 묻는다. 데려가는 방법은
       `docs/git-flow.md` "워크트리" 의 stash 줄을 따른다. `git stash push` 에는 내 파일만 경로로 준다(경로가 없으면
       다른 작업의 변경까지 옮겨진다). 내가 하지 않은 변경은 다른 작업의 것이니 건드리지 않는다.
   - 데스크톱 앱이 처음부터 워크트리로 연 세션이면 그 안에서 `git fetch origin`,
     `git switch --no-track -c feature/<주제> origin/develop` 으로 만든다(로컬 `develop` 은 쓰지도 옮기지도 않는다).
     세션이 처음 받은 브랜치(예: `claude/<이름>`)에 커밋이 있으면 그 커밋을 데려갈지 사용자에게 묻는다.
   - 이미 작업 브랜치의 워크트리에 있으면 그대로 쓴다.
   - 이미 있는 브랜치(이어받은 PR 등)를 고칠 때는 메인 체크아웃에서 `git switch` 하지 않는다.
     `docs/git-flow.md` "워크트리" 의 "이미 있는 브랜치를 이어서 고칠 때" 대로 그 브랜치의 워크트리를 찾거나 만들고,
     `EnterWorktree` 의 `path` 로 들어간다. 찾은 워크트리가 이 세션이 만들었거나 쓰던 것이 아니면 다른 세션이 쓰고
     있을 수 있으므로, 들어가기 전에 `AskUserQuestion` 으로 묻는다.
   - 이름은 `feature/`·`release/`·`hotfix/` 로 시작하고 뒤는 영어 소문자·숫자·하이픈만 쓴다.
   - `feature/` 에 판 번호 변경이 섞여 있으면 커밋하지 말고 사용자에게 알린다.
3. 5 단계 1 의 검증을 한 번 돌린다. 실패하면 커밋하지 않고 고친다.
4. `git config user.email` 로 작성자를 확인하고, 기능 단위로 커밋한다.
   - 메시지는 저장소의 최근 관례를 따른다: 영어 명령문 첫 줄, 빈 줄, 무엇을 왜 바꿨는지 적은 본문,
     마지막 줄 `Co-Authored-By`.
   - 여러 줄 메시지는 `git commit -F - <<'EOF'` 로 넘긴다.
   - `.env.local`, `out/`, `mod/app/`(빌드한 APK)은 git 에서 빠져 있다. 스테이징에 끼지 않았는지 본다.
5. 첫 푸시는 `git push -u origin <브랜치>`.

## 2. PR 열기

1. 같은 브랜치의 열린 PR 을 찾는다: `gh pr list --head <브랜치> --state open --json number,url`.
2. 없으면 `gh pr create --base <base> --head <브랜치> --title "<제목>" --body-file - <<'EOF'` 로 만든다.
   - base 는 원칙의 규칙대로(`feature/` → `develop`, `release/`·`hotfix/` → `main`). `--base` 를 빠뜨리지
     않는다(GitHub 기본 브랜치가 `main` 이다).
   - 제목은 첫 커밋의 첫 줄 관례(영어)와 같게 한다.
   - 본문(한국어): 무엇을 바꿨나, 확인(실행한 명령과 결과 수치: `tests/mod-test.sh` 통과 건수, 빌드·엔진
     시험을 돌렸는지), 차에서 확인할 것(해당하면 `docs/design.md` 의 항목), 남은 것, 마지막 줄
     `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
   - 아직 합쳐지지 않은 다른 PR 의 브랜치 위에 쌓였으면 본문 맨 위에 "먼저 #<base PR> 를 합쳐 주세요" 를 적는다.
3. 이미 있으면 새 커밋만 푸시하고, 본문이 지금 상태와 맞는지 `gh pr edit <PR> --body-file -` 로 고친다.
4. Claude 데스크톱 앱이면 `mcp__ccd_pr__get_status` 로 PR 바 연결을 보고, 연결되지 않았으면 `bind_pr` 한다.

## 3. 리뷰

1. 띄우기 전에 체크아웃 기준을 적어 둔다(5 에서 비교한다): `git status --short --untracked-files=all`, `git rev-parse HEAD`,
   추적 파일 내용 `git diff HEAD --binary | shasum`(이미 수정 중인 파일을 더 고친 것은 이것으로만 보임), git 이 무시하는
   빌드 결과 `shasum mod/app/NX4KOR.apk out/*.zip`, `git worktree list` 의 체크아웃 줄. 미커밋 변경이 있으면
   `git diff HEAD --binary` 전체도 체크아웃 밖 임시 파일에 저장해 둔다(해시만으로는 어느 파일이 바뀌었는지 가를 수 없음).
   원칙대로 이번 작업과 무관한 미커밋 변경이 있을 수 있으므로 깨끗한 상태를 기준으로 가정하지 않는다. 리뷰가 도는 동안
   메인 쪽이 체크아웃을 바꾸면(사용자 지시 등) 무엇을 바꿨는지 함께 적어 둔다.
   그다음 리뷰어 서브에이전트를 띄운다. `Agent` 도구, `subagent_type: "general-purpose"`,
   `name: "pr-<PR 번호>-reviewer"`, `run_in_background: true`. 재리뷰 때 같은 이름으로 `SendMessage` 해 이어서 보낸다.
2. 지시문은 [references/reviewer-brief.md](references/reviewer-brief.md) 의 "첫 리뷰" 를 채워서 보낸다. 내 판단이나
   예상 문제는 넣지 않는다. `<로컬 체크아웃>` 은 이 세션의 작업 트리(`git rev-parse --show-toplevel`, 곧 이 작업의
   워크트리)이고, `<개인 설정 파일>` 은 `.env.local` 이 실제로 있는 곳(보통 메인 체크아웃의 것)이다.
   두 값을 같은 경로로 묶어 적지 않는다.
3. 리뷰어가 끝날 때까지 PR 대상 파일을 고치지 않고 기다린다. 완료 알림이 오기 전에는 결과를 짐작해 말하지 않는다.
4. 리뷰어의 알림을 그대로 믿지 않는다. "PR 코멘트 조회 규칙" 대로 실제로 올라간 리뷰와 인라인 코멘트를 읽는다.
   리뷰어가 사실이라고 적은 것 중 고칠 근거가 되는 것은 직접 확인한다.
5. 체크아웃이 1 에서 적어 둔 기준과 같은지 본다: `git status --short --untracked-files=all`, `git rev-parse HEAD`,
   `git diff HEAD --binary | shasum`, 무시된 빌드 결과의 `shasum`, `git worktree list` 의 체크아웃 줄, 그리고 이 PR 의
   리뷰용 워크트리(`review-pr-<PR>`)가 남지 않았는지. 리뷰어는 서브에이전트라 `cd` 가 다음 호출로 이어지지 않아, 지시문을
   벗어나면 체크아웃에서 돌거나 체크아웃 파일을 바꿀 수 있다. 리뷰어 알림의 "체크아웃 비교 결과" 도 함께 본다.
   `git worktree list` 의 다른 워크트리(다른 PR 의 `review-pr-*`, 다른 세션의 `.claude/worktrees/*`)는 다른 작업이 쓰는
   중일 수 있으므로 건드리지 않는다.
   - 리뷰는 백그라운드로 돌고 그동안 메인 쪽, 사용자(편집기), 다른 작업도 체크아웃을 바꿀 수 있으므로, 기준과
     다르다고 리뷰어가 바꿨다고 단정하지 않는다. 1 에 적어 둔 메인 쪽 변경은 빼고 본다.
   - 남은 차이 중 리뷰어가 알림에 "제 명령으로 바뀜" 이라고 적은 것만 리뷰어가 만든 것으로 본다. 리뷰어의 "다름" 만으로는
     리뷰어가 했다는 뜻이 아니다. "제가 한 일이 아님"·"모름" 이거나, 리뷰어는 "같음" 이라는데 차이가 있거나, 누가
     만들었는지 가를 수 없으면 **되돌리지 말고 사용자에게 묻는다**.

   리뷰어가 만든 것으로 정해진 경우의 처리:
   - 파일 변경: 그 파일이 기준 때 이미 있던 변경이면(1 의 `git status --short --untracked-files=all` 에 있었거나 저장한 diff 에 있으면.
     아직 `git add` 하지 않은 미추적 파일은 diff 에 나오지 않으므로 status 로 본다) 되돌리면 기존 작업까지 사라지므로
     되돌리지 말고 사용자에게 묻는다. 그렇지 않으면 되돌리기 전에 되살릴 수 있게 체크아웃 밖 임시 폴더에 남겨 둔다. 추적
     파일은 `git diff HEAD --binary -- <파일>`(스테이징 포함. `--binary` 가 없으면 바이너리는 "differ" 한 줄만 남음), 미추적
     파일은 `cp` 로 복사한다(`git diff` 는 미추적 파일을 내지 않음). 그다음 그 파일만 되돌리고(추적 파일은
     `git restore --source=HEAD --staged --worktree -- <파일>`, 미추적 파일은 지움) 알린다.
   - 이 PR 의 `review-pr-<PR>` 가 남음: `git worktree remove --force <그 경로>`.
   - HEAD 가 바뀜: `git switch <원래 브랜치>` 로 돌리고 알린다. 새 커밋이 생겼으면 지우지 말고 알린다.
   - 무시된 빌드 결과가 바뀜: 그 파일은 시험 키로 서명됐을 수 있으므로 쓰지 않는다. 앱은 `sh scripts/build-app.sh`
     (`.env.local` 의 배포용 키)로 다시 만들고, `out/` 의 바뀐 묶음은 배포에 쓰지 않는다고 알린다.

## 4. 수정 여부 확인

판단할 지적은 두 가지다.

- 이번 리뷰에서 새로 나온 지적
- 반영하기로 했는데 재리뷰에서 "미해소" 나 "일부" 로 판정된 지적

반영하지 않기로 한(미룬) 지적은 다시 묻지 않는다. 판단할 지적이 없으면 6 단계로 간다. 있으면 지적마다
번호·등급(반드시 고칠 것 / 권장 / 사소함)·한 줄 요약·제안과 내 판단(맞는 지적인지, 근거)을 보여 주고 묻는다.

`AskUserQuestion` — "어떤 지적을 반영할까요?"

- **전부 반영 (권장)**
- **반드시·권장만 반영**
- **반영 없이 머지 여부 확인으로**

번호를 골라 답하면 그대로 따른다. 반영하지 않기로 한 지적에는 이유와 후속 처리(다른 PR, 차에서 확인 등)를
답글로 남긴다.

## 5. 수정과 재리뷰

1. **수정** — 바뀐 범위에 맞춰 검증한다.
   - 늘: `sh tests/mod-test.sh` 가 "모두 통과". `.env.local` 에 `HMGAPI_SRC` 가 있으면 빌드와 HMG-API 엔진
     시험까지 돈다. "skip 빌드·HMG-API 엔진 시험" 이 나오면 PR 본문의 확인 절에 그렇게 적는다.
     워크트리에는 `.env.local` 이 없으므로 `NX4_ENV_FILE=<메인 체크아웃>/.env.local sh tests/mod-test.sh` 처럼 메인
     체크아웃의 것을 가리킨다(`scripts/build-app.sh` 도 같다). 주지 않으면 빌드·엔진 시험이 "skip" 된다.
   - `app/` 를 바꿨으면: `sh scripts/build-app.sh` 가 끝까지 되는지(`ReportTest` 는 `mod-test.sh` 가 돌린다).
     화면이 바뀌었으면 에뮬레이터를 쓸 수 있을 때 [`docs/emulator-test.md`](../../../docs/emulator-test.md)의
     해당 시나리오를 돌린다.
   - `scripts/build.sh`·`usb/` 를 바꿨으면: `HMGAPI_SRC` 를 두고 `mod-test.sh` 의 빌드 시험이 돌았는지 확인한다.
   - 리뷰어가 짚은 실패 시나리오를 시험이나 직접 실행으로 재현해 고쳐졌는지 본다.
2. **커밋** — 지적 번호를 본문에 적은 새 커밋으로 올린다. amend·강제 푸시하지 않는다.
3. **PR 본문** — 확인 수치·남은 것 등 사실과 달라진 곳을 `gh pr edit <PR> --body-file -` 로 고친다.
4. **답글** — 인라인 지적마다 답글을 단다.
   `gh api repos/<R>/pulls/<PR>/comments/<comment id>/replies -f body=<답글>`
   무엇을 어느 커밋(SHA 앞 7자 이상)에서 어떻게 고쳤고 어떻게 확인했는지 적는다. 커밋 SHA 는 "0. 이어받기" 가
   반영 답글을 알아보는 표시이므로 빠뜨리지 않는다. 리뷰 본문에만 있는 지적과 전체 요약은
   `gh pr comment <PR> --body-file -` 로 PR 코멘트 하나에 남긴다.
5. **재리뷰** — 보내기 전에 3 단계 1 처럼 체크아웃 기준을 다시 적어 둔다. 그다음 `SendMessage`
   (to: `pr-<PR 번호>-reviewer`) 로 [references/reviewer-brief.md](references/reviewer-brief.md) 의 "재리뷰" 를 채워
   보낸다. 범위는 리뷰어가 마지막으로 본 커밋부터 새 커밋까지다. 리뷰어 지시문이 지난번 뒤 바뀌었으면 "리뷰어 규칙이
   바뀐 것" 칸에 적는다(이어 받는 리뷰어는 예전 규칙을 기억하고 있다). 리뷰어가 이어지지 않으면 새 리뷰어를 띄우고
   지난 리뷰 링크를 함께 준다.
6. 결과를 3 단계 4·5 처럼 확인하고 4 단계로 돌아간다.

## 6. 머지 여부 확인과 머지

1. **머지 전 확인**
   - `gh pr view <PR> --json mergeable,mergeStateStatus,headRefOid,baseRefName`
   - `gh pr checks <PR>` 를 한 번 본다. 검사가 없거나 진행 중이면 5 단계 1 의 로컬 검증 결과를 근거로 알린다.
   - 쌓인 PR 이면 base PR 이 먼저 합쳐졌는지 본다. 안 됐으면 base PR 부터 이 6 단계를 진행한다.
   - `docs/git-flow.md` 규칙 8 의 합치기 전 확인을 채웠는지 본다. `release/`·`hotfix/` 는 빌드·HMG-API 엔진
     시험까지 통과해야 하고, `docs/design.md` "차에서 확인할 것" 중 해당 항목의 확인 여부를 함께 적는다.
2. `AskUserQuestion` — "PR #<번호> 를 merge commit 으로 합칠까요?" 선택지는 **합치기 (권장)** / **아직**.
   미룬 지적이 있거나, 엔진 시험을 건너뛰었거나, 차에서 확인하지 않았으면 질문에 그 사실을 함께 적는다.
   합치기 선택지 설명에 "합친 뒤 7 단계대로 워크트리에서 나와(`ExitWorktree`) 워크트리와 브랜치를 지웁니다" 를 적는다.
   1 단계 2 에서 물어서 들어간 다른 세션의 워크트리면 "합친 뒤 워크트리에서 나오고, 그 워크트리와 로컬 브랜치는
   남깁니다" 로 적는다. `ExitWorktree` 는 사용자가 요청할 때만 부르는 도구라, 이 답이 그 요청이 된다.
   `release/`·`hotfix/` 면 `v<판>` 태그와 `develop` 으로 되돌려 합치기까지 함께 묻는다.
3. **base 가 앞서 충돌이 있을 때** — PR 을 연 뒤라 rebase·강제 푸시하지 않는다.
   - `git fetch origin`
   - `git merge origin/<base>` 로 풀고 커밋·푸시한다. 푼 내용을 PR 코멘트로 남기고 재리뷰한다(5 단계 5).
4. **합치기** — `gh pr merge <PR> --merge`. `--squash`·`--rebase` 를 쓰지 않는다. 브랜치 삭제는 7 단계에서 한다.
5. `gh pr view <PR> --json state,mergeCommit` 로 합쳐졌는지 확인한다.
6. **`release/`·`hotfix/` 만**
   - 태그: `git fetch origin`, `git tag -a v<판> -m "NX4 KOR <판>" <merge commit>`, `git push origin v<판>`.
     로컬 `main` 으로 바꾸거나 옮기지 않는다. 태그는 지우거나 옮기지 않는다.
   - `develop` 으로 되돌려 합치기: `gh pr create --base develop --head <브랜치>`. 내용이 이미 리뷰된 것이라
     리뷰어는 띄우지 않고, 충돌이 있으면 3 처럼 푼다. 합치기는 위와 같이 `--merge`.
   - `hotfix/` 인데 진행 중인 `release/` 가 있으면 거기에도 같은 방법으로 합친다.
   - 태그를 올리면 release 워크플로가 `production` 승인을 기다린 뒤 배포 묶음을 만들어 GitHub 릴리스에 올린다
     ([`docs/release.md`](../../../docs/release.md)). 승인은 사용자가 Actions 화면에서 한다. 대신 승인하거나
     승인 여부를 짐작해 말하지 않는다.
   - PC 에서 만들 때는 태그를 단 커밋에서 `.env.local` 이 가리키는 배포용 키(저장소 밖)로만 만든다(`docs/git-flow.md`
     규칙 7). 만들지는 사용자가 시킬 때만.

## 7. 정리

`docs/git-flow.md` 규칙 10 을 따른다. `release/`·`hotfix/` 는 `main` 과 `develop` 양쪽에 합친 뒤에 지운다.

1. 원격 브랜치: `git ls-remote origin refs/heads/<브랜치>` 가 합쳐진 PR 의 head SHA 와 같을 때만
   `git push origin --delete <브랜치>` 한다. 저장소 설정으로 이미 지워졌으면 건너뛴다.
2. 로컬: `-D` 로 강제 삭제하지 않는다. 로컬 `<base>` 는 `git fetch origin <base>:<base>` 로 옮기지 않는다
   (2026-11-20 #11·#29 뒤 두 번 이렇게 옮겨 메인 체크아웃이 어긋났다).
   - 1 단계에서 `git worktree add` 로 만든 워크트리면:
     - `ExitWorktree`(`keep`)로 메인 체크아웃에 돌아온다. 6 단계 2 에서 사용자가 합치기(정리 포함)를 골랐을 때만 부른다.
     - 메인 체크아웃에서 `git pull --ff-only` 로 `develop` 을 맞춘다. 커밋하지 않은 변경과 겹쳐 멈추면 손대지 말고
       보고에 적는다.
     - `git worktree remove .claude/worktrees/<이름>`, `git branch -d <브랜치>` 로 지운다. `git worktree remove` 가
       남은 변경 때문에 멈추면 `--force` 로 지우지 말고 무엇이 남았는지 사용자에게 알린다.
   - 데스크톱 앱이 처음부터 워크트리로 연 세션이면 `git fetch origin`, `git switch --detach origin/<base>`,
     `git branch -d <브랜치>` 로 정리한다. 워크트리 폴더는 앱이 정리한다. 메인 체크아웃의 로컬 `<base>` 는 그 트리에서
     `git pull --ff-only` 로 맞추면 된다고 보고에 적는다.
   - 1 단계 2 에서 물어서 들어간 다른 세션의 워크트리면 `ExitWorktree`(`keep`)로 나오기만 한다. 그 워크트리와 로컬
     브랜치는 지우지 않는다(`docs/git-flow.md` "워크트리": 다른 세션의 워크트리는 지우지 않음. 워크트리가 브랜치를 열고
     있어 `git branch -d` 도 막힌다). 원격 브랜치는 1 대로 정리하고, 워크트리와 로컬 브랜치가 남았다고 8 단계 보고에
     적는다. 지우려면 사용자에게 묻는다.
3. 쌓인 PR 이 있었으면 base PR 도 같은 절차로 정리한다.

## 8. 마무리 보고

합친 커밋, 태그, 정리 결과, 합칠 때의 확인 근거(로컬 검증 수치, CI), 미룬 지적과 후속 처리, 차에서 확인할 것,
정리하지 못한 것과 그 이유를 보고한다.

## 예외

- **리뷰어가 코드를 고치려 함** — 지시문에서 금지한다. 리뷰어가 바꾼 파일이 있으면 되돌리고 알린다.
- **머지 충돌** — 6 단계 3 처럼 base 를 merge 해서 풀고, 푼 내용을 PR 코멘트로 남긴 뒤 재리뷰한다.
- **`main`·`develop` 에 커밋해 버림** — 푸시 전이면 사용자에게 알리고, 그 커밋을 작업 브랜치로 옮기는 명령을
  보여 준 뒤 승인을 받아 한다. 푸시 뒤면 되돌리지 말고 사용자에게 알린다.
- **사용자가 중간에 다른 지시를 함** — 그 지시를 따르고, 사이클을 이어 갈지 묻는다.
- **체크아웃의 HEAD 만 옮겨짐** — `git status` 에 내가 하지 않은 스테이징 변경이 있고, 그것이 방금 합친 PR 을
  되돌리는 내용이면, 다른 트리에서 이 트리에 열린 브랜치를 `git fetch origin <브랜치>:<브랜치>` 로 옮긴 경우다.
  [`docs/git-flow.md`](../../../docs/git-flow.md) "워크트리" 의 알아보는 법대로 확인하고, 남은 흔적뿐이면
  사용자에게 물은 뒤 맞춘다. 그 상태로 브랜치를 만들거나 커밋하지 않는다(PR 이 되돌려진다).
- **잘못 올린 코멘트** — `gh api -X PATCH repos/<R>/pulls/comments/<id>` (인라인) 또는
  `gh api -X PATCH repos/<R>/issues/comments/<id>` (PR 코멘트)로 고친다. 지우기는 사용자에게 묻고 한다.
