#!/bin/bash
index=$(yabai -m query --spaces --display | jq -r 'map(select(.["has-focus"] == true))[0].index')
if [ -z "$index" ] || [ "$index" = "null" ]; then
    exit 1
fi

# Move non-sticky windows on this space to the previous space
yabai -m query --windows --space "$index" | jq -r '.[] | select(.["is-sticky"] == false) | .id' | while read -r wid; do
    yabai -m window "$wid" --space prev
done

yabai -m space --destroy "$index"
