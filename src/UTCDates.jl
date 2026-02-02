module UTCDates

export UTCDate
export elapsed, after
export iso8601
# export utc_date_to_quasi_julian_day
# export LeapSecondEntry, LeapSecondTable

using Printf: format, Format

# Constants
const seconds_in_normal_minute = 60
const seconds_in_normal_day    = 24 * 60 * seconds_in_normal_minute

"""
Stores a leap second (+/- 1) for a given year, month, and day.
"""
struct LeapSecondEntry
    year::Int64
    month::Int64
    day::Int64
    leap::Int64
end

"""
A type to hold a table of leap seconds plus the date (year, month, day) through which the
table is guaranteed to be valid.
"""
@kwdef struct LeapSecondTable
    table::Vector{LeapSecondEntry}
    valid_through::NTuple{3, Int64}
end

# This default table is only valid through the given date. Future leap seconds are not yet
# known.
#
# https://www.nist.gov/pml/time-and-frequency-division/time-realization/leap-seconds
#
const default_leap_second_table = LeapSecondTable(;
    table = LeapSecondEntry[
        LeapSecondEntry(1972, 06, 30, 1),
        LeapSecondEntry(1972, 12, 31, 1),
        LeapSecondEntry(1973, 12, 31, 1),
        LeapSecondEntry(1974, 12, 31, 1),
        LeapSecondEntry(1975, 12, 31, 1),
        LeapSecondEntry(1976, 12, 31, 1),
        LeapSecondEntry(1977, 12, 31, 1),
        LeapSecondEntry(1978, 12, 31, 1),
        LeapSecondEntry(1979, 12, 31, 1),
        LeapSecondEntry(1981, 06, 30, 1),
        LeapSecondEntry(1982, 06, 30, 1),
        LeapSecondEntry(1983, 06, 30, 1),
        LeapSecondEntry(1985, 06, 30, 1),
        LeapSecondEntry(1987, 12, 31, 1),
        LeapSecondEntry(1989, 12, 31, 1),
        LeapSecondEntry(1990, 12, 31, 1),
        LeapSecondEntry(1992, 06, 30, 1),
        LeapSecondEntry(1993, 06, 30, 1),
        LeapSecondEntry(1994, 06, 30, 1),
        LeapSecondEntry(1995, 12, 31, 1),
        LeapSecondEntry(1997, 06, 30, 1),
        LeapSecondEntry(1998, 12, 31, 1),
        LeapSecondEntry(2005, 12, 31, 1),
        LeapSecondEntry(2008, 12, 31, 1),
        LeapSecondEntry(2012, 06, 30, 1),
        LeapSecondEntry(2015, 06, 30, 1),
        LeapSecondEntry(2016, 12, 31, 1),
    ],
    valid_through = (2026, 06, 30),
)

"""
A type for storing UTC date and time, with fields for `year`, `month`, `day`, `hour`,
`minute`, and `second`.
"""
struct UTCDate

    year::Int64
    month::Int64
    day::Int64
    hour::Int64
    minute::Int64
    seconds::Float64

    function UTCDate(
        year::Number = 1970, month::Number = 1, day::Number = 1,
        hour::Number = 0, minute::Number = 0, seconds::Number = 0.;
        leap_second_table = default_leap_second_table,
    )
        @assert year >= 1 "Sorry, these UTCDates only work for years >= 1."
        @assert month >= 1 && month <= 12 "Month $month is out of the expected range of [1, 12]."
        @assert day >= 1 && day <= 31 "Day $day is out of the expected range of [1, 31]."
        @assert hour >= 0 && hour <= 23 "Hour $hour is out of the expected range of [0, 23]."
        @assert minute >= 0 && minute <= 59 "Minute $minute is out of the expected range of [0, 59]."
        @assert seconds >= 0 && seconds < 61 "Seconds $seconds are out of the expected range of [0., 61.)."
        if day > days_in_month(year, month)
            error("Day $day did not exist in month $month of $year.")
        end
        if leap_second_table !== nothing
            if seconds >= seconds_in_minute(year, month, day, hour, minute; leap_second_table)
                error("There were not $seconds seconds in $year-$month-$day.")
            end
        end
        return new(year, month, day, hour, minute, seconds)
    end

    function UTCDate(s::AbstractString)
        return convert(UTCDate, s)
    end

end

"""
Returns the number of whole days in the given month for the given year.
"""
function days_in_month(year, month)
    if month == 2
        if mod(year, 400) == 0 || (mod(year, 4) == 0 && mod(year, 100) != 0)
            return 29 # Leap years
        else
            return 28
        end
    elseif month in (4, 6, 9, 11)
        return 30
    else
        return 31
    end
end

"""
Returns the number of SI seconds in the given minute, given the year, month, day, hour and
minute, plus the (optional) leap second table.
"""
function seconds_in_minute(year, month, day, hour, minute; leap_second_table = default_leap_second_table)
    for lse in leap_second_table.table
        if lse.year == year && lse.month == month && lse.day == day && hour == 23 && minute == 59
            return seconds_in_normal_minute + lse.leap
        end
    end
    return seconds_in_normal_minute
end

"""
Returns the number of SI seconds elapsed since the beginning of the day for the given UTC
date.
"""
function seconds_since_midnight(d::UTCDate)
    return d.hour * 60 * 60 + d.minute * 60 + d.seconds
end

# TODO: Remove this.
"""
Returns the number of SI seconds in the given day, given the year, month, and day plus the
(optional) leap second table.
"""
function seconds_in_day(year, month, day; leap_second_table = default_leap_second_table)
    for lse in leap_second_table.table
        if lse.year == year && lse.month == month && lse.day == day
            return seconds_in_normal_day + lse.leap
        end
    end
    return seconds_in_normal_day
end

# TODO: Redo this much more efficiently.
"""
Returns the fractional number of SI seconds of elapsed time from one UTCDate to another.
The elapsed time to future dates is only known 6 months in advance. Beyond that, the value
returned from this function should be considered a projection.

Note that this is an inefficient implementation. It's intended to be simple to read and
reason about, and it's not intended for applications that require speed.
"""
function elapsed(; from::UTCDate, to::UTCDate, leap_second_table::LeapSecondTable = default_leap_second_table)

    elapsed_time = 0.
    year  = from.year
    month = from.month
    day   = from.day

    # If the "to" is before the "from", do it backwards and return the opposite sign.
    if to < from
        return -elapsed(;
            from = to, to = from, # Intentionally opposite!
            leap_second_table,
        )
    end

    # We can now assume the "to" date is after or equal to the "from" date.

    # TODO: Get the number of days between the two midnights. Get the nominal number of
    # seconds in those days. Add on the number of leap seconds between those two days.

    # Add up all of the days between the two dates until it's the same day.
    while year < to.year || month < to.month || day < to.day

        # We need to add a day.
        elapsed_time += seconds_in_day(year, month, day; leap_second_table)

        # Figure out how the calendar moves forward.
        if day + 1 <= days_in_month(year, month)
            day += 1
        else
            day = 1
            if month + 1 <= 12
                month += 1
            else
                month = 1
                year += 1
            end
        end

    end

    # That takes care of the elapsed time for the days between the dates. Now let's just
    # figure out the time since the start of the day for each date and add the difference.
    elapsed_time += seconds_since_midnight(to) - seconds_since_midnight(from)

    return elapsed_time

end

# TODO: Redo this much more efficiently.
"""
Returns the UTCDate after the given amount of elapsed SI seconds from the given UTCDate.

Note that this is an inefficient implementation. It's intended to be simple to read and
reason about, and it's not intended for applications that require speed.
"""
function after(start::UTCDate, elapsed_time; leap_second_table::LeapSecondTable = default_leap_second_table)

    # Start from the most recent midnight.
    elapsed_time += seconds_since_midnight(start)

    # If it was after the most recent midnight, we'll count up days.
    if elapsed_time >= 0.

        # Advance to the right day, subtracting off the appropriate amount of time as we go.
        year  = start.year
        month = start.month
        day   = start.day
        while true
            todays_seconds = seconds_in_day(year, month, day; leap_second_table)
            if elapsed_time >= todays_seconds
                elapsed_time -= todays_seconds
                if day + 1 > days_in_month(year, month)
                    day = 1
                    if month + 1 > 12
                        month = 1
                        year += 1
                    else
                        month += 1
                    end
                else
                    day += 1
                end
            else
                break
            end
        end

    else

        # Advance to the right day, subtracting off the appropriate amount of time as we go.
        year  = start.year
        month = start.month
        day   = start.day
        while elapsed_time < 0.

            # Go back a day.
            if day > 1
                day -= 1
            else
                if month > 1
                    month -= 1
                else
                    month = 12
                    year -= 1
                end
                day = days_in_month(year, month)
            end

            # Account for that day's seconds.
            todays_seconds = seconds_in_day(year, month, day; leap_second_table)
            elapsed_time += todays_seconds

        end

    end

    # Now we have the time into the current day. Turn that into hours, minutes, and
    # seconds.
    minutes = floor(elapsed_time / 60)
    hours = floor(minutes / 60)
    if hours == 24
        hours = 23
        minutes = 59
    else
        minutes -= hours * 60
    end
    elapsed_time -= (hours * 60 + minutes) * 60
    return UTCDate(year, month, day, hours, minutes, elapsed_time; leap_second_table)

end

"""
Returns true iff the given UTCDates are exactly equal.
"""
function Base.isequal(a::UTCDate, b::UTCDate)
    return (
        a.year    == b.year &&
        a.month   == b.month &&
        a.day     == b.day &&
        a.hour    == b.hour &&
        a.minute  == b.minute &&
        a.seconds == b.seconds
    )
end

"""
Returns true iff the given UTCDates are approximately equal.
"""
function Base.isapprox(a::UTCDate, b::UTCDate; kwargs...)
    return (
        a.year    == b.year &&
        a.month   == b.month &&
        a.day     == b.day &&
        a.hour    == b.hour &&
        a.minute  == b.minute &&
        isapprox(a.seconds, b.seconds; kwargs...)
    )
end

"""
Returns true if the first UTCDate comes before the second.
"""
function Base.:<(earlier::UTCDate, later::UTCDate)
    if earlier.year < later.year
        return true
    elseif earlier.year == later.year
        if earlier.month < later.month
            return true
        elseif earlier.month == later.month
            if earlier.day < later.day
                return true
            elseif earlier.day == later.day
                if seconds_since_midnight(earlier) < seconds_since_midnight(later)
                    return true
                end
            end
        end
    end
    return false
end

"""
Returns the UTCDate `s` seconds after the given UTCDate, `d`, using the built-in leap-second
table.
"""
function Base.:+(d::UTCDate, s::Number)
    return after(d, s)
end

"""
Returns the UTCDate `s` seconds after the given UTCDate, `d`, using the built-in leap-second
table.
"""
function Base.:+(s::Number, d::UTCDate)
    return after(d, s)
end

"""
Returns the elapsed number of seconds from the second UTCDate to the first, using the
built-in leap-second table.
"""
function Base.:-(a::UTCDate, b::UTCDate)
    return elapsed(; from = b, to = a)
end

"""
Returns the UTCDate `s` seconds before the given UTCDate, `d`, using the built-in
leap-second table.
"""
function Base.:-(d::UTCDate, s::Number)
    return after(d, -s)
end

"""
Returns a UTCDate when given a string with ISO8601 format.
"""
function Base.convert(::Type{UTCDate}, s::AbstractString)
    return utc_date_from_string(s)
end

"""
Parses a string in ISO 8601 format as a UTCDate.
"""
function Base.parse(::Type{UTCDate}, s::AbstractString)
    return utc_date_from_string(s)
end

"""
    iso8601(d::UTCDate; digits = 3)

Returns a string representing the date in ISO 8601 format (YYYY-MM-DDThh:mm:ss.sssZ).

If the `digits` keyword argument is provided, it floors the `seconds` to the specified number
of digits after the decimal place.
"""
function iso8601(d::UTCDate; digits = 3)
    seconds = floor(d.seconds; digits)
    @assert digits >= 0 "The number of digits in the fraction of the second cannot be less than 0."
    if digits == 0
        return format(
            Format("%04d-%02d-%02dT%02d:%02d:%02.0fZ"),
            d.year, d.month, d.day, d.hour, d.minute, seconds,
        )
    else
        return format(
            Format("%04d-%02d-%02dT%02d:%02d:%0$(3 + digits).$(digits)fZ"),
            d.year, d.month, d.day, d.hour, d.minute, seconds,
        )
    end
end

"""
    iso8601(io::IO, d::UTCDate; digits = 3)

Prints a string representing the date in ISO 8601 format (YYYY-MM-DDThh:mm:ss.sssZ) to the
given IO.

If the `digits` keyword argument is provided, it floors the `seconds` to the specified number
of digits after the decimal place.
"""
function iso8601(io::IO, d::UTCDate; digits = 3)
    seconds = floor(d.seconds; digits)
    return format(
        io,
        Format("%04d-%02d-%02dT%02d:%02d:%0$(3 + digits).$(digits)fZ"),
        d.year, d.month, d.day, d.hour, d.minute, seconds,
    )
end

function Base.print(io::IO, d::UTCDate)
    return iso8601(io, d)
end

"""
Creates a UTCDate from the given ISO 8601 string (YYYY-MM-DDThh:mm:ss.sssZ). The colons in
the time string are not necessary. The "Z" _is_ necessary, because this module does not have
any logic for time zones, so we need to know that this is the UTC time zone.
"""
function utc_date_from_string(str::AbstractString)
    m = match(r"(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):?(\d\d):?(\d\d\.?\d*)Z", str)
    @assert m !== nothing && length(m.captures) == 6 "$str is not in a format SimpleUTCDates knows how to parse (YYYY-MM-DDThh:mm:ss.sssZ)"
    return UTCDate(
        parse(Int64,   m.captures[1]),
        parse(Int64,   m.captures[2]),
        parse(Int64,   m.captures[3]),
        parse(Int64,   m.captures[4]),
        parse(Int64,   m.captures[5]),
        parse(Float64, m.captures[6]),
    )
end

# """
# Returns the "quasi Julian day" for the given UTCDate.

# UTC dates have no consistent conversion to Julian days. Julian days are ultimately meant to
# be a continuous measure of the rotation of the earth, and the conversion to a Julian day is
# generally given assuming 86,400s in a day (a day implies rotation and the "seconds" here are
# not necessarily SI seconds). There is no consensus about how to handle the leap seconds of a
# UTC date when converting to a Julian day, so it doesn't make sense to speak of a "UTC Julian
# day". In most cases where Julian days are required, a UT1 Julian day is what's actually
# desired, and getting to UT1 from UTC requires a frequently updated data table that includes
# projections for the future. That's way beyond the scope of this package. However, for
# low-precision applications, this function will return a Julian day that's within 1s worth of
# earth rotation of a UT1 Julian day. The convention used here is that the Julian day number
# for a day with a leap second progresses regularly over the course of that day (so the day is
# treated as being 86,401s or 86,399s long).
# """
# function utc_date_to_quasi_julian_day(utc::UTCDate; leap_second_table::LeapSecondTable = default_leap_second_table)

#     # Apparently SOFA does this for the "quasi-JD":
#     # We calculate the Julian day number using the Gregorian calendar.
#     # We calculate the fraction of today according to the length of today.
#     # But this is imprecise, but it's easy.
#     # https://en.wikipedia.org/wiki/Julian_day#Converting_Gregorian_calendar_date_to_Julian_Day_Number
#     y = utc.year
#     m = utc.month
#     d = utc.day
#     jdn = (1461 * (y + 4800 + (m - 14)÷12))÷4 +(367 * (m - 2 - 12 * ((m - 14)÷12)))÷12 - (3 * ((y + 4900 + (m - 14)÷12)÷100))÷4 + d - 32075

#     # Now we add on how far into this day we've come. Also, note that we need to subtract
#     # half a day, because Julian days start at noon but we're measuring the fraction of the
#     # day elapsed since midnight.
#     jd = jdn - 0.5 + seconds_since_midnight(utc) / seconds_in_day(y, m, d; leap_second_table)

#     return jd

# end

end # module UTCDates
