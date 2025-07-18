# Photo Roll Rename

Renaming script for media from iOS devices.

## Purpose

* Convert everything to standard file formats:
  * jpg
  * mp4
* Use unique chronological naming
  * Pre: image creation time (year down to second)
  * Post: first 8 characters of file MD5 hash

## Usage

* Add this script to your PATH:  
`export PATH=/wherever/you/cloned/renameForArchive:$PATH`
* Use Image Capture to load all photos from your iOS photo-roll to your Mac.
* `cd` into directory with photoroll media
* Call `renameForArchive`

### MISC

It is safe to stall and relaunch the script at any time.

## Supported files

* HEIC/heic
* JPG
* jp(e)g
* CR2
* MOV
* PNG/png


## Known bugs

In some cases PNG screenshots loose their EXIF information, i.e. the information of when the image actually was created is irreversibly lost. In this case the current date is used for naming.
