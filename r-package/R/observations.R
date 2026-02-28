#' Get observations for a study
#'
#' Returns a tidy data frame with one row per observation unit × trait.
#'
#' @param con A `bbr_con` object from [bb_connect()].
#' @param study_id The `studyDbId` from Breedbase.
#' @param traits Character vector of trait names to return. `NULL` returns all.
#' @return A data frame with columns: `observationUnitDbId`, `germplasmName`,
#'   `plotNumber`, `trait`, `value`.
#' @export
get_observations <- function(con, study_id, traits = NULL) {
  path <- paste0("/brapi/v1/studies/", study_id, "/observationunits")
  req  <- bbr_request(con, path)

  resp <- httr2::req_perform(req)
  data <- httr2::resp_body_json(resp, simplifyVector = FALSE)

  # Unnest: one row per observationUnit × observation
  rows <- lapply(data$result$data, function(unit) {
    lapply(unit$observations, function(obs) {
      list(
        observationUnitDbId      = unit$observationUnitDbId %||% NA_character_,
        germplasmName            = unit$germplasmName        %||% NA_character_,
        plotNumber               = unit$plotNumber           %||% NA_character_,
        trait                    = obs$observationVariableName %||% NA_character_,
        value                    = obs$value                 %||% NA_character_
      )
    })
  })
  rows <- unlist(rows, recursive = FALSE)
  result <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))

  if (!is.null(traits)) {
    result <- result[result$trait %in% traits, , drop = FALSE]
  }

  result
}

# NULL-coalescing helper (base R has no %||%)
`%||%` <- function(x, y) if (!is.null(x)) x else y
