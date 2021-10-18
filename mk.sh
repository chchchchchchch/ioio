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
  OUTDIR="_";TMP="/tmp/IOIO"
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
# =========================================================================== #
# DO IT NOW!
# =========================================================================== #
  for SRC in $SVGINPUT
   do MD5SRC=`md5sum $SRC | cut -c 1-16`
      OUTPUTBASE=`basename $SRC            | #
                  cut -d "_" -f 2          | #
                  sed 's/-R+//g'           | #
                  tr -t [:lower:] [:upper:]` #
# --------------------------------------------------------------------------- #
# MOVE ALL LAYERS ON SEPARATE LINES IN A TMP FILE
# --------------------------------------------------------------------------- #
  sed ':a;N;$!ba;s/\n//g' $SRC           | # REMOVE ALL LINEBREAKS
  sed 's/<g/\n&/g'                       | # MOVE GROUP TO NEW LINES
  sed '/groupmode="layer"/s/<g/4Fgt7R/g' | # PLACEHOLDER FOR LAYERGROUP OPEN
  sed ':a;N;$!ba;s/\n/ /g'               | # REMOVE ALL LINEBREAKS
  sed 's/4Fgt7R/\n<g/g'                  | # RESTORE LAYERGROUP OPEN + NEWLINE
  sed 's/display:none/display:inline/g'  | # MAKE VISIBLE EVEN WHEN HIDDEN
  grep -v 'label="XX_'                   | # REMOVE EXCLUDED LAYERS
  sed 's/<\/svg>/\n&/g'                  | # CLOSE TAG ON SEPARATE LINE
  sed "s/^[ \t]*//"                      | # REMOVE LEADING BLANKS
  tr -s ' '                              | # REMOVE CONSECUTIVE BLANKS
  tee > ${TMP}SRC                          # WRITE TO TEMPORARY FILE
# --------------------------------------------------------------------------- #
# GENERATE CODE FOR FOR-LOOP TO EVALUATE COMBINATIONS
# --------------------------------------------------------------------------- #
  # RESET (IMPORTANT FOR 'FOR'-LOOP)
  LOOPSTART="";VARIABLES="";LOOPCLOSE="";CNT=0

  for BASETYPE in `sed ':a;N;$!ba;s/\n/ /g' ${TMP}SRC | #
                   sed 's/<g/\n&/g'                   | # GROUPS ON NEWLINE
                   sed '/^<g/s/>/&\n/g'               | # FIRST ON '>' ON NEWLINE
                   grep ':groupmode="layer"'          | #
                   sed '/^<g/s/scape:label/\nlabel/'  | #
                   grep ^label                        | #
                   cut -d "\"" -f 2                   | #
                   cut -d "-" -f 1                    | #
                   sort -u`
   do
       ALLOFTYPE=`sed ':a;N;$!ba;s/\n/ /g' ${TMP}SRC                | #
                  sed 's/scape:label/\nlabel/g'                     | #
                  grep '^label='                                    | #
                  egrep "=\"${BASETYPE}[-_]+[0-9]+|=\"${BASETYPE}$" | #
                  cut -d "\"" -f 2                                  | #
                  sort -u`                                            #
       LOOPSTART=${LOOPSTART}"for V$CNT in $ALLOFTYPE; do "
       VARIABLES=${VARIABLES}'$'V${CNT}" "
       LOOPCLOSE=${LOOPCLOSE}"done; "
       CNT=`expr $CNT + 1`
  done
# --------------------------------------------------------------------------- #
# CHECK SRC GIT STATUS
# --------------------------------------------------------------------------- #
  NOGIT=`git status |& tee | grep 'Not a git repository' | wc -l`
  if [ "$NOGIT" != 1 ]
  then
  if [ `ls $SRC 2>/dev/null | wc -l` -lt 1 ] ||
     [ `git ls-files $SRC --exclude-standard --others | wc -l` -gt 0 ]
  then LATESTHASH="UNTRACKED";echo -e "\e[31m$SRC UNTRACKED\e[0m"
  else LATESTHASH=`git log --pretty=tformat:%H $SRC | head -n 1`
       LATESTHASH="($LATESTHASH/$MD5SRC)"
       SVGSTATUS=`git status -s $SRC | #
                  sed 's/^[ \t]*//'  | #
                  cut -d " " -f 1`     #
       if [ "$SVGSTATUS" == "M" ]
       then LATESTHASH="$LATESTHASH/$MD5SRC +MOD"
            echo -e "\e[31m$SRC MODIFIED\e[0m"
       fi
  fi # CLEAR EMPTY (= () ) HASH
       LATESTHASH=`echo $LATESTHASH | sed 's/()//g'`
  else LATESTHASH=`echo $LATESTHASH | sed 's/()//g'`
  fi
# --------------------------------------------------------------------------- #
# EXECUTE CODE FOR FOR-LOOP TO EVALUATE COMBINATIONS
# --------------------------------------------------------------------------- #
  KOMBILIST=kombinationen.list ; if [ -f $KOMBILIST ]; then rm $KOMBILIST ; fi
  eval ${LOOPSTART}" echo $VARIABLES >> $KOMBILIST ;"${LOOPCLOSE}
# --------------------------------------------------------------------------- #
# WRITE SVG FILES ACCORDING TO POSSIBLE COMBINATIONS
# --------------------------------------------------------------------------- #
  SVGHEADER=`head -n 1 ${TMP}SRC`

  for KOMBI in `cat $KOMBILIST | sed 's/ /DHSZEJDS/g'`
   do
      KOMBI=`echo $KOMBI | sed 's/DHSZEJDS/ /g'`
        R=`basename $SRC | cut -d "_" -f 2 | #
           grep "R+" | sed 's/\(.*\)\(R+\)\(.*\)/\2/g'`
        M=`basename $SRC | cut -d "_" -f 2 | #
           grep -- "-M[-+]*" | sed 's/\(.*\)\(M[-+]*\)\(.*\)/\2/g'`
      if [ "$M" == "M"  ];then M="-M-";fi
      if [ "$M" == "M-" ];then M="-M-";fi
      if [ "$M" == "M+" ];then M="+M-";fi
      if [ "$R" == "R+" ];then R="+R-";else R="";fi

      IOS=`basename $SRC | cut -d "_" -f 3- | cut -d "." -f 1`

      NID=`echo ${OUTPUTBASE}        | #
           cut -d "-" -f 1           | #
           tr -t [:lower:] [:upper:] | #
           md5sum | cut -c 1-4       | #
           tr -t [:lower:] [:upper:]`  #
      FID=`basename $SRC             | #
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
    # ------------------------------------------------------------------- #
      if [ ! -f "$SVGOUT" ] || 
         [ "_$IOS" == "_XX_XX_XX_XX_" ]
      then AKTION="WRITE"
    # ------------------------------------------------------------------- #
      head -n 1 ${TMP}SRC                                >  ${TMP}
      for  LAYERNAME in `echo $KOMBI`
        do grep -n "label=\"$LAYERNAME\"" ${TMP}SRC      >> ${TMP}.tmp
      done
      cat ${TMP}.tmp | sort -n | cut -d ":" -f 2-        >> ${TMP}
      echo "</svg>"                                      >> ${TMP}
      rm ${TMP}.tmp
    # ------------------------------------------------------------------- #
      if [ "_$IOS" == "_XX_XX_XX_XX_" ]
      then  TOP=`sed 's/connect="/\n&/g' $TMP        | #
                 grep '^connect="' | cut -d '"' -f 2 | #
                 cut -c 1-2 | tr [:lower:] [:upper:] | #
                 egrep '[A-Z0]' | tail -n 1`
          RIGHT=`sed 's/connect="/\n&/g' $TMP        | #
                 grep '^connect="' | cut -d '"' -f 2 | #
                 cut -c 3-4 | tr [:lower:] [:upper:] | #
                 egrep '[A-Z0]' | tail -n 1`
         BOTTOM=`sed 's/connect="/\n&/g' $TMP        | #
                 grep '^connect="' | cut -d '"' -f 2 | #
                 cut -c 5-6 | tr [:lower:] [:upper:] | #
                 egrep '[A-Z0]' | tail -n 1`
           LEFT=`sed 's/connect="/\n&/g' $TMP        | #
                 grep '^connect="' | cut -d '"' -f 2 | #
                 cut -c 7-8 | tr [:lower:] [:upper:] | #
                 egrep '[A-Z0]' | tail -n 1`
            IOS="${TOP}_${RIGHT}_${BOTTOM}_${LEFT}_"
            DIF=`echo ${KOMBI}${IOS}.svg  | #
                 md5sum | cut -c 1-9       | #
                 tr -t [:lower:] [:upper:] | #
                 rev`                        #
           SVGOUT=$OUTDIR/$NID$FID`echo $R$M$DIF | rev    | #
                                   sed 's/-M[-]*R+/-MR+/' | #
                                   rev | cut -c 1-9 | rev`_${IOS}.svg
       # -------------------------------------------------------------- #
         if [ ! -f "$SVGOUT" ] &&
            [ `grep "$LATESTHASH" $SVGOUT 2> /dev/null | wc -l` -lt 1 ]
         then mv $TMP $SVGOUT;AKTION="WRITE";else AKTION="SKIP";     fi
       # -------------------------------------------------------------- #
      fi
    # ------------------------------------------------------------------- #
      else AKTION="SKIP"
      fi
   # --------------------------------------------------------------------- #
     if [ `grep "$LATESTHASH" $SVGOUT 2> /dev/null | wc -l` -lt 1 ]
     then if [ -f "$TMP" ];then mv $TMP $SVGOUT;AKTION="WRITE";fi
     else if [ -f "$TMP" ];then rm $TMP ;fi;AKTION="SKIP"
     fi
  # ======================================================================= #
    if [ `basename $SVGOUT | #
           egrep "^[0-9A-FRM+-]{17}_([A-Z0]{2}_){4}\.svg" | #
            wc -l` -gt 0 ] && [ "$AKTION" != "SKIP" ]
      then
    # ------------------------------------------------------------------- #
      echo "WRITING: $SVGOUT"
    # ------------------------------------------------------------------- #
    # MAKE IDs UNIQ
    # ------------------------------------------------------------------- #
    ( IFS=$'\n'
      for OLDID in `sed 's/id="/\n&/g' $SVGOUT | #
                    grep "^id=" | cut -d "\"" -f 2`
       do
          SVGNAME=`basename $SVGOUT`
          NEWID=`echo $SVGNAME$OLDID | md5sum | #
                 cut -c 1-9 | tr [:lower:] [:upper:]`
          sed -i "s,id=\"$OLDID\",id=\"$NEWID\",g" $SVGOUT
          sed -i "s,url(#$OLDID),url(#$NEWID),g"   $SVGOUT
      done; )
    # ------------------------------------------------------------------- #
    # DO SOME CLEAN UP
    # ------------------------------------------------------------------- #
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
      tee > ${TMP}TWO                           # WRITE TO FILE

      mv ${TMP}TWO $SVGOUT
    # -------------------------------------------------------------------- #
    # DO STAMP
    # -------------------------------------------------------------------- #
      SRCSTAMP=`echo '<!-- '\`basename $SRC\`" $LATESTHASH -->" | tr -s ' '`
      sed -i "1s,^.*$,&\n$SRCSTAMP," $SVGOUT
  # ======================================================================= #
    else if [ `basename $SVGOUT | #
               egrep "^[0-9A-FRM+-]{17}_([A-Z0]{2}_){4}\.svg" | #
               wc -l` -lt 1 ] && [ -f "$SVGOUT" ]
         then rm $SVGOUT
              >&2 echo -e "\e[31mSKIPPING "`basename $SVGOUT`"\e[0m"
         else >&2 echo -e "\e[32m$SVGOUT UP-TO-DATE\e[0m"
         fi
    fi
  # ======================================================================= #
  done
# --------------------------------------------------------------------------- #
# REMOVE TMP FILES
# --------------------------------------------------------------------------- #
  if [ `echo ${TMP} | wc -c` -ge 4 ] &&
     [ `ls ${TMP}*.* 2>/dev/null | wc -l` -gt 0 ]
  then  ls ${TMP}*.* ;fi
  rm $KOMBILIST
# =========================================================================== #
  done
# =========================================================================== #

exit 0;
