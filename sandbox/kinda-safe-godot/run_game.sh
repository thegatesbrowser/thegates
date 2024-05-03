#!/bin/bash

cd $1
sh ./fakechroot_enviroment/fakechroot.sh chroot ./fakechroot_enviroment/root /bin/sh /GATES-FILES/launch.sh ${@:2}
rm ./fakechroot_enviroment/root/GATES-FILES/game
