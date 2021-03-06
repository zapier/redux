context("hiredis")

test_that("connection", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)
  ## Dangerous raw pointer:
  expect_that(ptr, is_a("externalptr"))
  ## Check for no crash:
  rm(ptr)
  gc()
})

test_that("simple commands", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)

  ans <- redis_command(ptr, list("PING"))
  expect_that(ans, is_a("redis_status"))
  expect_that(print(ans), prints_text("[Redis: PONG]", fixed=TRUE))
  expect_that(as.character(ans), is_identical_to("PONG"))

  expect_that(redis_command(ptr, "PING"),
              is_identical_to(ans))
  expect_that(redis_command(ptr, list("PING", character(0))),
              is_identical_to(ans))

  ## Various invalid commands; some of these need more consistent
  ## errors I think.  Importantly though, none crash.
  expect_that(redis_command(ptr, NULL),
              throws_error("Invalid type"))
  expect_that(redis_command(ptr, 1L),
              throws_error("Invalid type"))
  expect_that(redis_command(ptr, list()),
              throws_error("argument list cannot be empty"))
  expect_that(redis_command(ptr, list(1L)),
              throws_error("Redis command must be a non-empty character"))
  expect_that(redis_command(ptr, character(0)),
              throws_error("Redis command must be a non-empty character"))
  expect_that(redis_command(ptr, list(character(0))),
              throws_error("Redis command must be a non-empty character"))
})

test_that("commands with arguments", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)

  expect_that(redis_command(ptr, list("SET", "foo", "1")), is_OK())
  expect_that(redis_command(ptr, list("SET", "foo", "1")), is_OK())

  expect_that(redis_command(ptr, list("GET", "foo")), equals("1"))
})

test_that("commands with NULL arguments", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)

  expect_that(redis_command(ptr, list("SET", "foo", "1", NULL)), is_OK())
  expect_that(redis_command(ptr, list("SET", "foo", NULL, "1", NULL)),
              is_OK())
  expect_that(redis_command(ptr, list("SET", NULL, "foo", NULL, "1", NULL)),
              is_OK())
})

test_that("missing values are NULL", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)
  key <- rand_str(prefix="redux_")
  expect_that(redis_command(ptr, list("GET", key)),
              is_null())
})

test_that("Errors are converted", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)
  key <- rand_str(prefix="redux_")
  on.exit(redis_command(ptr, c("DEL", key)))
  ## Conversion to integer:
  expect_that(redis_command(ptr, c("LPUSH", key, "a", "b", "c")),
              is_identical_to(3L))
  expect_that(redis_command(ptr, c("HGET", key, 1)),
              throws_error("WRONGTYPE"))
})

## Warning; this pipeline approach is liable to change because we'll
## need to do it slightly differently perhaps.  The main api approach
## would be a *general* codeblock that added commands to a buffer and
## then executed them.  To get that to work we'll need support a
## growing list or pushing them directly into Redis' buffer and
## keeping them protected appropriately.  So for now the automatically
## balanced approach is easiest.
test_that("Pipelining", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)
  key <- rand_str(prefix="redux_")
  cmd <- list(list("SET", key, "1"), list("GET", key))
  on.exit(redis_command(ptr, c("DEL", key)))

  x <- redis_pipeline(ptr, cmd)
  expect_that(length(x), equals(2))
  expect_that(x[[1]], is_OK())
  expect_that(x[[2]], equals("1"))

  ## A pipeline with an error:
  cmd <- list(c("HGET", key, "a"), c("INCR", key))
  y <- redis_pipeline(ptr, cmd)
  expect_that(length(x), equals(2))
  expect_that(y[[1]], is_a("redis_error"))
  expect_that(y[[1]], matches("^WRONGTYPE"))
  ## This still ran:
  expect_that(y[[2]], is_identical_to(2L))
})

## Storing binary data:
test_that("Binary data", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)
  data <- serialize(1:5, NULL)
  key <- rand_str(prefix="redux_")
  expect_that(redis_command(ptr, list("SET", key, data)),
              is_OK())
  x <- redis_command(ptr, list("GET", key))
  expect_that(x, is_a("raw"))
  expect_that(x, equals(data))

  key2 <- rand_str(prefix="redux_")
  ok <- redis_command(ptr, list("MSET", key, "1", key2, data))
  expect_that(ok, is_OK())

  res <- redis_command(ptr, list("MGET", key, key2))
  expect_that(res, equals(list("1", data)))

  expect_that(redis_command(ptr, c("DEL", key, key2)), equals(2L))
})

test_that("Lists of binary data", {
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)
  data <- serialize(1:5, NULL)
  key1 <- rand_str(prefix="redux_")
  key2 <- rand_str(prefix="redux_")
  cmd <- list("MSET", list(key1, data, key2, data))

  ok <- redis_command(ptr, list("MSET", list(key1, data, key2, data)))
  expect_that(ok, is_OK())
  res <- redis_command(ptr, list("MGET", key1, key2))
  expect_that(res, equals(list(data, data)))

  ## But throw an error on a list of lists of lists:
  expect_that(
    redis_command(ptr, list("MSET", list(key1, data, key2, list(data)))),
    throws_error("Nested list element"))
  expect_that(
    redis_command(ptr, list("MSET", list(list(key1), data, key2, data))),
    throws_error("Nested list element"))
})

test_that("pointer commands are safe", {
  expect_that(redis_command(NULL, "PING"),
              throws_error("Expected an external pointer"))
  expect_that(redis_command(list(), "PING"),
              throws_error("Expected an external pointer"))
  ptr <- redis_connect_tcp("127.0.0.1", 6379L)
  expect_that(redis_command(list(ptr), "PING"),
              throws_error("Expected an external pointer"))

  expect_that(redis_command(ptr, "PING"),
              equals(redis_status("PONG")))

  ptr_null <- unserialize(serialize(ptr, NULL))
  expect_that(redis_command(ptr_null, "PING"),
              throws_error("Context is not connected"))
})
