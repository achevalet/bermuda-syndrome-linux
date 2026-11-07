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
exec "$BIN" --datapath="$DATA" --savepath="$STATE/saves" "$@"
