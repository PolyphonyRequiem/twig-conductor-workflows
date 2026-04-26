/**
 * dotnet-build-test MCP Server
 *
 * Provides structured build and test results for .NET projects.
 * Eliminates agents parsing wall-of-text terminal output.
 *
 * Tools:
 *   - dotnet_build: Build a project/solution, return structured errors/warnings
 *   - dotnet_test: Run tests with TRX logger, return structured pass/fail results
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execSync } from "child_process";
import { readFileSync, readdirSync, unlinkSync } from "fs";
import { join, resolve } from "path";
import { tmpdir } from "os";

const server = new McpServer({
  name: "dotnet-build-test",
  version: "1.0.0",
});

/**
 * Parse MSBuild output into structured errors and warnings.
 */
function parseBuildOutput(output) {
  const errors = [];
  const warnings = [];
  // MSBuild format: path(line,col): error CODE: message
  const pattern = /^(.+?)\((\d+),(\d+)\):\s+(error|warning)\s+(\w+):\s+(.+)$/gm;
  let match;
  while ((match = pattern.exec(output)) !== null) {
    const entry = {
      file: match[1].trim(),
      line: parseInt(match[2]),
      column: parseInt(match[3]),
      code: match[5],
      message: match[6].trim(),
    };
    if (match[4] === "error") errors.push(entry);
    else warnings.push(entry);
  }
  return { errors, warnings };
}

/**
 * Parse TRX (Visual Studio Test Results) XML into structured results.
 */
function parseTrxFile(trxPath) {
  const xml = readFileSync(trxPath, "utf-8");
  const tests = [];
  let passed = 0,
    failed = 0,
    skipped = 0;

  // Parse counters from ResultSummary
  const countersMatch = xml.match(
    /Counters[^>]*total="(\d+)"[^>]*passed="(\d+)"[^>]*failed="(\d+)"/i
  );
  if (countersMatch) {
    passed = parseInt(countersMatch[2]);
    failed = parseInt(countersMatch[3]);
  }

  // Parse individual test failures for actionable output
  const failurePattern =
    /<UnitTestResult[^>]*testName="([^"]*)"[^>]*outcome="Failed"[^>]*>[\s\S]*?<Message>([\s\S]*?)<\/Message>[\s\S]*?(?:<StackTrace>([\s\S]*?)<\/StackTrace>)?[\s\S]*?<\/UnitTestResult>/gi;
  let fMatch;
  while ((fMatch = failurePattern.exec(xml)) !== null) {
    tests.push({
      name: fMatch[1],
      outcome: "Failed",
      message: fMatch[2].replace(/<!\[CDATA\[|\]\]>/g, "").trim(),
      stackTrace: fMatch[3]
        ? fMatch[3].replace(/<!\[CDATA\[|\]\]>/g, "").trim()
        : null,
    });
  }

  // Count skipped
  const skippedMatch = xml.match(/outcome="NotExecuted"/gi);
  skipped = skippedMatch ? skippedMatch.length : 0;

  return { passed, failed, skipped, total: passed + failed + skipped, failures: tests };
}

server.tool(
  "dotnet_build",
  "Build a .NET project or solution. Returns structured errors and warnings.",
  {
    project: z
      .string()
      .optional()
      .describe(
        "Project or solution path relative to cwd. Defaults to the solution in cwd."
      ),
    configuration: z
      .string()
      .optional()
      .default("Debug")
      .describe("Build configuration (Debug/Release)"),
    cwd: z
      .string()
      .optional()
      .describe("Working directory. Defaults to process cwd."),
  },
  async ({ project, configuration, cwd }) => {
    const workDir = cwd ? resolve(cwd) : process.cwd();
    const projectArg = project ? ` ${project}` : "";
    const cmd = `dotnet build${projectArg} --configuration ${configuration || "Debug"} --no-restore -v quiet 2>&1`;

    let output, exitCode;
    try {
      output = execSync(cmd, {
        cwd: workDir,
        encoding: "utf-8",
        timeout: 300000,
      });
      exitCode = 0;
    } catch (e) {
      output = e.stdout || e.message;
      exitCode = e.status || 1;
    }

    const { errors, warnings } = parseBuildOutput(output);
    const success = exitCode === 0 && errors.length === 0;

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            { success, exitCode, errors, warnings, errorCount: errors.length, warningCount: warnings.length },
            null,
            2
          ),
        },
      ],
    };
  }
);

server.tool(
  "dotnet_test",
  "Run .NET tests with structured results. Parses TRX output for pass/fail details.",
  {
    project: z
      .string()
      .optional()
      .describe("Test project path relative to cwd."),
    filter: z
      .string()
      .optional()
      .describe(
        'Test filter expression (e.g., "FullyQualifiedName~MyTest" or "Category=Unit")'
      ),
    settings: z
      .string()
      .optional()
      .describe("Path to .runsettings file"),
    cwd: z
      .string()
      .optional()
      .describe("Working directory. Defaults to process cwd."),
    noBuild: z
      .boolean()
      .optional()
      .default(false)
      .describe("Skip build before running tests"),
  },
  async ({ project, filter, settings, cwd, noBuild }) => {
    const workDir = cwd ? resolve(cwd) : process.cwd();
    const trxDir = join(tmpdir(), `twig-trx-${Date.now()}`);
    const projectArg = project ? ` ${project}` : "";
    const filterArg = filter ? ` --filter "${filter}"` : "";
    const settingsArg = settings ? ` --settings ${settings}` : "";
    const noBuildArg = noBuild ? " --no-build" : "";

    const cmd = `dotnet test${projectArg}${noBuildArg}${filterArg}${settingsArg} --logger "trx;LogFileName=results.trx" --results-directory "${trxDir}" 2>&1`;

    let output, exitCode;
    try {
      output = execSync(cmd, {
        cwd: workDir,
        encoding: "utf-8",
        timeout: 600000,
      });
      exitCode = 0;
    } catch (e) {
      output = e.stdout || e.message;
      exitCode = e.status || 1;
    }

    // Find and parse the TRX file
    let results = { passed: 0, failed: 0, skipped: 0, total: 0, failures: [] };
    try {
      const trxFiles = readdirSync(trxDir).filter((f) => f.endsWith(".trx"));
      if (trxFiles.length > 0) {
        results = parseTrxFile(join(trxDir, trxFiles[0]));
        // Cleanup
        trxFiles.forEach((f) => unlinkSync(join(trxDir, f)));
      }
    } catch {
      // TRX parsing failed — fall back to exit code
    }

    const success = exitCode === 0 && results.failed === 0;

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              success,
              passed: results.passed,
              failed: results.failed,
              skipped: results.skipped,
              total: results.total,
              failures: results.failures,
            },
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
