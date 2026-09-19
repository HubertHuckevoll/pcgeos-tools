# Swat source-line breakpoints

`stop at file:line` parses the colon form correctly.
Samples for swat.rc:
```
run bbxbrow
stop at /home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc 82
```
The app / lib must be called with run or spawn before setting the breakpoint in swat.rc.