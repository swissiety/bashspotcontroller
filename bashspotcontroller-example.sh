#! /bin/bash

#load heper functions
. spotify.sh

#initialize your user 
load_credentials;

#list your playlists
#my_playlists;

#list your running devices
list_devices;
echo "> copy deviceId to activate a device"
read DID;
activate_device "$DID";


# play a song
volume 20;
play "spotify:track:4uLU6hMCjMI75M1A2tKUQC"

sleep 1;

volume 30;
sleep 1;
volume 45;
sleep 1;
volume 60;
sleep 1;
volume 80;
sleep 1;
volume 100;

#play  playlist/album
play_list spotify:album:5p0H50uFCdWTpLY640HoPc

next;

sleep 3;

previous;

sleep 3;

pause;

sleep 2;

play;


