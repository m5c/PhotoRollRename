## M.Schiedermeier, 2025

#! /bin/bash

# Removes all files containing " 1" String, which is iPhone way to deal with duplicates
function removePhantoms {
      ls -l1 *\ [1-9]\.* -R 2>/dev/null | tr \\n \\0 | xargs -0 rm
      rm *AAE 2>/dev/null
}

# REQUIRES 1 ARGUMENT
# MUST BE CALLED ON ORIGINAL FILE (OTHERWISE CREATION TIMESTAMP FLAWED)
function extractTimeStamp {
   # For most cases, use "DateTimeOriginal"
   RAW_TIMESTAMP=$(exiftool -DateTimeOriginal "$1" 2>/dev/null)

   # As second fallback, use "-FileModifyDate" (PNG files / screenshots)
   if [ -z "$RAW_TIMESTAMP" ]; then
	  RAW_TIMESTAMP=$(exiftool -ModifyDate "$1" 2>/dev/null)
   fi

   # As last fallback (avis / movs) use "-MediaCreateDate"
   if [ -z "$RAW_TIMESTAMP" ]; then
	  RAW_TIMESTAMP=$(exiftool -MediaCreateDate "$1" 2>/dev/null)
   fi

   # As last fallback (avis / movs) use "-MediaCreateDate"
   if [ -z "$RAW_TIMESTAMP" ]; then
	  RAW_TIMESTAMP=$(exiftool -FileModifyDate "$1" 2>/dev/null)
   fi

  if [ -z "$RAW_TIMESTAMP" ]; then
      RAW_TIMESTAMP=$(exiftool -DateCreated "$1" 2>/dev/null)
  fi

  TIMESTAMP=$(echo "$RAW_TIMESTAMP" | cut -d ':' -f2- | cut -c 2-20 | sed 's/[: ]/-/g')
  echo "Timestamp: $TIMESTAMP"
}

 function renameToTimeStamp {

  # Figure out file ending
  set -x
  EXTENSION=$(echo "$1" | rev | cut -d '.' -f1 | rev)
  extractTimeStamp "$1"
  #     extractHash $1
  if [ -z $TIMESTAMP ]; then
    echo "No timestamp, skipping renaming of $1"
     STAMPED_FILE="$1"
    return
  fi

  STAMPED_FILE=$TIMESTAMP.$EXTENSION
  mv "$1" $STAMPED_FILE
}

function convertToJpg {
    UNCONVERTED_FILE=$1
    EXTENSION=$(echo "$UNCONVERTED_FILE" | rev | cut -d '.' -f1 | rev)
    # Dont add globbing protection here, basename command cannot handle it.
    CONVERTED_FILE=$(basename $UNCONVERTED_FILE $EXTENSION)jpg
    magick "$UNCONVERTED_FILE" -quality 80 "$CONVERTED_FILE"
    rm "$UNCONVERTED_FILE"
}

function compressToMp4 {
    UNCONVERTED_FILE=$1
    EXTENSION=$(echo "$UNCONVERTED_FILE" | rev | cut -d '.' -f1 | rev)
    # Dont add globbing protection here, basename command cannot handle it.
    CONVERTED_FILE=$(basename $UNCONVERTED_FILE $EXTENSION)mp4
    ffmpeg -loglevel quiet -y -i "$UNCONVERTED_FILE" -map_metadata 0 -c copy "$CONVERTED_FILE"
    rm "$UNCONVERTED_FILE"
}

function appendHash {
    EXTENSION="."$(echo "$1" | rev | cut -d '.' -f1 | rev)
    BASENAME=$(basename "$1" "$EXTENSION")
    HASH=$(md5sum "$1" | cut -c 1-8)
    FINAL_NAME=$BASENAME-$HASH$EXTENSION
    mv "$1" "$FINAL_NAME"
}

## Conversion procedures for various file types...

function processHeics {
        # Check if there's at least one HEIC
        HEICS_PRESENT=$(ls ./*[hH][eE][iI][cC] 2>&1 | grep "No")
        if [ -z "$HEICS_PRESENT" ]; then
          for FILE in ./*[hH][eE][iI][cC]; do
            renameToTimeStamp "$FILE"
		        convertToJpg "$STAMPED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
          done
        else
	   echo "No HEIC files found. Skipping."
        fi
}

# This one is only for files that already have "JPG" suffix. No additional compression, but renaming.
function processJPGs {
        # Check if there's at least one JPG
        JPGS_PRESENT=$(ls ./*JPG 2>&1 | grep "No")
        if [ -z "$JPGS_PRESENT" ]; then
          for FILE in *JPG; do
            renameToTimeStamp "$FILE"
            CONVERTED_FILE=$(basename $STAMPED_FILE JPG)jpg
            mv $STAMPED_FILE $CONVERTED_FILE
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
          done
        else
	   echo "No JPG files found. Skipping."
        fi
}

# This one is only for files that already have "jgp" suffix. No additional compression.
function processSmallJPGs {
        # Check if there's at least one jpg
        jpgs_PRESENT=$(ls -l1 ./*jp[e?]g | grep "No")
        if [ -z "$jpgs_PRESENT" ]; then
          ## This loop handles spaces in file names correctly...
          find . -type f -name "[!0-9][!0-9][!0-9][!0-9][!-]*jp[e?]g" -print0 | while IFS= read -r -d '' FILE; do
            renameToTimeStamp "$FILE"
            ## Already a conversion, no re-compression needed, but "jpeg needs to be renamed into jpg"
            ## THERE SEEMS TO BE AN ISSUE WITH THIS LINE...
            CONVERTED_FILE="${STAMPED_FILE/jpeg/jpg}"
            # If already jpg extension (not jpeg) this line does nothing.
            mv "$STAMPED_FILE" "$CONVERTED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
          done
        else
	        echo "No small jpg files found. Skipping."
        fi
}

function processPngs {
        # Check if there's at least one PNG
        PNGS_PRESENT=$(ls ./*[pP][nN][gG] 2>&1 | grep "No")
        if [ -z "$PNGS_PRESENT" ]; then
	  for FILE in ./*[pP][nN][gG]; do
            renameToTimeStamp "$FILE"
		        convertToJpg "$STAMPED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
		done
        else
	   echo "No PNG files found. Skipping."
        fi
}

function processMovs {
        # Check if there's at least one MOV
        MOVS_PRESENT=$(ls ./*[mM][oO][vV] 2>&1 | grep "No")
        if [ -z "$MOVS_PRESENT" ]; then
		      for FILE in ./*[mM][oO][vV]; do
            renameToTimeStamp "$FILE"
            compressToMp4 "$STAMPED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
		      done
        else
	        echo "No MOV files found. Skipping."
        fi
}


# ACTUAL LOGIC
removePhantoms
processHeics
processPngs
processMovs
processJPGs # ONLY upper case jpgs, to avoid doing the same files twice
processSmallJPGs
 # ONLY lower case jpgs starting with IMG, to avoid doing the same files twice
#processJpegs


