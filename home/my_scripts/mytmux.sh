#!/bin/bash

shopt -s expand_aliases

echo "HI"
SESSION1="Local"

# Only create tmux session if it doesn't already exist
# Start New Session with our name
tmux new-session -d -s $SESSION1
tmux send-keys C-m

# Start bash at home
tmux rename-window -t 0 'Home'
tmux send-keys -t 'Home' 'clear;neofetch' C-m
tmux splitw -h
# sleep 1
tmux send-keys -t 'Home' 'bpytop' C-m
tmux last-pane

# Attach Session, on the Main window
tmux attach-session -t $SESSION:0
