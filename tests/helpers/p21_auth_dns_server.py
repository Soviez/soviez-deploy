#!/usr/bin/env python3
"""Minimal disposable authoritative DNS (A records) for Phase 21 certification."""
from __future__ import annotations

import argparse
import socket
import struct
import threading
import time


def encode_name(name: str) -> bytes:
    out = bytearray()
    for label in name.rstrip(".").split("."):
        b = label.encode("ascii")
        out.append(len(b))
        out.extend(b)
    out.append(0)
    return bytes(out)


def parse_name(data: bytes, offset: int):
    labels = []
    jumped = False
    original = offset
    while True:
        if offset >= len(data):
            raise ValueError("bad name")
        length = data[offset]
        if length & 0xC0 == 0xC0:
            if offset + 1 >= len(data):
                raise ValueError("bad pointer")
            pointer = ((length & 0x3F) << 8) | data[offset + 1]
            if not jumped:
                original = offset + 2
            offset = pointer
            jumped = True
            continue
        offset += 1
        if length == 0:
            break
        labels.append(data[offset : offset + length].decode("ascii"))
        offset += length
    name = ".".join(labels).lower()
    return name, (original if jumped else offset)


def build_response(query: bytes, records: dict[str, str]) -> bytes:
    if len(query) < 12:
        return b""
    tid = query[:2]
    flags = struct.pack("!H", 0x8180)  # standard response, no error
    qdcount = query[4:6]
    # parse question
    name, off = parse_name(query, 12)
    qtype, qclass = struct.unpack("!HH", query[off : off + 4])
    question = query[12 : off + 4]
    answers = b""
    ancount = 0
    if qtype in (1, 255):  # A or ANY
        ip = records.get(name)
        if ip:
            answers += encode_name(name)
            answers += struct.pack("!HHIH", 1, 1, 60, 4)
            answers += socket.inet_aton(ip)
            ancount = 1
    header = tid + flags + qdcount + struct.pack("!HHH", ancount, 0, 0)
    return header + question + answers


def serve(host: str, port: int, records: dict[str, str], ready: threading.Event, stop: threading.Event):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((host, port))
    sock.settimeout(0.5)
    ready.set()
    while not stop.is_set():
        try:
            data, addr = sock.recvfrom(2048)
        except socket.timeout:
            continue
        try:
            resp = build_response(data, records)
            if resp:
                sock.sendto(resp, addr)
        except Exception:
            continue
    sock.close()


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--record", action="append", default=[], help="name=ip")
    p.add_argument("--ready-file")
    p.add_argument("--stop-file")
    args = p.parse_args()
    records = {}
    for r in args.record:
        n, ip = r.split("=", 1)
        records[n.rstrip(".").lower()] = ip
    ready = threading.Event()
    stop = threading.Event()
    t = threading.Thread(target=serve, args=(args.host, args.port, records, ready, stop), daemon=True)
    t.start()
    ready.wait(5)
    if args.ready_file:
        open(args.ready_file, "w").write("ready\n")
    if args.stop_file:
        while not stop.is_set():
            if os_path_exists(args.stop_file):
                stop.set()
                break
            time.sleep(0.1)
    else:
        while True:
            time.sleep(1)


def os_path_exists(path: str) -> bool:
    import os

    return os.path.exists(path)


if __name__ == "__main__":
    main()
