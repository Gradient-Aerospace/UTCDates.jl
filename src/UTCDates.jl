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
# TODO: We could construct the intervals between these epochs upon construction fo the
# table. This would make the `after` function faster.

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

"""
Returns true if the given year is a leap year.
"""
function is_leap_year(year)
    return mod(year, 400) == 0 || (mod(year, 4) == 0 && mod(year, 100) != 0)
end

"""
Returns the number of days (revolutions) in the given year.
"""
function days_in_year(year)
    return is_leap_year(year) ? 366 : 365
end

"""
Returns the fractional number of SI seconds of elapsed time from one UTCDate to another.
The elapsed time to future dates is only known 6 months in advance. Beyond that, the value
returned from this function should be considered a projection.
"""
function elapsed(; from::UTCDate, to::UTCDate, leap_second_table::LeapSecondTable = default_leap_second_table)

    # If the "to" is before the "from", do it backwards and return the opposite sign.
    if to < from
        return -elapsed(;
            from = to, to = from, # Intentionally opposite!
            leap_second_table,
        )
    end

    # We can now assume the "to" date is after or equal to the "from" date.

    # There are alternatives to the below implementation, such as by finding the Julian
    # day of 00:00 of each date, adding on leap seconds, etc. However, that's much harder
    # to read, loses a lot of precision compared to the below, and isn't actually much
    # faster. We stick with this plain implementation of mostly integer math.

    # Get the number of days between the two midnights.
    whole_days = 0
    if from.year < to.year # If we count all the way to the year's end...

        # Count up the days in the whole years between the two.
        for year in from.year + 1 : to.year - 1
            whole_days += days_in_year(year)
        end

        # Count up days for the months leading up to the end of the year.
        for month in from.month + 1 : 12
            whole_days += days_in_month(from.year, month)
        end

        # Count up days from the beginning of the year to the given month.
        for month in 1 : to.month - 1
            whole_days += days_in_month(to.year, month)
        end

        # Count days from 00:00 of "from" to the end of the month.
        whole_days += (days_in_month(from.year, from.month) - from.day + 1)

        # Count days from beginning of "to" month to 00:00 of to.day.
        whole_days += to.day - 1

    else # Otherwise, they're the same year.

        if from.month < to.month # If we count to the month's end...

            # Count up days for the whole months between the two.
            for month in from.month + 1 : to.month - 1
                whole_days += days_in_month(from.year, month)
            end

            # Count to the end of the "from" month.
            whole_days += days_in_month(from.year, from.month) - from.day + 1

            # Count from the beginning of the "to" month.
            whole_days += to.day - 1

        else # Same month

            whole_days = to.day - from.day

        end

    end

    # Get the number of leap seconds between those two dates. We'll start from the beginning
    # of the table and search until the entry is beyond the "to" date.
    leap_seconds = 0
    for entry in leap_second_table.table

        # If this entry comes after the "to" date, break out. Note the final ">="; we're
        # counting to 00:00 of the "to" date, and leap seconds come at the end of the day.
        if (
            entry.year > to.year ||
            (entry.year == to.year && entry.month > to.month) ||
            (entry.year == to.year && entry.month == to.month && entry.day >= to.day)
        )
            break
        end

        # We know the entry is before the "to" date. If it's after 00:00 of the "from" date,
        # then we count it.
        if (
            entry.year > from.year ||
            (entry.year == from.year && entry.month > from.month) ||
            (entry.year == from.year && entry.month == from.month && entry.day >= from.day)
        )
            leap_seconds += entry.leap
        end

    end

    # The elapsed time is the nominal number of seconds in a day times the number of whole
    # days between 00:00 on each date, plus the leap seconds that have been added, plus how
    # far the "to" date is into its day, minus the leap seconds that came before the time
    # of day for "from" (because we've account for time since midnight).
    return (
        (whole_days * seconds_in_normal_day + leap_seconds) # Integers
        - seconds_since_midnight(from)
        + seconds_since_midnight(to)
    )

end

function seconds_to_hms(seconds)
    minutes = floor(seconds / 60)
    hours = floor(minutes / 60)
    if hours == 24
        hours = 23
        minutes = 59
    else
        minutes -= hours * 60
    end
    seconds -= (hours * 60 + minutes) * 60 # 60.9 is a perfectly valid value here.
    return (hours, minutes, seconds)
end

struct YMD
    year::Int64
    month::Int64
    day::Int64
end
function Base.:<(a::YMD, b::YMD)
    if a.year < b.year
        return true
    elseif a.year > b.year
        return false
    end
    # So the years are the same.
    if a.month < b.month
        return true
    elseif a.month > b.month
        return false
    end
    # So the months are the same.
    return a.day < b.day
end

"""
Returns the UTCDate after the given amount of time (SI seconds) from the given UTCDate.
"""
function after(start::UTCDate, elapsed_time; leap_second_table::LeapSecondTable = default_leap_second_table)

    # First, move the start to the beginning of the day.
    elapsed_time += seconds_since_midnight(start)
    year = start.year
    month = start.month
    day = start.day

    if iszero(elapsed_time)

        return UTCDate(year, month, day, 0, 0, 0.)

    elseif elapsed_time > 0

        # Calculate the interval from year, month, day to the next leap second. If we're going
        # further, accept the date of the leap second, subtract the interval from elapsed_time,
        # and loop. We'll complete this until we aren't going further than the next leap second
        # (or there is no next leap second).
        for entry in leap_second_table.table

            # If the entry is in the future...
            if YMD(entry.year, entry.month, entry.day) >= YMD(year, month, day)

                # See how long it is until that day.
                # TODO: We know there are no leap seconds, so we could use a more efficient calculation here.
                time_until_day_of_next_leap = (
                    UTCDate(entry.year, entry.month, entry.day) - UTCDate(year, month, day)
                )

                # If we're going past that, then update the day to that day.
                if time_until_day_of_next_leap < elapsed_time

                    # This puts us at the beginning of the day with the leap second.
                    year = entry.year
                    month = entry.month
                    day = entry.day
                    elapsed_time -= time_until_day_of_next_leap

                    # Are we going past the leap second?
                    length_of_day = seconds_in_normal_day + entry.leap
                    if length_of_day <= elapsed_time

                        day = 1 # Leap seconds occur at the end of the month.
                        month += 1
                        if month == 13
                            year += 1
                            month = 1
                        end
                        elapsed_time -= length_of_day

                    else

                        # If not going past the leap second, then we already have the
                        # solution.
                        return UTCDate(year, month, day, seconds_to_hms(elapsed_time)...)

                    end

                else

                    break

                end

            end

        end

    else # elapsed_time < 0

        # Our strategy here is to find a date that's definitely before the date we seek and
        # then use the forward logic. We'll start at the most recent leap second and keep
        # moving backwards to find a leap second that's farther back in time from what we're
        # seeking.
        for entry in reverse(leap_second_table.table)

            # If the leap second is before the year, month, and day...
            if YMD(entry.year, entry.month, entry.day) < YMD(year, month, day)

                # See how far back the beginning of that day is.
                time_since_this_leap_second = (
                    UTCDate(year, month, day) - UTCDate(entry.year, entry.month, entry.day)
                )

                # Accept that date.
                year = entry.year
                month = entry.month
                day = entry.day
                elapsed_time += time_since_this_leap_second

                # When we've backed up enough, break out of this loop and rely on the
                # "forward" logic.
                if elapsed_time > 0

                    # Ok, now we're going forward.

                    # Are we going past the leap second?
                    length_of_day = seconds_in_normal_day + entry.leap
                    if length_of_day <= elapsed_time

                        day = 1 # Leap seconds occur at the end of the month.
                        month += 1
                        if month == 13
                            year += 1
                            month = 1
                        end
                        elapsed_time -= length_of_day

                    else

                        # If not going past the leap second, then we already have the
                        # solution.
                        return UTCDate(year, month, day, seconds_to_hms(elapsed_time)...)

                    end

                    break

                end

            end

        end

        if elapsed_time < 0

            # If we got here, it means there are no more leap seconds before year, month,
            # day. So, let's just go to the beginning of time (as far as this package is
            # concerned).
            time_since_1 = UTCDate(year, month, day) - UTCDate(1, 1, 1)
            elapsed_time += time_since_1
            year = 1
            month = 1
            day = 1

            if elapsed_time < 0
                error("UTCDates does not have logic to deal with years prior to year 1.")
            end

        end

    end

    # There are no more leap seconds in the elapsed_time interval following the beginning of
    # (year, month day). We can use simpler logic to find the updated date. We just need the
    # number of whole days, where all days are the same length.
    whole_days = floor(elapsed_time / seconds_in_normal_day)
    time_of_day = mod(elapsed_time, seconds_in_normal_day)

    # What year, month, and day is the given number of days in the future?

    # While the goal remains more than a year in the future...
    while true
        if month <= 2 # In or before Feb., add *this* year's number of days to get the same day next year.
            d = days_in_year(year)
            if d <= whole_days
                whole_days -= d
                year += 1
                if month == 2 && day == 29
                    month = 3
                    day = 1
                else # Otherwise, the month and day are unchanged.
                end
            else
                break
            end
        else # After Feb., use *next* year's number of days to get to the date next year.
            d = days_in_year(year+1)
            if d <= whole_days
                whole_days -= d
                year += 1 # Month and day stay the same.
            else
                break
            end
        end
    end

    # We now have less than a year to go. Check each month.
    while true

        # See if we move past the end of this month.
        days_remaining_in_month = days_in_month(year, month) - day + 1
        if days_remaining_in_month <= whole_days

            # If so, discount the remaining days, and move the beginning of next month.
            whole_days -= days_remaining_in_month
            day = 1
            month += 1
            if month == 13
                month = 1
                year += 1
            end

        else

            # Otherwise, we have the year and month, so the day of the month is just our
            # current day plus whatever's left.
            day += whole_days
            break

        end

    end

    return UTCDate(year, month, day, seconds_to_hms(time_of_day)...)

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
Returns true iff the given UTCDates are approximately equal by comparing the amount of time
between them to 0.
"""
function Base.isapprox(a::UTCDate, b::UTCDate; kwargs...)
    return isapprox(abs(a - b), 0.; kwargs...)
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

# # Remove this if we remove the JD stuff.
# """
# Returns the number of SI seconds in the given day, given the year, month, and day plus the
# (optional) leap second table.
# """
# function seconds_in_day(year, month, day; leap_second_table = default_leap_second_table)
#     for lse in leap_second_table.table
#         if lse.year == year && lse.month == month && lse.day == day
#             return seconds_in_normal_day + lse.leap
#         end
#     end
#     return seconds_in_normal_day
# end

end # module UTCDates
