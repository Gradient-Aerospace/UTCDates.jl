# UTCDates.jl

This package implements the `UTCDate` type and allows the calculation of the amount of elapsed time between two UTC dates in SI seconds.

Here's an example of finding the elapsed time between two UTC dates:

```
new_years_eve_morning = UTCDate(2016, 12, 31, 0, 0, 0.)
new_years_day = UTCDate(2017, 1, 1, 0, 0, 0.)
seconds_between_those_dates = new_years_day - new_years_eve_morning
```

This returns 86,401s, and that is the correctly number of SI seconds between those two UTC dates. See below for more about where that extra 1 comes from.

Here's an example of finding the UTC date that happened a certain number of elapsed seconds after a given UTC date:

```
gps_epoch = UTCDate(1980, 1, 6, 0, 0, 0.)
number_of_elapsed_seconds = 1454038350. # I just got this from a GPS receiver.
current_utc_date = gps_epoch + number_of_elapsed_seconds
```

This gives `UTCDate(2026, 2, 2, 3, 32, 12.0)`.

When printing a `UTCDate` (or otherwise converting it to a string), the IS8601 format is used:

```
string(UTCDate(2026, 2, 2, 3, 32, 12.0))
```

gives `"2026-02-02T03:32:12.000Z"`.

The number of digits in the seconds can be controlled using the `iso8601` function directly:

```
iso8601(UTCDate(2026, 2, 2, 3, 32, 12.0); digits = 0)
```

gives `"2026-02-02T03:32:12Z"`.

This package requires the use of a leap second table. That table is only accurate for six months in the future (in the worst case) because future leap seconds are simply not known in advance but rather come from the observations of the changing rotation rate of the earth. The table in this package will be updated when new leap seconds are announced, which is rare (every couple of years on average, but actually none in the last 10 years).

## Why Is This Package Useful?

A UTC date (and time) is not a number; it is a unique and unambiguous description of a moment in time, like 2016-12-31T23:59:60.500Z. That's a perfectly valid UTC date, because the very last minute of December 31st of 2016 had 61s in it. That added second is called a "leap second". We need (or at least, UTC uses) leap seconds because the earth doesn't have a perfectly predictable rotation rate. When it's been going too slow or too fast for a little while, the International Earth Rotation Service decides to add or remove a leap second so that the sun is directly over the Greenwich meridian at the time called 12:00pm, in an averaged sense. So, to determine how many SI seconds are between two UTC dates, you just have to add up how many SI seconds are in each minute between the two dates. The overwhelming majority of those minutes will have 60 SI seconds, but some will have 61s, and it's theoretically possible that some will have 59s (a "negative leap second", which has never actually happened).

It's perhaps odd that civil time systems chose to track UTC and deal with leap seconds. UTC is based on other "universal time" systems like UT1, and those are absolutely useful for scientific applications that care about the orientation of the earth, its position around the sun, the stars, etc. But there's no clear reason that _civil_ time systems need to worry about those things. They might very well have instead chosen to track one of the atomic time standards and ignored the sun altogether. Then, doing calculations of elapsed time between dates given in civil time systems would be a little more straightforward, and certainly more intuitive. The only cost would be that the sun isn't over the Greenwich meridian at exactly the time called "12pm" in Greenwich. Given that all humans live in very coarse time zones, where the sun may be "off" by more than an hour anyway (to say nothing of daylight saving time), it's hard to see how leap seconds matter for civil timekeeping systems. Nonetheless, civil time systems did standardize on UTC, and if you need to calculate the time between two events in that system with errors less than a second, then you need calculations like those provided in this package.

Further, the implementation chosen here retains excellent floating-point accuracy. The internal representations never rely on large floating-point numbers (such as Julian days), with the result being that calculations are generally accurate to within `eps(x)` where `x` is the number of elapsed seconds between two UTC dates.

## Notes

Julia's built-in `DateTime` cannot be used to accurately calculate the elapsed time between two dates. In fact, it is fundamentally unclear how a given UTC date would be represented using Julia's `DateTime`. For this reason, a `UTCDate` cannot, in general, be converted to Julia's `DateTime`. Consider the perfectly valid UTC date 2016-12-31T23:59:60.500Z. This simply cannot be represented by Julia's `DateTime`, which does not allow for a minute with 61s in it.

This package should not be confused with UTCDateTimes.jl, which is about time zones, not elapsed time. It, similarly, cannot be used to accurately calculate the elapsed time between two UTC dates.

UTC is phasing out leap seconds. This has nothinng to do with the rotation of the earth, and nothing was "wrong" with UTC. Rather, so many civil time systems have chosen to track UTC, and subsequently been confused by calculations of elapsed time, that UTC is, itself, choosing to change. However, leap seconds may still be introduced until 2035, and if you need to calculate the elapsed time between two events prior to 2035, then you'll still need to perform that kinds of calculations represented here.

## TODOs

* [ ] Add time zone support when parsing and printing ISO8601 strings.
