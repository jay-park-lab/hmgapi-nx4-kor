#!/bin/bash
# 1.8.0 동글 드라이버 시험 빌드: 받은 kernel.org 3.18.24 소스의 헤더에 순정에만 있는 필드를 같은 자리에 넣는다.
# 동작은 바꾸지 않는다. 구조체 배치(필드 위치·크기)만 순정 커널과 같게 하려는 것이다.
# 근거는 순정 bcmdhd.ko의 디버그 정보다(조사 문서 8·9장). 여러 번 돌려도 한 번만 들어간다. PC에서만 쓴다.
# 쓰는 법: hdr-patch.sh 커널소스폴더
set -e
K=$1
[ -f "$K/include/net/flow.h" ] || { echo "커널 소스 폴더가 아닙니다: $K"; exit 1; }
if grep -q "iterate_avn" "$K/include/linux/fs.h"; then echo "헤더 패치: 이미 들어가 있음"; exit 0; fi
cd "$K"

# 1) flowi_common 끝에 flowic_uid(순정 20번 위치, 4바이트). 이른 안드로이드 패치
perl -0pi -e 's/(\t__u32\tflowic_secid;\n)(\};)/$1\tkuid_t\tflowic_uid;\t\/* kp: 순정 배치 맞춤 *\/\n$2/' include/net/flow.h
perl -0pi -e 's/(#include <linux\/in6.h>\n)/$1#include <linux\/uidgid.h>\n/' include/net/flow.h

# 2) ipv6_devconf: accept_ra_rt_table(96), use_optimistic(116), use_oif_addrs_only(140). 이른 안드로이드 패치
perl -0pi -e 's/(\t__s32\t\tproxy_ndp;\n)/\t__s32\t\taccept_ra_rt_table;\t\/* kp *\/\n$1/' include/linux/ipv6.h
perl -0pi -e 's/(\t__s32\t\toptimistic_dad;\n)/$1\t__s32\t\tuse_optimistic;\t\/* kp *\/\n/' include/linux/ipv6.h
perl -0pi -e 's/(\t__s32\t\tsuppress_frag_ndisc;\n)/$1\t__s32\t\tuse_oif_addrs_only;\t\/* kp *\/\n/' include/linux/ipv6.h

# 3) cgroup_subsys: can_attach 앞에 allow_attach(20). 이른 안드로이드 패치
perl -0pi -e 's/(\tint \(\*can_attach\)\(struct cgroup_subsys_state \*css,)/\tint (*allow_attach)(struct cgroup_subsys_state *css,\n\t\t\t    struct cgroup_taskset *tset);\t\/* kp *\/\n$1/' include/linux/cgroup.h

# 4) task_struct: prev_cputime 앞에 cpu_power(928, 8바이트). 안드로이드 패치(작업별 전력 통계)
perl -0pi -e 's/(\tcputime_t gtime;\n)(#ifndef CONFIG_VIRT_CPU_ACCOUNTING_NATIVE\n\tstruct cputime prev_cputime;)/$1\tunsigned long long cpu_power;\t\/* kp *\/\n$2/' include/linux/sched.h

# 5) file_operations: show_fdinfo 앞에 iterate_avn(112). 제조사 필드. 형은 추정(크기 4바이트의 함수 포인터)
perl -0pi -e 's/(\tint \(\*show_fdinfo\)\(struct seq_file \*m, struct file \*f\);)/\tint (*iterate_avn) (struct file *, struct dir_context *);\t\/* kp: 제조사 필드, 형은 추정 *\/\n$1/' include/linux/fs.h

# 6) PM_GENERIC_DOMAINS는 묻는 말이 없는 설정이다(플랫폼이 켬). 순정 pm_subsys_data에 domain_data가 있어 켤 수 있게 묻는 말만 붙인다
perl -0pi -e 's/config PM_GENERIC_DOMAINS\n\tbool\n/config PM_GENERIC_DOMAINS\n\tbool "kp: pm domains"\n/' kernel/power/Kconfig

# 들어갔는지 필드 이름으로 하나씩 확인한다
for p in "flowic_uid:include/net/flow.h" "accept_ra_rt_table:include/linux/ipv6.h" "use_optimistic:include/linux/ipv6.h" "use_oif_addrs_only:include/linux/ipv6.h" "allow_attach:include/linux/cgroup.h" "cpu_power;:include/linux/sched.h" "iterate_avn:include/linux/fs.h" "kp. pm domains:kernel/power/Kconfig"; do
  grep -q "${p%%:*}" "${p#*:}" || { echo "헤더 패치 실패: ${p%%:*}"; exit 1; }
done
echo "헤더 패치: 8곳 넣음"
