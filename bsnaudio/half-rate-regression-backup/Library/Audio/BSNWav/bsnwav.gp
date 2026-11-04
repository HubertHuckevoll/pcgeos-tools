########################################################################
#
#     Copyright (c) Dirk Lausecker 1999-2000 -- All Rights Reserved
#
# PROJECT:      BestSound
# MODULE:       NewWave Library
# FILE:         bsnwav.gp
#
# AUTHOR:       Dirk Lausecker
#
# DESCRIPTION:
#   Geode definitions for the NEWWAVE-Library.
#
# REVISION HISTORY:
#   Date      Name      Description
#   --------  --------  -----------
#   21.06.98  DirkL     Initial Version.
#   06.10.98    DL      Ableitung von Template
#   08.10.99	DL	Ableitung von Mixer Library
#   27.12.99	DL	Ableitung von Recordlibrary
#   20.02.2000	DL	NewWave Routinen
#   08.08.2000	DL	Translating for ND
#
########################################################################

name bsnwav.lib
longname "PC/GEOS Ensemble Audio"
tokenchars "BSNW"
tokenid 16427

type    library, single, c-api

# platform geos201

#
# Libraries: list which libraries are used by the application.
#
library geos
# Keep arithmetic and memory routines local: AnsiC imports Math and UI.
resource WCC_TEXT fixed code read-only shared
resource STRINGCODE fixed code read-only shared

# resource STATUSBOXRESOURCE	ui-object
# resource MONIKERRESOURCE	data object read-only

#
# Export classes
#       These are the classes exported by the library
#

# export StatusInteractionClass


#
# Routines
#       These are the routines exported by the library
#

entry   BSNWLIBENTRY

incminor

export  BSNWAVLOADDRIVER
export	BSNWAVGETMAXPROPERTIES
export	BSNWALLOCSECBUFFER
export	BSNWAVEPLAYFILE
export	BSNWAVEGETSTATUS
export	BSNWAVEGETAISTATE
export	BSNWAVESTOPRECORPLAY
export	BSNWAVEPLAYMEMORY
export	BSNWAVESTOP
export	BSNWAVESETPAUSE
export	BSNWAVEPLAYCALLBACK
export	BSNWAVECHECKDRIVER
export	BSNWAVECALCPLAYTIMETEXT
export	BSNWAVEGETPLAYSTATE
export	BSNWAVEGETLASTFORMAT
export  BSNWAVEPLAYPCM

# usernotes "NewWave-Library for best sound. \xa9 2000 Dirk Lausecker"


incminor
export BSNPCMPLAY
export BSNWAVOPEN
export BSNWAVREADPCM
export BSNWAVCLOSE

# Mutable playback state shares dgroup with immutable decoder tables.
resource dgroup fixed
resource MP3MathCode fixed code read-only shared
resource MP3ApiCode code read-only shared
resource MP3FrameCode code read-only shared
resource MP3HuffCode code read-only shared
resource MP3ImdctCode code read-only shared
resource MP3SynthCode code read-only shared
resource MP3DspCode code read-only shared
resource MP3QuantCode code read-only shared
resource MP3SterCode code read-only shared
export BSNMP3DECOPEN
export BSNMP3DECREADPCM
export BSNMP3DECCLOSE
resource MP3ReaderCode code read-only shared
resource AudioMainCode code read-only shared
resource PCMCode code read-only shared
resource WAVCode code read-only shared
resource ASMTOOLS_TEXT code read-only shared

# Optional MP3 output quality; retain all existing export ordinals.
incminor
export BSNMP3DECOPENEX
