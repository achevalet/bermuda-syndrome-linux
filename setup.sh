#!/usr/bin/env bash
# Build the Bermuda Syndrome engine and import the game data from your own copy.
#
#   ./setup.sh [OPTIONS] [SOURCE]
#
# Run ./setup.sh --help for details.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENGINE_DIR=$ROOT/engine
BUILD_DIR=$ROOT/build
DATA_DIR=$ROOT/data
DESKTOP_FILE=${XDG_DATA_HOME:-$HOME/.local/share}/applications/bermuda-syndrome.desktop

SOUNDFONTS=(
	/usr/share/sounds/sf2/default-GM.sf2
	/usr/share/sounds/sf2/FluidR3_GM.sf2
	/usr/share/sounds/sf2/TimGM6mb.sf2
	/usr/share/soundfonts/default.sf2
	/usr/share/soundfonts/FluidR3_GM.sf2
	/usr/share/sounds/sf2/FluidR3_GM2-2.sf2
)

INSTALL_DEPS=1
INSTALL_DESKTOP=1
FORCE_DATA=0
CLEAN=0
SOURCE=

msg()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage: ./setup.sh [OPTIONS] [SOURCE]

Installs build dependencies, compiles the engine and imports the game data.
Run it again at any time: every step is skipped when already done.

SOURCE is your copy of the original Windows game, any of:
  - the CD image (.iso)
  - a mounted CD, or any folder containing the game's BERMUDA directory
  - a .tar/.tar.gz archive (or its unpacked folder) containing the CD image,
    such as a DOSBox bundle of the game

Options:
  --no-deps      do not install packages (just report what is missing)
  --no-desktop   do not create the application menu entry
  --force-data   re-import the game data from SOURCE even if it is already present
  --clean        remove the built engine, the imported game data and the menu
                 entry, then exit (saves and this folder are kept)
  -h, --help     show this help
EOF
}

while [ $# -gt 0 ]; do
	case $1 in
		--no-deps)    INSTALL_DEPS=0 ;;
		--no-desktop) INSTALL_DESKTOP=0 ;;
		--force-data) FORCE_DATA=1 ;;
		--clean)      CLEAN=1 ;;
		-h|--help)    usage; exit 0 ;;
		-*)           die "unknown option: $1 (see --help)" ;;
		*)            [ -z "$SOURCE" ] || die "only one SOURCE can be given"; SOURCE=$1 ;;
	esac
	shift
done

if [ $CLEAN = 1 ] && { [ -n "$SOURCE" ] || [ $FORCE_DATA = 1 ]; }; then
	die "--clean only removes files: run ./setup.sh again afterwards to reinstall"
fi
if [ $FORCE_DATA = 1 ] && [ -z "$SOURCE" ]; then
	die "--force-data needs a SOURCE to import from, e.g. ./setup.sh --force-data /path/to/bermuda.iso"
fi
if [ -n "$SOURCE" ]; then
	[ -e "$SOURCE" ] || die "no such file or directory: $SOURCE"
	SOURCE=$(realpath -- "$SOURCE")
fi

# --- dependencies ------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

find_soundfont() {
	local sf
	for sf in "${SOUNDFONTS[@]}"; do
		[ -f "$sf" ] && { echo "$sf"; return 0; }
	done
	return 1
}

have_build_deps() {
	have g++ && have make && have pkg-config &&
		pkg-config --exists sdl2 SDL2_mixer vorbisfile zlib
}

have_extractor() { have bsdtar || have 7z || have 7zz; }

install_deps() {
	local need_build=0 need_extract=0 need_sf=0
	have_build_deps || need_build=1
	have_extractor  || need_extract=1
	find_soundfont >/dev/null || need_sf=1
	if [ $need_build$need_extract$need_sf = 000 ]; then
		msg "Dependencies: all present"
		return
	fi

	local pm='' pkgs=()
	if have apt-get; then
		pm=apt
		[ $need_build = 1 ]   && pkgs+=(g++ make pkg-config libsdl2-dev libsdl2-mixer-dev libvorbis-dev zlib1g-dev)
		[ $need_extract = 1 ] && pkgs+=(libarchive-tools)
		[ $need_sf = 1 ]      && pkgs+=(fluid-soundfont-gm)
	elif have dnf; then
		pm=dnf
		[ $need_build = 1 ]   && pkgs+=(gcc-c++ make pkgconf-pkg-config SDL2-devel SDL2_mixer-devel libvorbis-devel zlib-devel)
		[ $need_extract = 1 ] && pkgs+=(bsdtar)
		[ $need_sf = 1 ]      && pkgs+=(fluid-soundfont-gm)
	elif have pacman; then
		pm=pacman
		[ $need_build = 1 ]   && pkgs+=(gcc make pkgconf sdl2 sdl2_mixer libvorbis zlib)
		[ $need_extract = 1 ] && pkgs+=(libarchive)
		[ $need_sf = 1 ]      && pkgs+=(soundfont-fluid)
	elif have zypper; then
		pm=zypper
		[ $need_build = 1 ]   && pkgs+=(gcc-c++ make pkg-config libSDL2-devel libSDL2_mixer-devel libvorbis-devel zlib-devel)
		[ $need_extract = 1 ] && pkgs+=(bsdtar)
		[ $need_sf = 1 ]      && pkgs+=(fluid-soundfont-gm)
	fi

	if [ -z "$pm" ]; then
		warn "unknown package manager; please install manually: a C++ compiler, make, pkg-config,"
		warn "SDL2, SDL2_mixer, libvorbis and zlib development files, bsdtar or 7-Zip, and a GM soundfont."
		have_build_deps || die "build dependencies missing"
		return
	fi
	if [ $INSTALL_DEPS = 0 ]; then
		warn "missing packages (--no-deps given): ${pkgs[*]}"
		have_build_deps || die "build dependencies missing"
		return
	fi

	local sudo=
	[ "$(id -u)" = 0 ] || sudo=sudo
	msg "Installing packages with $pm: ${pkgs[*]}"
	case $pm in
		apt)    $sudo apt-get update -q && $sudo apt-get install -y "${pkgs[@]}" ;;
		dnf)    $sudo dnf install -y "${pkgs[@]}" ;;
		pacman) $sudo pacman -S --needed --noconfirm "${pkgs[@]}" ;;
		zypper) $sudo zypper --non-interactive install "${pkgs[@]}" ;;
	esac
	have_build_deps || die "build dependencies still missing after installing packages"
}

# --- engine ------------------------------------------------------------------

build_engine() {
	if [ ! -f "$ENGINE_DIR/Makefile" ]; then
		if [ -d "$ROOT/.git" ] || [ -f "$ROOT/.git" ]; then
			msg "Fetching the engine source (git submodule)"
			git -C "$ROOT" submodule update --init
		fi
		[ -f "$ENGINE_DIR/Makefile" ] ||
			die "engine source missing: clone with 'git clone --recursive' or run 'git submodule update --init'"
	fi

	# Build out of tree so the engine checkout stays pristine.
	msg "Building the engine"
	mkdir -p "$BUILD_DIR/src"
	cp -p "$ENGINE_DIR"/*.cpp "$ENGINE_DIR"/*.h "$ENGINE_DIR"/Makefile "$BUILD_DIR/src/"
	make -s -C "$BUILD_DIR/src" -j"$(nproc 2>/dev/null || echo 2)" \
		SDL_CFLAGS="$(pkg-config --cflags sdl2 SDL2_mixer)" \
		SDL_LIBS="$(pkg-config --libs sdl2 SDL2_mixer)" \
		VORBIS_LIBS="$(pkg-config --libs vorbisfile)"
	cp -p "$BUILD_DIR/src/bs" "$BUILD_DIR/bs"
}

# --- game data ---------------------------------------------------------------

# Prints the game directory (the one holding BERMUDA.SPR) under $1, if any.
find_game_dir() {
	local spr
	spr=$(find "$1" -maxdepth 4 -iname bermuda.spr -type f -print -quit 2>/dev/null)
	[ -n "$spr" ] && dirname "$spr"
}

data_present() { [ -n "$(find_game_dir "$DATA_DIR" 2>/dev/null)" ]; }

is_iso() {
	# ISO 9660 images carry "CD001" at byte 32769.
	[ "$(dd if="$1" bs=1 skip=32769 count=5 2>/dev/null)" = CD001 ]
}

extract_iso() { # iso dest
	msg "Extracting $(basename "$1")"
	if have bsdtar; then
		bsdtar -xf "$1" -C "$2" --exclude 'INSTALL.DAT*' --exclude 'install.dat*'
	elif have 7z || have 7zz; then
		"$(command -v 7z || command -v 7zz)" x -y -bd -o"$2" "$1" '-x!INSTALL.DAT' '-x!install.dat' >/dev/null
	else
		die "need bsdtar or 7-Zip to read the ISO"
	fi
}

# Tar archives, possibly compressed, that may hold the CD image (e.g. emulator bundles).
TAR_RE='.*\.(tar|tgz|tar\.gz|tar\.xz|tar\.bz2|tar\.zst)$'

# Resolves SOURCE into a game directory, extracting into $1 as needed.
locate_game() { # src tmp
	local src=$1 tmp=$2 dir member

	if [ -d "$src" ]; then
		dir=$(find_game_dir "$src") && { echo "$dir"; return; }
		member=$(find "$src" -maxdepth 3 -type f -iname '*.iso' -print -quit)
		[ -n "$member" ] ||
			member=$(find "$src" -maxdepth 3 -type f -regextype posix-extended -iregex "$TAR_RE" -print -quit)
		[ -n "$member" ] || die "no Bermuda Syndrome data, ISO or archive found in $src"
		locate_game "$member" "$tmp"
		return
	fi

	if is_iso "$src"; then
		mkdir -p "$tmp/iso"
		extract_iso "$src" "$tmp/iso"
		dir=$(find_game_dir "$tmp/iso") || die "$(basename "$src") does not look like a Bermuda Syndrome CD"
		echo "$dir"
		return
	fi

	if tar -tf "$src" >/dev/null 2>&1; then
		member=$(tar -tf "$src" | grep -i -m1 -E '\.iso$' || true)
		[ -n "$member" ] || member=$(tar -tf "$src" | grep -i -m1 -E "$TAR_RE" || true)
		[ -n "$member" ] || die "no ISO or nested archive inside $(basename "$src")"
		msg "Unpacking $member from $(basename "$src") (this can take a minute)"
		mkdir -p "$tmp/tar"
		tar -xf "$src" -C "$tmp/tar" "$member"
		locate_game "$tmp/tar/$member" "$tmp"
		return
	fi

	die "unsupported source: $src (expected an ISO, a folder or a .tar/.tar.gz package)"
}

import_data() {
	if [ -z "$SOURCE" ]; then
		data_present && { msg "Game data: present"; return; }
		warn "no game data yet: run ./setup.sh /path/to/bermuda.iso (see --help)"
		return
	fi
	if data_present && [ $FORCE_DATA = 0 ]; then
		msg "Game data: already present (use --force-data to re-import)"
		return
	fi

	local game
	IMPORT_TMP=$(mktemp -d "$ROOT/.import.XXXXXX")
	trap 'rm -rf "$IMPORT_TMP" "$DATA_DIR.new"' EXIT
	game=$(locate_game "$SOURCE" "$IMPORT_TMP")

	msg "Importing game data from $game"
	rm -rf "$DATA_DIR.new"
	cp -R "$game" "$DATA_DIR.new"
	chmod -R u+rwX "$DATA_DIR.new"   # files from CDs are often read-only
	rm -rf "$DATA_DIR"
	mv "$DATA_DIR.new" "$DATA_DIR"
	rm -rf "$IMPORT_TMP"
	trap - EXIT
	msg "Game data: $(du -sh "$DATA_DIR" | cut -f1) imported"
}

# --- desktop entry -----------------------------------------------------------

install_desktop() {
	[ $INSTALL_DESKTOP = 1 ] || return 0
	mkdir -p "$(dirname "$DESKTOP_FILE")"
	cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Bermuda Syndrome
Comment=1995 action-adventure game, running on a native engine rewrite
Exec="$ROOT/play.sh"
Path=$ROOT
Icon=$ENGINE_DIR/icon.bmp
Terminal=false
Categories=Game;AdventureGame;
EOF
	if have update-desktop-database; then
		update-desktop-database -q "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true
	fi
	msg "Menu entry: $DESKTOP_FILE"
}

# --- clean -------------------------------------------------------------------

# Removes what setup created and can recreate. Saves live in $XDG_DATA_HOME and
# installed packages may be used by other programs, so both stay.
clean() {
	local path removed=0
	for path in "$BUILD_DIR" "$DATA_DIR" "$DATA_DIR.new" "$ROOT"/.import.* "$DESKTOP_FILE"; do
		[ -e "$path" ] || continue
		rm -rf -- "$path"
		msg "Removed $path"
		removed=1
	done
	if [ $removed = 1 ] && have update-desktop-database; then
		update-desktop-database -q "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true
	fi
	[ $removed = 1 ] || msg "Nothing to clean"
	msg "Saves kept in ${BERMUDA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/bermuda-syndrome}"
	msg "Reinstall with: ./setup.sh /path/to/bermuda.iso"
}

# -----------------------------------------------------------------------------

if [ $CLEAN = 1 ]; then
	clean
	exit 0
fi

install_deps
build_engine
import_data
install_desktop

find_soundfont >/dev/null || warn "no General MIDI soundfont found: the game will run without music"
if data_present; then
	msg "Done. Start the game with: $ROOT/play.sh"
else
	msg "Engine built. Import the game data next: ./setup.sh /path/to/bermuda.iso"
fi
