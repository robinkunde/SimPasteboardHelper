# SimPasteboardHelper

SimPasteboardHelper is a debug helper class designed to work around issues with copying and pasting into the iOS Simulator when running under Rosetta (or other situations where it doesn't work properly). It does so by creating a file called `simPasteboard` in your home folder and monitoring it for changes. When a change is detected, the contents of the file then become available for pasting inside the app through the keyboard shortcut ^+v (not ⌘+v).

I might add support for writing copied text from the app back to the file in a future release.

## Why does Rosetta break copy/paste in the simulator?

Judging from the error messages in the console log, some combination of XPC and permission issues. The simulator's Pasteboard stores copied data in a cache file inside the simulator's device directory, but for some reason is unable to read it back.
