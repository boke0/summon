import Foundation
import Testing
@testable import summon

@Test func cancelledProcessBoxDoesNotLaunchProcess() {
    let box = ProcessBox()
    box.terminate()

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/true")

    #expect(throws: CancellationError.self) {
        try box.launch(process)
    }
    #expect(!process.isRunning)
}
