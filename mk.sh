#!/bin/bash

# PERMUTE SVG LAYERS                                                          #
# --------------------------------------------------------------------------- #
# copyright (c) 2016 Christoph Haag                                           #
# --------------------------------------------------------------------------- #

# This is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
# 
# The software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License below for more details.
# 
# -> http://www.gnu.org/licenses/gpl.txt

# --------------------------------------------------------------------------- #
# CONFIGURATION 
# --------------------------------------------------------------------------- #
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
                  grep $BASETYPE                           | #
                  sort -u`                                   #
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
           grep "R+" | sed 's/\(.*\)\(R+\)\(.*\)/\2/g'`
        M=`basename $SVG | cut -d "_" -f 2 | #
           grep -- "-M[-]*" | sed 's/\(.*\)\(M\)\(.*\)/\2/g'`
      if [ A$R = "AR+" ]; then R="+R-"; else R= ; fi
      if [ A$M = "AM" ]; then M="-M-"; else M= ; fi
      IOS=`basename $SVG | cut -d "_" -f 3-`
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
      SVGOUT=$OUTDIR/$NID$FID`echo $R$M$DIF | rev            | #
                              sed 's/-M[-]*R+/-MR+/'         | #
                              rev | cut -c 1-9 | rev`_${IOS}   #
      echo "WRITING: $SVGOUT"
      head -n 1 ${SVG%%.*}.tmp                           >  $SVGOUT
      for  LAYERNAME in `echo $KOMBI`
        do grep -n "label=\"$LAYERNAME\"" ${SVG%%.*}.tmp >> ${SVGOUT}.tmp
      done
      cat ${SVGOUT}.tmp | sort -n | cut -d ":" -f 2-     >> $SVGOUT
      echo "</svg>"                                      >> $SVGOUT
      rm ${SVGOUT}.tmp

    # MAKE IDs UNIQ
    # -------------------------------------------  #
    ( IFS=$'\n'
      for OLDID in `sed 's/id="/\n&/g' $SVGOUT | #
                    grep "^id=" | cut -d "\"" -f 2`
       do
          NEWID=`echo $SVGOUT$OLDID | md5sum | #
                 cut -c 1-9 | tr [:lower:] [:upper:]`
          sed -i "s,id=\"$OLDID\",id=\"$NEWID\",g" $SVGOUT
          sed -i "s,url(#$OLDID),url(#$NEWID),g"   $SVGOUT
      done; )

    # DO SOME CLEAN UP
    # -------------------------------------------  #
      inkscape --vacuum-defs              $SVGOUT  # INKSCAPES VACUUM CLEANER
      NLFOO=Nn${RANDOM}lL                          # RANDOM PLACEHOLDER
      sed -i ":a;N;\$!ba;s/\n/$NLFOO/g"   $SVGOUT  # FOR LINEBREAKS

      cat $SVGOUT                             | # USELESS USE OF CAT
      sed "s,<defs,\n<defs,g"                 | #
      sed "s,</defs>,</defs>\n,g"             | #
      sed "/<\/defs>/!s/\/>/&\n/g"            | # SEPARATE DEFS
      sed "s,</sodipodi:[^>]*>,&\n,g"         | #
      sed "s,<.\?sodipodi,\nXXX&,g"           | #
      sed "/<\/sodipodi:[^>]*>/!s/\/>/&\n/g"  | # MARK TO RM SODIPODI
      sed "/^XXX.*/d"                         | # RM MARKED LINE
      tr -d '\n'                              | # DE-LINEBREAK (AGAIN)
      sed "s,<metadata,\nXXX&,g"              | #
      sed "s,</metadata>,&\n,g"               | #
      sed "/<\/metadata>/!s/\/>/&\n/g"        | # MARK TO RM METADATA
      sed "/^XXX.*/d"                         | # RM MARKED LINE
      sed "s/$NLFOO/\n/g"                     | # RESTORE LINEBREAKS
      sed "/^[ \t]*$/d"                       | # DELETE EMPTY LINES
      tee > ${SVG%%.*}.X.tmp                    # WRITE TO FILE

      mv ${SVG%%.*}.X.tmp $SVGOUT

      SRCSTAMP="<!-- Based on "`basename $SVG`" ("`date +%d.%m.%Y" "%T`")-->"
      sed -i "1s,^.*$,&\n$SRCSTAMP,"     $SVGOUT

  done

# --------------------------------------------------------------------------- #
# REMOVE TEMP FILES
# --------------------------------------------------------------------------- #
  rm ${SVG%%.*}.tmp $KOMBILIST

# =========================================================================== #
  done
# =========================================================================== #


exit 0;


