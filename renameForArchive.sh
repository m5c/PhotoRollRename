## M.Schiedermeier, 2025

#! /bin/bash


## Helper function to verify if all runtime requirements are satisfied.
function verifyDependency {

  ## Verify jq (json parsing) command is installed
  if ! command -v $1 >/dev/null 2>&1; then
    echo "Error: $1 is not installed." >&2
    echo "Install with (something like):" >&2
    echo "  brew install $1" >&2
    exit 1
  fi
}


# Removes all files containing " [0-9]." String, which is iPhone way to deal with duplicates
# Must exclude screenshots though, because screenshots contain timestamp e.g. "...at 3.13.02 PM.png"
function removePhantoms {
      ls -l1 *\ [1-9]\.* 2>/dev/null | grep -v Screenshot | tr \\n \\0 | xargs -0 rm
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
}

function renameToTimeStamp {

  # Figure out file ending
  EXTENSION=$(echo "$1" | rev | cut -d '.' -f1 | rev)
  extractTimeStamp "$1"
  if [ -z $TIMESTAMP ]; then
    echo "No timestamp, skipping renaming of $1"
     STAMPED_FILE="$1"
    return
  fi

  STAMPED_FILE=$TIMESTAMP.$EXTENSION
  mv "$1" "$STAMPED_FILE"
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
    # Only delete original file if an actual file rename took place (i.e. extension changed)
    if [ ! "$UNCONVERTED_FILE" = "$CONVERTED_FILE" ]; then
      rm "$UNCONVERTED_FILE"
    fi
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
          HEIC_AMOUNT=$(find ./*[hH][eE][iI][cC] | wc -l)
          echo "Renaming $HEIC_AMOUNT HEICs:"
          for FILE in ./*[hH][eE][iI][cC]; do
            renameToTimeStamp "$FILE"
		        convertToJpg "$STAMPED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
          done | pv -l -s $HEIC_AMOUNT >> renamed.txt
        else
	   echo "No HEIC files found. Skipping."
        fi
}

# This one is only for files that already have "JPG" suffix. No additional compression, but renaming.
function processJPGs {
        # Check if there's at least one JPG
        JPGS_PRESENT=$(ls ./*JPG 2>&1 | grep "No")
        if [ -z "$JPGS_PRESENT" ]; then
          JPG_AMOUNT=$(find ./*JPG | wc -l)
          echo "Renaming $JPG_AMOUNT JPGs:"
          for FILE in *JPG; do
            renameToTimeStamp "$FILE"
            CONVERTED_FILE=$(basename $STAMPED_FILE JPG)jpg
            mv $STAMPED_FILE $CONVERTED_FILE
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
          done | pv -l -s $JPG_AMOUNT >> renamed.txt
        else
	   echo "No JPG files found. Skipping."
        fi
}

# This one is only for files that already have "jgp" suffix. No additional compression.
function processSmallJPGs {
        # Check if there's at least one jpg
#        jpgs_PRESENT=$(ls -l1 ./*jp[e?]g | grep "No")
        AMOUNT_SMALL_JPGs=$(find . -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) ! -iname "[0-9][0-9][0-9][0-9]-*" | wc -l)
        if [[ ! $AMOUNT_SMALL_JPGs -eq 0 ]]; then
          echo "Renaming $AMOUNT_SMALL_JPGs jp(e)gs:"
          ## This loop handles spaces in file names correctly...
          find . -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) ! -iname "[0-9][0-9][0-9][0-9]-*" -print0 | while IFS= read -r -d '' FILE; do
            renameToTimeStamp "$FILE"
            ## Already a conversion, no re-compression needed, but "jpeg needs to be renamed into jpg"
            ## THERE SEEMS TO BE AN ISSUE WITH THIS LINE...
            CONVERTED_FILE="${STAMPED_FILE/jpeg/jpg}"
            # If already jpg extension (not jpeg) this line does nothing.
            mv "$STAMPED_FILE" "$CONVERTED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
          done | pv -l -s $AMOUNT_SMALL_JPGs >> renamed.txt
        else
	        echo "No small jp(e)g files found. Skipping."
        fi
}

function processPngs {
    # Check if there's at least one PNG
    PNGS_PRESENT=$(ls ./*[pP][nN][gG] 2>&1 | grep "No")
    if [ -z "$PNGS_PRESENT" ]; then
      PNG_AMOUNT=$(find ./*[pP][nN][gG] | wc -l)
      echo "Renaming $PNG_AMOUNT PNGs:"
      for FILE in ./*[pP][nN][gG]; do
              renameToTimeStamp "$FILE"
              convertToJpg "$STAMPED_FILE"
              appendHash "$CONVERTED_FILE"
              echo "$FILE => $FINAL_NAME"
      done | pv -l -s $PNG_AMOUNT >> renamed.txt
     else
	   echo "No PNG files found. Skipping."
        fi
}

function processMovs {
        # Check if there's at least one MOV
        MOVS_PRESENT=$(ls ./*[mM][oO][vV] 2>&1 | grep "No")
        if [ -z "$MOVS_PRESENT" ]; then
          MOV_AMOUNT=$(find ./*[mM][oO][vV] | wc -l)
          echo "Renaming $MOV_AMOUNT MOVs:"
		      for FILE in ./*[mM][oO][vV]; do
            renameToTimeStamp "$FILE"
            compressToMp4 "$STAMPED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
		      done | pv -l -s $MOV_AMOUNT >> renamed.txt
        else
	        echo "No MOV files found. Skipping."
        fi
}

function processMp4s {
        # Look up how many _unrenamed_ mp4 files still linger
        MP4_AMOUNT=$(find . ! -name "[0-9][0-9][0-9][0-9]-*" | grep -e mp4 -e MP4 | wc -l)
        if [ $MP4_AMOUNT -ne 0 ]; then
          echo "Renaming $MP4_AMOUNT MP4s:"
	  for FILE in $(find . ! -name "[0-9][0-9][0-9][0-9]-*" | grep -e mp4 -e MP4); do
            renameToTimeStamp "$FILE"
            compressToMp4 "$STAMPED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
		      done | pv -l -s $MP4_AMOUNT >> renamed.txt
        else
	        echo "No (previously unprocessed) mp4/MP4 files found. Skipping."
        fi
}

function processRaws {
        # Check if there's at least one MOV
        RAWS_PRESENT=$(ls ./*CR2 2>&1 | grep "No")
        if [ -z "$RAWS_PRESENT" ]; then
          RAW_AMOUNT=$(find ./*CR2 | wc -l)
          echo "Renaming $RAW_AMOUNTT CR2s:"
		      for FILE in ./*CR2; do
            renameToTimeStamp "$FILE"
            # No compression needed for raws
            CONVERTED_FILE="${STAMPED_FILE/CR2/cr2}"
            mv "$STAMPED_FILE" "$CONVERTED_FILE"
            appendHash "$CONVERTED_FILE"
            echo "$FILE => $FINAL_NAME"
		      done | pv -l -s $RAW_AMOUNT >> renamed.txt
        else
	        echo "No CR2 files found. Skipping."
        fi
}

function printStats {

  if [ -f renamed.txt ]; then
    echo "Files renamed:"
    cat renamed.txt
    echo "----------"
    echo "Total: $(cat renamed.txt | wc -l)"
    rm renamed.txt
  else
    echo "0 files renamed"
  fi
}


# PRELIMINARY CHECKS (ALL DEPENDENCIES INSTALLED)
## Verify all software dependencies
DEPENDENCIES=(exiftool md5sum ffmpeg magick)
for DEP in "${DEPENDENCIES[@]}"; do
  verifyDependency "$DEP"
done


# ACTUAL LOGIC
removePhantoms
processHeics
processJPGs # ONLY upper case jpgs, to avoid doing the same files twice
processSmallJPGs
processRaws
processMovs
processMp4s
processPngs
printStats



