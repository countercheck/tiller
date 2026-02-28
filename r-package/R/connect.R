#' Create a Breedbase connection
#'
#' @param url Base URL of the Breedbase instance. Defaults to `BB_URL` env var.
#' @param token BrAPI authentication token. Defaults to `BB_TOKEN` env var.
#' @return A `bbr_con` object (list with `url` and `token`).
#' @export
bb_connect <- function(url   = Sys.getenv("BB_URL"),
                       token = Sys.getenv("BB_TOKEN")) {
  if (!nzchar(url)) {
    stop("BB_URL is not set. Add `BB_URL=https://...` to ~/.Renviron.", call. = FALSE)
  }
  if (!nzchar(token)) {
    stop("BB_TOKEN is not set. Add `BB_TOKEN=...` to ~/.Renviron.", call. = FALSE)
  }
  structure(
    list(url = sub("/$", "", url), token = token),
    class = "bbr_con"
  )
}

#' @export
print.bbr_con <- function(x, ...) {
  cat("<bbr_con>\n")
  cat("  URL:", x$url, "\n")
  cat("  Token: [set]\n")
  invisible(x)
}

# Internal: build a base httr2 request authenticated for this connection.
# Not exported — used by get_trials(), get_germplasm(), get_observations().
bbr_request <- function(con, path) {
  stopifnot(inherits(con, "bbr_con"))
  httr2::request(con$url) |>
    httr2::req_url_path_append(path) |>
    httr2::req_headers(Authorization = paste("Bearer", con$token)) |>
    httr2::req_error(is_error = function(resp) httr2::resp_status(resp) >= 400)
}
