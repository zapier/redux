# Vignette sources

The `redux.Rmd` file is automatically generated from `redux.R`; make edits in the `.R` file or they will be lost!

Because `redux.Rmd` requires Redis to be run, we use a trick (due to Carl Boettiger; see https://github.com/ropensci/redux/pulls/6) to avoid building the vignette on CRAN.  Running `make vignettes` (at the top level) will:

* Compile `vignettes/src/redux.R` -> `vignettes/src/redux.Rmd`
* Knit `vignettes/src/redux.Rmd` -> `vignettes/src/redux.md`
* Copy `vignettes/src/redux.md` to `vignettes/redux.Rmd`
* Knits `vignettes/redux.Rmd` (which has no executable code) to `inst/doc/`

The `R CMD check` vignette builder then repeats the last step which does not require Redis server to be run.

The travis build will rebuild the vignettes from scratch so we do get some level of checking there.
