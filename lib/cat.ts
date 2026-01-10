#!/usr/bin/env -S deno run -A --node-modules-dir=auto
/**
 * cat.ts
 *
 * A programmable analogue of Unix `cat` for Deno.
 *
 * Concatenates text sources into a single stream. Sources may be:
 * - local files (absolute paths, relative paths, or `file:` URLs)
 * - remote `http(s):` URLs
 * - inline text
 *
 * Optional BEGIN/END markers can be enabled for debugging. When enabled,
 * markers use deterministic, relative labels to keep output stable across
 * machines and environments.
 */

import { expandGlob } from "@std/fs";
import { extname, fromFileUrl, isAbsolute, relative, resolve } from "@std/path";

const encoder = new TextEncoder();
const decoder = new TextDecoder();

type ResolvedSource =
  | { kind: "remote"; original: string; label: string }
  | { kind: "file"; original: string; label: string }
  | { kind: "inline"; original: string; label: string };

export type AutoCompileSpec = {
  file?: string;
  glob?: string | string[];
  cwd?: string;
  labelPrefix?: string;
};

export type AutoCompiled = {
  executablePath: string;
  label: string;
  text: string;
};

export class Cat {
  #sources: ResolvedSource[] = [];
  #separator = "\n\n";
  #includeMarkers = false;

  /**
   * Add sources to concatenate.
   */
  add(...sources: string[]) {
    for (const source of sources) this.#sources.push(resolveSource(source));
    return this;
  }

  /**
   * Add inline text (typically generated output).
   */
  addText(text: string, label = "inline") {
    this.#sources.push({ kind: "inline", original: text, label });
    return this;
  }

  /**
   * Set the separator between concatenated sources.
   */
  separator(value: string) {
    this.#separator = value;
    return this;
  }

  /**
   * Enable or disable BEGIN/END markers.
   *
   * Disabled by default for deterministic output.
   */
  markers(enabled = true) {
    this.#includeMarkers = enabled;
    return this;
  }

  /**
   * Discover executable generator scripts and yield their STDOUT.
   */
  async *autoCompile(
    specs: readonly AutoCompileSpec[],
  ): AsyncGenerator<AutoCompiled> {
    for (const spec of specs) {
      const cwd = spec.cwd ? resolve(spec.cwd) : undefined;
      const labelPrefix = spec.labelPrefix ?? "autoCompile";

      const paths: string[] = [];

      if (spec.file) paths.push(resolveFileSpec(spec.file, cwd));

      if (spec.glob) {
        const patterns = Array.isArray(spec.glob) ? spec.glob : [spec.glob];
        for (const pattern of patterns) {
          for await (
            const entry of expandGlob(pattern, {
              root: cwd,
              includeDirs: false,
            })
          ) {
            paths.push(entry.path);
          }
        }
      }

      for (const p of paths) {
        const st = await safeStat(p);
        if (!st?.isFile) continue;
        if (!(await isExecutableFile(p, st))) continue;

        const text = await runExecutableCaptureStdout(p);
        yield {
          executablePath: p,
          label: `${labelPrefix}:${relativeLabel(p)}`,
          text,
        };
      }
    }
  }

  /**
   * Concatenate all sources into a single string.
   */
  async concat(): Promise<string> {
    const chunks: string[] = [];

    for (const src of this.#sources) {
      const text = await readSourceText(src);

      if (this.#includeMarkers) {
        chunks.push(`-- >>> BEGIN ${src.label}`);
        chunks.push(text.trimEnd());
        chunks.push(`-- <<< END ${src.label}`);
      } else {
        chunks.push(text.trimEnd());
      }
    }

    return chunks.join(this.#separator) + "\n";
  }

  /**
   * Write concatenated output directly to STDOUT.
   */
  async writeToStdout() {
    await Deno.stdout.write(encoder.encode(await this.concat()));
  }
}

export async function catToStdout(...sources: string[]) {
  await new Cat().add(...sources).writeToStdout();
}

function resolveSource(input: string): ResolvedSource {
  const parsed = tryParseUrl(input);

  if (parsed) {
    if (parsed.protocol === "http:" || parsed.protocol === "https:") {
      return { kind: "remote", original: parsed.href, label: parsed.pathname };
    }
    if (parsed.protocol === "file:") {
      const path = fromFileUrl(parsed);
      return { kind: "file", original: path, label: relativeLabel(path) };
    }
  }

  if (isAbsolute(input)) {
    return { kind: "file", original: input, label: relativeLabel(input) };
  }

  const u = new URL(input, import.meta.url);
  if (u.protocol === "file:") {
    const path = fromFileUrl(u);
    return { kind: "file", original: path, label: relativeLabel(path) };
  }

  return { kind: "remote", original: u.href, label: u.pathname };
}

function resolveFileSpec(input: string, cwd?: string): string {
  const parsed = tryParseUrl(input);
  if (parsed?.protocol === "file:") return fromFileUrl(parsed);
  if (isAbsolute(input)) return input;
  if (cwd) return resolve(cwd, input);

  const u = new URL(input, import.meta.url);
  if (u.protocol !== "file:") {
    throw new Error(`Expected local file, got ${u.href}`);
  }
  return fromFileUrl(u);
}

function relativeLabel(pathOrUrl: string) {
  try {
    if (pathOrUrl.startsWith("http")) {
      const u = new URL(pathOrUrl);
      return u.pathname.replace(/^\/+/, "");
    }
    return relative(Deno.cwd(), pathOrUrl) || pathOrUrl;
  } catch {
    return pathOrUrl;
  }
}

function tryParseUrl(value: string) {
  try {
    return new URL(value);
  } catch {
    return null;
  }
}

async function readSourceText(src: ResolvedSource): Promise<string> {
  if (src.kind === "inline") return src.original;

  if (src.kind === "remote") {
    const res = await fetch(src.original);
    if (!res.ok) {
      throw new Error(
        `Failed to fetch ${src.original}: ${res.status} ${res.statusText}`,
      );
    }
    return await res.text();
  }

  return await Deno.readTextFile(src.original);
}

async function safeStat(path: string): Promise<Deno.FileInfo | null> {
  try {
    return await Deno.stat(path);
  } catch {
    return null;
  }
}

// deno-lint-ignore require-await
async function isExecutableFile(
  path: string,
  st: Deno.FileInfo,
): Promise<boolean> {
  if (Deno.build.os !== "windows") {
    return ((st.mode ?? 0) & 0o111) !== 0;
  }
  const ext = extname(path).toLowerCase();
  return ext === ".exe" || ext === ".cmd" || ext === ".bat" || ext === ".ps1";
}

async function runExecutableCaptureStdout(
  executablePath: string,
): Promise<string> {
  const cmd = new Deno.Command(executablePath, {
    stdin: "null",
    stdout: "piped",
    stderr: "piped",
  });

  const out = await cmd.output();
  if (out.code !== 0) {
    const err = decoder.decode(out.stderr).trimEnd();
    throw new Error(
      `autoCompile failed for ${executablePath}${err ? `\n${err}` : ""}`,
    );
  }
  return decoder.decode(out.stdout);
}

/**
 * Write a `Cat` instance’s output based on how the caller was loaded.
 *
 * If `moduleUrl` is remote (`http(s):`), emits concatenated text to STDOUT.
 * If `moduleUrl` is local (`file:`), writes a sibling `.cat.auto.sqlite.sql`
 * next to the caller module and prints only the generated file path.
 *
 * @param cat Object implementing `concat(): Promise<string>` (typically `Cat`).
 * @param moduleUrl Usually the caller’s `import.meta.url`.
 */
export async function writeAutoCompileOutput(
  cat: { concat(): Promise<string> },
  moduleUrl: string | URL,
  localPath: (suggested: string) => string,
) {
  const url = typeof moduleUrl === "string" ? new URL(moduleUrl) : moduleUrl;
  const text = await cat.concat();

  if (url.protocol !== "file:") {
    await Deno.stdout.write(encoder.encode(text));
    return;
  }

  const out = localPath(fromFileUrl(url));
  await Deno.writeTextFile(out, text);
  await Deno.stdout.write(encoder.encode(out + "\n"));
}

if (import.meta.main) {
  const cat = new Cat();

  const specs: AutoCompileSpec[] = Deno.args.length > 0
    ? Deno.args.map((arg) => ({ file: arg }))
    : [{ glob: "**/*.cat.ts" }];

  for await (const generated of cat.autoCompile(specs)) {
    cat.addText(generated.text, generated.label);
  }

  await cat.writeToStdout();
}
