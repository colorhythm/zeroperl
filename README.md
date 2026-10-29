> **Fork notice & thanks** — this is Colorhythm's fork of
> [**zeroperl** by Andrew Sampson (6over3)](https://github.com/6over3/zeroperl).
> The remarkable feat of putting a sandboxed Perl 5 in a self-contained
> WebAssembly module is entirely his; our changes are small build and
> integration adjustments for the `@colorhythm/exiftool-wasm` toolchain.
> Thank you, Andrew.

zeroperl is an experimental build of Perl5 in a sandboxed, self-contained WebAssembly module.

## Build

Requires Docker or Apple Container (macOS).

**Docker:**
```bash
docker build -t zeroperl .
mkdir -p output
docker run --rm -v $(pwd)/output:/output zeroperl cp -r /artifacts/. /output/
```

**Apple Container (macOS):**
```bash
container build -t zeroperl .
mkdir -p output
container run --rm -v $(pwd)/output:/output zeroperl cp -r /artifacts/. /output/
```

Output in `./output/`:
- `zeroperl.wasm` — reactor with asyncify
- `zeroperl_reactor.wasm` — reactor without asyncify
- `perl-wasi-prefix/` — Perl library prefix
- `exiftool.min.pl` — minified ExifTool (if enabled)

### Build args

**Docker:**
```bash
docker build --build-arg PERL_VERSION=5.42.0 --build-arg BUILD_EXIFTOOL=false -t zeroperl .
```

**Apple Container:**
```bash
container build --build-arg PERL_VERSION=5.42.0 --build-arg BUILD_EXIFTOOL=false -t zeroperl .
```

<details>
<summary>Available build arguments</summary>

| Arg | Default | |
|-----|---------|--|
| `PERL_VERSION` | `5.42.0` | Perl source version |
| `EXIFTOOL_VERSION` | `13.60` | ExifTool version |
| `EXIFTOOL_SHA256` | `c8e3c42576f46d862e4cd9c192989776e7363931e890c95056bcd6293e83ea36` | Official source archive SHA-256; must match the selected version |
| `BUILD_EXIFTOOL` | `true` | Include ExifTool |
| `STACK_SIZE` | `8388608` | WASM stack (bytes) |
| `INITIAL_MEMORY` | `33554432` | WASM initial memory (bytes) |
| `ASYNCIFY` | `true` | Enable asyncify |
| `TRIM` | `true` | Strip unused modules |

</details>

ExifTool builds verify the source archive against the supplied SHA-256, check the
CLI and module version, and run the upstream native test suite before installing.
Use the digest in [Phil Harvey's checksum file](https://exiftool.org/checksums.txt)
when overriding the version. A missing source, failed test, or missing artifact
fails the build. The trimmed prefix retains ExifTool's character-set tables;
removing them silently loses metadata such as MacRoman QuickTime text.

Release orchestration belongs to
[exiftool-wasm](https://github.com/colorhythm/exiftool-wasm). It builds this repo
at a recorded commit and tests the paired CLI/WASM artifacts through the actual
package before publishing. The manual `zeroperl` workflow only builds artifacts.
The former cross-repository updater has been replaced by a manual dispatch to
that validated release pipeline.

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
```

See the [zeroperl-ts README](https://github.com/colorhythm/zeroperl-ts) for details.

## Usage

> **Note:** The first argument passed to Perl **must** be `zeroperl`.
> Depending on your runtime, you may need to map `/dev/null` as a preopen.
