# VOCALOID DB Installer

A macOS utility that registers locally supplied VOCALOID database components for VOCALOID 5 and newer installations, including databases built for VOCALOID 3 and VOCALOID 4.

This project does not include voicebanks or other Yamaha/VOCALOID content. Use only files you are authorized to install. The installer writes VOCALOID component metadata to system preference files and asks macOS for administrator authorization.

## Requirements

- macOS 15 or later
- A locally available VOCALOID database folder with its `.ddi` file, or a component folder containing `dvqm.dat`
- On Apple Silicon, Rosetta 2 may be required for the bundled `date2drp2` x86_64 helper

## Build

Open `VOCALOID_DB_Installer.xcodeproj` in Xcode, or build from Terminal:

```sh
xcodebuild \
  -project VOCALOID_DB_Installer.xcodeproj \
  -scheme VOCALOID_DB_Installer \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO \
  build
```

The `date2drp2` helper is bundled as an x86_64 Mach-O executable. Its original C source is not included in this repository.

## Use

1. Select the `.ddi` file for a database component, or select `dvqm.dat` for a VOCALOID DVQM component.
2. Confirm the component shown by the app.
3. Choose **Install Selected Components** and authorize the requested system preference update.

The app is provided for research and compatibility purposes. This repository has not been validated against every VOCALOID release or commercial voicebank. Back up the relevant system preference files before use.

## Distribution

The release DMG is built for Apple Silicon, ad-hoc signed, and not notarized with an Apple Developer ID. macOS may report that it cannot verify the developer.

## License

The project is licensed under Apache-2.0. See [LICENSE](LICENSE). The included `date2drp2` helper is distributed as part of this project; its source and separate provenance are not available here.

VOCALOID and Yamaha are trademarks of Yamaha Corporation. This project is independent and is not affiliated with or endorsed by Yamaha Corporation.
