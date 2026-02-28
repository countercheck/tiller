library(httptest2)

test_that("get_germplasm() returns a data frame", {
  with_mock_api({
    con    <- bb_connect("https://example.com", "mytoken")
    result <- get_germplasm(con, study_id = "123")
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 3)
    expect_true("germplasmDbId" %in% names(result))
    expect_true("germplasmName" %in% names(result))
  })
})
