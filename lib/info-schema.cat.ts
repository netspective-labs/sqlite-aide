#!/usr/bin/env -S deno run -A --node-modules-dir=auto
// info-schema.cat.ts
import { Cat, writeAutoCompileOutput } from "./cat.ts";

const cat = new Cat().add(
  new URL("../src/core-ddl.sqlite.sql", import.meta.url).href,
  new URL("../src/info-schema.sqlite.sql", import.meta.url).href,
);

export default cat;

if (import.meta.main) {
  await writeAutoCompileOutput(
    cat,
    import.meta.url,
    (path) => path.replace(/\.cat\.ts$/, ".auto.sqlite.sql"),
  );
}
