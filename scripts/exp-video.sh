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
export CONFIG_FILE=app-delay-video-quic-exp

for ((i=1;i<=n;i++))
do
echo "==== Running Test No. $i/$n ===="
export SL_I=$i
export CLIENT=nodem3.moongenmultipath.spork-join.filab.uni-hannover.de
export SERVER=nodem1.moongenmultipath.spork-join.filab.uni-hannover.de
export ROUTER=nodem2.moongenmultipath.spork-join.filab.uni-hannover.de


#: <<'END'


export SL_SCHED="lowRTT"
~/sshlauncher/sshlauncher $CONFIG_FILE.config -d
sleep 5

export SL_SCHED="RR"
~/sshlauncher/sshlauncher $CONFIG_FILE.config
sleep 5


#ssh vuva@$CLIENT 'sudo sysctl -w net.mptcp.mptcp_scheduler=oppredundant'
#ssh vuva@$SERVER 'sudo sysctl -w net.mptcp.mptcp_scheduler=oppredundant'
#sleep 5
#export SL_SCHED="opp"
#~/sshlauncher/sshlauncher $CONFIG_FILE.config
#sleep 5


export SL_SCHED="redundant"
~/sshlauncher/sshlauncher $CONFIG_FILE.config
sleep 5


export SL_SCHED="nineTails"
~/sshlauncher/sshlauncher $CONFIG_FILE.config
sleep 5
END

#sleep 5
#export SL_SCHED="sp"
#~/sshlauncher/sshlauncher $CONFIG_FILE.config
#sleep 5

done


echo done
