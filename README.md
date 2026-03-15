# Photo Roll Rename

Renaming script for media from iOS/Samsung devices.

## Purpose

* Convert everything to standard file formats:
  * HEIC/heic/JPG/JPEG/JPEG/PNG/png/CR2 -> jpg
  * MOV/MP4 -> mp4
* Applies same compression
  * jpg: uses [magick](https://github.com/ImageMagick/ImageMagick) to optimize jpg compression.
  * mp4: uses [ffmpeg](https://github.com/FFmpeg/FFmpeg) to boil movies down to a third.
* Use unique chronological naming
  * Pre: image creation time (year down to second): YYYY-MM-DD-HH-MM-SS
  * Post: dash, then first 8 characters of file MD5 hash: XXXXXXXX
  * Suffix: filename in lowercase: mp4, jpg, etc.

## Usage

* Add this script to your PATH:  
`export PATH=/wherever/you/cloned/renameForArchive:$PATH`
* Use Image Capture to load all photos from your iOS photo-roll to your Mac.
* `cd` into directory with photoroll media
* Call `./renameForArchive.sh`

### MISC

It is safe to stall and relaunch the script at any time.

## Supported files

* HEIC/heic
* JPG/JPEG/jpg/jpeg
* PNG/png
* CR2
* MOV
* MP4/mp4

## MISC

### License

[GNU GENERAL PUBLIC LICENSE](LICENSE)

### Author / Pull-Requests

[Maximilian Schiedermeier](mailto:schiedermeier.maximilian@uqam.ca)
