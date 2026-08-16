import Foundation
import Testing
@testable import MachKitCore

@Test func curlLabRunnerRejectsEmptyAndNonHTTPURLs() async {
    let empty = await CurlLabRunner.run(payload: ["method": "GET", "url": ""])
    #expect(empty.ok == false)
    #expect(empty.error == "empty-url")

    let ftp = await CurlLabRunner.run(payload: [
        "method": "GET",
        "url": "ftp://example.com/file"
    ])
    #expect(ftp.ok == false)
    #expect(ftp.error == "unsupported-scheme")
}

@Test func curlLabRunnerRejectsMissingFormFile() async {
    let result = await CurlLabRunner.run(payload: [
        "method": "POST",
        "url": "https://example.com/upload",
        "bodyMode": "formdata",
        "formFields": [
            ["key": "file", "value": "/tmp/machkit-missing-\(UUID().uuidString).bin", "kind": "file"]
        ]
    ])
    #expect(result.ok == false)
    #expect(result.error == "missing-file")
}
