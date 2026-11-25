#!/bin/bash
# 1.8.0 동글 드라이버 시험 빌드(tcc803x 전용): hdr-patch.sh(니로에서 찾은 필드) 위에 tcc803x 순정에만 있는 것을 더 맞춘다.
# 동작은 바꾸지 않는다. 구조체 배치만 순정 커널과 같게 하려는 것이다. PC에서만 쓴다. 여러 번 돌려도 한 번만 들어간다.
# 근거: 팰리세이드 LX2PE(tcc803x 09-02 17:43:03) 순정 bcmdhd.ko·vpu.ko 디버그 정보(조사 문서 14장).
# 쓰는 법: hdr-patch-803x.sh 커널소스폴더
set -e
K=$1
[ -f "$K/include/linux/mm_types.h" ] || { echo "커널 소스 폴더가 아닙니다: $K"; exit 1; }
if grep -q "kp803" "$K/include/linux/sched.h"; then echo "tcc803x 헤더 패치: 이미 들어가 있음"; exit 0; fi
cd "$K"

# 1) vmacache_seqnum: 순정은 8바이트(task_struct 728, mm_struct 8→get_unmapped_area 16).
#    뒤늦게 들어온 보안 수정(seqnum 넘침 막기)을 얹은 커널로 보인다(추정). u32 → u64
perl -0pi -e 's/\tu32 vmacache_seqnum;(\s+\/\* per-thread vmacache \*\/)/\tu64 vmacache_seqnum;\t\/* kp803 *\/$1/' include/linux/mm_types.h
perl -0pi -e 's/\tu32 vmacache_seqnum;\n/\tu64 vmacache_seqnum;\t\/* kp803 *\/\n/' include/linux/sched.h

# 2) linux_mib: 순정이 4바이트 크다(항목 하나 더). 어느 항목인지 모르므로 끝에 자리만 둔다(드라이버는 이 표를 쓰지 않음)
perl -0pi -e 's/(\n\t__LINUX_MIB_MAX\n)/\n\tLINUX_MIB_KP803_PAD,\t\t\t\/* kp803: 순정 크기 맞춤, 이름은 모름 *\/$1/' include/uapi/linux/snmp.h

grep -q "u64 vmacache_seqnum;	/\* kp803" include/linux/sched.h || { echo "실패: sched.h"; exit 1; }
grep -q "u64 vmacache_seqnum;	/\* kp803" include/linux/mm_types.h || { echo "실패: mm_types.h"; exit 1; }
grep -q "LINUX_MIB_KP803_PAD" include/uapi/linux/snmp.h || { echo "실패: snmp.h"; exit 1; }
echo "tcc803x 헤더 패치: 넣음"
