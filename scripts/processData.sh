n=$2
EXPNAME=$1
for ((i=1;i<=n;i++)); do
python3.6 ~/logs/outage/pcapProcess.py -p MPTCP -sf $i-lrtt-$EXPNAME-sender.csv -rf $i-lrtt-$EXPNAME-receiver.csv -saddr 10.1.2.2 10.1.3.2 -daddr 10.1.1.2 -o $i-lrtt-$EXPNAME-pcap.dat
python3.6 ~/logs/outage/pcapProcess.py -p MPTCP -sf $i-rr-$EXPNAME-sender.csv -rf $i-rr-$EXPNAME-receiver.csv -saddr 10.1.2.2 10.1.3.2 -daddr 10.1.1.2 -o $i-rr-$EXPNAME-pcap.dat
python3.6 ~/logs/outage/pcapProcess.py -p MPTCP -sf $i-re-$EXPNAME-sender.csv -rf $i-re-$EXPNAME-receiver.csv -saddr 10.1.2.2 10.1.3.2 -daddr 10.1.1.2 -o $i-re-$EXPNAME-pcap.dat
python3.6 ~/logs/outage/pcapProcess.py -p MPTCP -sf $i-opp-$EXPNAME-sender.csv -rf $i-opp-$EXPNAME-receiver.csv -saddr 10.1.2.2 10.1.3.2 -daddr 10.1.1.2 -o $i-opp-$EXPNAME-pcap.dat

done
