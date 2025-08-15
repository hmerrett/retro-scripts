# Silly scripts

## Useful scripts for retro computing.

### floppy-image-archive.sh 

#### a quick and easy way to archive a local folder to floppy images readable by a DOS pc and arj

Usage: `./floppy-image-archive.sh <source directory> <destination directory>`

`<source directory>` the location of your directory containing files for archive

`<destination directory>` the loation of your set of floppy images to be created

Dependencies (assuming Ubuntu): `sudo apt install arj mtools dosfstools`

### make-floppy.sh

#### put all the files in the current directory into a fat 12 floppy image

Usage: `./make-floppy.sh [--size=1.44|--size=720k]`

Dependencies (assuming Ubuntu): `sudo apt install mtools dosfstools`
