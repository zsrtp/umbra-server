// tp-net-test: Test client that simulates a second Wii for umbra-server relay testing.
// Connects to the server, displays received state packets, and echoes them back.
//
// Usage: go run . [server_ip:port]
// Default: 127.0.0.1:52224

package main

import (
	"encoding/binary"
	"fmt"
	"math"
	"net"
	"os"
	"time"
)

const (
	defaultServer = "127.0.0.1:52224"
	maxPacketSize = 1408

	MsgState = 0x01
	MsgJoin  = 0x02
)

// Matches the LinkState struct sent by umbra
type LinkState struct {
	PosX, PosY, PosZ    float32
	AngleX, AngleY, AngleZ int16
	SpeedF              float32
	Animation           uint16
	_pad                uint16
}

func parseLinkState(data []byte) *LinkState {
	if len(data) < 24 {
		return nil
	}
	return &LinkState{
		PosX:      math.Float32frombits(binary.BigEndian.Uint32(data[0:4])),
		PosY:      math.Float32frombits(binary.BigEndian.Uint32(data[4:8])),
		PosZ:      math.Float32frombits(binary.BigEndian.Uint32(data[8:12])),
		AngleX:    int16(binary.BigEndian.Uint16(data[12:14])),
		AngleY:    int16(binary.BigEndian.Uint16(data[14:16])),
		AngleZ:    int16(binary.BigEndian.Uint16(data[16:18])),
		SpeedF:    math.Float32frombits(binary.BigEndian.Uint32(data[18:22])),
		Animation: binary.BigEndian.Uint16(data[22:24]),
	}
}

func main() {
	server := defaultServer
	if len(os.Args) > 1 {
		server = os.Args[1]
	}

	serverAddr, err := net.ResolveUDPAddr("udp", server)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bad server address %q: %v\n", server, err)
		os.Exit(1)
	}

	conn, err := net.DialUDP("udp", nil, serverAddr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "dial: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close()

	fmt.Printf("tp-net-test connected to %s\n", server)
	fmt.Println("Sending JOIN, then listening for relayed state packets...")
	fmt.Println("Will echo received states back to server.")
	fmt.Println()

	// Send JOIN packet: [player_id=0][msg_type=JOIN][len=0]
	joinPkt := []byte{0x00, MsgJoin, 0x00, 0x00}
	conn.Write(joinPkt)

	// Start receiver in background
	go func() {
		buf := make([]byte, maxPacketSize)
		pktCount := 0
		for {
			n, err := conn.Read(buf)
			if err != nil {
				fmt.Printf("recv error: %v\n", err)
				continue
			}

			if n < 4 {
				continue
			}

			playerID := buf[0]
			msgType := buf[1]
			payloadLen := binary.BigEndian.Uint16(buf[2:4])

			pktCount++

			switch msgType {
			case MsgState:
				payload := buf[4:n]
				state := parseLinkState(payload)
				if state != nil {
					fmt.Printf("[#%04d] player=%d pos=(%.1f, %.1f, %.1f) angle=%d speed=%.2f anim=0x%04X\n",
						pktCount, playerID,
						state.PosX, state.PosY, state.PosZ,
						state.AngleY, state.SpeedF, state.Animation)

					// Echo back as our own state
					echoPkt := make([]byte, n)
					copy(echoPkt, buf[:n])
					echoPkt[0] = 0 // our player_id (server will reassign)
					conn.Write(echoPkt)
				} else {
					fmt.Printf("[#%04d] player=%d STATE (%d bytes, too short to parse)\n",
						pktCount, playerID, payloadLen)
				}

			default:
				fmt.Printf("[#%04d] player=%d msg_type=0x%02X len=%d\n",
					pktCount, playerID, msgType, payloadLen)
			}
		}
	}()

	// Keep alive: send a heartbeat state every 2 seconds so we don't get reaped
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		// Minimal state packet: [player_id=0][STATE][len=24][24B zeroed state]
		heartbeat := make([]byte, 4+24)
		heartbeat[0] = 0x00
		heartbeat[1] = MsgState
		binary.BigEndian.PutUint16(heartbeat[2:4], 24)
		// Leave state zeroed — server sees it as pos=(0,0,0)
		conn.Write(heartbeat)
	}
}
