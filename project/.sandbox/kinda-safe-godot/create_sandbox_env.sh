#!/bin/bash

sandbox_env_dir=../sandbox
sandbox_env_zip=$sandbox_env_dir/sandbox_env.zip

symlinks_dir=fakechroot_enviroment/root
symlinks_zip=$symlinks_dir/symlinks.zip

files_to_zip="fakechroot_enviroment run_game.sh list_child_processes.sh"

rm -f $sandbox_env_zip
mkdir $sandbox_env_dir

unzip -o $symlinks_zip -d $symlinks_dir

zip -ry $sandbox_env_zip $files_to_zip -x $symlinks_zip
