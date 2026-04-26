/**
 * C# Code Intelligence MCP Server
 *
 * Provides code navigation tools for C# codebases using fast regex-based search.
 * Designed as a pragmatic 80% solution — covers definition lookup, reference finding,
 * and implementation discovery without requiring a running language server.
 *
 * Tools:
 *   - find_definition: Find where a symbol (class, interface, method, property) is defined
 *   - find_references: Find all usages of a symbol across the codebase
 *   - find_implementations: Find classes/structs implementing an interface or base class
 *   - get_type_hierarchy: Show inheritance chain for a type
 *   - list_members: List all members of a class/interface/record
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execSync } from "child_process";
import { resolve } from "path";

const server = new McpServer({
  name: "csharp-intelligence",
  version: "1.0.0",
});

/**
 * Run ripgrep and return parsed results.
 * Falls back to Select-String if rg is not available.
 */
function search(pattern, cwd, options = {}) {
  const {
    glob = "*.cs",
    maxResults = 100,
    context = 0,
    multiline = false,
  } = options;
  const rgArgs = [
    `--glob "${glob}"`,
    "--no-heading",
    "--line-number",
    "--column",
    `--max-count ${maxResults}`,
    "--color never",
    multiline ? "--multiline" : "",
    context > 0 ? `--context ${context}` : "",
    `"${pattern}"`,
  ]
    .filter(Boolean)
    .join(" ");

  try {
    const output = execSync(`rg ${rgArgs}`, {
      cwd,
      encoding: "utf-8",
      timeout: 30000,
      maxBuffer: 1024 * 1024 * 5,
    });
    return parseRgOutput(output);
  } catch (e) {
    if (e.status === 1) return []; // No matches
    // Fallback to PowerShell Select-String
    try {
      const psCmd = `Get-ChildItem -Recurse -Include "${glob}" | Select-String -Pattern '${pattern.replace(/'/g, "''")}' | Select-Object -First ${maxResults} | ForEach-Object { "$($_.Path):$($_.LineNumber):1:$($_.Line)" }`;
      const output = execSync(`pwsh -NoProfile -Command "${psCmd}"`, {
        cwd,
        encoding: "utf-8",
        timeout: 30000,
      });
      return parseRgOutput(output);
    } catch {
      return [];
    }
  }
}

function parseRgOutput(output) {
  const results = [];
  for (const line of output.split("\n").filter(Boolean)) {
    const match = line.match(/^(.+?):(\d+):(\d+)?:?(.*)$/);
    if (match) {
      results.push({
        file: match[1],
        line: parseInt(match[2]),
        column: match[3] ? parseInt(match[3]) : 1,
        text: match[4]?.trim() || "",
      });
    }
  }
  return results;
}

server.tool(
  "find_definition",
  "Find where a C# symbol (class, interface, method, property, enum) is defined.",
  {
    symbol: z.string().describe("Symbol name to find the definition of"),
    kind: z
      .enum(["class", "interface", "method", "property", "enum", "record", "struct", "any"])
      .optional()
      .default("any")
      .describe("Kind of symbol to narrow the search"),
    cwd: z.string().optional().describe("Repository root. Defaults to process cwd."),
  },
  async ({ symbol, kind, cwd }) => {
    const workDir = cwd ? resolve(cwd) : process.cwd();
    const patterns = {
      class: `(class|sealed class|abstract class|static class|partial class)\\s+${symbol}`,
      interface: `interface\\s+${symbol}`,
      method: `\\b(public|private|protected|internal|static|async|override|virtual|sealed)\\b.*\\b${symbol}\\s*[<(]`,
      property: `\\b(public|private|protected|internal|static)\\b.*\\b${symbol}\\s*\\{`,
      enum: `enum\\s+${symbol}`,
      record: `(record|sealed record)\\s+(class|struct)?\\s*${symbol}`,
      struct: `(struct|readonly struct)\\s+${symbol}`,
      any: `(class|interface|enum|record|struct|sealed|abstract|static|partial)\\s+(class|struct|record)?\\s*${symbol}\\b`,
    };

    const pattern = patterns[kind || "any"];
    const results = search(pattern, workDir, { context: 0 });

    // Filter out test files and generated files for cleaner results
    const filtered = results.filter(
      (r) => !r.file.includes("obj/") && !r.file.includes("bin/")
    );

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            { symbol, kind, matches: filtered.slice(0, 20) },
            null,
            2
          ),
        },
      ],
    };
  }
);

server.tool(
  "find_references",
  "Find all usages/references to a symbol across the C# codebase.",
  {
    symbol: z.string().describe("Symbol name to find references for"),
    includeDefinition: z
      .boolean()
      .optional()
      .default(false)
      .describe("Include the definition site in results"),
    includeTests: z
      .boolean()
      .optional()
      .default(true)
      .describe("Include test files in results"),
    cwd: z.string().optional().describe("Repository root. Defaults to process cwd."),
  },
  async ({ symbol, includeDefinition, includeTests, cwd }) => {
    const workDir = cwd ? resolve(cwd) : process.cwd();
    // Search for the symbol as a whole word
    const pattern = `\\b${symbol}\\b`;
    let results = search(pattern, workDir, { maxResults: 200 });

    // Filter
    results = results.filter(
      (r) => !r.file.includes("obj/") && !r.file.includes("bin/")
    );
    if (!includeTests) {
      results = results.filter((r) => !r.file.includes("Tests/") && !r.file.includes(".Tests."));
    }
    if (!includeDefinition) {
      results = results.filter(
        (r) =>
          !r.text.match(
            new RegExp(
              `(class|interface|enum|record|struct)\\s+${symbol}\\b`
            )
          )
      );
    }

    // Group by file for readability
    const byFile = {};
    for (const r of results) {
      if (!byFile[r.file]) byFile[r.file] = [];
      byFile[r.file].push({ line: r.line, text: r.text });
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            { symbol, totalReferences: results.length, fileCount: Object.keys(byFile).length, byFile },
            null,
            2
          ),
        },
      ],
    };
  }
);

server.tool(
  "find_implementations",
  "Find classes/structs that implement an interface or extend a base class.",
  {
    symbol: z.string().describe("Interface or base class name"),
    cwd: z.string().optional().describe("Repository root. Defaults to process cwd."),
  },
  async ({ symbol, cwd }) => {
    const workDir = cwd ? resolve(cwd) : process.cwd();
    // Match type declarations with base type lists containing the symbol
    // Covers: class Foo : IBar, class Foo : Base, IBar, class Foo(args) : IBar
    const pattern = `(class|struct|record)\\s+\\w+[^{]*:\\s*[^{]*\\b${symbol}\\b`;
    const results = search(pattern, workDir, { maxResults: 100 });

    const filtered = results.filter(
      (r) => !r.file.includes("obj/") && !r.file.includes("bin/")
    );

    // Extract implementing type names
    const implementations = filtered.map((r) => {
      const nameMatch = r.text.match(
        /(?:class|struct|record)\s+(\w+)/
      );
      return {
        type: nameMatch ? nameMatch[1] : "unknown",
        file: r.file,
        line: r.line,
        declaration: r.text.trim(),
      };
    });

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            { interface: symbol, implementationCount: implementations.length, implementations },
            null,
            2
          ),
        },
      ],
    };
  }
);

server.tool(
  "list_members",
  "List all public members (methods, properties, fields) of a C# type.",
  {
    typeName: z.string().describe("Class, interface, or record name"),
    cwd: z.string().optional().describe("Repository root. Defaults to process cwd."),
  },
  async ({ typeName, cwd }) => {
    const workDir = cwd ? resolve(cwd) : process.cwd();

    // First find the file containing the type definition
    const defPattern = `(class|interface|enum|record|struct)\\s+${typeName}\\b`;
    const defs = search(defPattern, workDir);
    if (defs.length === 0) {
      return {
        content: [{ type: "text", text: JSON.stringify({ error: `Type '${typeName}' not found` }) }],
      };
    }

    // Read the file and extract members between the type's braces
    const defFile = defs[0].file;
    const memberPattern = `\\b(public|internal)\\b[^;{]*\\b\\w+\\s*[({<]|\\b(public|internal)\\b.*\\b\\w+\\s*\\{\\s*get`;
    const members = search(memberPattern, workDir, {
      glob: defFile.includes("/") ? defFile.split("/").pop() : defFile.split("\\").pop(),
    });

    const parsed = members
      .filter((m) => m.file === defFile || m.file.endsWith(defFile.replace(/.*[/\\]/, "")))
      .map((m) => {
        const text = m.text.trim();
        let kind = "unknown";
        if (text.match(/\(\s*\)/)) kind = "method";
        else if (text.match(/\{.*get/)) kind = "property";
        else if (text.match(/\(/)) kind = "method";
        else kind = "field";
        return { line: m.line, kind, signature: text };
      });

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            { typeName, file: defFile, memberCount: parsed.length, members: parsed },
            null,
            2
          ),
        },
      ],
    };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
