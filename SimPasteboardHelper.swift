//
//  SimPasteboardHelper.swift
//  SimPasteboardHelperExample
//
//  Created by Robin Kunde on 9/3/22.
//

#if DEBUG

import Foundation
import UIKit

class SimPasteboardHelper {
    static let shared = SimPasteboardHelper()

    private var handle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var pbContents: String?

    func activate() -> Bool {
        #if !targetEnvironment(simulator)
        return false
        #endif

        if let handle = self.handle {
            try? handle.close()
            self.handle = nil
        }
        if let dispatchSource = self.dispatchSource {
            dispatchSource.cancel()
            self.dispatchSource = nil
        }

        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return false }

        let homeFolderUrl = URL(fileURLWithPath: home)
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: homeFolderUrl.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else { return false }

        let proxyFileUrl = homeFolderUrl.appendingPathComponent("simPasteboard", isDirectory: false)
        if FileManager.default.fileExists(atPath: proxyFileUrl.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return false
            }
        } else {
            try! "".write(to: proxyFileUrl, atomically: true, encoding: .utf8)
        }

        guard let handle = try? FileHandle(forReadingFrom: proxyFileUrl) else { return false }
        self.handle = handle

        readFromProxyFile()

        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: handle.fileDescriptor,
            eventMask: [.write],
            queue: DispatchQueue.main
        )
        self.dispatchSource = dispatchSource

        dispatchSource.setEventHandler { [weak self] in
            self?.readFromProxyFile()
        }
        dispatchSource.activate()

        return true
    }

    private func readFromProxyFile() {
        guard let handle = self.handle else { return }

        do {
            try handle.seek(toOffset: 0)
            let data = handle.readDataToEndOfFile()
            let string = String(data: data, encoding: .utf8)!

            self.pbContents = string.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("SimPasteboardHelper failed with error: \(error.localizedDescription)")
        }
    }

    @objc
    fileprivate func paste() {
        guard let pbContents = pbContents, let responder = UIResponder.currentFirstResponder else {
            return
        }

        if let textfield = responder as? UITextField {
            textfield.insertText(pbContents)
        } else if let textview = responder as? UITextView {
            textview.insertText(pbContents)
        }
    }
}

extension UIResponder {
    private weak static var _currentFirstResponder: UIResponder?

    public static var currentFirstResponder: UIResponder? {
        UIResponder._currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder(sender:)), to: nil, from: nil, for: nil)
        return UIResponder._currentFirstResponder
    }

    @objc
    private func findFirstResponder(sender: AnyObject) {
        UIResponder._currentFirstResponder = self
    }
}

extension AppDelegate {
    override var keyCommands: [UIKeyCommand]? {
        var commands = super.keyCommands ?? []

        commands.append(UIKeyCommand(input: "v", modifierFlags: [.control], action: #selector(pasteboardHelperPaste)))

        return commands
    }

    @objc
    private func pasteboardHelperPaste() {
        SimPasteboardHelper.shared.paste()
    }
}

#endif
