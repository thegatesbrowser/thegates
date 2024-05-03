#!/bin/bash

zip=../sandbox/sandbox_env.zip

rm $zip
zip -ry $zip fakechroot_enviroment run_game.sh list_child_processes.sh