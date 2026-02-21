# umbra-server

A lightweight UDP relay server for [Umbra](https://github.com/zsrtp/umbra) multiplayer state synchronization.

## Overview

umbra-server listens on UDP port `52224` (0x00CC00) and relays player state packets between connected clients. Clients are automatically registered on first packet and removed after a 5-second inactivity timeout.

## Building

```sh
go build -o umbra-server .
```

## Running

```sh
./umbra-server
```

The server listens on UDP port 52224.

## Test Client

`tp-net-test` is a test client that simulates a second Wii for relay testing. It connects to the server, displays received state packets, and echoes them back.

```sh
cd tp-net-test
go run . [server_ip:port]
```

Defaults to `127.0.0.1:52224` if no address is provided.
