#!/bin/bash

 OUTPUTDIR=FREEZE
 SVGFOLDERS=tmp

# =========================================================================== #
  for SVG in `find $SVGFOLDERS -name "*.svg"`
   do
# =========================================================================== #

   OUTPUTBASE=`basename $SVG   | \
               cut -d "_" -f 2 | \
               sed 's/-R+//g'  | \
               tr -t [:lower:] [:upper:]`

# --------------------------------------------------------------------------- #
# MOVE ALL LAYERS ON SEPARATE LINES IN A TMP FILE
# --------------------------------------------------------------------------- #
  sed ':a;N;$!ba;s/\n//g' $SVG           | # REMOVE ALL LINEBREAKS
  sed 's/<g/\n&/g'                       | # MOVE GROUP TO NEW LINES
  sed '/groupmode="layer"/s/<g/4Fgt7R/g' | # PLACEHOLDER FOR LAYERGROUP OPEN
  sed ':a;N;$!ba;s/\n/ /g'               | # REMOVE ALL LINEBREAKS
  sed 's/4Fgt7R/\n<g/g'                  | # RESTORE LAYERGROUP OPEN + NEWLINE
  sed 's/display:none/display:inline/g'  | # MAKE VISIBLE EVEN WHEN HIDDEN
  grep -v 'label="XX_'                   | # REMOVE EXCLUDED LAYERS
  sed 's/<\/svg>/\n&/g'                  | # CLOSE TAG ON SEPARATE LINE
# tr -s ' '                              | # CLEAN CONSECUTIVE SPACES
  sed "s/^[ \t]*//"                      | # REMOVE LEADING BLANKS
  tr -s ' '                              | # REMOVE CONSECUTIVE BLANKS
  tee > ${SVG%%.*}.tmp                     # WRITE TO TEMPORARY FILE

# --------------------------------------------------------------------------- #
# GENERATE CODE FOR FOR-LOOP TO EVALUATE COMBINATIONS
# --------------------------------------------------------------------------- #

  # RESET (IMPORTANT FOR 'FOR'-LOOP)
  LOOPSTART=""
  VARIABLES=""
  LOOPCLOSE=""  

  CNT=0  
  for BASETYPE in `sed ':a;N;$!ba;s/\n/ /g' ${SVG%%.*}.tmp | \
                   sed 's/scape:label/\nlabel/g'           | \
                   grep ^label                             | \
                   cut -d "\"" -f 2                        | \
                   cut -d "-" -f 1                         | \
                   sort -u`
   do
      ALLOFTYPE=`sed ':a;N;$!ba;s/\n/ /g' ${SVG%%.*}.tmp   | \
                 sed 's/scape:label/\nlabel/g'             | \
                 grep ^label                               | \
                 cut -d "\"" -f 2                          | \
                 grep $BASETYPE`

      LOOPSTART=${LOOPSTART}"for V$CNT in $ALLOFTYPE; do "
      VARIABLES=${VARIABLES}'$'V${CNT}" "
      LOOPCLOSE=${LOOPCLOSE}"done; "

      CNT=`expr $CNT + 1`

  done

# --------------------------------------------------------------------------- #
# EXECUTE CODE FOR FOR-LOOP TO EVALUATE COMBINATIONS
# --------------------------------------------------------------------------- #

  KOMBILIST=kombinationen.list ; if [ -f $KOMBILIST ]; then rm $KOMBILIST ; fi

# echo ${LOOPSTART}" echo $VARIABLES >> $KOMBILIST ;"${LOOPCLOSE}
  eval ${LOOPSTART}" echo $VARIABLES >> $KOMBILIST ;"${LOOPCLOSE}

# --------------------------------------------------------------------------- #
# WRITE SVG FILES ACCORDING TO POSSIBLE COMBINATIONS
# --------------------------------------------------------------------------- #

  SVGHEADER=`head -n 1 ${SVG%%.*}.tmp`

  for KOMBI in `cat $KOMBILIST | sed 's/ /DHSZEJDS/g'`
   do
      KOMBI=`echo $KOMBI | sed 's/DHSZEJDS/ /g'`

#     R=`basename $SVG | cut -d "_" -f 2 | grep "R+" |  cut -d "-" -f 2`
#     if [ A$R = "AR+" ]; then R="-R+"; else R= ; fi
#     IOS=`basename $SVG | cut -d "_" -f 3-`
#   # OSVG=$OUTPUTDIR/${OUTPUTBASE}`echo ${KOMBI}${IOS} | \
#   #                               md5sum | cut -c 1-6 | \
#   #                               tr -t [:lower:] [:upper:]`${R}_${IOS}

#     BASEID=`echo ${OUTPUTBASE} | md5sum | cut -c 1-8 | tr -t [:lower:] [:upper:]`
#     OSVG=${BASEID}`echo ${KOMBI}${IOS} | \
#                    md5sum | cut -c 1-6 | \
#                    tr -t [:lower:] [:upper:]`
#     OSVG=$OUTPUTDIR/`echo $OSVG${R} | rev | cut -c 1-14 | rev`_${IOS}
#     echo $OSVG

        R=`basename $SVG | cut -d "_" -f 2 | #
           grep "R+" | cut -d "-" -f 2`
      IOS=`basename $SVG | cut -d "_" -f 3-`
      if [ A$R = "AR+" ]; then R="+R-"; else R= ; fi
      NID=`echo ${OUTPUTBASE} | #
           cut -d "-" -f 1 | #
           tr -t [:lower:] [:upper:] | #
           md5sum | cut -c 1-4 | #
           tr -t [:lower:] [:upper:]`
      FID=`basename $SVG | #
           tr -t [:lower:] [:upper:] | #
           md5sum | cut -c 1-4 | #
           tr -t [:lower:] [:upper:]`
      DIF=`echo ${KOMBI}${IOS} | #
           md5sum | cut -c 1-9 | #
           tr -t [:lower:] [:upper:] | rev`

     OSVG=$OUTPUTDIR/$NID$FID`echo $R$DIF | cut -c 1-9 | rev`_${IOS}
     echo $OSVG


     if [ ! -f $OSVG ]; then

      echo "$SVGHEADER"                                   >  $OSVG

      for LAYERNAME in `echo $KOMBI`
        do
          grep -n "label=\"$LAYERNAME\"" ${SVG%%.*}.tmp   >> ${OSVG%%.*}.tmp
      done

      cat ${OSVG%%.*}.tmp | sort -n | cut -d ":" -f 2-    >> $OSVG
      echo "</svg>"                                       >> $OSVG
      rm ${OSVG%%.*}.tmp

    # DO SOME CLEAN UP
    # -----------------------------------------  #
      inkscape --vacuum-defs              $OSVG  # INKSCAPES VACUUM CLEANER
      NLFOO=Nn${RANDOM}lL                        # SET RANDOM PLACEHOLDER
      sed -i ":a;N;\$!ba;s/\n/$NLFOO/g"   $OSVG  # PLACEHOLDER FOR LINEBREAKS
      sed -i -e "s,<defs,\nXXX<defs,g"    \
             -e "s,</defs>,</defs>\n,g"   \
             -e "/^<defs/s/\/>/&\n/g"     $OSVG  # FORMAT DEFS AND MARK
      sed -i -e "s,<sodipodi,\nXXX&,g"    \
             -e "s,</sodipodi>,&\n,g"     \
             -e "/^<sodipodi/s/\/>/&\n/g" $OSVG  # FORMAT SODIPODI STUFF AND MARK
      sed -i -e "s,<metadata,\nXXX&,g"    \
             -e "s,</metadata>,&\n,g"     $OSVG  # FORMAT METADATA AND MARK
      sed -i "/^XXX/s/^.*$//g"            $OSVG  # DELETE MARKED LINES
      sed -i "s/$NLFOO/\n/g"              $OSVG  # RESTORE LINEBREAKS
      sed -i '/^$/d'                      $OSVG  # DELETE EMPTY LINES

     fi

  done

# --------------------------------------------------------------------------- #
# REMOVE TEMP FILES
# --------------------------------------------------------------------------- #
  rm ${SVG%%.*}.tmp $KOMBILIST

# =========================================================================== #
  done
# =========================================================================== #


exit 0;


