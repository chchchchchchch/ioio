#!/bin/bash

 SVGDIR="_"
 TMP=XX


# =========================================================================== #
# CHECK EXIFTOOL
# --------------------------------------------------------------------------- #
  if [ `hash exiftool 2>&1 | wc -l` -gt 0 ]
  then EXIF="OFF";echo "PLEASE INSTALL exiftool";exit 0;else EXIF="ON"; fi


# --------------------------------------------------------------------------- #
# VALIDATE (PROVIDED) INPUT 
# --------------------------------------------------------------------------- #
  if [ `echo $* | wc -c` -lt 2 ]; then echo "No arguments provided"; exit 0;
  else if [ `ls \`ls ${1}* 2> /dev/null\` 2> /dev/null  | #
             grep "\.svg$" | wc -l` -lt 1 ];              #
        then echo 'No valid svg!'; exit 0;                #    
      # else echo -e "PROCESSING NOW:\n${1}* \n--------------------";
    fi
  fi

# =========================================================================== #
# DO IT NOW!
# =========================================================================== #
  for SVG in `ls \`ls ${1}*\` | grep "\.svg$"`
   do
     OUT=$SVGDIR/`basename $SVG | sed 's/\.svg$//'`.gif
     echo "WRITING: $OUT"

     cp $SVG ${TMP}.svg    
     inkscape --vacuum-defs ${TMP}.svg

     BG='<path style="fill:#ccffaa;" \
          d="m 0\,0 800\,0 0\,800 -800\,0 z" id="c" />'
   # CANVAS='<path style="fill:#ffffff;" \
   #          d="m 0\,0 400\,0 0\,400 -400\,0 z" id="c" />'
   # TRANSFORM='transform="translate(300\,300) scale(0.5\,0.5)"'        
     TRANSFORM='transform="scale(0.5\,0.5) translate(600\,600)"'        

     sed -i "s,</metadata>,&$BG<g $TRANSFORM>$CANVAS,g" ${TMP}.svg
     sed -i 's,</svg>,</g>&,g'                          ${TMP}.svg
     sed -i 's/stroke-width:1/stroke-width:2/g'         ${TMP}.svg
     sed -i 's/height="400"/height="800"/g'             ${TMP}.svg
     sed -i 's/width="400"/width="800"/g'               ${TMP}.svg

     COUNT=0
     for COLOR in `cat ${TMP}.svg | sed 's/style="/\n&/g' | #
                   grep "^style" | sed 's/#/\n#/g' | #
                   grep '^#' | cut -c 1-7 | #
                   sed -re '/#[0-9A-Fa-f]{6}/!d' | #
                   sort -u | grep -v "#ffffff"`
      do
         cp ${TMP}.svg ${TMP}2.svg
         sed -i -re "s/$COLOR/XxXxXx/g"           ${TMP}2.svg  # PROTECT COLOR
         sed -i -re 's/#[0-9A-Fa-f]{6}/#ffffff/g' ${TMP}2.svg  # ALL HEX TO BLACK
         sed -i -re "s/XxXxXx/#000000/g"          ${TMP}2.svg  # PROTECT COLOR

         inkscape --export-pdf=${TMP}.pdf ${TMP}2.svg
         convert -monochrome ${TMP}.pdf ${TMP}.gif

         convert ${TMP}.gif -fill $COLOR -opaque black ${COUNT}.gif
         if [ $COUNT -gt 0 ]; then
         composite -compose Multiply -gravity center \
                    collect.gif ${COUNT}.gif ${TMP}.gif
              mv ${TMP}.gif collect.gif
              rm ${COUNT}.gif
         else
              mv ${COUNT}.gif collect.gif
              rm ${TMP}.gif
         fi
         COUNT=`expr $COUNT + 1`
     done

     convert collect.gif -transparent "#ccffaa" $OUT

     SRCSTAMP=`grep '^<!-- .*\.svg ([0-9a-f]*) -->$' $SVG | #
               sed 's/^<!--[ ]*//' | sed 's/[ ]*-->$//'`
     if [ "$EXIF" == ON ]; then
           exiftool -Source="$SRCSTAMP" $OUT > /dev/null 2>&1
           rm ${OUT}_original
     fi

     rm ${TMP}.svg ${TMP}2.svg ${TMP}.pdf collect.gif 
 done


exit 0;

