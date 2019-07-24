#/bin/bash
export n=$3
export SL_ONTIME=5
export SL_OFFTIME=3

export SL_EXP_NAME=$1
export SL_EXP_TIME=$2
export SL_SIZE_DIST=$6
export SL_SIZE=$7
export SL_RATE_DIST=$4
export SL_RATE=$5
export CONFIG_FILE=$SL_EXP_NAME-exp

for ((i=1;i<=n;i++))
do
echo "==== Running Test No. $i/$n ===="
export SL_I=$i
export CLIENT=nodem3.moongenmultipath.spork-join.filab.uni-hannover.de
export SERVER=nodem1.moongenmultipath.spork-join.filab.uni-hannover.de
export ROUTER=nodem2.moongenmultipath.spork-join.filab.uni-hannover.de

#: <<'END'
ssh vuva@$CLIENT 'sudo sysctl -w net.mptcp.mptcp_scheduler=default'
ssh vuva@$SERVER 'sudo sysctl -w net.mptcp.mptcp_scheduler=default'
sleep 5
export SL_SCHED="lrtt"
~/sshlauncher/sshlauncher $CONFIG_FILE.config
sleep 5

ssh vuva@$CLIENT 'sudo sysctl -w net.mptcp.mptcp_scheduler=roundrobin'
ssh vuva@$SERVER 'sudo sysctl -w net.mptcp.mptcp_scheduler=roundrobin'
sleep 5
export SL_SCHED="rr"
~/sshlauncher/sshlauncher $CONFIG_FILE.config
sleep 5
END
#ssh vuva@$CLIENT 'sudo sysctl -w net.mptcp.mptcp_scheduler=redundant'
#ssh vuva@$SERVER 'sudo sysctl -w net.mptcp.mptcp_scheduler=redundant'
#sleep 5
#export SL_SCHED="re"
#~/sshlauncher/sshlauncher $CONFIG_FILE.config
#sleep 5


ssh vuva@$CLIENT 'sudo sysctl -w net.mptcp.mptcp_scheduler=oppredundant'
ssh vuva@$SERVER 'sudo sysctl -w net.mptcp.mptcp_scheduler=oppredundant'
sleep 5
export SL_SCHED="opp"
~/sshlauncher/sshlauncher $CONFIG_FILE.config
sleep 5

done


echo done
