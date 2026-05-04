# UTCDates.jl

Universal Time, Coordinated (UTC) is a system for describing specific moments of time and the amount of time between them. This packages implements the `UTCDate` type and provides two primary functions:

* Calculate the amount of time (SI seconds) between two `UTCDate`s
* Calculate what `UTCDate` happened a given amount of time after/before another `UTCDate`

## Installation

```julia
using Pkg
Pkg.add("UTCDates")
```

## Example

Here's an example of finding the elapsed time between two UTC dates:

```julia
using UTCDates

new_years_eve_morning = UTCDate(2016, 12, 31, 0, 0, 0.)
new_years_day = UTCDate(2017, 1, 1, 0, 0, 0.)
seconds_between_those_dates = new_years_day - new_years_eve_morning
```

This returns 86,401s, and that is the correct number of SI seconds between those two UTC dates. See below for more about where that extra 1 comes from.

Here's an example of finding the UTC date that happened a certain number of elapsed seconds after a given UTC date:

```julia
using UTCDates

gps_epoch = UTCDate(1980, 1, 6, 0, 0, 0.)
number_of_elapsed_seconds = 1454038350. # I just got this from a GPS receiver.
current_utc_date = gps_epoch + number_of_elapsed_seconds
```

This gives `UTCDate(2026, 2, 2, 3, 32, 12.0)`.

When printing a `UTCDate` (or otherwise converting it to a string), the ISO 8601 format is used:

```julia
using UTCDates

string(UTCDate(2026, 2, 2, 3, 32, 12.0))
```

gives `"2026-02-02T03:32:12.000Z"`.

The number of digits in the seconds can be controlled using the `iso8601` function directly:

```julia
using UTCDates

iso8601(UTCDate(2026, 2, 2, 3, 32, 12.0); digits = 0)
```

gives `"2026-02-02T03:32:12Z"`.

This package requires the use of a leap second table. That table is only accurate for six months in the future (in the worst case) because future leap seconds are simply not known in advance but rather come from the observations of the changing rotation rate of the earth. The packaged table records the date through which it is valid, and this package will be updated when new leap seconds are announced. That is rare: historically every couple of years on average, and none since 2016.

## API

`UTCDate(year, month, day, hour = 0, minute = 0, seconds = 0.; leap_second_table = ...)` constructs a UTC date and validates that the requested minute exists.

`UTCDate(str)` and `parse(UTCDate, str)` parse UTC ISO 8601 strings such as `"2016-12-31T23:59:60Z"`. Time zone offsets are not supported; the string must end in `Z`.

`elapsed(; from, to, leap_second_table = ...)` returns the number of SI seconds from one `UTCDate` to another.

`after(start, seconds; leap_second_table = ...)` returns the `UTCDate` that many SI seconds after `start`.

The `+` and `-` operators call `elapsed` and `after`, respectively, using the packaged leap-second table. If you supply a custom table with `UTCDates.LeapSecondTable` and `UTCDates.LeapSecondEntry`, pass that table explicitly to `UTCDate`, `elapsed`, and `after`.

`iso8601(d; digits = 3)` formats a `UTCDate` as a UTC ISO 8601 string.

## Why Is This Package Useful?

A UTC date (and time) is not a number; it is a unique and unambiguous description of a moment in time, like 2016-12-31T23:59:60.500Z. That's a perfectly valid UTC date, because the very last minute of December 31st of 2016 had 61s in it. That added second is called a "leap second". We need (or at least, UTC uses) leap seconds because the earth doesn't have a perfectly predictable rotation rate. When it's been going too slow or too fast for a little while, the International Earth Rotation Service decides to add or remove a leap second so that the sun is directly over the Greenwich meridian at the time called 12:00pm, in an averaged sense, plus or minus 0.9s. So, to determine how many SI seconds are between two UTC dates, you just have to add up how many SI seconds are in each minute between the two dates. The overwhelming majority of those minutes will have 60 SI seconds, but some will have 61s, and it's theoretically possible that some will have 59s (a "negative leap second", which has never actually happened). This package makes such calculations easy.

Further, the implementation chosen here retains excellent floating-point accuracy. The internal representations never rely on large floating-point numbers (such as Julian days), with the result being that calculations are generally accurate to within `eps(x)` where `x` is the number of elapsed seconds between two UTC dates. That is, the method used here is more expensive than other calculations but has greater accuracy.

## Notes

Julia's built-in `DateTime` cannot be used to accurately calculate the elapsed time between two dates. In fact, it is fundamentally unclear how a given UTC date would be represented using Julia's `DateTime`. For this reason, a `UTCDate` cannot, in general, be converted to Julia's `DateTime`. Consider the perfectly valid UTC date 2016-12-31T23:59:60.500Z. This simply cannot be represented by Julia's `DateTime`, which does not allow for a minute with 61s in it.

This package should not be confused with UTCDateTimes.jl, which is about time zones, not elapsed time. It, similarly, cannot be used to accurately calculate the elapsed time between two UTC dates.

The amount of time that will elapse between any UTC date and some future UTC date is not known beyond about half a year into the future, because the earth's rotation rate will vary in unknown ways. Leap seconds are, to some degree, a quantization of our uncertainty about the earth's rotation rate. As a result, if you call `after(UTCDate(...), 10 * 365 * 24 * 60 * 60)` today and then call exactly the same thing again in 5 years (assuming you have updated this package and hence received the updated leap second table), you may get a different answer. That's just part of UTC.

Why does this package include a hard-coded leap-second table? Why doesn't it automatically pull the newest leap second table from the International Earth Rotation Service (IERS)? In short: repeatability. Running a given release of this package, the user will always get the same answers to the same questions. It would be particularly annoying, for instance, if this were used in a simulation, and you were debugging something that happened in the simulation, and then IERS released a new leap second, and suddenly that leap second were pulled into your code base, changing the results of the simulation and preventing you from debugging what you were just debugging. So, nothing automatically updates data tables used here. They change very infrequently, and this package will have a minor update when there is new data.

UTC is phasing out leap seconds. This has nothing to do with the rotation of the earth, and nothing was "wrong" with UTC. Rather, so many civil time systems have chosen to track UTC, and subsequently so many people have been confused by calculations of elapsed time, that UTC is, itself, choosing to change. However, leap seconds may still be introduced until 2035, and if you need to calculate the elapsed time between two events prior to 2035, then you'll still need to perform the kinds of calculations represented here.
