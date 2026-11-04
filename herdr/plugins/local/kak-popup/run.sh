#!/usr/bin/env bash
# Popup entrypoint registered in herdr-plugin.toml. Kakoune's herdr module
# passes the whole command line (usually `exec 'prog' 'arg' ...`) in
# KAK_POPUP_CMD; the leading exec makes this script become the program, so
# herdr sees the popup's root process exit and closes the popup itself.
set -u
: "${KAK_POPUP_CMD:?kak-popup: KAK_POPUP_CMD is not set}"
exec sh -c "$KAK_POPUP_CMD"
