#' @param quantiles conditional quantiles of y to calculate and display
#' @param formula formula relating y variables to x variables
#' @param method Quantile regression method to use. Available options are `"rq"` (for
#'    [`quantreg::rq()`]) and `"rqss"` (for [`quantreg::rqss()`]).
#' @inheritParams layer
#' @inheritParams geom_point
#' @section Computed variables:
#' \describe{
#'   \item{quantile}{quantile of distribution}
#' }
#' @export
#' @rdname geom_quantile
stat_quantile <- function(mapping = NULL, data = NULL,
                          geom = "quantile", position = "identity",
                          ...,
                          quantiles = c(0.25, 0.5, 0.75),
                          formula = NULL,
                          method = "rq",
                          method.args = list(),
                          na.rm = FALSE,
                          show.legend = NA,
                          inherit.aes = TRUE) {
  layer(
    data = data,
    mapping = mapping,
    stat = StatQuantile,
    geom = geom,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list2(
      quantiles = quantiles,
      formula = formula,
      method = method,
      method.args = method.args,
      na.rm = na.rm,
      ...
    )
  )
}


#' @rdname ggplot2-ggproto
#' @format NULL
#' @usage NULL
#' @export
StatQuantile <- ggproto("StatQuantile", Stat,
  required_aes = c("x", "y"),

  compute_group = function(data, scales, quantiles = c(0.25, 0.5, 0.75),
                           formula = NULL, xseq = NULL, method = "rq",
                           method.args = list(), lambda = 1, na.rm = FALSE) {
    check_installed("quantreg", reason = "for `stat_quantile()`")

    if (is.null(formula)) {
      if (method == "rqss") {
        formula <- eval(
          substitute(y ~ qss(x, lambda = lambda)),
          list(lambda = lambda)
        )
        # make qss function available in case it is needed;
        # works around limitation in quantreg
        qss <- quantreg::qss
      } else {
        formula <- y ~ x
      }
      message("Smoothing formula not specified. Using: ",
        deparse(formula))
    }

    if (is.null(data$weight)) data$weight <- 1

    if (is.null(xseq)) {
      xmin <- min(data$x, na.rm = TRUE)
      xmax <- max(data$x, na.rm = TRUE)
      xseq <- seq(xmin, xmax, length.out = 100)
    }
    grid <- new_data_frame(list(x = xseq))

    # if method was specified as a character string, replace with
    # the corresponding function
    if (identical(method, "rq")) {
      method <- quantreg::rq
    } else if (identical(method, "rqss")) {
      method <- quantreg::rqss
    } else {
      method <- match.fun(method) # allow users to supply their own methods
    }

    rbind_dfs(lapply(quantiles, quant_pred, data = data, method = method,
      formula = formula, weight = weight, grid = grid, method.args = method.args))
  }
)

quant_pred <- function(quantile, data, method, formula, weight, grid,
                       method.args = method.args) {
  args <- c(list(quote(formula), data = quote(data), tau = quote(quantile),
    weights = quote(weight)), method.args)
  model <- do.call(method, args)

  grid$y <- stats::predict(model, newdata = grid)
  grid$quantile <- quantile
  grid$group <- paste(data$group[1], quantile, sep = "-")

  grid
}
