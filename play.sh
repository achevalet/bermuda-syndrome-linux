#!/bin/sh
# Start Bermuda Syndrome. Extra arguments go to the engine, e.g.:
#   ./play.sh --fullscreen --widescreen=16:9
set -e

ROOT=$(cd "$(dirname "$0")" && pwd)
BIN=$ROOT/build/bs
DATA=$ROOT/data
STATE=${BERMUDA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/bermuda-syndrome}

[ -x "$BIN" ] || { echo "The engine is not built yet: run $ROOT/setup.sh" >&2; exit 1; }
[ -d "$DATA" ] || { echo "No game data yet: run $ROOT/setup.sh /path/to/bermuda.iso" >&2; exit 1; }

# SDL_mixer plays the game's MIDI music through FluidSynth, which needs a soundfont.
if [ -z "${SDL_SOUNDFONTS:-}" ]; then
	for sf in /usr/share/sounds/sf2/default-GM.sf2 /usr/share/sounds/sf2/FluidR3_GM.sf2 \
	          /usr/share/sounds/sf2/TimGM6mb.sf2 /usr/share/soundfonts/default.sf2 \
	          /usr/share/soundfonts/FluidR3_GM.sf2 /usr/share/sounds/sf2/FluidR3_GM2-2.sf2; do
		if [ -f "$sf" ]; then
			export SDL_SOUNDFONTS="$sf"
			break
		fi
	done
fi

# Saves and screenshots live outside the repo so updates and 'git clean' never touch them.
mkdir -p "$STATE/saves"
cd "$STATE"

# The engine overwrites a save slot in place, so before each session keep a copy
# of the saves in backups/<date>/, if they changed since the last one. The last
# $KEEP backups are kept.
KEEP=${BERMUDA_BACKUPS:-10}
case $KEEP in
	''|*[!0-9]*)
		echo "BERMUDA_BACKUPS must be a number of backups to keep (0 disables them), not '$KEEP': using 10" >&2
		KEEP=10 ;;
esac

# Succeeds if a save is new or differs from its copy in the latest backup.
saves_changed() {
	latest=$(ls -d backups/*/ 2>/dev/null | tail -n 1)
	[ -n "$latest" ] || return 0
	for f in saves/bermuda.[0-9][0-9][0-9]; do
		cmp -s "$f" "$latest${f#saves/}" || return 0
	done
	return 1
}

# Deletes the oldest backups beyond $KEEP. Folder names are dates, so the glob
# lists them oldest first. (A function, to keep the script's "$@" intact.)
prune_backups() {
	set -- backups/*/
	excess=$(( $# - KEEP ))
	for old in "$@"; do
		[ "$excess" -gt 0 ] || break
		rm -rf "$old"
		excess=$(( excess - 1 ))
	done
}

if [ "$KEEP" -gt 0 ] && ls saves/bermuda.[0-9][0-9][0-9] >/dev/null 2>&1 && saves_changed; then
	backup=backups/$(date +%Y-%m-%d_%H%M%S)
	mkdir -p "$backup"
	cp -p saves/bermuda.[0-9][0-9][0-9] "$backup/"
	prune_backups
fi

exec "$BIN" --datapath="$DATA" --savepath="$STATE/saves" "$@"
