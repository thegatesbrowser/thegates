# Kinda-Safe-Godot

## Sandbox and File Isolation for Godot

Kinda-Safe-Godot provides a sandboxed environment with file isolation for running Godot games. Although extensive efforts have been made to prevent sandbox escapes, it is essential to acknowledge that no system can guarantee absolute security.

The sandboxed environment utilizes symbolic links to expose specific directories on your computer. This method may inadvertently leak some information, such as installed programs and resource usage.

Running a bash environment inside the sandbox is not possible due to restricted syscalls.

## Purpose

The development of Kinda-Safe-Godot was primarily motivated by the [gates](https://flathub.org/apps/io.itch.nordup.TheGates) project. While a typical approach would involve creating a container image or using Flatpak, these solutions introduce significant dependencies, potentially hindering casual users from accessing the game.

Instead of using this project, I recommend building a Flatpak, which provides finer controls and ensures compatibility across various systems.

## Usage

1. Execute the "runner/build.sh" script.
2. Export your game as a single file bundle and rename its executable file to "game".
3. Move the game executable to the main directory.
4. Run the "run_game.sh" script.

## Generating the List of Syscalls

To generate the list of syscalls, we suggest using the "strace" tool:

```
strace ./{game} 2> /dev/stdout | sed 's/\([^()]*\).*/\1/' > syscalls.txt
```

Once you have the "syscalls.txt" file, you can sort and deduplicate the entries:

```
cat syscalls.txt | sort | uniq
```

You may need to remove any garbage data.
