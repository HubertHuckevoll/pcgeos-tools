# Swat source-line breakpoints

Samples for swat.rc.
The app / lib must be called with run or spawn before setting the breakpoint in swat.rc:

run bbxbrow
spawn bbxbrow

## stop at
stop at /home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc 82

## stop in
stop in HTMLVProcessClass::MSG_META_NOTIFY
