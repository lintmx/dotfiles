#!/bin/bash

# My Script

cp -R ~/.tools/* ./tools/

# Oh-My-Zsh config

cp ~/.zshrc ./

# Vim config

cp ~/.vimrc ./

# config

cp -r ~/.config/conky ./config
cp -r ~/.config/i3 ./config
cp -r ~/.config/mpd/mpd.conf ./config/mpd/
cp -r ~/.config/mpv ./config/mpv
cp -r ~/.config/xarchiver ./config/xarchiver
cp -r ~/.config/termite ./config/termite

cp ~/.xprofile ./
cp ~/.Xresources ./

# systemd

cp ~/.config/systemd/user/wallpaper.* ./config/systemd/user/
