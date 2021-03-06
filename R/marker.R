#' Marker objects
#'
#' Creating a marker object associated with a pedigree
#'
#'
#' @param x a [`ped`] object
#' @param ... one or more expressions of the form `id = genotype`, where `id` is
#'   the ID label of a member of `x`, and `genotype` is a numeric or character
#'   vector of length 1 or 2 (see Examples).
#' @param allelematrix a matrix with 2 columns and `pedsize(x)` rows. If this is
#'   non-NULL, then `...` must be empty.
#' @param alleles a character (or coercible to character) containing allele
#'   names. If not given, and `afreq` is named, `names(afreq)` is used. The
#'   default action is to take the sorted vector of distinct alleles occurring
#'   in `allelematrix` or `...`.
#' @param afreq a numeric of the same length as `alleles`, indicating the
#'   population frequency of each allele. A warning is issued if the frequencies
#'   don't sum to 1 after rounding to 3 decimals. If the vector is named, and
#'   `alleles` is not NULL, an error is raised if `setequal(names(afreq),
#'   alleles)` is not TRUE. If `afreq` is not specified, all alleles are given
#'   equal frequencies.
#' @param chrom a single integer: the chromosome number. Default: NA.
#' @param posMb a nonnegative real number: the physical position of the marker,
#'   in megabases. Default: NA.
#' @param posCm a nonnegative real number: the centiMorgan position of the
#'   marker. Default: NA.
#' @param name a character string: the name of the marker. Default: NA.
#' @param NAstrings A character vector containing strings to be treated as
#'   missing alleles. Default: `c("", "0", NA, "-")`.
#' @param mutmod,rate mutation model parameters. These are passed directly to
#'   [pedmut::mutationModel()]; see there for details. Note: `mutmod`
#'   corresponds to the `model` parameter. Default: NULL (no mutation model).
#' @param validate if TRUE, the validity of the created `marker` object is
#'   checked.
#'
#' @return An object of class `marker`. This is an integer matrix with 2 columns
#'   and one row per individual, and the following attributes:
#'
#'   * `alleles` (a character vector with allele labels)
#'
#'   * `afreq` (allele frequencies; default `rep.int(1/length(alleles),
#'   length(alleles))`)
#'
#'   * `chrom` (chromosome number; default = NA)
#'
#'   * `posMb` (physical location in megabases; default = NA)
#'
#'   * `posCm` (position in centiMorgan; default = NA)
#'
#'   * `name` (marker identifier; default = NA)
#'
#'   * `mutmod` (a list of two (male and female) mutation matrices; default =
#'   NULL)
#'
#' @seealso [marker_attach]
#'
#' @examples
#' x = nuclearPed(father = "fa", mother = "mo", children = "child")
#'
#' # An empty SNP with alleles "A" and "B"
#' marker(x, alleles = c("A", "B"))
#'
#' # Alleles/frequencies can be given jointly or separately
#' stopifnot(identical(
#'   marker(x, afreq = c(A = 0.01, B = 0.99)),
#'   marker(x, alleles = c("A", "B"), afreq = c(0.01, 0.99)),
#'   ))
#'
#' # Genotypes can be assigned using different formats
#' marker(x, fa = c(1,2), mo = "1/2")
#'
#' # For homozygous genotypes, three formats are possible
#' marker(x, fa = 1, mo = c(1,1), child = "1/1")
#'
#' # Attaching a marker to the pedigree
#' m = marker(x) # By default a SNP with alleles 1,2
#' x = setMarkers(x, m)
#'
#' # A marker with a "proportional" mutation model,
#' # with different rates for males and females
#' mutrates = list(female = 0.1, male = 0.2)
#' marker(x, alleles = 1:2, mutmod = "prop", rate = mutrates)
#'
#' @export
marker = function(x, ...,  allelematrix = NULL, alleles = NULL, afreq = NULL,
                  chrom = NA, posMb = NA, posCm = NA, name = NA,
                  NAstrings = c(0, "", NA, "-"), mutmod = NULL, rate = NULL,
                  validate = TRUE) {

  # Some parameters cannot have length 0 or be ""
  if(length(chrom) == 0) chrom = NA
  if(length(posMb) == 0) posMb = NA
  if(length(posCm) == 0) posCm = NA
  if(length(name) == 0 || identical(name, "")) name = NA

  pedN = pedsize(x)

  if (is.null(allelematrix)) {
    # Initalize empty allele matrix
    m = matrix(0, ncol = 2, nrow = pedN)

    # Capture genotypes given in dots
    dots = eval(substitute(alist(...)))
    if((ld <- length(dots)) > pedN)
      stop2("Too many genotype assignments")

    # Genotypes (may be empty)
    genos = lapply(dots, eval.parent)

    # Internal ID of each genotype
    # (If no names, take pedigree members in sequence)
    dotnames = names(dots)
    if(is.null(dotnames))
      ids_int = seq_len(ld)
    else
      ids_int = internalID(x, dotnames)

    for(i in seq_len(ld)) {
      g = genos[[i]]
      lg = length(g)

      if(!is.vector(g) || !lg %in% 1:2)
        stop2("Genotype must be a vector of length 1 or 2: ", deparse(g))

      # Split compound genotypes, e.g., "a/b"
      if(lg == 1 && is.character(g))
        g = strsplit(g, "/")[[1]]

      # Insert in `m`
      m[ids_int[i], ] = g
    }
  }
  else {
    m = allelematrix
  }

  # If alleles are NULL, take from afreq names, otherwise from supplied genos
  if (is.null(alleles)) {
    if(!is.null(afreq) && !is.null(names(afreq)))
       alleles = names(afreq)
    else {
      alleles = .mysetdiff(m, NAstrings)
      if (length(alleles) == 0)
        alleles = 1:2 # NEW
    }
  }
  else if(!all(m %in% c(NAstrings, alleles))) {
      mtxt = if(is.na(name)) "this marker: " else sprintf("marker `%s`: ", name)
      stop2("Invalid allele for ", mtxt, setdiff(m, c(NAstrings, alleles)))
  }

  ### Frequencies
  if (is.null(afreq)) {
    nall = length(alleles)
    afreq = rep.int(1/nall, nall)
  }
  if (is.null(names(afreq)))
    names(afreq) = alleles

  # Sort alleles and frequencies (numerical sorting if appropriate)
  if (!is.numeric(alleles) && !anyNA(suppressWarnings(as.numeric(alleles))))
    ord = order(as.numeric(alleles))
  else
    ord = order(alleles)

  afreq = afreq[ord]
  alleles = names(afreq)

  ### Mutation model
  if(!is.null(mutmod)) {
    if (!requireNamespace("pedmut", quietly = TRUE))
      stop2("Package `pedmut` must be installed in order to include mutation models")
    mutmod = pedmut::mutationModel(mutmod, alleles = alleles, afreq = afreq, rate = rate)
  }

  ### Create the internal allele matrix
  m_int = match(m, alleles, nomatch = 0)
  dim(m_int) = dim(m)

  ma = newMarker(m_int, alleles = alleles, afreq = unname(afreq),
            name = as.character(name), chrom = as.character(chrom),
            posMb = as.numeric(posMb), posCm = as.numeric(posCm),
            mutmod = mutmod, pedmembers = labels(x), sex = x$SEX)

  if(validate) validateMarker(ma)

  ma
}


newMarker = function(allelematrix_int, alleles, afreq, name = NA_character_,
                     chrom = NA_character_, posMb = NA_real_, posCm = NA_real_,
                     mutmod = NULL, pedmembers, sex) {
  stopifnot2(is.matrix(allelematrix_int),
            ncol(allelematrix_int) == 2,
            is.integer(allelematrix_int),
            is.character(alleles),
            is.numeric(afreq),
            is.character(name),
            is.character(chrom),
            is.numeric(posMb),
            is.numeric(posCm),
            is.null(mutmod) || is.list(mutmod),
            is.character(pedmembers),
            is.integer(sex))

  structure(allelematrix_int, alleles = alleles, afreq = afreq, name = name,
            chrom = chrom, posMb = posMb, posCm = posCm, mutmod = mutmod,
            pedmembers = pedmembers, sex = sex, class = "marker")
}


validateMarker = function(x) {
  attrs = attributes(x)

  ## alleles
  alleles = attrs$alleles
  NA_allele_ = c(0, "", NA)
  if(any(alleles %in% NA_allele_))
    stop2("Invalid entry in `alleles`: ", intersect(alleles, NA_allele_))

  ## afreq
  afreq = attrs$afreq
  if (length(afreq) != length(alleles))
    stop2("Frequency vector doesn't match the number of alleles")
  if (round(sum(afreq), 3) != 1)
    stop2("Allele frequencies do not sum to 1 (after rounding to 3 decimal places): ", afreq)

  # name
  name = attrs$name
  if(length(name) != 1)
    stop2("Length of `name` must be 1: ", name)
  if (isTRUE(suppressWarnings(name == as.integer(name))))
    stop2("Attribute `name` cannot consist entirely of digits: ", name)

  # chrom
  chrom = attrs$chrom
  if(length(chrom) != 1)
    stop2("Length of `chrom` must be 1: ", chrom)

  # pedmembers and sex
  pedmembers = attrs$pedmembers
  if(length(pedmembers) != nrow(x))
    stop2("`pedmembers` attribute must have same length as nrows of the allele matrix")
  sex = attrs$sex
  if(length(sex) != nrow(x))
    stop2("`sex` attribute must have same length as nrows of the allele matrix")

  # mutation model
  mutmod = attrs$mutmod
  if(!is.null(mutmod)) {
    if (!requireNamespace("pedmut", quietly = TRUE))
      stop2("Package `pedmut` is not installed")

    pedmut::validateMutationModel(mutmod)
  }

  x
}

checkMutationMatrix = function(mutmat, alleles, identifier = NULL) {
  prefix = if(!is.null(identifier)) sprintf("%s mutation matrix: ", identifier) else ""
  N = length(alleles)

  if(!is.numeric(mutmat))
    stop2(prefix, "Type must be numeric, not ", typeof(mutmat))

  if (!identical(dm <- dim(mutmat), c(N,N)))
    stop2(prefix,
          sprintf("Dimensions (%d x %d) incompatible with number of alleles (%d)",
                  dm[1], dm[2], N))

  if(!identical(alleles, rownames(mutmat)) ||
     !identical(alleles, colnames(mutmat)))
    stop2(prefix, "Dimnames differ from allele names")

  if (any(round(rowSums(mutmat), 3) != 1))
    stop2(prefix, "Row sums are not 1")
}



