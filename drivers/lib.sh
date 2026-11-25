# drivers/build-in-container.sh와 drivers/kernel/prepare.sh가 함께 쓰는 함수(. 으로 읽음). 컨테이너 안에서만 돈다.

say() { echo "== $*"; }
die() { echo "빌드 실패: $*" >&2; exit 2; }
sha_ok() { [ "$(sha256sum "$2" | cut -d' ' -f1)" = "$1" ]; }

# 폴더 하나의 값: 모든 파일의 sha256과 경로, 모든 링크의 경로와 대상을 이름 차례로 늘어놓은 것의 sha256.
# 툴체인처럼 묶음 파일의 sha256이 고정되지 않는 자료를 받은 뒤 확인하는 데 쓴다
tree_sum() {
  ( cd "$1"
    { find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
      find . -type l -printf '%p -> %l\n' | LC_ALL=C sort; } | sha256sum | cut -d' ' -f1 )
}

# make를 돌리되, qemu 에뮬레이션(Apple Silicon 맥)에서 컴파일러·어셈블러·호스트 도구가 Segmentation fault로 멈추면
# 이어서 다시 돌린다(모두 MAKE_TRIES번까지, 기본 3). make는 이어서 하므로 다 된 것은 다시 만들지 않아 결과는 같다.
# 다른 오류는 바로 멈춘다.
# 커널 3.18의 kbuild에는 .DELETE_ON_ERROR가 없어 멈춘 단계가 반쯤 쓴 파일을 남길 수 있다. 다시 돌리기 전에 make가 실패로
# 적은 대상([scripts/Makefile.<무엇>:<줄>: <대상>])을 지운다. 상대 경로는 make를 돈 폴더 기준이다.
#   make_retry <기록 파일> <make를 돈 폴더(-C)> make 인자...
make_retry() {
  _log=$1; _dir=$2; shift 2
  _n=1; _max=${MAKE_TRIES:-3}
  : > "$_log"
  until make -C "$_dir" "$@" > "$_log.try" 2>&1; do
    cat "$_log.try" >> "$_log"
    if [ $_n -lt $_max ] && grep -q -E 'Segmentation fault|internal compiler error' "$_log.try"; then
      echo "컴파일러가 멈춤(에뮬레이션), 이어서 다시 돌림($_n번째 실패, 모두 ${_max}번까지)"
      grep -o -E '\[scripts/Makefile\.[a-z]+:[0-9]+: [^]]+\]' "$_log.try" | sed -E 's/^\[[^ ]+ //; s/\]$//' | while read -r _t; do
        case "$_t" in /*) ;; *) _t=$_dir/$_t ;; esac
        if [ -f "$_t" ]; then rm -f "$_t"; fi
      done
      _n=$((_n+1))
      continue
    fi
    tail -30 "$_log.try"
    return 1
  done
  cat "$_log.try" >> "$_log"
  rm -f "$_log.try"
}
