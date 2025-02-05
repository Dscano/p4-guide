#! /bin/bash

F=typedef-test1.p4

B=`basename $F .p4`

# TBD: Change this to your local p4c executable, or if you leave this
# as is it will use the first one in your shell's command path.
#P4C=p4c-bm2-ss
P4C=$HOME/forks/p4c/build/p4c
#P4TEST=p4test
P4TEST=$HOME/forks/p4c/build/p4test

DELETEDUPS=$HOME/p4-guide/bin/p4c-delete-duplicate-passes.sh
DUMP_FEW_PASSES="FrontEndLast,FrontEndDump,MidEndLast"
DUMP_MANY_PASSES="Front,Mid"

set -x
mkdir -p tmp
$P4C --target bmv2 --arch v1model --p4runtime-files ${B}.p4info.txtpb --dump tmp --top4 ${DUMP_MANY_PASSES} $F
$DELETEDUPS $F tmp
$P4TEST --toJSON ${B}.ir.json $F
$P4C --version
