# Bermuda Syndrome on Linux

Play **Bermuda Syndrome** (Century Interactive / BMG Interactive, 1995) natively on
Linux, from your own copy of the original Windows CD. One script installs the
dependencies, builds the engine and imports the game data.

There's no Wine, no DOSBox and no Windows 3.1. It uses
[**bermuda**](https://github.com/cyxx/bermuda), Gregory Montoir's open-source rewrite
of the game engine, which reads the original data files directly.

> **This repository contains no game data.** You need your own copy of the game.
> The game is still under copyright, so please don't commit or share its data files.

## Quick start

```sh
git clone --recursive https://github.com/achevalet/bermuda-syndrome-linux.git
cd bermuda-syndrome-linux
./setup.sh /path/to/bermuda.iso
./play.sh
```

`setup.sh` asks for your `sudo` password only if packages are missing. You can
run it again at any time: each step is skipped when it's already done.

After setup, **Bermuda Syndrome** also appears in your desktop's application menu.

## What `setup.sh` accepts

Pass your copy of the original Windows game in any of these forms:

| Source | Example |
|---|---|
| CD image | `./setup.sh bermuda.iso` |
| Mounted CD, or any folder containing the game's `BERMUDA` directory | `./setup.sh /media/cdrom` |
| A `.tar` / `.tar.gz` archive (or its unpacked folder) containing the CD image, such as a DOSBox bundle of the game | `./setup.sh bermuda-dosbox.tar.gz` |

The data is copied into `data/` (about 164 MB). The 170 MB `INSTALL.DAT` installer
archive on the CD isn't needed and is skipped. The engine supports several language
versions of the game. Only the French CD has been tested with these scripts.

Options:

```
--no-deps      do not install packages (just report what is missing)
--no-desktop   do not create the application menu entry
--force-data   re-import the game data from SOURCE even if it is already present
--clean        remove the built engine, the imported game data and the menu
               entry, then exit (saves and this folder are kept)
```

## Playing

```sh
./play.sh                          # windowed
./play.sh --fullscreen
./play.sh --widescreen=16:9        # or 4:3
```

In the game, these keys depend on whether Jack has the rifle in his hands:

| Key | Hands free | Rifle in hand |
|---|---|---|
| Space | Take the rifle out | Fire (5 shots). When it's empty or wet, Jack swings it like a baseball bat |
| Shift | Sprint, jump forward, or grab a ledge | Put the rifle away |
| Up | Jump | Aim up |
| Down | Crouch | Aim down, then crouch; hold to reload (one bullet per cycle, until full) |

These work the same either way:

| Key | Action |
|---|---|
| Left / Right | Move Jack |
| Enter | Action / use the item selected in the bag; also skips dialogue and videos. After Game Over, restarts the game from the very beginning (load a save instead) |
| Tab | Open the bag (inventory) |
| Ctrl | Show or hide the energy bar |
| Esc | Main menu (new game, load, save, quit); Esc again returns to the game. The menu also works with the mouse |

Engine keys:

| Key | Action |
|---|---|
| S / L | Save / load the game in the current slot |
| PgUp / PgDn (or keypad + / −) | Choose the save slot (1–999), shown in the top right corner |
| W | Toggle fullscreen |
| F | Toggle fast mode (runs the game as fast as possible) |
| C | Screenshot (`screenshot-NNN.tga` in `~/.local/share/bermuda-syndrome/`) |

## Saves

Saves and screenshots go to `~/.local/share/bermuda-syndrome/` (or
`$XDG_DATA_HOME/bermuda-syndrome/`), outside the repository, so updating or
`git clean` never touches them. Set `BERMUDA_HOME` to use another folder.

The game starts on your most recently saved slot, so pressing L right after
launching resumes where you left off. A new game is saved to a free slot instead,
until you load a game or choose a slot with PgUp / PgDn, so it never overwrites
that save.

> **Saving overwrites the current slot with no confirmation.** Use several slots
> (PgUp / PgDn) so that one bad save can't cost you your progress. The slot
> number, and whether a save or load worked, show in the top right corner.

**When Jack dies, load a save (L). Don't press S.** In the original engine,
saving on the Game Over screen replaces your slot with a dead game that ends as
soon as it loads, and Enter restarts the game *from the very beginning*. These
scripts protect you in two ways:

1. **S is disabled on the Game Over screen.** A small patch
   ([`patches/`](patches/)) is applied to the engine when `setup.sh` builds it.
2. **Automatic backups.** Each time you save over a slot, the previous version
   is moved to `~/.local/share/bermuda-syndrome/backups/bermuda.NNN/<date>`,
   named after the time it was saved. The last 10 versions of each slot are
   kept; set `BERMUDA_BACKUPS` to change that (`0` disables it). To restore one,
   copy it into a free slot, for example from `~/.local/share/bermuda-syndrome/`:
   `cp backups/bermuda.001/2026-11-04_221428 saves/bermuda.005`.

The game's MIDI music plays through SDL_mixer and FluidSynth. `setup.sh` installs a
General MIDI soundfont if there isn't one already. To use a different one, set
`SDL_SOUNDFONTS=/path/to/soundfont.sf2`.

## Supported systems

`setup.sh` knows how to install dependencies with **apt**, **dnf**, **pacman** and
**zypper**. Tested from clean containers on:

- Debian 13 (trixie)
- Ubuntu 24.04
- Fedora (latest)
- Arch Linux (latest)

The openSUSE (zypper) package names are untested. On other systems, install a C++
compiler, `make`, `pkg-config`, the SDL2, SDL2_mixer, libvorbis and zlib development
files, `bsdtar` or 7-Zip, and a GM soundfont, then run `./setup.sh --no-deps`.

Because the engine is built from source, it should also work on non-x86 machines such as ARM boards (untested).

## Updating

```sh
git pull
git submodule update --init
./setup.sh
```

## Uninstalling

`./setup.sh --clean` removes the built engine, the imported game data (about
164 MB) and the menu entry, but keeps the repository and your saves. Run
`./setup.sh /path/to/bermuda.iso` to reinstall. To remove everything:

```sh
rm -rf bermuda-syndrome-linux
rm ~/.local/share/applications/bermuda-syndrome.desktop
rm -rf ~/.local/share/bermuda-syndrome    # saves, if you don't want to keep them
```

## Troubleshooting

- **No music.** Check that a soundfont exists (for example
  `/usr/share/sounds/sf2/default-GM.sf2`) or set `SDL_SOUNDFONTS`.
- **"Unable to find startup scene file!"** The game data is missing or incomplete.
  Re-import it with `./setup.sh --force-data <source>`.
- **"engine source missing".** The repository was cloned without `--recursive`. Run
  `git submodule update --init`.

## Engine fixes

The upstream engine repository, [cyxx/bermuda](https://github.com/cyxx/bermuda), is
archived (read-only), so bugs can't be reported or fixed there anymore. Fixes are
kept in [`patches/`](patches/) instead. `setup.sh` applies them to a copy of the
engine source at build time, and the submodule itself stays untouched. Because the
upstream code will never change, the patches will keep applying cleanly.

| Patch | Fixes |
|---|---|
| [`0001-no-save-after-game-over`](patches/0001-no-save-after-game-over.patch) | Pressing S on the Game Over screen overwrote the slot with a dead game |
| [`0002-keep-save-history`](patches/0002-keep-save-history.patch) | Saving overwrote the slot, losing the previous save; it now keeps the last versions of each slot (see Saves) |
| [`0003-show-save-slot-messages`](patches/0003-show-save-slot-messages.patch) | Changing slot, saving and loading gave no feedback on screen, so it was easy to save over the wrong slot |
| [`0004-start-on-latest-save-slot`](patches/0004-start-on-latest-save-slot.patch) | The game always started on slot 1, so L after launching didn't load the game you were playing |
| [`0005-stop-music-with-sdl-mixer`](patches/0005-stop-music-with-sdl-mixer.patch) | The previous music (e.g. the Game Over tune) kept playing after loading a save |
| [`0006-loop-music-with-sdl-mixer`](patches/0006-loop-music-with-sdl-mixer.patch) | Music played only once, so the game went silent after each track (1 to 5 minutes) |

## Credits and licenses

- **Engine:** [bermuda](https://github.com/cyxx/bermuda) © 2007–2011 Gregory Montoir.
  It's included as a git submodule pointing to the author's repository and isn't
  redistributed here. It doesn't declare a license, so see the upstream project.
  The small fixes in [`patches/`](patches/) are applied to a copy at build time.
- **Game:** Bermuda Syndrome © 1995 Century Interactive / BMG Interactive. No game
  files are included.
- **These scripts and patches:** MIT License, see [LICENSE](LICENSE).
