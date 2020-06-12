#!/usr/bin/python3

import socket
import sqlite3
from time import sleep

conn = sqlite3.connect('/Users/chris/Desktop/DIYDragy.db')
c = conn.cursor()


UDP_IP = "127.0.0.1"
UDP_PORT = 9999

print("UDP target IP:", UDP_IP)
print("UDP target port:", UDP_PORT)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) 


for gpsLogEntry in c.execute('SELECT * FROM rawlog WHERE id > 28900 ORDER BY id'):
    new_str = ""
    for i in gpsLogEntry[2]:
#        sock.sendto(i.to_bytes(1, byteorder='little'), (UDP_IP, UDP_PORT))
        new_str += hex(i) + " "
    #print(new_str)
    print(gpsLogEntry[0])
    sock.sendto(gpsLogEntry[2], (UDP_IP, UDP_PORT))
    sleep(0.1)
    
