# NewsNative

<img src="clients/ios/Resources/logo_512.png" width="96" alt="" />

**An independent native iOS client for NewsBlur-compatible servers.**

NewsNative is an iPhone and iPad app for reading your feeds from a NewsBlur-compatible server, either newsblur.com or a self-hosted installation. It is only a client: your account, subscriptions and stories stay on the server you sign in to.

[Website](https://mjwaters1985.github.io/NewsNative/) · [Privacy Policy](https://mjwaters1985.github.io/NewsNative/privacy.html) · [Terms of Use](https://mjwaters1985.github.io/NewsNative/terms.html) · [Issues](https://github.com/MJWaters1985/NewsNative/issues)

## What it does

- Native iOS styling throughout, with Auto, Light and Dark appearances.
- Support for the iPhone Duo, including its side rail in both the open and closed positions.
- Sign in to the server of your choice with an existing account.
- Read sites and folders, filter by All, Unread or Saved, and keep stories offline.
- Home screen widgets, and a share extension for saving stories and adding sites.

## What you need

An existing account on a NewsBlur-compatible server. NewsNative does not create accounts, sell subscriptions or run a server of its own, and it leaves out the server's AI, social and training features. Support for your account comes from your server's operator.

## Where the code is

NewsNative is the iOS app in [`clients/ios`](clients/ios). The features it sets aside are switched off in [`clients/ios/Classes/NewsNativeFeatures.swift`](clients/ios/Classes/NewsNativeFeatures.swift).

This repository is a fork of [samuelclay/NewsBlur](https://github.com/samuelclay/NewsBlur), so it also carries NewsBlur's web server, Android app and other clients as they were when NewsNative branched. NewsNative doesn't change or support those parts; for them, see the upstream project.

To build, open `clients/ios/NewsBlur.xcodeproj` in Xcode and run the `NewsBlur` scheme.

## An independent project

NewsNative is an independent app made by Mike Waters. It is not affiliated with, endorsed, or supported by NewsBlur, Inc. or Samuel Clay.

## Derived from NewsBlur

NewsNative is built from the open-source NewsBlur iOS app, which Samuel Clay publishes under the MIT License. It has been modified to use native iOS styling and design. NewsBlur is the name of a service and app by NewsBlur, Inc., and appears here only to describe compatibility.

## Support

NewsNative is a free, one-person project. Problems and ideas go in
[GitHub issues](https://github.com/MJWaters1985/NewsNative/issues). If it saves you time, you can
[buy me a coffee](https://buymeacoffee.com/mjwaters1985).

## License

NewsNative's source code is released under the MIT License, the same license as the NewsBlur code it is built from. The NewsNative name, app icon and logo are © 2026 Mike Waters, all rights reserved, and are not covered by that license, so modified versions must use a different name and icon. See [`clients/ios/LICENSE.md`](clients/ios/LICENSE.md).

NewsNative © 2026 Mike Waters. NewsBlur © 2009 Samuel Clay, NewsBlur.
