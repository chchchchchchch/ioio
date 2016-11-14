#!/bin/bash

# TODO: SVGHEADER not as variable

  OUTDIR=_


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
   do OUTPUTBASE=`basename $SVG            | #
                  cut -d "_" -f 2          | #
                  sed 's/-R+//g'           | #
                  tr -t [:lower:] [:upper:]` #
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
  sed "s/^[ \t]*//"                      | # REMOVE LEADING BLANKS
  tr -s ' '                              | # REMOVE CONSECUTIVE BLANKS
  tee > ${SVG%%.*}.tmp                     # WRITE TO TEMPORARY FILE

# --------------------------------------------------------------------------- #
# GENERATE CODE FOR FOR-LOOP TO EVALUATE COMBINATIONS
# --------------------------------------------------------------------------- #
  # RESET (IMPORTANT FOR 'FOR'-LOOP)
  LOOPSTART="";VARIABLES="";LOOPCLOSE="";CNT=0

  for BASETYPE in `sed ':a;N;$!ba;s/\n/ /g' ${SVG%%.*}.tmp | #
                   sed 's/<g/\n&/g'                  | # GROUPS ON NEWLINE
                   sed '/^<g/s/>/&\n/g'              | # FIRST ON '>' ON NEWLINE
                   grep ':groupmode="layer"'         | #
                   sed '/^<g/s/scape:label/\nlabel/' | #
                   grep ^label                       | #
                   cut -d "\"" -f 2                  | #
                   cut -d "-" -f 1                   | #
                   sort -u`
   do
       ALLOFTYPE=`sed ':a;N;$!ba;s/\n/ /g' ${SVG%%.*}.tmp  | #
                  sed 's/scape:label/\nlabel/g'            | #
                  grep ^label                              | #
                  cut -d "\"" -f 2                         | #
                  grep $BASETYPE`                            #
       LOOPSTART=${LOOPSTART}"for V$CNT in $ALLOFTYPE; do "
       VARIABLES=${VARIABLES}'$'V${CNT}" "
       LOOPCLOSE=${LOOPCLOSE}"done; "
       CNT=`expr $CNT + 1`
  done

# --------------------------------------------------------------------------- #
# EXECUTE CODE FOR FOR-LOOP TO EVALUATE COMBINATIONS
# --------------------------------------------------------------------------- #
  KOMBILIST=kombinationen.list ; if [ -f $KOMBILIST ]; then rm $KOMBILIST ; fi
  eval ${LOOPSTART}" echo $VARIABLES >> $KOMBILIST ;"${LOOPCLOSE}

# --------------------------------------------------------------------------- #
# WRITE SVG FILES ACCORDING TO POSSIBLE COMBINATIONS
# --------------------------------------------------------------------------- #

  SVGHEADER=`head -n 1 ${SVG%%.*}.tmp`

  for KOMBI in `cat $KOMBILIST | sed 's/ /DHSZEJDS/g'`
   do
      KOMBI=`echo $KOMBI | sed 's/DHSZEJDS/ /g'`
        R=`basename $SVG | cut -d "_" -f 2 | #
           grep "R+" | cut -d "-" -f 2`
      IOS=`basename $SVG | cut -d "_" -f 3-`
      if [ A$R = "AR+" ]; then R="+R-"; else R= ; fi
      NID=`echo ${OUTPUTBASE}        | #
           cut -d "-" -f 1           | #
           tr -t [:lower:] [:upper:] | #
           md5sum | cut -c 1-4       | #
           tr -t [:lower:] [:upper:]`  #
      FID=`basename $SVG             | #
           tr -t [:lower:] [:upper:] | #
           md5sum | cut -c 1-4       | #
           tr -t [:lower:] [:upper:]`  #
      DIF=`echo ${KOMBI}${IOS}       | #
           md5sum | cut -c 1-9       | #
           tr -t [:lower:] [:upper:] | #
           rev`                        #

      SVGOUT=$OUTDIR/$NID$FID`echo $R$DIF | cut -c 1-9 | rev`_${IOS}
      echo "WRITING: $SVGOUT"

      echo "$SVGHEADER"                                  >  $SVGOUT
      for  LAYERNAME in `echo $KOMBI`
        do grep -n "label=\"$LAYERNAME\"" ${SVG%%.*}.tmp >> ${SVGOUT}.tmp
      done
      cat ${SVGOUT}.tmp | sort -n | cut -d ":" -f 2-     >> $SVGOUT
      echo "</svg>"                                      >> $SVGOUT
      rm ${SVGOUT}.tmp

    # DO SOME CLEAN UP
    # -------------------------------------------  #
      inkscape --vacuum-defs              $SVGOUT  # INKSCAPES VACUUM CLEANER
      NLFOO=Nn${RANDOM}lL                          # SET RANDOM PLACEHOLDER
      sed -i ":a;N;\$!ba;s/\n/$NLFOO/g"   $SVGOUT  # PLACEHOLDER FOR LINEBREAKS
      sed -i -e "s,<defs,\nXXX<defs,g"    \
             -e "s,</defs>,</defs>\n,g"   \
             -e "/^<defs/s/\/>/&\n/g"     $SVGOUT  # FORMAT DEFS AND MARK
      sed -i -e "s,<sodipodi,\nXXX&,g"    \
             -e "s,</sodipodi>,&\n,g"     \
             -e "/^<sodipodi/s/\/>/&\n/g" $SVGOUT  # FORMAT SODIPODI STUFF AND MARK
      sed -i -e "s,<metadata,\nXXX&,g"    \
             -e "s,</metadata>,&\n,g"     $SVGOUT  # FORMAT METADATA AND MARK
      sed -i "/^XXX/s/^.*$//g"            $SVGOUT  # DELETE MARKED LINES
      sed -i "s/$NLFOO/\n/g"              $SVGOUT  # RESTORE LINEBREAKS
      sed -i '/^$/d'                      $SVGOUT  # DELETE EMPTY LINES

  done

# --------------------------------------------------------------------------- #
# REMOVE TEMP FILES
# --------------------------------------------------------------------------- #
  rm ${SVG%%.*}.tmp $KOMBILIST

# =========================================================================== #
  done
# =========================================================================== #


exit 0;


