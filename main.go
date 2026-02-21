package main

import (
	"encoding/binary"
	"fmt"
	"log"
	"net"
	"os"
	"sync"
	"time"
)

const (
	listenPort    = 52224
	clientTimeout = 5 * time.Second
	maxPacketSize = 1408 // 4-byte header + 1400 payload

	// Message types (byte 1 of packet header)
	MsgState = 0x01
	MsgJoin  = 0x02
	MsgLeave = 0x03
)

type Client struct {
	Addr     *net.UDPAddr
	PlayerID uint8
	LastSeen time.Time
}

type Server struct {
	conn         *net.UDPConn
	mu           sync.Mutex
	clients      map[string]*Client // keyed by "ip:port"
	nextPlayerID uint8
}

func NewServer() *Server {
	return &Server{
		clients:      make(map[string]*Client),
		nextPlayerID: 1,
	}
}

func (s *Server) Start() error {
	addr := &net.UDPAddr{Port: listenPort}
	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		return fmt.Errorf("listen: %w", err)
	}
	s.conn = conn
	log.Printf("listening on :%d", listenPort)

	// Reaper: remove clients that haven't sent packets recently
	go s.reaper()

	buf := make([]byte, maxPacketSize)
	for {
		n, src, err := conn.ReadFromUDP(buf)
		if err != nil {
			log.Printf("read error: %v", err)
			continue
		}

		if n < 4 {
			continue
		}

		// Packet format: [1B player_id][1B msg_type][2B payload_len][payload...]
		msgType := buf[1]
		payloadLen := binary.BigEndian.Uint16(buf[2:4])

		if int(payloadLen) > n-4 {
			continue
		}

		key := src.String()

		s.mu.Lock()

		switch msgType {
		case MsgJoin:
			if _, exists := s.clients[key]; !exists {
				pid := s.nextPlayerID
				s.nextPlayerID++
				s.clients[key] = &Client{
					Addr:     src,
					PlayerID: pid,
					LastSeen: time.Now(),
				}
				log.Printf("[%s] joined as player %d (%d total)", key, pid, len(s.clients))
			} else {
				s.clients[key].LastSeen = time.Now()
			}

		case MsgLeave:
			if c, exists := s.clients[key]; exists {
				log.Printf("[%s] player %d left", key, c.PlayerID)
				delete(s.clients, key)
			}

		case MsgState:
			c, exists := s.clients[key]
			if !exists {
				pid := s.nextPlayerID
				s.nextPlayerID++
				c = &Client{
					Addr:     src,
					PlayerID: pid,
					LastSeen: time.Now(),
				}
				s.clients[key] = c
				log.Printf("[%s] auto-joined as player %d", key, pid)
			} else {
				c.LastSeen = time.Now()
			}

			// Stamp sender's player_id into the packet header
			buf[0] = c.PlayerID

			// Relay to all other clients
			packet := buf[:n]
			for otherKey, other := range s.clients {
				if otherKey == key {
					continue
				}
				if _, err := s.conn.WriteToUDP(packet, other.Addr); err != nil {
					log.Printf("[%s] relay to %s failed: %v", key, otherKey, err)
				}
			}

		default:
			log.Printf("[%s] unknown msg_type 0x%02X", key, msgType)
		}

		s.mu.Unlock()
	}
}

func (s *Server) reaper() {
	for {
		time.Sleep(1 * time.Second)
		s.mu.Lock()
		now := time.Now()
		for key, c := range s.clients {
			if now.Sub(c.LastSeen) > clientTimeout {
				log.Printf("[%s] player %d timed out", key, c.PlayerID)
				delete(s.clients, key)
			}
		}
		s.mu.Unlock()
	}
}

func main() {
	log.SetFlags(log.Ltime | log.Lmicroseconds)

	srv := NewServer()
	if err := srv.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "fatal: %v\n", err)
		os.Exit(1)
	}
}
