#!/usr/bin/env -S deno run -A --node-modules-dir=auto --import-map ../../../../programmablemd/spry/import_map.json
// Use `deno run -A --watch` in the shebang if you're contributing / developing Spry itself.

// NOTE: this spry.ts file is useful if you're contributing to Spry code. If
//       you're just using Spry it's better to use the binary at https://sprymd.org.

import { CLI } from "../../../../programmablemd/spry/bin/spry.ts";

await CLI({ defaultFiles: ["Spryfile.md"] }).parse(Deno.args);
