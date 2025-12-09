#!/usr/bin/env swift
import Foundation
let s = "  spaced_start.txt"
print("raw:\(s)")
print("length: \(s.count)")
for (i, ch) in s.enumerated() {
    print("index \(i): [\(ch)]")
}
let raw = s.trimmingCharacters(in: .newlines)
print("after trimming newlines: [\(raw)] count=\(raw.count)")
if raw.count >= 3 {
    let idx2 = raw.index(raw.startIndex, offsetBy: 2)
    print("char at idx2 (2): [\(raw[idx2])]")
    if raw[idx2] == " " {
        let path = String(raw[raw.index(idx2, offsetBy: 1)...]).trimmingCharacters(in: .whitespaces)
        print("path via drop at 3: [\(path)]")
    } else {
        if let firstNonSpace = raw.firstIndex(where: { $0 != " " && $0 != "\t" }) {
            let path = String(raw[firstNonSpace...]).trimmingCharacters(in: .whitespaces)
            print("path via firstNonSpace: [\(path)]")
        } else { print("no non-space char") }
    }
} else { print("raw < 3") }
