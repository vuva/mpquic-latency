# mquic-latency

This is an experimental network traffic generator for MPTCP and MP-QUIC

Usage:

cd ~/mpquic-latency/mpquic-go/src/github/lucas-clemente/quic-go/traffic-gen

go run traffic-gen.go

  -a string
  
        Destination address (default "localhost")
        
  -arrdist string
  
        arrival distribution (default "c")
        
  -arrval float
  
        arrival value (default 1000)
        
  -cc string
  
        Congestion control (default "cubic")
        
  -csizedist string
  
        data chunk size distribution (default "c")
        
  -csizeval float
  
        data chunk size value (default 1000)
        
  -log string
  
        Log folder
        
  -m    Enable multipath (default true)
  
  -mode string
  
        start in client or server mode (default "server")
        
  -p string
  
        TCP or QUIC (default "tcp")
        
  -sched string
  
        Scheduler
        
  -t uint
  
        time to run (ms) (default 10000)
        
  -v    Debug mode
