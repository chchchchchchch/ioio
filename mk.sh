#!/bin/bash

# PERMUTE SVG LAYERS                                                          #
# --------------------------------------------------------------------------- #
# Copyright (C) 2020 Christoph Haag                                           #
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
  OUTDIR="_"
# --------------------------------------------------------------------------- #
# VALIDATE (PROVIDED) INPUT 
# --------------------------------------------------------------------------- #
  if [ `echo $* | wc -c` -lt 2 ];then echo "No arguments provided";exit 0;
  else  NOFLAGS=`echo $* | sed 's/ /\n/g' | grep -v '^-'`
        if [ `ls \`ls ${NOFLAGS}* 2> /dev/null\` 2> /dev/null  | #
              grep "\.svg$" | wc -l` -lt 1 ];              #
        then  echo 'No valid svg!';exit 0
        else  SVGINPUT=`ls \`ls ${NOFLAGS}*\` | grep "\.svg$"`
        fi
  fi
# --------------------------------------------------------------------------- #
# CHECK/SET FLAGS
# --------------------------------------------------------------------------- #
  if [ `echo $* | sed 's/ /\n/g' | grep "^-" | #
        egrep -- '-u|update' | wc -l` -gt 0  ];then MODUS="UPDATE";fi
# =========================================================================== #
# DO IT NOW!
# =========================================================================== #
  for SVG in $SVGINPUT
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
       ALLOFTYPE=`sed ':a;N;$!ba;s/\n/ /g' ${SVG%%.*}.tmp      | #
                  sed 's/scape:label/\nlabel/g'                | #
                  grep ^label                                  | #
                  cut -d "\"" -f 2                             | #
                  egrep "${BASETYPE}[-_]+[0-9]+|^${BASETYPE}$" | #
                  sort -u`                                       #
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
           grep -- "-M[-+]*" | sed 's/\(.*\)\(M[-+]*\)\(.*\)/\2/g'`
      if [ "$M" == "M"  ];then M="-M-";fi
      if [ "$M" == "M-" ];then M="-M-";fi
      if [ "$M" == "M+" ];then M="+M-";fi
      if [ "$R" == "R+" ];then R="+R-";else R="";fi

      IOS=`basename $SVG | cut -d "_" -f 3- | cut -d "." -f 1`

      NID=`echo ${OUTPUTBASE}        | #
           cut -d "-" -f 1           | #
           tr -t [:lower:] [:upper:] | #
           md5sum | cut -c 1-4       | #
           tr -t [:lower:] [:upper:]`  #
      FID=`basename $SVG             | #
           tr -t [:lower:] [:upper:] | #
           md5sum | cut -c 1-4       | #
           tr -t [:lower:] [:upper:]`  #
      DIF=`echo ${KOMBI}${IOS}.svg   | #
           md5sum | cut -c 1-9       | #
           tr -t [:lower:] [:upper:] | #
           rev`                        #
      SVGOUT=$OUTDIR/$NID$FID`echo $R$M$DIF | rev              | #
                              sed 's/-M[-]*R+/-MR+/'           | #
                              rev | cut -c 1-9 | rev`_${IOS}.svg #

      if [ ! -f "$SVGOUT" ] || 
         [ "$MODUS" != "UPDATE" ] || 
         [ "_$IOS" == "_XX_XX_XX_XX_" ]
      then AKTION="WRITE"
    # ------------------------------------------------------------------- #
      head -n 1 ${SVG%%.*}.tmp                           >  ${SVGOUT}
      for  LAYERNAME in `echo $KOMBI`
        do grep -n "label=\"$LAYERNAME\"" ${SVG%%.*}.tmp >> ${SVGOUT}.tmp
      done
      cat ${SVGOUT}.tmp | sort -n | cut -d ":" -f 2-     >> ${SVGOUT}
      echo "</svg>"                                      >> ${SVGOUT}
      rm ${SVGOUT}.tmp
    # ------------------------------------------------------------------- #
      if [ "_$IOS" == "_XX_XX_XX_XX_" ]
      then  TOP=`sed 's/connect="/\n&/g' $SVGOUT     | #
                 grep '^connect="' | cut -d '"' -f 2 | #
                 cut -c 1-2 | tr [:lower:] [:upper:] | #
                 egrep '[A-Z0]' | tail -n 1`
          RIGHT=`sed 's/connect="/\n&/g' $SVGOUT     | #
                 grep '^connect="' | cut -d '"' -f 2 | #
                 cut -c 3-4 | tr [:lower:] [:upper:] | #
                 egrep '[A-Z0]' | tail -n 1`
         BOTTOM=`sed 's/connect="/\n&/g' $SVGOUT     | #
                 grep '^connect="' | cut -d '"' -f 2 | #
                 cut -c 5-6 | tr [:lower:] [:upper:] | #
                 egrep '[A-Z0]' | tail -n 1`
           LEFT=`sed 's/connect="/\n&/g' $SVGOUT     | #
                 grep '^connect="' | cut -d '"' -f 2 | #
                 cut -c 7-8 | tr [:lower:] [:upper:] | #
                 egrep '[A-Z0]' | tail -n 1`
            IOS="${TOP}_${RIGHT}_${BOTTOM}_${LEFT}_"
            DIF=`echo ${KOMBI}${IOS}.svg  | #
                 md5sum | cut -c 1-9       | #
                 tr -t [:lower:] [:upper:] | #
                 rev`                        #
           SVGNEU=$OUTDIR/$NID$FID`echo $R$M$DIF | rev    | #
                                   sed 's/-M[-]*R+/-MR+/' | #
                                   rev | cut -c 1-9 | rev`_${IOS}.svg
           if [ ! -f "$SVGNEU" ] || [ "$MODUS" != "UPDATE" ]
           then mv $SVGOUT $SVGNEU;AKTION="WRITE"
           else if [ -f "$SVGOUT" ];then rm $SVGOUT;fi;AKTION="SKIP"
           fi
           SVGOUT="$SVGNEU"
      fi
    # ------------------------------------------------------------------- #
      else AKTION="SKIP"
      fi
  # ----------------------------------------------------------------------- #
    if [ `basename $SVGOUT | #
           egrep "^[0-9A-FRM+-]{17}_([A-Z0]{2}_){4}\.svg" | #
            wc -l` -gt 0 ] && [ "$AKTION" != "SKIP" ]
      then
    # ------------------------------------------------------------------- #
      echo "WRITING: $SVGOUT"
    # ------------------------------------------------------------------- #

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

    # CHECK FILE'S GIT STATUS
    # -------------------------------------------------------------------- #
      NOGIT=`git status |& tee | grep 'Not a git repository' | wc -l`
      if [ "$NOGIT" != 1 ]
      then
      if [ `ls $SVG 2>/dev/null | wc -l` -lt 1 ] ||
         [ `git ls-files $SVG --exclude-standard --others | wc -l` -gt 0 ]
      then LATESTHASH="UNTRACKED";echo -e "\e[31m$SVG UNTRACKED\e[0m"
      else LATESTHASH=`git log --pretty=tformat:%H $SVG | head -n 1`
           LATESTHASH="($LATESTHASH)"
           SVGSTATUS=`git status -s $SVG | #
                      sed 's/^[ \t]*//'  | #
                      cut -d " " -f 1`     #
           if [ "$SVGSTATUS" == "M" ]
           then LATESTHASH="$LATESTHASH +MOD"
                echo -e "\e[31m$SVG MODIFIED\e[0m"
           fi
      fi # CLEAR EMPTY (= () ) HASH
           LATESTHASH=`echo $LATESTHASH | sed 's/()//g'`
      else LATESTHASH=`echo $LATESTHASH | sed 's/()//g'`
      fi
    # DO STAMP
    # -------------------------------------------------------------------- #
      SRCSTAMP=`echo '<!-- '\`basename $SVG\`" $LATESTHASH -->" | tr -s ' '`
      sed -i "1s,^.*$,&\n$SRCSTAMP," $SVGOUT
    # ------------------------------------------------------------------- #
  # ----------------------------------------------------------------------- #
    else if [ `basename $SVGOUT | #
               egrep "^[0-9A-FRM+-]{17}_([A-Z0]{2}_){4}\.svg" | #
               wc -l` -lt 1 ] && [ -f "$SVGOUT" ]
         then rm $SVGOUT
              >&2 echo -e "\e[31mSKIPPING "`basename $SVGOUT`"\e[0m"
         else >&2 echo -e "\e[32m$SVGOUT EXISTS\e[0m"
         fi
    fi
  # ----------------------------------------------------------------------- #
  done
# --------------------------------------------------------------------------- #
# REMOVE TEMP FILES
# --------------------------------------------------------------------------- #
  rm ${SVG%%.*}.tmp $KOMBILIST
# =========================================================================== #
  done
# =========================================================================== #

exit 0;
