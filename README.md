> **Fork notice & thanks** — this is Colorhythm's fork of
> [**zeroperl** by Andrew Sampson (6over3)](https://github.com/6over3/zeroperl).
> The remarkable feat of putting a sandboxed Perl 5 in a self-contained
> WebAssembly module is entirely his; our changes are small build and
> integration adjustments for the `@colorhythm/exiftool-wasm` toolchain.
> Thank you, Andrew.

zeroperl is an experimental build of Perl5 in a sandboxed, self-contained WebAssembly module.

## Role in the Colorhythm forks

This repository builds the Perl/WASI runtime and optional ExifTool script. It is
not an npm package. The JavaScript embedding lives in
[zeroperl-ts](https://github.com/colorhythm/zeroperl-ts); the published metadata
package is [@colorhythm/exiftool-wasm](https://www.npmjs.com/package/@colorhythm/exiftool-wasm).

ExifTool releases are controlled by
[exiftool-wasm](https://github.com/colorhythm/exiftool-wasm/blob/main/RELEASING.md).
That workflow selects a recorded revision of this repository, overrides the
ExifTool version and checksum, and validates the paired CLI/WASM artifacts.
The defaults in this repository are standalone build pins, not an indication of
the latest published ExifTool release. Consult the installed package's
`exiftool-build.json` or CLI `-ver` for its actual identity.

## Build

Requires Docker or Apple Container (macOS).

**Docker:**
```bash
docker build -t zeroperl .
mkdir -p output
docker run --rm -v "$(pwd)/output:/output" zeroperl cp -r /artifacts/. /output/
```

**Apple Container (macOS):**
```bash
container build -t zeroperl .
mkdir -p output
container run --rm -v "$(pwd)/output:/output" zeroperl cp -r /artifacts/. /output/
```

Output in `./output/`:
- `config.h` — configuration from the WASI Perl build
- `zeroperl.wasm` — reactor with asyncify
- `zeroperl_reactor.wasm` — reactor without asyncify
- `perl-wasi-prefix/` — Perl library prefix
- `exiftool.min.pl` — minified ExifTool (if enabled)

### Build args

**Docker:**
```bash
docker build --build-arg BUILD_EXIFTOOL=false -t zeroperl .
```

**Apple Container:**
```bash
container build --build-arg BUILD_EXIFTOOL=false -t zeroperl .
```

<details>
<summary>Available build arguments</summary>

Defaults are defined in the [Dockerfile](Dockerfile); the manual Actions form is
defined in [zeroperl.yml](.github/workflows/zeroperl.yml). Set ExifTool's version
and checksum together when overriding either one.

| Argument | Purpose |
| --- | --- |
| `ASYNCIFY` | Enable Asyncify for asynchronous imports |
| `BINARYEN_VERSION` | Binaryen toolchain version |
| `BUILD_EXIFTOOL` | Include ExifTool |
| `EXIFTOOL_SHA256` | Official source archive SHA-256 for the selected version |
| `EXIFTOOL_VERSION` | ExifTool source version |
| `INITIAL_MEMORY` | WASM initial memory, in bytes |
| `PERL_VERSION` | Perl source version |
| `STACK_SIZE` | WASM stack, in bytes |
| `TARGETPLATFORM` | Docker-supplied platform used to select toolchain architecture |
| `TRIM` | Remove comments and POD from the prepared Perl sources |
| `WASI_SDK_VERSION` | WASI SDK version |
| `WASM_OPT_FLAGS` | Additional flags for the final Asyncify/optimization pass |

</details>

ExifTool builds verify the source archive against the supplied SHA-256, check the
CLI and module version, and run the upstream native test suite before installing.
Use the digest in [Phil Harvey's checksum file](https://exiftool.org/checksums.txt)
when overriding the version. A missing source, failed test, or missing artifact
fails the build. The trimmed prefix retains ExifTool's character-set tables;
removing them silently loses metadata such as MacRoman QuickTime text.

The manual `zeroperl` workflow builds artifacts without publishing npm packages.
The former cross-repository updater now only dispatches the validated
exiftool-wasm release workflow. The separate `perlemscripten-nodefs` workflow is
a legacy Emscripten experiment, not the WASI release path described here.

### Iterating on stubs/zeroperl.c

Build from `final` stage to reuse cached wasi-perl:

**Docker:**
```bash
docker build --target final -t zeroperl .
```

**Apple Container:**
```bash
container build --target final -t zeroperl .
```

## Testing

The easiest way to test a new build of `zeroperl.wasm` is to clone the TypeScript wrapper and run its test suite:

```bash
git clone https://github.com/colorhythm/zeroperl-ts
cp output/zeroperl.wasm zeroperl-ts/zeroperl.wasm
cd zeroperl-ts
npm install
bun test
```

Run these commands from this repository after building the runtime. The copy
replaces the companion checkout's development binary with the one being tested.
See the [zeroperl-ts README](https://github.com/colorhythm/zeroperl-ts) for API and
coverage details. Skipped tests are not passing coverage.

## Usage

> **Note for direct embedders:** The first argument passed to Perl **must** be `zeroperl`.
> Depending on your runtime, you may need to map `/dev/null` as a preopen.

The TypeScript wrapper supplies this executable argument and its in-memory
`/dev/null` entry. Its script-argument arrays should contain only the script's
arguments.
