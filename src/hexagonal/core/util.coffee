precision = 1

module.exports =
  precision: (value) ->
    if value?
      precision = value
    else
      precision

  round: (value) ->
    if precision?
      divider = Math.pow 10, precision
      Math.round(value * divider) / divider
    else
      value
