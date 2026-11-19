# PC마다 다른 경로(Android SDK, 서명 키, HMG-API 소스 등)를 .env.local에서 읽는다. PC에서 도는 스크립트가 `.`으로 불러 쓴다.
# 코드에는 이런 경로의 기본값을 두지 않는다: 값은 명령 앞에 주거나 .env.local에 적는다(형식은 .env.example).
#
# .env.local: 저장소 맨 위, git에 넣지 않는다.
#   한 줄에 KEY=값. # 로 시작하는 줄과 빈 줄은 건너뛴다. 앞의 "export "는 무시한다.
#   값을 감싼 따옴표 한 쌍은 벗기고, 값 앞의 ~/ 는 홈 폴더로 바꾼다. 그 밖의 변수($HOME 등)는 펼치지 않는다.
# 이미 값이 있는 변수(명령 앞에 준 값, 셸에 export된 값)는 바꾸지 않는다.
# NX4_ENV_FILE로 다른 파일을 줄 수 있고, 빈 값(NX4_ENV_FILE=)을 주면 아무 파일도 읽지 않는다.
#
#   nx4_env <저장소 맨 위> [키 ...]   .env.local을 읽어 export한다. 키를 주면 그 키만 읽는다
#   nx4_need <변수> <설명>            값이 없으면 안내하고 끝낸다(종료 코드 1)

nx4_env() {
  _nf=${NX4_ENV_FILE-$1/.env.local}
  shift
  [ -n "$_nf" ] && [ -f "$_nf" ] || return 0
  _ncr=$(printf '\r')
  _nn=0
  while IFS= read -r _nl || [ -n "$_nl" ]; do
    _nn=$((_nn + 1))
    case $_nl in *"$_ncr") _nl=${_nl%?} ;; esac
    case $_nl in '' | '#'*) continue ;; esac
    case $_nl in 'export '*) _nl=${_nl#export } ;; esac
    case $_nl in *=*) ;; *) echo "$_nf:$_nn: KEY=값 꼴이 아닙니다" >&2; return 1 ;; esac
    _nk=${_nl%%=*}
    case $_nk in '' | [0-9]* | *[!A-Za-z0-9_]*) echo "$_nf:$_nn: 변수 이름이 맞지 않습니다: $_nk" >&2; return 1 ;; esac
    if [ $# -gt 0 ]; then
      _nw=
      for _na in "$@"; do [ "$_na" = "$_nk" ] && _nw=1; done
      [ -n "$_nw" ] || continue
    fi
    eval "_nh=\${$_nk:-}"
    [ -z "$_nh" ] || continue
    _nv=${_nl#*=}
    case $_nv in
      \"*\") _nv=${_nv#\"}; _nv=${_nv%\"} ;;
      \'*\') _nv=${_nv#\'}; _nv=${_nv%\'} ;;
    esac
    case $_nv in
      '~') _nv=$HOME ;;
      '~/'*) _nv=$HOME/${_nv#'~/'} ;;
    esac
    eval "$_nk=\$_nv"
    export "$_nk"
  done < "$_nf"
}

nx4_need() {
  eval "_nh=\${$1:-}"
  [ -n "$_nh" ] && return 0
  echo "$1 값이 없습니다($2). 저장소 맨 위 .env.local에 적거나(.env.example 참고) 명령 앞에 주세요." >&2
  exit 1
}
