package main

import (
	"bytes"
	crand "crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"encoding/binary"
	"encoding/pem"

	// "sync"

	// "errors"
	"flag"
	"fmt"
	"io"
	"log"
	"math/big"
	"math/rand"
	"net"

	// "net/http"
	"os"
	"strconv"
	"strings"
	"time"

	quic "github.com/lucas-clemente/quic-go"

	// "github.com/lucas-clemente/quic-go/h2quic"
	// "github.com/lucas-clemente/quic-go/internal/testdata"
	"github.com/lucas-clemente/quic-go/internal/utils"
	// "quic-go"
	//	"io/ioutil"
)

type binds []string

func (b binds) String() string {
	return strings.Join(b, ",")
}

func (b *binds) Set(v string) error {
	*b = strings.Split(v, ",")
	return nil
}

var BASE_SEQ_NO uint = 2147483648 // 0x80000000
var LOG_PREFIX string = ""
var SERVER_ADDRESS string = "10.1.1.2"
var SERVER_TCP_PORT int = 2121
var SERVER_QUIC_PORT int = 4343

type ClientManager struct {
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
}

type Client struct {
	socket net.Conn
	data   chan []byte
}

func (manager *ClientManager) start() {
	for {
		select {
		case connection := <-manager.register:
			manager.clients[connection] = true
			fmt.Println("Added new connection!")
		case connection := <-manager.unregister:
			if _, ok := manager.clients[connection]; ok {
				close(connection.data)
				delete(manager.clients, connection)
				fmt.Println("A connection has terminated!")
			}
		case message := <-manager.broadcast:
			for connection := range manager.clients {
				select {
				case connection.data <- message:
				default:
					close(connection.data)
					delete(manager.clients, connection)
				}
			}
		}
	}
}

func (manager *ClientManager) receive(client *Client) {

	timeStamps := make(map[uint]uint)
	buffer := make([]byte, 0)
	for {
		message := make([]byte, 65536)
		length, err := client.socket.Read(message)
		if err != nil {
			log.Println(err)
			manager.unregister <- client
			client.socket.Close()
			break
		}
		if length > 0 {
			message = message[0:length]
			// utils.Debugf("\n RECEIVED: %x \n", message)
			// manager.broadcast <- message
			eoc_byte_index := bytes.Index(message, intToBytes(uint(BASE_SEQ_NO-1), 4))
			// log.Println(eoc_byte_index)

			for eoc_byte_index != -1 {
				data_chunk := append(buffer, message[0:eoc_byte_index+4]...)
				//				seq_no := message[eoc_byte_index-4:eoc_byte_index]
				//				utils.Debugf("\n CHUNK: %x \n  length %d \n", data_chunk, len(data_chunk))
				// Get data chunk ID and record receive timestampt
				seq_no := data_chunk[0:4]
				seq_no_int := bytesToInt(seq_no)
				timeStamps[seq_no_int] = uint(time.Now().UnixNano())
				//				buffer.Write(message[eoc_byte_index:length])

				// Cut out recorded chunk
				message = message[eoc_byte_index+4:]
				buffer = make([]byte, 0)
				eoc_byte_index = bytes.Index(message, intToBytes(uint(BASE_SEQ_NO-1), 4))
			}
			buffer = append(buffer, message...)
		}
	}

	writeToFile(LOG_PREFIX+"server-timestamp.log", timeStamps)
}

// func (client *Client) receive() {
// 	for {
// 		message := make([]byte, 4096)
// 		length, err := client.socket.Read(message)
// 		if err != nil {
// 			client.socket.Close()
// 			break
// 		}
// 		if length > 0 {
// 			utils.Debugf("RECEIVED: " + string(message))
// 		}
// 	}
// }

func (manager *ClientManager) send(client *Client) {
	defer client.socket.Close()
	for {
		select {
		case message, ok := <-client.data:
			if !ok {
				return
			}
			client.socket.Write(message)
		}
	}
}

func startServerMode(address string, protocol string, multipath bool, log_file string) {
	fmt.Println("Starting server...")
	var listener net.Listener
	var err error
	manager := ClientManager{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
	go manager.start()

	switch protocol {
	case "tcp":

		listener, err = net.Listen("tcp", address)
		if err != nil {
			log.Println(err)
		}
		log.Println("TCP Listen ...")
		for {
			connection, _ := listener.Accept()
			tcp_connection := connection.(*net.TCPConn)
			tcp_connection.SetNoDelay(true)
			if err != nil {
				log.Println(err)
			}
			client := &Client{socket: tcp_connection, data: make(chan []byte)}
			manager.register <- client
			go manager.receive(client)
			//		go manager.send(client)
		}
	case "quic":

		startQUICServer(address)

	}

}

func startClientMode(address string, protocol string, run_time uint, csize_distro string, csize_value float64, arrival_distro string, arrival_value float64, multipath bool, scheduler string) {
	fmt.Println("Starting client...")

	var stream quic.Stream
	var quic_session quic.Session
	var connection *net.TCPConn
	var err error

	if protocol == "quic" {
		addresses := []string{address}
		quic_session, stream, err = startQUICClient(addresses, scheduler)
		defer stream.Close()
		defer quic_session.Close(nil)

	} else if protocol == "tcp" {
		tcp_address := strings.Split(address, ":")
		ip_add := net.ParseIP(tcp_address[0]).To4()
		port, _ := strconv.Atoi(tcp_address[1])
		connection, err = net.DialTCP("tcp", nil, &net.TCPAddr{IP: ip_add, Port: port})
		connection.SetNoDelay(true)
		defer connection.Close()

	}
	//	addr,_:=net.ResolveTCPAddr("tcp", address+":443")
	//	connection, error := net.DialTCP("tcp", nil, addr)

	if err != nil {
		log.Println(err)
	}

	//	error = connection.SetNoDelay(true)
	//	if error != nil {
	//	    log.Println(error.Error())
	//	}
	//	client := &Client{socket: connection}
	//	go client.receive()

	// sendingDone := make(chan bool)
	//	go client.send(connection ,run_time , csize_distro , csize_value , arrival_distro , arrival_value )

	// go func() {
	var run_time_duration time.Duration
	run_time_duration, err = time.ParseDuration(strconv.Itoa(int(run_time)) + "ms")
	if err != nil {
		log.Println(err)
	}

	startTime := time.Now()
	timeStamps := make(map[uint]uint)

	send_queue := make([][]byte, 0)

	for i := 1; time.Now().Sub(startTime) < run_time_duration; i++ {
		// reader := bufio.NewReader(os.Stdin)
		// message, _ := reader.ReadString('\n')
		//			utils.Debugf("before: %d \n", time.Now().UnixNano())
		message, _ := generateMessage(uint(i), csize_distro, csize_value)

		send_queue = append(send_queue, message)
		next_message := send_queue[0]

		utils.Debugf("Messages in queue: %d \n", len(send_queue))
		if protocol == "quic" {
			stream.Write(next_message)

		} else if protocol == "tcp" {
			connection.Write(next_message)

		}

		timeStamps[bytesToInt(next_message[0:4])] = uint(time.Now().UnixNano())
		// remove sent file from the queue
		send_queue = send_queue[1:]

		// utils.Debugf("SENT: %x \n", message)

		wait(1 / getRandom(arrival_distro, arrival_value))
	}

	writeToFile(LOG_PREFIX+"client-timestamp.log", timeStamps)
	// sendingDone <- true
	// }()
	// <-sendingDone
}

func startQUICServer(addr string) error {
	listener, err := quic.ListenAddr(addr, generateTLSConfig(), &quic.Config{
		CreatePaths: true,
	})
	if err != nil {
		return err
	}
	sess, err := listener.Accept()
	if err != nil {
		return err
	}
	stream, err := sess.AcceptStream()
	if err != nil {
		panic(err)
	}
	defer stream.Close()
	// defer sess.Close(nil)

	// Echo through the loggingWriter
	// _, err = io.Copy(loggingWriter{stream}, stream)
	timeStamps := make(map[uint]uint)
	buffer := make([]byte, 0)
	for {
		message := make([]byte, 65536)
		length, err := stream.Read(message)
		if err != nil {
			log.Println(err)
			break
		}
		if length > 0 {
			message = message[0:length]
			// utils.Debugf("\n RECEIVED: %x \n", message)
			// manager.broadcast <- message
			eoc_byte_index := bytes.Index(message, intToBytes(uint(BASE_SEQ_NO-1), 4))
			// log.Println(eoc_byte_index)

			for eoc_byte_index != -1 {
				data_chunk := append(buffer, message[0:eoc_byte_index+4]...)
				//				seq_no := message[eoc_byte_index-4:eoc_byte_index]
				//				utils.Debugf("\n CHUNK: %x \n  length %d \n", data_chunk, len(data_chunk))
				// Get data chunk ID and record receive timestampt
				seq_no := data_chunk[0:4]
				seq_no_int := bytesToInt(seq_no)
				timeStamps[seq_no_int] = uint(time.Now().UnixNano())
				//				buffer.Write(message[eoc_byte_index:length])

				// Cut out recorded chunk
				message = message[eoc_byte_index+4:]
				buffer = make([]byte, 0)
				eoc_byte_index = bytes.Index(message, intToBytes(uint(BASE_SEQ_NO-1), 4))
			}
			buffer = append(buffer, message...)
		}
	}

	writeToFile(LOG_PREFIX+"server-timestamp.log", timeStamps)

	return err
}

func startQUICClient(urls []string, scheduler string) (sess quic.Session, stream quic.Stream, err error) {

	session, err := quic.DialAddr(urls[0], &tls.Config{InsecureSkipVerify: true}, &quic.Config{
		CreatePaths: true,
	})

	if err != nil {
		return nil, nil, err
	}
	quic.SetSchedulerAlgorithm(scheduler)
	stream, err2 := session.OpenStreamSync()
	if err2 != nil {
		return nil, nil, err2
	}

	// fmt.Printf("Client: Sending '%s'\n", message)
	// _, err = stream.Write([]byte(message))
	// if err != nil {
	// 	return err
	// }

	// buf := make([]byte, len(message))
	// _, err = io.ReadFull(stream, buf)
	// if err != nil {
	// 	return err
	// }
	// fmt.Printf("Client: Got '%s'\n", buf)

	return session, stream, nil
}

//func (client *Client) send(connection net.Conn,run_time uint, csize_distro string, csize_value float64, arrival_distro string, arrival_value float64) {
//
//	run_time_duration, error := time.ParseDuration(strconv.Itoa(int(run_time)) + "ms")
//	if error != nil {
//		log.Println(error)
//	}
//
//	startTime := time.Now()
//	timeStamps := make(map[uint]uint)
//	for i:=1; time.Now().Sub(startTime) < run_time_duration;i++ {
//		// reader := bufio.NewReader(os.Stdin)
//		// message, _ := reader.ReadString('\n')
//		message, seq_no := generateMessage(uint(i),csize_distro, csize_value)
//		connection.Write(message)
//		timeStamps[seq_no] = uint(time.Now().UnixNano())
//		wait(getRandom(arrival_distro, arrival_value))
//	}
//	writeToFile("client-timestamp.log", timeStamps)
//
//}

// wait for interarrival_time second
func wait(interarrival_time float64) {
	waiting_time := time.Duration(interarrival_time*1000000000) * time.Nanosecond
	utils.Debugf("wait for %d ms \n", waiting_time.Nanoseconds()/1000000)
	time.Sleep(waiting_time)
}

func getRandom(distro string, value float64) float64 {
	var retVal float64
	switch distro {
	case "c":
		retVal = value
	case "e":
		retVal = rand.ExpFloat64() * value
	case "g":

	case "b":

	case "wei":

	default:
		retVal = 1.0
	}

	return retVal
}

func generateMessage(offset_seq uint, csize_distro string, csize_value float64) ([]byte, uint) {
	//	utils.Debugf("Gen mess: %d \n", time.Now().UnixNano())
	seq_no := BASE_SEQ_NO + offset_seq
	seq_header := intToBytes(uint(seq_no), 4)
	eoc_header := intToBytes(uint(BASE_SEQ_NO-1), 4)

	csize := uint(getRandom(csize_distro, csize_value))
	//chunk size must be a factor of 4 to avoid EOL fragmenting
	csize = csize - csize%4
	if csize < 8 {
		csize = 8
	}

	pseudo_payload := make([]byte, (csize - 8))
	for i := 0; i < len(pseudo_payload); i++ {
		pseudo_payload[i] = 0x01
	}

	message := append(seq_header, pseudo_payload...)
	//	message = append(message, seq_header...)
	message = append(message, eoc_header...)
	//	utils.Debugf("Message size %d: %x \n ", uint(csize), message)
	return message, seq_no
}

func intToBytes(num uint, size uint) []byte {
	bs := make([]byte, size)
	binary.BigEndian.PutUint32(bs, uint32(num))
	return bs
}

func bytesToInt(b []byte) uint {
	return uint(binary.BigEndian.Uint32(b))
}

func writeToFile(filename string, data map[uint]uint) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	for k, v := range data {

		_, err = io.WriteString(file, fmt.Sprintln(k, v))
		if err != nil {
			return err
		}
	}

	return file.Sync()
}

type loggingWriter struct{ io.Writer }

func (w loggingWriter) Write(b []byte) (int, error) {
	fmt.Printf("Server: Got '%x'\n", b)
	return w.Writer.Write(b)
}

func generateTLSConfig() *tls.Config {
	key, err := rsa.GenerateKey(crand.Reader, 1024)
	if err != nil {
		panic(err)
	}
	template := x509.Certificate{SerialNumber: big.NewInt(1)}
	certDER, err := x509.CreateCertificate(crand.Reader, &template, &template, &key.PublicKey, key)
	if err != nil {
		panic(err)
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: certDER})

	tlsCert, err := tls.X509KeyPair(certPEM, keyPEM)
	if err != nil {
		panic(err)
	}
	return &tls.Config{Certificates: []tls.Certificate{tlsCert}}
}

func schedNameConvert(protocol string, sched_name string) string {
	converted_name := sched_name
	if protocol == "quic" {
		switch sched_name {
		case "lrtt":
			converted_name = "lowRTT"
		case "rr":
			converted_name = "RR"
		case "opp":
			converted_name = "oppRedundant"
		default:
			panic("no scheduler found")
		}
	}

	return converted_name
}

func main() {
	flagMode := flag.String("mode", "server", "start in client or server mode")
	flagTime := flag.Uint("t", 10000, "time to run (ms)")
	flagCsizeDistro := flag.String("csizedist", "c", "data chunk size distribution")
	flagCsizeValue := flag.Float64("csizeval", 1000, "data chunk size value")
	flagArrDistro := flag.String("arrdist", "c", "arrival distribution")
	flagArrValue := flag.Float64("arrval", 1000, "arrival value")
	flagAddress := flag.String("a", "localhost", "Destination address")
	flagProtocol := flag.String("p", "tcp", "TCP or QUIC")
	flagLog := flag.String("log", "", "Log folder")
	flagMultipath := flag.Bool("m", true, "Enable multipath")
	flagSched := flag.String("sched", "", "Scheduler")
	flagDebug := flag.Bool("v", false, "Debug mode")
	flagCong := flag.String("cc", "cubic", "Congestion control")
	flag.Parse()
	if *flagDebug {
		utils.SetLogLevel(utils.LogLevelDebug)
	}

	LOG_PREFIX = *flagLog
	quic.SetCongestionControl(*flagCong)

	if strings.ToLower(*flagMode) == "server" {
		startServerMode(*flagAddress, *flagProtocol, *flagMultipath, *flagLog)
	} else {
		sched := schedNameConvert(*flagProtocol, *flagSched)
		startClientMode(*flagAddress, *flagProtocol, *flagTime, *flagCsizeDistro, float64(*flagCsizeValue), *flagArrDistro, float64(*flagArrValue), *flagMultipath, sched)
	}
}
