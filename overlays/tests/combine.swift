// Exercises the Combine framework under Darling: that publishers actually publish, not just that
// the framework loads. The @Published/objectWillChange cases are the surface apps bind most.
import Combine

var failures = 0
func check(_ condition: Bool, _ label: String) {
    print(condition ? "ok:" : "FAIL:", label)
    if !condition { failures += 1 }
}

var cancellables = Set<AnyCancellable>()

// Just: one value, then a finished completion.
var justValue: Int?
var justFinished = false
Just(42).sink(receiveCompletion: { if case .finished = $0 { justFinished = true } },
              receiveValue: { justValue = $0 })
    .store(in: &cancellables)
check(justValue == 42, "Just delivers its value to a sink")
check(justFinished, "Just finishes")

// PassthroughSubject forwards what is sent after subscription.
let subject = PassthroughSubject<Int, Never>()
var forwarded: [Int] = []
subject.sink { forwarded.append($0) }.store(in: &cancellables)
subject.send(1)
subject.send(2)
subject.send(3)
check(forwarded == [1, 2, 3], "PassthroughSubject forwards sent values")

// CurrentValueSubject replays its current value on subscription and tracks writes.
let current = CurrentValueSubject<String, Never>("initial")
var seen: [String] = []
current.sink { seen.append($0) }.store(in: &cancellables)
current.send("updated")
check(seen.first == "initial", "CurrentValueSubject replays its current value")
check(seen.last == "updated", "CurrentValueSubject forwards later values")
check(current.value == "updated", "CurrentValueSubject.value tracks sends")

// An operator chain transforms values in order.
var mapped: [Int] = []
[1, 2, 3, 4, 5].publisher
    .filter { $0 % 2 == 1 }
    .map { $0 * 10 }
    .sink { mapped.append($0) }
    .store(in: &cancellables)
check(mapped == [10, 30, 50], "filter and map compose")

// ObservableObject and @Published. objectWillChange fires through the _enclosingInstance
// subscript, which is the mechanism behind the symbols SwiftUI-era apps bind.
final class Model: ObservableObject {
    @Published var count: Int = 0
    @Published var name: String = "start"
}

let model = Model()
var willChangeCount = 0
model.objectWillChange.sink { _ in willChangeCount += 1 }.store(in: &cancellables)

var publishedValues: [Int] = []
model.$count.sink { publishedValues.append($0) }.store(in: &cancellables)

model.count = 1
model.count = 2
model.name = "changed"

check(publishedValues == [0, 1, 2], "@Published projected value replays and forwards")
check(willChangeCount == 3, "objectWillChange fires once per @Published mutation")
check(model.count == 2 && model.name == "changed", "@Published stores the written value")

// Cancelling stops delivery.
let cancelSubject = PassthroughSubject<Int, Never>()
var afterCancel: [Int] = []
let token = cancelSubject.sink { afterCancel.append($0) }
cancelSubject.send(1)
token.cancel()
cancelSubject.send(2)
check(afterCancel == [1], "AnyCancellable.cancel stops delivery")

// A failure arrives as a failure completion, not as a value.
enum TestError: Error { case boom }
var failureSeen = false
var valueAfterFailure = false
Fail<Int, TestError>(error: .boom)
    .sink(receiveCompletion: { if case .failure = $0 { failureSeen = true } },
          receiveValue: { _ in valueAfterFailure = true })
    .store(in: &cancellables)
check(failureSeen && !valueAfterFailure, "Fail delivers a failure completion")

// Merge forwards both inputs and finishes only after both finish.
let mergeA = PassthroughSubject<Int, Never>()
let mergeB = PassthroughSubject<Int, Never>()
var merged: [Int] = []
var mergeFinished = false
mergeA.merge(with: mergeB)
    .sink(receiveCompletion: { if case .finished = $0 { mergeFinished = true } },
          receiveValue: { merged.append($0) })
    .store(in: &cancellables)
mergeA.send(1)
mergeB.send(2)
mergeA.send(completion: .finished)
check(!mergeFinished, "Merge waits for both publishers to finish")
mergeB.send(3)
mergeB.send(completion: .finished)
check(merged == [1, 2, 3] && mergeFinished, "Merge interleaves values and finishes")

// MergeMany accepts a sequence and watches all of its publishers.
let manyA = PassthroughSubject<Int, Never>()
let manyB = PassthroughSubject<Int, Never>()
let manyC = PassthroughSubject<Int, Never>()
var manyValues: [Int] = []
Publishers.MergeMany([manyA, manyB, manyC])
    .sink { manyValues.append($0) }
    .store(in: &cancellables)
manyB.send(20)
manyA.send(10)
manyC.send(30)
check(manyValues == [20, 10, 30], "MergeMany forwards every upstream")

// CombineLatest waits for a value from every upstream, then pairs each new value with the latest others.
let latestA = PassthroughSubject<Int, Never>()
let latestB = PassthroughSubject<String, Never>()
var pairs: [String] = []
var latestFinished = false
latestA.combineLatest(latestB)
    .sink(receiveCompletion: { if case .finished = $0 { latestFinished = true } },
          receiveValue: { pairs.append("\($0.0)\($0.1)") })
    .store(in: &cancellables)
latestA.send(1)
check(pairs.isEmpty, "CombineLatest waits for every upstream")
latestB.send("a")
latestA.send(2)
latestB.send("b")
check(pairs == ["1a", "2a", "2b"], "CombineLatest pairs each value with the latest of the other")
latestA.send(completion: .finished)
check(!latestFinished, "CombineLatest waits for both publishers to finish")
latestB.send(completion: .finished)
check(latestFinished, "CombineLatest finishes after both upstreams finish")

// CombineLatest4 through the transform overload, as OpenSwiftUI's ProgressView uses it.
let q1 = CurrentValueSubject<Int, Never>(1)
let q2 = CurrentValueSubject<Int, Never>(2)
let q3 = CurrentValueSubject<Int, Never>(3)
let q4 = CurrentValueSubject<Int, Never>(4)
var sums: [Int] = []
q1.combineLatest(q2, q3, q4) { $0 + $1 + $2 + $3 }
    .sink { sums.append($0) }
    .store(in: &cancellables)
q3.send(30)
check(sums == [10, 37], "CombineLatest4 transform sees the latest of all four")
let _: Publishers.CombineLatest4<CurrentValueSubject<Int, Never>, CurrentValueSubject<Int, Never>,
                                 CurrentValueSubject<Int, Never>, CurrentValueSubject<Int, Never>>
    = Publishers.CombineLatest4(q1, q2, q3, q4)

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
