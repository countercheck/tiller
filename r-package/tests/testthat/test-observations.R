library(httptest2)

test_that("get_observations() returns a data frame", {
  with_mock_api({
    con    <- bb_connect("https://example.com", "mytoken")
    result <- get_observations(con, study_id = "123")
    expect_s3_class(result, "data.frame")
    expect_true("germplasmName" %in% names(result))
    expect_true("trait" %in% names(result))
    expect_true("value" %in% names(result))
  })
})

test_that("get_observations() filters by trait name", {
  with_mock_api({
    con    <- bb_connect("https://example.com", "mytoken")
    result <- get_observations(con, study_id = "123", traits = "Yield")
    expect_equal(unique(result$trait), "Yield")
  })
})

test_that("get_observations() returns all traits when traits=NULL", {
  with_mock_api({
    con    <- bb_connect("https://example.com", "mytoken")
    result <- get_observations(con, study_id = "123")
    expect_true(all(c("Yield", "Height") %in% unique(result$trait)))
  })
})
