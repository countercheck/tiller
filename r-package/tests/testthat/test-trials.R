library(httptest2)

test_that("get_trials() returns a data frame", {
  with_mock_api({
    con <- bb_connect("https://example.com", "mytoken")
    result <- get_trials(con)
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 2)
    expect_true("trialDbId" %in% names(result))
    expect_true("trialName" %in% names(result))
  })
})

test_that("get_trials() filters by program", {
  with_mock_api({
    con <- bb_connect("https://example.com", "mytoken")
    result <- get_trials(con, program = "AB_Barley")
    expect_s3_class(result, "data.frame")
  })
})
