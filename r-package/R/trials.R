#' Get trials from Breedbase
#'
#' @param con A `bbr_con` object from [bb_connect()].
#' @param program Filter by program name (optional).
#' @param year Filter by year as integer (optional). Maps to `seasonDbId`.
#' @return A data frame of trials.
#' @export
get_trials <- function(con, program = NULL, year = NULL) {
  req <- bbr_request(con, "/brapi/v1/trials")

  if (!is.null(program)) {
    req <- httr2::req_url_query(req, programName = program)
  }
  if (!is.null(year)) {
    req <- httr2::req_url_query(req, seasonDbId = as.character(year))
  }

  resp <- httr2::req_perform(req)
  data <- httr2::resp_body_json(resp, simplifyVector = TRUE)

  as.data.frame(data$result$data)
}
