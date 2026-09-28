import XCTest
@testable import Maccy

class TextTransformTests: XCTestCase {
  private func apply(_ id: String, _ input: String) -> String? {
    guard let transform = TextTransform.named(id) else {
      XCTFail("missing transform \(id)")
      return nil
    }
    return transform.apply(input)
  }

  func testRegistryIsLargeAndUnique() {
    XCTAssertGreaterThanOrEqual(TextTransform.all.count, 75)
    XCTAssertEqual(Set(TextTransform.all.map(\.id)).count, TextTransform.all.count)
    for category in TextTransform.Category.allCases {
      XCTAssertFalse(TextTransform.transforms(in: category).isEmpty, "\(category) is empty")
    }
  }

  func testEveryTransformHandlesEmptyAndUnicodeInput() {
    for transform in TextTransform.all {
      _ = transform.apply("")
      _ = transform.apply("héllo wörld 👋🏽\n日本語\ttab")
    }
  }

  func testCase() {
    XCTAssertEqual(apply("camelCase", "Hello big_world-again"), "helloBigWorldAgain")
    XCTAssertEqual(apply("pascalCase", "hello world"), "HelloWorld")
    XCTAssertEqual(apply("snakeCase", "helloWorldHTTPServer"), "hello_world_http_server")
    XCTAssertEqual(apply("screamingSnakeCase", "hello world"), "HELLO_WORLD")
    XCTAssertEqual(apply("kebabCase", "Hello World"), "hello-world")
    XCTAssertEqual(apply("trainCase", "hello world"), "Hello-World")
    XCTAssertEqual(apply("dotCase", "hello world"), "hello.world")
    XCTAssertEqual(apply("sentenceCase", "HELLO. how ARE you?"), "Hello. How are you?")
    XCTAssertEqual(apply("swapCase", "aBc"), "AbC")
  }

  func testWhitespace() {
    XCTAssertEqual(apply("collapseSpaces", "a   b\t\tc"), "a b c")
    XCTAssertEqual(apply("removeEmptyLines", "a\n\n  \nb"), "a\nb")
    XCTAssertEqual(apply("joinLines", " a \n\n b "), "a b")
    XCTAssertEqual(apply("dedent", "    a\n      b\n\n    c"), "a\n  b\n\nc")
    XCTAssertEqual(apply("normalizeLineEndings", "a\r\nb\rc"), "a\nb\nc")
  }

  func testLines() {
    XCTAssertEqual(apply("sortAscending", "b\na\nc"), "a\nb\nc")
    XCTAssertEqual(apply("sortNumeric", "10\n9\n100"), "9\n10\n100")
    XCTAssertEqual(apply("uniqueLines", "a\nb\na\nc\nb"), "a\nb\nc")
    XCTAssertEqual(apply("numberLines", "a\nb"), "1. a\n2. b")
    XCTAssertEqual(apply("reverseLines", "a\nb\nc"), "c\nb\na")
    XCTAssertEqual(apply("linesToCommaList", "a\n\nb"), "a, b")
    XCTAssertEqual(apply("commaListToLines", "a, b ,c"), "a\nb\nc")
    XCTAssertEqual(apply("sortByLength", "ccc\na\nbb\nd"), "a\nd\nbb\nccc")
  }

  func testEncodingRoundTrips() {
    let input = "Copper 🪙 a+b/c?d=e&f"
    let pairs = [
      ("base64Encode", "base64Decode"), ("base64URLEncode", "base64URLDecode"),
      ("urlEncode", "urlDecode"), ("hexEncode", "hexDecode"),
      ("unicodeEscape", "unicodeUnescape"), ("jsonStringEscape", "jsonStringUnescape"), ("rot13", "rot13")
    ]
    for (encode, decode) in pairs {
      let encoded = apply(encode, input)
      XCTAssertNotNil(encoded, encode)
      XCTAssertEqual(encoded.flatMap { apply(decode, $0) }, input, "\(encode) then \(decode)")
    }
  }

  func testEncodingValues() {
    XCTAssertEqual(apply("base64Encode", "hello"), "aGVsbG8=")
    XCTAssertEqual(apply("urlEncode", "a b&c"), "a%20b%26c")
    XCTAssertEqual(apply("htmlEncode", "<a href=\"x\">&</a>"), "&lt;a href=&quot;x&quot;&gt;&amp;&lt;/a&gt;")
    XCTAssertEqual(apply("htmlDecode", "&lt;b&gt; &amp; &quot;"), "<b> & \"")
    XCTAssertEqual(apply("rot13", "Hello"), "Uryyb")
    XCTAssertNil(apply("base64Decode", "%%%not base64"))
    XCTAssertNil(apply("hexDecode", "abc"))
  }

  func testJSON() {
    XCTAssertEqual(apply("jsonMinify", "{ \"a\" : [ 1, 2 ] }"), "{\"a\":[1,2]}")
    XCTAssertEqual(apply("jsonSortKeys", "{\"b\":1,\"a\":2}"), "{\n  \"a\" : 2,\n  \"b\" : 1\n}")
    XCTAssertNotNil(apply("jsonPretty", "[1,2]"))
    XCTAssertNil(apply("jsonPretty", "{not json"))
  }

  func testHashes() {
    XCTAssertEqual(apply("md5", "abc"), "900150983cd24fb0d6963f7d28e17f72")
    XCTAssertEqual(apply("sha1", "abc"), "a9993e364706816aba3e25717850c26c9cd0d89d")
    XCTAssertEqual(apply("sha256", "abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  }

  func testText() {
    XCTAssertEqual(apply("slugify", "Héllo, World! 2026"), "hello-world-2026")
    XCTAssertEqual(apply("stripHTML", "<p>Hi <b>there</b></p>"), "Hi there")
    XCTAssertEqual(apply("extractURLs", "see https://a.com/x and (http://b.io)."), "https://a.com/x\nhttp://b.io")
    XCTAssertEqual(apply("extractEmails", "mail a@b.com or c.d@e.co"), "a@b.com\nc.d@e.co")
    XCTAssertEqual(apply("keepDigits", "+234 (803) 555"), "234803555")
    XCTAssertEqual(apply("countStats", "one two\nthree"), "3 words, 13 characters, 2 lines")
    XCTAssertEqual(apply("straightQuotes", "\u{201C}hi\u{201D} it\u{2019}s"), "\"hi\" it's")
    XCTAssertEqual(apply("markdownToPlain", "# Title\n**bold** [link](https://x.y)"), "Title\nbold link")
  }

  func testDeveloper() {
    XCTAssertEqual(apply("timestampToDate", "0"), "1970-01-01T00:00:00Z")
    XCTAssertEqual(apply("timestampToDate", "1700000000000"), "2023-11-14T22:13:20Z")
    XCTAssertEqual(apply("dateToTimestamp", "1970-01-02T00:00:00Z"), "86400")
    XCTAssertEqual(apply("hexToRGB", "#fa0"), "rgb(255, 170, 0)")
    XCTAssertEqual(apply("rgbToHex", "rgb(255, 170, 0)"), "#FFAA00")
    XCTAssertNil(apply("rgbToHex", "rgb(300, 0, 0)"))
    XCTAssertEqual(apply("escapeShell", "it's"), "'it'\\''s'")
    XCTAssertEqual(apply("queryToJSON", "https://x.y/?b=2&a=hello%20there"), "{\n  \"a\" : \"hello there\",\n  \"b\" : \"2\"\n}")
  }
}
