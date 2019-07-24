#/bin/bash
export n=$3
export SL_ONTIME=5
export SL_OFFTIME=3
export SL_EXPTIME=$2
export SL_FILE=$2
EXP_TYPE=$1
for ((i=1;i<=n;i++))
do
echo "==== Running Test No. $i/$n ===="
export SL_I=$i
export CLIENT=pc52.filab.uni-hannover.de
export SERVER=pc50.filab.uni-hannover.de
export ROUTER=pc51.filab.uni-hannover.de




ssh vuva@$CLIENT 'sudo sysctl -w net.mptcp.mptcp_scheduler=default'
ssh vuva@$SERVER 'sudo sysctl -w net.mptcp.mptcp_scheduler=default'
sleep 10
export SL_EX="lrtt"
~/sshlauncher/sshlauncher app-delay-exp.config
sleep 10

ssh vuva@$CLIENT 'sudo sysctl -w net.mptcp.mptcp_scheduler=redundant'
ssh vuva@$SERVER 'sudo sysctl -w net.mptcp.mptcp_scheduler=redundant'
sleep 10
export SL_EX="re"
~/sshlauncher/sshlauncher app-delay-exp.config
sleep 10

done
rm ~/*.zip.*
echo done
