# r2-streamer-swift
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

R2-streamer-swift aims at simplifying the usage of numeric publication by parsing and serving them.
It takes the publication as input, and generates an accessible [WebPubManifest](https://github.com/readium/webpub-manifest)/object as output.

It also provides helper functions in order to use features like mediaOverlays more conveniently.

Supported formats: 

**EPUB 2/3/3.1- OEBPS - CBZ**

## Dependencies

The project dependencies are managed with [Carthage](https://github.com/Carthage/Carthage).
You need to run `carthage update (--platform ios)` to install them.

Using:
- [swisspol/GCDWebServer](https://github.com/swisspol/GCDWebServer) A modern and lightweight GCD based HTTP 1.1 server designed to be embedded in OS X & iOS apps.
- [Hearst-DD/ObjectMapper](https://github.com/Hearst-DD/ObjectMapper) A framework written in Swift that makes it easy to convert your model objects (classes and structs) to and from JSON.
- [tadija/AEXML](https://github.com/tadija/AEXML) Simple and lightweight XML parser written in Swift.
- [krzyzanowskim/CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) Crypto related functions and helpers for Swift implemented in Swift.

## Documentation

[Jazzy](https://github.com/realm/jazzy) is used to generate the project documentation.
There are two script for building either the Public API documentation of the full documentation.

    `./generate_doc_public.sh`
    `./generate_doc_full.sh`

### [Old] Testing the project with the r2-launcher-swift (iOS)

- Clone this project (r2-streamer-swift) and the launcher ([r2-launcher-swift](https://github.com/readium/r2-launcher-swift))
- In each project directories run : `$> carthage update --platform ios` 
- Create a new XCode workspace and drag the two aforementioned project's `.xcodeproj` in the navigator panel on the left.
- Select the `R2-Launcher-Development` target and `Run` it on navigator or device.

NB: Choose the same branches on both r2-streamer/launcher repositories. E.g: `r2-streamer-swift/feature/X with r2-launcher-swift/feature/X`
