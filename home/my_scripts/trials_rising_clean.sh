#!/bin/bash
pkill -9 -f "trials\|uplay\|ubisoft\|UbisoftConnect\|EasyAntiCheat\|xalia"
WINEPREFIX=/home/pat/Games/trials-rising wineserver -k
sleep 2
