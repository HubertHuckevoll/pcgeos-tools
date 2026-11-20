# Adding custom Warnings and break on them using swat.rc

(Custom) `EC_WARNING`s added to the code will show up in Swat. Swat can execute instructions when warnings hit. Add a function like the following to `~/swat.rc` to show variable values, trigger a backtrace, etc. Avoid giving instructions to execute by hand at the Swat prompt. Also, don't dump to much information at once.

```rc
[defsubr pdf::PDF_TRANSLATION_FAILED {} {
    echo {PDF translator failure:}
    locals
    print p->error
    print op
    bt
    return 1
}]
```

You can also use `~/swat.rc` to configure breakpoints. When creating breakpoints for Swat, use the breakpoint syntax for `stop at` described in `~/pcgeos-tools/wiki/swat-source-breakpoints.md`.