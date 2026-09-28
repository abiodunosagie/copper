import XCTest
@testable import Maccy

class DateQueryTests: XCTestCase {
  var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Africa/Lagos")!
    calendar.firstWeekday = 2
    return calendar
  }

  // Wednesday 2026-09-30 15:00 in Lagos.
  var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 15))! }

  private func day(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
  }

  func testPlainTextHasNoRange() {
    let query = DateQuery.parse("invoice", now: now, calendar: calendar)
    XCTAssertNil(query.range)
    XCTAssertEqual(query.text, "invoice")
  }

  func testYesterdayWithText() throws {
    let query = DateQuery.parse("Yesterday invoice", now: now, calendar: calendar)
    let range = try XCTUnwrap(query.range)
    XCTAssertEqual(query.text, "invoice")
    XCTAssertTrue(range.contains(day(9, 29)))
    XCTAssertFalse(range.contains(day(9, 30)))
    XCTAssertFalse(range.contains(day(9, 28)))
  }

  func testTodayAndWeeks() throws {
    XCTAssertTrue(try XCTUnwrap(DateQuery.parse("today", now: now, calendar: calendar).range).contains(day(9, 30, hour: 1)))
    let thisWeek = try XCTUnwrap(DateQuery.parse("this week", now: now, calendar: calendar).range)
    XCTAssertTrue(thisWeek.contains(day(9, 28)))
    XCTAssertFalse(thisWeek.contains(day(9, 27)))
    let lastWeek = try XCTUnwrap(DateQuery.parse("notes last week", now: now, calendar: calendar).range)
    XCTAssertTrue(lastWeek.contains(day(9, 21)))
    XCTAssertFalse(lastWeek.contains(day(9, 28)))
  }

  func testMonths() throws {
    let lastMonth = try XCTUnwrap(DateQuery.parse("last month", now: now, calendar: calendar).range)
    XCTAssertTrue(lastMonth.contains(day(8, 15)))
    XCTAssertFalse(lastMonth.contains(day(9, 1)))
  }

  func testPhrasesInsideWordsAreIgnored() {
    XCTAssertNil(DateQuery.parse("todays-special", now: now, calendar: calendar).range)
    XCTAssertNil(DateQuery.parse("birthdaytoday", now: now, calendar: calendar).range)
  }
}
