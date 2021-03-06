% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/marker_utils.R
\name{nMarkers}
\alias{nMarkers}
\alias{hasMarkers}
\title{The number of markers attached to a pedigree}
\usage{
nMarkers(x)

hasMarkers(x)
}
\arguments{
\item{x}{A \code{ped} object or a list of such (se Value).}
}
\value{
The function \code{nMarkers} returns the number of marker objects attached
to \code{x}. If \code{x} is a list of pedigrees, an error is raised unless all of
them have the same number of markers.

The function \code{hasMarkers} returns TRUE if \code{nMarkers(x) > 0}.
}
\description{
The number of markers attached to a pedigree
}
