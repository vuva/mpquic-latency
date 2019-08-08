import argparse
# import matplotlib.pyplot as plt
import csv
import json
import sys
import hashlib
import ipaddress
import socket
import struct
TCP_PROTO = 6
RETRANSMISSION_TIMEOUT = 2.0
DEFAULT_OUTPUT = 'TLOWPM.dat'
debug=False
class PacketData:
    def __init__(self, no, timestamp, source, srcport, dest, destport, protocol, length, seq, ack, payload):
        self.no= no
        self.timestamp= timestamp
        self.source= source
        self.dest= dest
        self.srcport= srcport
        self.destport= destport
        self.protocol= protocol
        self.length= length
        self.seq= seq
        self.ack= ack


def main(argv):
    parser = argparse.ArgumentParser(description='TCP Latency One-way Passive Measurement')
    parser.add_argument('-p', dest='protocol', help='Select protocol: TCP or MPTCP ', required=True, default='TCP')
    parser.add_argument('-sf', dest='senderPcapFiles', nargs='+', help='Sender Pcap files')
    parser.add_argument('-rf', dest='receiverPcapFiles', nargs='+', help='Receiver Pcap files')
    parser.add_argument('-saddr', dest='sourceAddresses', nargs='+', help='Sender address')
    parser.add_argument('-daddr', dest='destinationAddresses', nargs='+', help='Receiver address')
    parser.add_argument('-o', dest='outputFile', default=DEFAULT_OUTPUT, help='Output filename')
    parser.add_argument('-v','--verbosity', help="increase output verbosity",action="store_true")
    parser.add_argument('-r','--reversed', help="seperate ack",action="store_true")

    args = parser.parse_args()
    src_addresses = args.sourceAddresses
    dst_addresses = args.destinationAddresses
    debug=args.verbosity
    print('Parsing Sender Pcap ...')
    sent_packets_pcap=dict()
    for sender_file_name in args.senderPcapFiles:
        if '.json' in sender_file_name:
            sent_packets_pcap = {**sent_packets_pcap, **impt_json(sender_file_name)}
        elif '.csv' in sender_file_name:
            sent_packets_pcap = {**sent_packets_pcap, **impt_csv(sender_file_name, args.protocol)}
        else:
            print('Invalid file format')
            return
    # sent_packets_pcap.sort(key=lambda t:'t.timestamp')

    print('Parsing Receiver Pcap ...')
    received_packets_pcap={}
    for receiver_file_name in args.receiverPcapFiles:
        if '.json' in receiver_file_name:
            received_packets_pcap = {**received_packets_pcap, **impt_json(receiver_file_name)}
        elif '.csv' in receiver_file_name:
            received_packets_pcap = {**received_packets_pcap, **impt_csv(receiver_file_name, args.protocol)}
        else:
            print('Invalid file format')
            return
    # received_packets_pcap.sort(key=lambda t:'t.timestamp')

    print('Filtering Sender Pcap ...')
    senderPcap=filter_pcap(sent_packets_pcap, src_addresses, dst_addresses, args.reversed)
    print('Filtering Receiver Pcap ...')
    receiverPcap=filter_pcap(received_packets_pcap, src_addresses, dst_addresses,args.reversed)
    print('Processing Pcap ...')
    processed_data = process_tcp(senderPcap,receiverPcap, src_addresses, dst_addresses)

    print('Writing results to ' + args.outputFile + ' ...')
    outputFile = open(args.outputFile, 'w', newline='')
    outputWriter = csv.writer(outputFile)
    if args.reversed:
        reversedOutputFile = open('reversed-'+args.outputFile, 'w', newline='')
        reversedOutputWriter = csv.writer(reversedOutputFile)
    for entry in processed_data:
        row_data=[]
        for key in entry:
            row_data.append(entry[key])

        if args.reversed and socket.inet_ntoa(struct.pack('!L', entry['src'])) in args.destinationAddresses:
            row_data[9]= -row_data[9]
            reversedOutputWriter.writerow(row_data)
        else:
            outputWriter.writerow(row_data)

    outputFile.close()
    if args.reversed:
        reversedOutputFile.close()
    # draw_plot(processed_data)

def export_json_data(data, outfileName):
    with open(outfileName, 'w') as outfile:
        json.dump(data, outfile)

def generate_hash_key(packet, protocol):
    hash_func = hashlib.blake2b()
    if protocol == 'MPTCP':
        hash_func.update(('proto' + repr(packet.protocol)).encode("UTF-8"))
        hash_func.update(('dst'+repr(packet.dest)).encode("UTF-8"))
        hash_func.update(('dstp'+repr(packet.destport)).encode("UTF-8"))
        hash_func.update(('dataseq'+repr(packet.rawdataseqno)).encode("UTF-8"))
        hash_func.update(('dataack'+repr(packet.rawdataackno)).encode("UTF-8"))
    elif protocol=='TCP':
        hash_func.update(('proto'+repr(packet.protocol)).encode("UTF-8"))
        hash_func.update(('src'+repr(packet.source)).encode("UTF-8"))
        hash_func.update(('srcp'+repr(packet.srcport)).encode("UTF-8"))
        hash_func.update(('dst'+repr(packet.dest)).encode("UTF-8"))
        hash_func.update(('dstp'+repr(packet.destport)).encode("UTF-8"))
        hash_func.update(('seq'+repr(packet.seq)).encode("UTF-8"))
        hash_func.update(('ack'+repr(packet.ack)).encode("UTF-8"))
        #hash_func.update(('len'+repr(packet.length)).encode("UTF-8"))
    return hash_func.hexdigest()


def impt_json(pcap_filename):
    try:
        pcap_file = open(pcap_filename, "r")
        packets_data=json.load(pcap_file)
    except FileNotFoundError:
        print('File(s) not found')
        return

    packets = dict()
    for data_entry in packets_data:
        if 'ip' not in data_entry['_source']['layers']:
            continue
        packet= PacketData(packets_data.index(data_entry) , float(data_entry['_source']['layers']['frame']['frame.time_epoch']), data_entry['_source']['layers']['ip']['ip.src'],int(data_entry['_source']['layers']['tcp']['tcp.srcport']), data_entry['_source']['layers']['ip']['ip.dst'], int(data_entry['_source']['layers']['tcp']['tcp.dstport']),int(data_entry['_source']['layers']['ip']['ip.proto']),int(data_entry['_source']['layers']['frame']['frame.len']),int(data_entry['_source']['layers']['tcp']['tcp.seq']), int(data_entry['_source']['layers']['tcp']['tcp.ack']))
        if packet is not None:
            hash_key = generate_hash_key(packet)
            if hash_key in packets:
                print('Retransmitted packet: ')
                print(packet.__dict__)
                print('of')
                print(packets[hash_key].__dict__)
            else:
                packets[hash_key] = packet

    return packets

def impt_csv(pcap_filename, protocol):
    try:
        pcap_file = open(pcap_filename, "r")
        packet_reader = csv.reader(pcap_file, delimiter='\t')
    except FileNotFoundError:
        print('File(s) not found')
        return

    packets_data=list(packet_reader)
    packets_data.sort(key=lambda p: p[1])
    packets = dict()
    dup_packets_count=0
    for data_entry in packets_data:
        try:
            packet= PacketData(int(data_entry[0]), float(data_entry[1]),data_entry[2], int(data_entry[3]),data_entry[4], int(data_entry[5]),int(data_entry[6]),int(data_entry[7]),int(data_entry[8]) if data_entry[8] is not '' else None,int(data_entry[9]) if data_entry[9] is not '' else None)
            if protocol=='MPTCP':
                packet.rawdataseqno = int(data_entry[10]) if data_entry[10] is not '' else None
                packet.rawdataackno = int(data_entry[11]) if data_entry[11] is not '' else None
            elif protocol=='TCP':
                packet.rawdataseqno = -1;
                packet.rawdataackno = -1;

            packet.payload= base64.b16decode(data_entry[12]) if data_entry[12] is not '' else None

            if packet is not None:
                hash_key = generate_hash_key(packet, protocol)
                if hash_key in packets:
                    dup_packets_count+=1
                    if debug:
                        print('Retransmitted packet: ')
                        print(packet.__dict__)
                        print('of')
                        print(packets[hash_key].__dict__)
                else:
                    packets[hash_key] = packet
        except Exception as e:
            print(e)
            # print(packets.__dict__)
            # raise
            continue
    print('Retransmitted packets: ' + repr(dup_packets_count) + '/'+ repr(len(packets_data)))
    return packets


# def draw_plot(data):
#     index=[]
#     depart=[]
#     arrive=[]
#     latency=[]
#
#     for entry in data:
#         depart.append(entry['departure_time'])
#         arrive.append(entry['arrival_time'])
#         index.append(entry['index'])
#         latency.append(entry['arrival_time']-entry['departure_time'])
#
#     plt.scatter(index ,latency, color='red')
#     # plt.plot(index, depart, color='red')
#     # plt.plot(index, arrive, color='blue')
#     plt.show()

def filter_pcap(pcap_list, src_adds, dst_adds, reversed):
    result=dict()
    for packet in pcap_list:
        if  (pcap_list[packet].protocol == TCP_PROTO and pcap_list[packet].source in src_adds and pcap_list[packet].dest in dst_adds ):
            result[packet] = pcap_list[packet]
        elif reversed and pcap_list[packet].source in dst_adds and pcap_list[packet].dest in src_adds:
            result[packet] = pcap_list[packet]


    return result

def process_tcp(sender_pcap, receiver_pcap, src_addrs, dst_addrs):
    depart_arrive_pairs = []
    index=0
    # retransmission_packets=[]
    size=len(sender_pcap)
    for sent_packet_key in sender_pcap:
        # if sent_packet.no >1000:
        #     break
        sent_packet = sender_pcap[sent_packet_key]
        # if sent_packet.no in retransmission_packets:
        #     continue

        sent_seq = sent_packet.seq
        sent_ack = sent_packet.ack
        sent_src = sent_packet.source
        sent_dst = sent_packet.dest
        sent_len = sent_packet.length
        payload = int.from_bytes(sent_packet.payload[0:4], byteorder='big', signed=False)
        if sent_packet_key in receiver_pcap:
            depart_arrive_pairs.append(
                {'index': index, 'src':int(ipaddress.ip_address(sent_src)), 'dst':int(ipaddress.ip_address(receiver_pcap[sent_packet_key].source)), 'seq': sent_seq, 'ack': sent_ack, 'departure_time': sent_packet.timestamp,
                 "arrival_time": receiver_pcap[sent_packet_key].timestamp, 'dataseq': sent_packet.rawdataseqno, 'dataack': sent_packet.rawdataackno, 'latency': receiver_pcap[sent_packet_key].timestamp - sent_packet.timestamp, 'length':sent_len, 'payload': payload})
            index+=1
            if debug:
                print(repr(index) + '/' + repr(size))

    print('Total measured packets: ' + repr(len(depart_arrive_pairs)))
    # print(retransmission_packets)
    # print(len(retransmission_packets))
    return depart_arrive_pairs

if __name__ == "__main__":
    main(sys.argv)
