#' Get germplasm for a study
#'
#' @param con A `bbr_con` object from [bb_connect()].
#' @param study_id The `studyDbId` from Breedbase. In BrAPI terminology a
#'   "study" is a single location-year instance of an experiment — what the
#'   breeder typically calls a "trial".
#' @return A data frame of germplasm entries.
#' @export
get_germplasm <- function(con, study_id) {
  path <- paste0("/brapi/v1/studies/", study_id, "/germplasm")
  req  <- bbr_request(con, path)

  resp <- httr2::req_perform(req)
  data <- httr2::resp_body_json(resp, simplifyVector = TRUE)

  as.data.frame(data$result$data)
}
