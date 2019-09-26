#!/bin/bash

for i in `echo master01 master02 master03 slave01 slave02 slave03`;do
expect -c "
spawn scp $1 root@$i:$2
    expect {
            \"*yes/no*\" {send \"yes\r\"; exp_continue}
            \"*password*\" {send \"123456\r\"; exp_continue}
            \"*Password*\" {send \"123456\r\";}
    } "
done
