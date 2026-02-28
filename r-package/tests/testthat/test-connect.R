test_that("bb_connect() errors with a clear message when BB_URL is empty", {
  withr::with_envvar(c(BB_URL = "", BB_TOKEN = "tok"), {
    expect_error(bb_connect(), "BB_URL is not set")
  })
})

test_that("bb_connect() errors with a clear message when BB_TOKEN is empty", {
  withr::with_envvar(c(BB_URL = "https://example.com", BB_TOKEN = ""), {
    expect_error(bb_connect(), "BB_TOKEN is not set")
  })
})

test_that("bb_connect() returns a bbr_con object with url and token", {
  con <- bb_connect("https://example.com", "mytoken")
  expect_s3_class(con, "bbr_con")
  expect_equal(con$url, "https://example.com")
  expect_equal(con$token, "mytoken")
})

test_that("bb_connect() strips trailing slash from URL", {
  con <- bb_connect("https://example.com/", "mytoken")
  expect_equal(con$url, "https://example.com")
})
