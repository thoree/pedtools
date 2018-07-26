#' Plot pedigrees with genotypes
#'
#' This is the main function for pedigree plotting, with many options for
#' controlling the appearance of pedigree symbols and accompanying labels. Most
#' of the work is done by the plotting functionality in the 'kinship2' package.
#'
#' `plot.ped` is in essence a wrapper for `plot.pedigree` in the `kinship2`
#' package.
#'
#' @param x a [ped()] object.
#' @param marker either NULL, a vector of positive integers, a [`marker`]
#'   object, or a list of such. If NULL, no genotypes are plotted.  If a vector
#'   of integers is given, the corresponding marker objects are extracted from
#'   `x$markerdata`. The genotypes are written below each individual in the
#'   pedigree, in the format determined by `sep` and `missing`. See also
#'   `skip.empty.genotypes` below.
#' @param sep a character of length 1 separating alleles for diploid markers.
#' @param missing the symbol (integer or character) for missing alleles.
#' @param skip.empty.genotypes a logical. If TRUE, and `marker` is
#'   non-NULL, empty genotypes (which by default looks like '-/-') are not
#'   printed.
#' @param id.labels a vector with labels for each pedigree member. This defaults
#'   to `x$LABELS` (see [setLabels()]).
#' @param title the plot title. If NULL or '', no title is added to the plot.
#' @param col a vector with color indicators for the pedigree members. Recycled
#'   if necessary. By default everyone is drawn black.
#' @param deceased a numeric containing ID's of deceased pedigree members.
#' @param starred a numeric containing ID's of pedigree members that should be
#'   marked with a star in the pedigree plot.
#' @param margins a numeric of length 4 indicating the plot margins. For
#'   singletons only the first element (the 'bottom' margin) is used.
#' @param \dots arguments passed on to `plot.pedigree` in the `kinship2`
#'   package. In particular `symbolsize` and `cex` can be useful.
#' @author Magnus Dehli Vigeland, Guro Doerum
#' @seealso [plot.pedigree()], [setLabels()]
#'
#' @examples
#'
#' x = cousinsPed(1)
#' plot(x)
#'
#' @export
plot.ped = function(x, marker = NULL, sep = "/", missing = "-", skip.empty.genotypes = FALSE,
                    id.labels = x$LABELS, title = NULL, col = 1, deceased = numeric(0),
                    starred = numeric(0), margins = c(0.6, 1, 4.1, 1), ...) {

  # Labels
  if (is.null(id.labels)) id.labels=rep("", pedsize(x))
  else if(identical(id.labels, "")) id.labels=rep("", pedsize(x))
  else if(identical(id.labels, "num")) id.labels = as.character(x$ID)

  id.labels[is.na(id.labels)] = ""

  text = id.labels

  # Add stars to labels
  starred = internalID(x, starred)
  text[starred] = paste0(text[starred], "*")

  # Marker genotypes
  if (!is.null(marker)) {
    if (is.marker(marker))
      mlist = list(marker)
    else if (is.markerList(marker))
      mlist = marker
    else if (is.numeric(marker) || is.character(marker))
      mlist = getMarkers(x, markers=marker)
    else
      stop("Argument `marker` must be either:\n",
           "  * an integer vector (of marker indices)\n",
           "  * a character vector (of marker names)\n",
           "  * a `marker` or `markerList` object", call.=FALSE)
    checkConsistency(x, mlist)

    gg = do.call(cbind, lapply(mlist, format, sep=sep, missing = missing))
    geno = apply(gg, 1, paste, collapse = "\n")
    if (skip.empty.genotypes)
      geno[rowSums(do.call(cbind, mlist)) == 0] = ""

    text = if (!any(nzchar(text))) geno else paste(text, geno, sep = "\n")
  }

  # Needed for centered title. Without, par() doesnt equal 'margins'...(why??)
  oldmar = par(mar = margins)

  # Colors
  cols = rep(col, length = pedsize(x))

  # Special treatment for option 'available=shaded'
  #if (identical(available, "shaded")) {
  #    if (any(c("angle", "density") %in% names(list(...))))
  #        stop("Plot parameters 'angle' and 'density' cannot be used in combination with 'available=shaded'")
  #    pedigree = as.kinship2_pedigree(x, deceased = deceased, aff2 = aff2)
  #    pdat = kinship2::plot.pedigree(pedigree, id = text, col = cols, mar = margins, density = 25, angle = 45, ...)

  pedigree = as.kinship2_pedigree(x, deceased = deceased)
  pdat = kinship2::plot.pedigree(pedigree, id = text, col = cols, mar = margins, ...)

  # Add title
  if (!is.null(title)) title(title)

  # par(oldmar)
  invisible(pdat)
}

#' @rdname plot.ped
#' @export
plot.singleton = function(x, marker = NULL, sep = "/", missing = "-", skip.empty.genotypes = FALSE,
                          id.labels = x$LABELS, title = NULL, col = 1, deceased = numeric(0),
                          starred = numeric(0), margins = c(8, 0, 0, 0), ...) {
  assert_that(is.null(id.labels) || is.string(id.labels))

  y = addParents(x, x$LABELS[1], verbose = FALSE) # reorder necessary??

  # If input id.labels is "num" or "" or something else than x$LABELS, pass it directly on.
  if(is.null(id.labels) || id.labels == "num") id = id.labels
  else id = c(id.labels, "", "")

  p = plot.ped(y, marker = marker, sep =sep, missing = missing,
               skip.empty.genotypes = skip.empty.genotypes, id.labels = id,
               title = title, col = col, deceased = numeric(0), starred = starred,
               margins = c(margins[1], 0, 0, 0), ...)

  usr = par("usr")
  rect(usr[1] - 0.1, p$y[1], usr[2] + 0.1, usr[4], border = NA, col = "white")

  if (!is.null(title)) title(title, line = -2.8)
}

#' @rdname plot.ped
#' @export
as.kinship2_pedigree = function(x, deceased = numeric(0)) {
    ped = as.data.frame(x) # to include original labels

    status = ifelse(ped$id %in% deceased, 1, 0)
    kinship2::pedigree(id = ped$id, dadid = ped$fid, momid = ped$mid, sex = ped$sex,
        status = status, missid=0)
}




#' Plot a list of pedigrees.
#'
#' This function creates a row of pedigree plots, each created by
#' [plot.ped()].  Each parameter accepted by
#' [plot.ped()] can be applied here.  Some effort is made to
#' guess a reasonable window size and margins, but in general the user must be
#' prepared to do manual resizing of the plot window.
#'
#' See various examples in the Examples section below.
#'
#' Note that for tweaking dev.height and dev.width the function
#' [dev.size()] is useful to determine the size of the active device.
#'
#' @param plot.arg.list A list of lists. Each element of `plot.arg.list`
#' is a list, where the first element is the [ped()] object to be
#' plotted, and the remaining elements are passed on to `plot.ped`.
#' These elements must be correctly named. See examples below.
#' @param widths A numeric vector of relative widths of the subplots. Recycled
#' to `length(plot.arg.list)` if necessary, before passed on to
#' [layout()]. Note that the vector does not need to sum to 1.
#' @param frames Either a single logical (FALSE = no frames; TRUE = automatic
#' framing) or a list of numeric vectors: Each vector must consist of
#' consecutive integers, indicating subplots to be framed together. By default
#' the framing follows the list structure of `plot.arg.list`.
#' @param frametitles A character vector of titles for each frame. If this is
#' non-NULL, titles for individuals subplots are ignored.
#' @param fmar A single number in the interval [0,0.5) controlling the position
#' of the frames.
#' @param newdev A logical, indicating if a new plot window should be opened.
#' @param dev.height,dev.width The dimensions of the new device (only relevant
#' if newdev is TRUE). If these are NA suitable values are guessed from the
#' pedigree sizes.
#' @param \dots Further arguments passed on to each call to
#' [plot.ped()].
#' @author Magnus Dehli Vigeland
#' @seealso [plot.ped()]
#' @examples
#'
#'
#' # Simplest use: Just give a list of ped objects.
#' # To guess suitable plot window dimensions, use 'newdev=T'
#' peds = list(nuclearPed(3), cousinsPed(2), singleton(12), halfCousinsPed(0))
#' plotPedList(peds, newdev=TRUE)
#'
#' # Modify the relative widths (which are not guessed)
#' widths = c(2, 3, 1, 2)
#' plotPedList(peds, widths=widths)
#'
#' # In most cases the guessed dimensions are not perfect.
#' # Resize plot window manually, and then plot again with newdev=F (default)
#' # plotPedList(peds, widths=widths)
#'
#' ## Remove frames
#' plotPedList(peds, widths=widths, frames=FALSE)
#'
#' # Non-default frames
#' frames = list(1, 2:3)
#' plotPedList(peds, widths=widths, frames=frames, frametitles=c('First', 'Second'))
#'
#' # To give *the same* parameter to all plots, it can just be added at the end:
#' margins=c(2,4,2,4)
#' title='Same title'
#' id.labels=''
#' symbolsize=1.5 # note: doesn't work as expected for singletons
#' plotPedList(peds, widths=widths, frames=frames, margins=margins, title=title,
#'             id.labels=id.labels, symbolsize=symbolsize, newdev=TRUE)
#'
#' \dontrun{
#' ### EXAMPLE WITH MARKER DATA
#' # For more control of individual plots, each plot and all its parameters
#' # can be specified in its own list:
#' x1 = nuclearPed(3)
#' x1$available = 3:5
#' m1 = marker(x1, 3, 1:2)
#' marg1 = c(5,4,5,4)
#' plot1 = list(x1, marker=m1, margins=marg1, title='Plot 1', deceased=1:2)
#'
#' x2 = cousinsPed(2)
#' x2$available = leaves(x2)
#' m2 = marker(x2, leaves(x2), 'A')
#' marg2 = c(3,4,2,4)
#' plot2 = list(x2, marker=m2, margins=marg2, title='Plot 2', symbolsize=1.2,
#'              skip.empty.genotypes=T)
#'
#' x3 = singleton(12)
#' x3 = setAvailable(x3, 12)
#' marg3 = c(10,0,0,0)
#' plot3 = list(x3, margins=marg3, title='Plot 3', available='shaded', symbolsize=2)
#'
#' x4 = halfCousinsPed(0)
#' names4 = c(Father=1, Brother=3, Sister=5)
#' marg4 = marg1
#' plot4 = list(x4, margins=marg4, title='Plot 4', id.labels=names4)
#'
#' plotPedList(list(plot1, plot2, plot3, plot4), widths=c(2,3,1,2),
#'             frames=list(1,2:3,4), available=T, newdev=T)
#'
#' # Different example:
#' plotPedList(list(halfCousinPed(4), cousinsPed(7)), title='Many generations',
#'     new=T, dev.height=9, dev.width=9)
#' }
#'
#' @importFrom grDevices dev.new dev.size
#' @importFrom graphics grconvertX grconvertY layout mtext rect par plot
#' @export
plotPedList = function(plot.arg.list, widths = NA, frames = T, frametitles = NULL, fmar = NA,
                       newdev = F, dev.height = NA, dev.width = NA, ...) {

  plot.list.flattened = list()
  if (deduceFrames <- isTRUE(frames)) {
    frames = list()
    k = 0
  }
  for (p in plot.arg.list) {
    if (is.ped(p))
      p = list(p)  # will now be included in next line
    if (is.pedList(p)) {
      plot.list.flattened = c(plot.list.flattened, lapply(p, list))
    }
    else {
        # if list of ped with plot arguments
        if (!is.ped(p[[1]])) {
          print(p)
          stop("First element is not a ped object.")
        }
        p = list(p)
        plot.list.flattened = append(plot.list.flattened, p)
      }
    if (deduceFrames) {
      group = (k + 1):(k <- k + length(p))
      frames = append(frames, list(group))
    }
  }
  plot.arg.list = plot.list.flattened
  N = length(plot.arg.list)
  if (identical(widths, NA))
    widths = vapply(plot.arg.list, function(p) ifelse(is.singleton(p[[1]]), 1, 2.5), 1)
  else
    widths = rep_len(widths, N)
  maxGen = max(vapply(plot.arg.list, function(arglist) .generations(arglist[[1]]), 1))

  if (hasframetitles <- !is.null(frametitles))
    assert_that(length(frametitles) == length(frames))

  extra.args = list(...)
  if (!"title" %in% names(extra.args))
    extra.args$title = ""

  defaultmargins = if (N > 2)
    c(0, 4, 0, 4) else c(0, 2, 0, 2)

  plot.arg.list = lapply(plot.arg.list, function(arglist) {
    names(arglist)[1] = "x"
    g = .generations(arglist$x)
    addMargin = 2 * (maxGen - g + 1)
    if (!"margins" %in% c(names(arglist), names(extra.args)))
      arglist$margins = defaultmargins + c(addMargin, 0, addMargin, 0)

    # additional arguments given in (...)
    for (parname in setdiff(names(extra.args), names(arglist)))
      arglist[[parname]] = extra.args[[parname]]
    arglist
  })

  # title: this must be treated specially (in outer margins)
  titles = sapply(plot.arg.list, "[[", "title")
  plot.arg.list = lapply(plot.arg.list, function(arglist) {
    arglist$title = ""
    arglist
  })
  hastitles = hasframetitles || any(titles != "")

  # frame list: check that each vector is consecutive integers, and no duplicates.
  if (is.list(frames)) {
    for (v in frames)
      if (!identical(TRUE, all.equal(v, v[1]:v[length(v)])))
        stop(sprintf("Each element of 'frames' must consist of consecutive integers: %s",
                   paste(v, collapse = ",")))
    dup = anyDuplicated(unlist(frames))
    if (dup > 0)
      stop(sprintf("Plot %d occurs twice in 'frames' list", dup))
  }


  # create layout of plot regions and plot!
  if (newdev) {
    if (is.na(dev.height))
      dev.height = max(3, 1 * maxGen) + 0.3 * as.numeric(hastitles)
    if (is.na(dev.width))
      dev.width = 3 * N
    dev.new(height = dev.height, width = dev.width, noRStudioGD = TRUE)
  }

  if (hastitles)
    par(oma = c(0, 0, 3, 0), xpd = NA)
  else
    par(oma = c(0, 0, 0, 0), xpd = NA)

  layout(rbind(1:N), widths = widths)
  for (arglist in plot.arg.list)
    do.call(plot, arglist)

  # leftmost coordinate of each plot region (converted to value in [0,1]).
  ratios = c(0, cumsum(widths)/sum(widths))

  # add frames
  if (is.list(frames)) {
    midpoints = numeric()
    fstart_index = sapply(frames, function(v) v[1])
    fstop_index = sapply(frames, function(v) v[length(v)])
    ratio_start = ratios[fstart_index]
    ratio_stop = ratios[fstop_index + 1]  # fordi 0 foerst
    midpoints = (ratio_start + ratio_stop)/2

    # margin (fmar): if NA, set to 5% of vertical height, but at most 0.25 inches.
    if (is.na(fmar))
      fmar = min(0.05, 0.25/dev.size()[2])
    margPix = grconvertY(0, from = "ndc", to = "device") * fmar
    margXnorm = grconvertX(margPix, from = "device", to = "ndc")
    frame_start = grconvertX(ratio_start + margXnorm, from = "ndc")
    frame_stop = grconvertX(ratio_stop - margXnorm, from = "ndc")
    rect(xleft = frame_start,
         ybottom = grconvertY(1 - fmar, from = "ndc"),
         xright = frame_stop,
         ytop = grconvertY(fmar, from = "ndc"))
  }

  cex.title =
    if ("cex.main" %in% names(extra.args)) extra.args$cex.main
    else NA

  if (hasframetitles) {
    for (i in 1:length(frames))
      mtext(frametitles[i], outer = TRUE, at = midpoints[i], cex = cex.title)
  }
  else if (hastitles) {
    for (i in 1:N)
      mtext(titles[i], outer = TRUE, at = (ratios[i] + ratios[i + 1])/2, cex = cex.title)
  }
}