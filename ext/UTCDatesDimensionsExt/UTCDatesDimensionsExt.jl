module UTCDatesDimensionsExt

import Dimensions
using UTCDates: UTCDate

# This treats each field of the UTCDate as a separate dimension, so a UTCDate is
# 6-dimensional.
Dimensions.dimstyle(::Type{UTCDate}) = Dimensions.StructDimensionStyle()

end
