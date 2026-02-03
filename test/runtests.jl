using Test
using UTCDates
import Dates

const unix_epoch = UTCDate(1970, 01, 01, 0, 0, 0)
const gps_epoch  = UTCDate(1980, 01, 06, 0, 0, 0)

# TODO: Test for type stability and allocations.

@testset "known times between dates" begin

    gps_wrt_unix = elapsed(; from = unix_epoch, to = gps_epoch)

    # This should come to 10 years (365 days each) plus 2 leap days plus 5 more days to get
    # to the sixth, plus 9 seconds because there were 9 positive leaps seconds between those
    # UTC dates.
    expected_gps_wrt_unix = (10 * 365 + 2 + 5) * 24 * 60 * 60 + 9
    @test gps_wrt_unix == expected_gps_wrt_unix
    @test gps_epoch - unix_epoch == expected_gps_wrt_unix

    # Let's make sure we can rebuild the GPS epoch from the unix epoch.
    @test after(unix_epoch, gps_wrt_unix) == gps_epoch

    # Let's make sure the opposite direction works.
    unix_wrt_gps = elapsed(; from = gps_epoch, to = unix_epoch)
    @test unix_wrt_gps == -expected_gps_wrt_unix
    @test unix_epoch - gps_epoch == -expected_gps_wrt_unix

    @test after(gps_epoch, unix_wrt_gps) == unix_epoch
    @test gps_epoch + unix_wrt_gps == unix_epoch
    @test unix_wrt_gps + gps_epoch == unix_epoch

end

@testset "after different intervals" begin

    # This is to make sure we hit all of the branches of after for both positive and
    # negative elapsed intervals.

    d = UTCDate(1981, 06, 30, 12, 0, 0.)

    @test after(d, 1.25) == UTCDate(1981, 06, 30, 12, 0, 1.25)
    @test after(d, 60.25) == UTCDate(1981, 06, 30, 12, 1, 0.25)
    @test after(d, 600.25) == UTCDate(1981, 06, 30, 12, 10, 0.25)
    @test after(d, 3600.25) == UTCDate(1981, 06, 30, 13, 0, 0.25)
    @test after(d, 12*60*60 + 0.25) == UTCDate(1981, 06, 30, 23, 59, 60.25) # Leap second!
    @test after(d, 24*60*60 + 0.25) == UTCDate(1981, 07, 1, 11, 59, 59.25)
    @test after(d, 24*60*60 + 1.25) == UTCDate(1981, 07, 1, 12, 0, 0.25)
    @test after(d, 365*24*60*60 + 1.25) == UTCDate(1982, 06, 30, 12, 0, 0.25)
    @test after(d, (5*365+1)*24*60*60 + 4.25) == UTCDate(1986, 06, 30, 12, 0, 0.25) # Leap day and 4 leap seconds

    @test after(UTCDate(1981, 06, 30, 12, 0, 1.25), -1.25) == d
    @test after(UTCDate(1981, 06, 30, 12, 1, 0.25), -60.25) == d
    @test after(UTCDate(1981, 06, 30, 12, 10, 0.25), -600.25) == d
    @test after(UTCDate(1981, 06, 30, 13, 0, 0.25), -3600.25) == d
    @test after(UTCDate(1981, 06, 30, 23, 59, 60.25), -(12*60*60 + 0.25)) == d # Leap second!
    @test after(UTCDate(1981, 07, 1, 11, 59, 59.25), -(24*60*60 + 0.25)) == d
    @test after(UTCDate(1981, 07, 1, 12, 0, 0.25), -(24*60*60 + 1.25)) == d
    @test after(UTCDate(1982, 06, 30, 12, 0, 0.25), -(365*24*60*60 + 1.25)) == d
    @test after(UTCDate(1986, 06, 30, 12, 0, 0.25), -((5*365+1)*24*60*60 + 4.25)) == d # Leap day and 4 leap seconds

end

@testset "stepping to edges of leap seconds" begin

    d = UTCDate(2016, 12, 31, 23, 59, 0.)

    # Step to the beginning of a leap second.
    dt = 60.
    @test after(d, dt) == UTCDate(2016, 12, 31, 23, 59, 60.)
    @test after(d, dt) - d == dt

    # Step to the middle of a leap second.
    dt = 60.5
    @test after(d, dt) == UTCDate(2016, 12, 31, 23, 59, 60.5)
    @test after(d, dt) - d == dt

    # Step to the end of a leap second.
    dt = 61.
    @test after(d, dt) == UTCDate(2017, 1, 1, 0, 0, 0.)
    @test after(d, dt) - d == dt

end

@testset "type stability" begin

    d1 = UTCDate(2016, 12, 31, 23, 59, 0.)
    d2 = UTCDate(2017, 12, 31, 23, 59, 0.)

    # Step to the beginning of a leap second.
    @inferred after(d1, 600.)
    @inferred after(d1, -600)
    @inferred elapsed(; to = d2, from = d1)

end

@testset "comparison operators" begin
    @test unix_epoch <  gps_epoch
    @test unix_epoch <= gps_epoch
    @test gps_epoch  <= gps_epoch
    @test gps_epoch  >  unix_epoch
    @test gps_epoch  >= unix_epoch
    @test gps_epoch  >= gps_epoch
    @test gps_epoch  == gps_epoch
    @test gps_epoch  != unix_epoch
    gps_epoch_plus_eps = gps_epoch + eps(61.)
    @test gps_epoch !=  gps_epoch_plus_eps
    @test gps_epoch !== gps_epoch_plus_eps
    @test gps_epoch ≈   gps_epoch_plus_eps atol = eps(61.)
    @test !isapprox(gps_epoch, gps_epoch + 2 * eps(61.); atol = eps(61.))
end

@testset "add or remove seconds" begin
    @test iso8601(gps_epoch + 1)  == "1980-01-06T00:00:01.000Z"
    @test iso8601(1  + gps_epoch) == "1980-01-06T00:00:01.000Z"
    @test iso8601(1. + gps_epoch) == "1980-01-06T00:00:01.000Z"
    @test iso8601(gps_epoch - 1)  == "1980-01-05T23:59:59.000Z"
    @test iso8601(gps_epoch - 1.) == "1980-01-05T23:59:59.000Z"
end

@testset "the missing leap seconds" begin

    julia_timestamp = Dates.now()
    unix_timestamp = Dates.datetime2unix(julia_timestamp)
    now_wrt_unix = elapsed(;
        from = unix_epoch,
        to = UTCDate(
            Dates.yearmonthday(julia_timestamp)...,
            Dates.hour(julia_timestamp),
            Dates.minute(julia_timestamp),
            Dates.second(julia_timestamp) + Dates.millisecond(julia_timestamp)/1000,
        ),
    )
    @test now_wrt_unix - unix_timestamp == 27

end

@testset "leap seconds" begin

    @test elapsed(;
        from = UTCDate(2016, 12, 31, 23, 59, 60.7),
        to   = UTCDate(2017, 01, 01, 0, 0, 1.),
    ) ≈ 1.3

    @test elapsed(;
        from = UTCDate(2017, 01, 01, 0, 0, 1.),
        to   = UTCDate(2016, 12, 31, 23, 59, 60.7),
    ) ≈ -1.3

    @test elapsed(;
        from = UTCDate(2016, 12, 31, 23, 58, 0),
        to   = UTCDate(2016, 12, 31, 23, 59, 60.7),
    ) ≈ 120.7

end

@testset "ISO 8601" begin

    @test iso8601(gps_epoch) == "1980-01-06T00:00:00.000Z"

    offset = 1 * 60 * 60 + 2 * 60 + 34.567
    @test string(after(gps_epoch, offset)) == "1980-01-06T01:02:34.567Z"

    offset = -1
    @test string(after(gps_epoch, offset)) == "1980-01-05T23:59:59.000Z"

    @test UTCDate("1970-01-01T00:00:00.000Z") == unix_epoch
    @test UTCDate("1980-01-06T00:00:00.000Z") == gps_epoch
    @test UTCDate("2024-07-22T21:46:00Z")     == UTCDate(2024, 7, 22, 21, 46, 0.)
    @test UTCDate("2024-07-22T21:46:00.0Z")   == UTCDate(2024, 7, 22, 21, 46, 0.)
    @test UTCDate("2024-07-22T21:46:00.00Z")  == UTCDate(2024, 7, 22, 21, 46, 0.)
    @test UTCDate("2024-07-22T21:46:00.000Z") == UTCDate(2024, 7, 22, 21, 46, 0.)
    @test UTCDate("2024-07-22T214600Z")       == UTCDate(2024, 7, 22, 21, 46, 0.)
    @test UTCDate("2024-07-22T21:46:00.001Z") == UTCDate(2024, 7, 22, 21, 46, 0.001)
    @test UTCDate("2024-07-22T214600.001Z")   == UTCDate(2024, 7, 22, 21, 46, 0.001)

    @test iso8601(UTCDate(2016, 12, 31, 23, 59, 59.123456789123)) == "2016-12-31T23:59:59.123Z"
    @test iso8601(UTCDate(2016, 12, 31, 23, 59, 59.1239)) == "2016-12-31T23:59:59.123Z" # Truncates (doesn't round)
    @test iso8601(UTCDate(2016, 12, 31, 23, 59, 59.123456789123); digits = 9) == "2016-12-31T23:59:59.123456789Z"
    @test iso8601(UTCDate(2016, 12, 31, 23, 59, 0); digits = 9) == "2016-12-31T23:59:00.000000000Z"
    @test iso8601(UTCDate(2016, 12, 31, 23, 59, 59.123456789123); digits = 0) == "2016-12-31T23:59:59Z"

end

# @testset "quasi-Julian days" begin

#     # We compare these against known Julia days from textbooks and online calculators.
#     @test utc_date_to_quasi_julian_day(UTCDate(2000, 1, 1, 18, 00, 00)) ≈ 2.45154525e6
#     @test utc_date_to_quasi_julian_day(UTCDate(2000, 1, 1, 6, 00, 00)) ≈ 2.45154475e6
#     @test utc_date_to_quasi_julian_day(UTCDate(2017, 01, 01, 00, 00, 0.)) ≈ 2.4577545e6
#     @test utc_date_to_quasi_julian_day(UTCDate(2016, 12, 31, 23, 59, 60.999999)) ≈ 2.4577545e6
#     @test utc_date_to_quasi_julian_day(UTCDate(2016, 12, 31, 23, 59, 60.)) ≈ 2.457754499988426e6
#     @test utc_date_to_quasi_julian_day(UTCDate(2017, 01, 01, 00, 00, 0.)) - 1/86401 ≈ 2.457754499988426e6
#     @test utc_date_to_quasi_julian_day(UTCDate(2016, 12, 31, 00, 00, 0.)) ≈ 2.4577535e6

# end

@testset "custom leap-second table" begin

    # If there had been no leap seconds between the Unix and GPS epochs... (kind of what
    # Unix timestamps pretend is the case).
    leap_second_table = UTCDates.LeapSecondTable(;
        table = UTCDates.LeapSecondEntry[],
        valid_through = (2024, 12, 31),
    )
    gps_wrt_unix = elapsed(;
        from = unix_epoch,
        to   = gps_epoch,
        leap_second_table,
    )
    expected_gps_wrt_unix_without_leap_seconds = (10 * 365 + 2 + 5) * 24 * 60 * 60
    @test gps_wrt_unix == expected_gps_wrt_unix_without_leap_seconds

    # Now let's try a table with totally made-up leap seconds, including a negative one,
    # since that's otherwise untested in the default table.
    leap_second_table = UTCDates.LeapSecondTable(;
        table = UTCDates.LeapSecondEntry[
            UTCDates.LeapSecondEntry(2024, 07, 31,  1),
            UTCDates.LeapSecondEntry(2024, 12, 31, -1),
        ],
        valid_through = (2024, 12, 31),
    )

    # Positive leap-second worked.
    elapsed(;
        from = UTCDate(2024, 07, 31, 00, 00, 0.; leap_second_table),
        to   = UTCDate(2024, 08, 01, 00, 00, 0.; leap_second_table),
    ) == 86401

    # Negative leap-second worked.
    elapsed(;
        from = UTCDate(2024, 12, 31, 00, 00, 0.; leap_second_table),
        to   = UTCDate(2025, 01, 01, 00, 00, 0.; leap_second_table),
    ) == 86399

    # Where it's irrelevant, things are normal.
    elapsed(;
        from = UTCDate(1972, 12, 31, 00, 00, 0.; leap_second_table),
        to   = UTCDate(1973, 01, 01, 00, 00, 0.; leap_second_table),
    ) == 86400

end

@testset "fake dates" begin

    # These things never exist.
    @test_throws "Month 13 is out of" UTCDate(2023, 13, 01)
    @test_throws "Hour 24 is out of" UTCDate(1989, 12, 31, 24)
    @test_throws "Minute 60 is out of" UTCDate(1989, 12, 31, 23, 60)
    @test_throws "Seconds 61 are out of" UTCDate(1989, 12, 31, 23, 59, 61)

    # Test leap years.
    @test_throws "Day 29 did not exist in" UTCDate(2023, 02, 29)
    @test UTCDate(2024, 02, 29) !== nothing

    # Test leap seconds.
    @test UTCDate(1989, 12, 31, 23, 59, 60.9) !== nothing
    @test_throws "There were not 60.9 seconds" UTCDate(1989, 12, 30, 23, 59, 60.9)

end

@testset "roundtrip" begin

    # We'll just try a huge number of elapsed times to find the resulting date, and then
    # we'll go backwards to make sure we get the original date.
    d = UTCDate(1975, 1, 1, 0, 0, 0.)
    for dt = -5 * 365 * 24 * 60 * 60 : 119.3 : 5 * 365 * 24 * 60 * 60
        d2 = after(d, dt)
        @test d2 - d == dt
        d3 = after(d2, -dt)
        @test d3 ≈ d
    end

end
