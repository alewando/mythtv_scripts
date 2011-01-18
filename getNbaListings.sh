#!/bin/sh

#
# Retrieves NBA League Pass listings from DIRECTV and loads them into
# MythTV database.
#
# Uses XMLTV grabber tv_grab_na_dtv. The grabber was modified to add
# a new request parameter of 'sm=1' to the listings URL. This was 
# necessary to retrieve the extra channels (including the NBA channels).
# A patch has been submitted to XMLTV for inclusion in future releases.


MYTHTV_DIR=/home/mythtv/.mythtv
LISTINGS_FILE=${MYTHTV_DIR}/nba_listings.xml
PATH=$PATH:/usr/local/bin:/usr/bin:$MYTHTV_DIR

# Remove existing listings file
if [ -e $LISTINGS_FILE ]
then
 rm $LISTINGS_FILE
fi

# Get the listings in xmltv format
tv_grab_na_dtv --days 2 --quiet --config-file ${MYTHTV_DIR}/directv_nba_league_pass.xmltv --output ${LISTINGS_FILE}.orig

# Change title from "Suns @ Knicks" to "NBA Basketball" (for browsing consistency)
sed -i 's/<title lang="en">.* @ .*<\/title>/<title lang="en">NBA Basketball<\/title>/' ${LISTINGS_FILE}.orig

# 'Fix up' listings. Includes adjusting stop times and marking home vs visting team's coverage
adjustNbaListings.pl ${LISTINGS_FILE}.orig > ${LISTINGS_FILE}

# Import listings file into mythtv database
if [ -e $LISTINGS_FILE ]
then
 mythfilldatabase --update --file 1 $LISTINGS_FILE > /dev/null
else
 echo No listings file present. Did the XMLTV grabber fail?
fi

