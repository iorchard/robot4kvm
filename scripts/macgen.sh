#!/bin/bash

printf '52:54:00:%02x:%02x:%02x\n' \
    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))

