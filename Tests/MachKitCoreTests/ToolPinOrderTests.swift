import Foundation
import Testing
@testable import MachKitCore

private let available: Set<String> = ["a", "b", "c", "d"]

@Test func toolPinOrderResolveDropsUnknownAndDuplicates() {
    let resolved = ToolPinOrder.resolve(
        pinnedIDs: ["b", "gone", "a", "b", "missing", "c"],
        availableIDs: available
    )
    #expect(resolved == ["b", "a", "c"])
}

@Test func toolPinOrderResolveEmptyWhenNothingAvailable() {
    let resolved = ToolPinOrder.resolve(
        pinnedIDs: ["gone", "also-gone"],
        availableIDs: available
    )
    #expect(resolved.isEmpty)
}

@Test func toolPinOrderUnpinnedPreservesRegistryOrder() {
    let unpinned = ToolPinOrder.unpinnedIDs(
        registryOrder: ["a", "b", "c", "d"],
        pinnedIDs: ["c", "a"]
    )
    #expect(unpinned == ["b", "d"])
}

@Test func toolPinOrderPinAppendsOnce() {
    let first = ToolPinOrder.pin("b", in: ["a"], availableIDs: available)
    #expect(first == ["a", "b"])
    let again = ToolPinOrder.pin("b", in: first, availableIDs: available)
    #expect(again == ["a", "b"])
}

@Test func toolPinOrderPinIgnoresUnknown() {
    let result = ToolPinOrder.pin("gone", in: ["a"], availableIDs: available)
    #expect(result == ["a"])
}

@Test func toolPinOrderUnpinRemovesAndPrunes() {
    let result = ToolPinOrder.unpin(
        "a",
        from: ["gone", "a", "b", "a"],
        availableIDs: available
    )
    #expect(result == ["b"])
}

@Test func toolPinOrderMoveBeforeTarget() {
    let result = ToolPinOrder.move(
        "c",
        before: "a",
        in: ["a", "b", "c"],
        availableIDs: available
    )
    #expect(result == ["c", "a", "b"])
}

@Test func toolPinOrderMoveBeforeSelfIsNoOp() {
    let result = ToolPinOrder.move(
        "b",
        before: "b",
        in: ["a", "b", "c"],
        availableIDs: available
    )
    #expect(result == ["a", "b", "c"])
}

@Test func toolPinOrderMoveMissingTargetAppends() {
    let result = ToolPinOrder.move(
        "a",
        before: "gone",
        in: ["a", "b", "c"],
        availableIDs: available
    )
    #expect(result == ["b", "c", "a"])
}

@Test func toolPinOrderMoveUnknownIsNoOp() {
    let result = ToolPinOrder.move(
        "gone",
        before: "a",
        in: ["a", "b"],
        availableIDs: available
    )
    #expect(result == ["a", "b"])
}
