#!/usr/bin/env node

/**
 * check-benchmark-regression.js
 *
 * Compares benchmark results against predefined thresholds and fails
 * the CI step if any metric exceeds its limit.
 *
 * Environment variables:
 *   BUILD_TIME_MS  - Build time in milliseconds
 *   BUNDLE_SIZE_KB - Bundle size in kilobytes
 *
 * Exit codes:
 *   0 - All benchmarks within thresholds
 *   1 - One or more benchmarks exceeded thresholds
 */

const THRESHOLDS = {
  // Maximum acceptable build time in milliseconds (2 minutes)
  buildTimeMs: 120_000,

  // Maximum acceptable bundle size in kilobytes (5 MB)
  bundleSizeKb: 5_120,

  // Maximum acceptable test suite duration in milliseconds (5 minutes)
  testSuiteMs: 300_000,
};

function parseEnvNumber(name, fallback) {
  const value = process.env[name];
  if (value === undefined || value === '') {
    return fallback;
  }
  const parsed = Number(value);
  if (Number.isNaN(parsed)) {
    console.warn(`WARNING: ${name} is not a valid number: "${value}". Using fallback: ${fallback}`);
    return fallback;
  }
  return parsed;
}

function checkThreshold(name, value, threshold) {
  const passed = value <= threshold;
  const status = passed ? 'PASS' : 'FAIL';
  const pct = ((value / threshold) * 100).toFixed(1);

  console.log(
    `  ${status}: ${name} = ${value} (threshold: ${threshold}, usage: ${pct}%)`
  );

  return passed;
}

function main() {
  console.log('=== Benchmark Regression Check ===\n');
  console.log('Thresholds:');
  console.log(`  Build time:  ${THRESHOLDS.buildTimeMs}ms`);
  console.log(`  Bundle size: ${THRESHOLDS.bundleSizeKb}KB`);
  console.log('');

  const buildTimeMs = parseEnvNumber('BUILD_TIME_MS', null);
  const bundleSizeKb = parseEnvNumber('BUNDLE_SIZE_KB', null);

  let allPassed = true;

  console.log('Results:');

  if (buildTimeMs !== null) {
    if (!checkThreshold('Build Time (ms)', buildTimeMs, THRESHOLDS.buildTimeMs)) {
      allPassed = false;
    }
  } else {
    console.log('  SKIP: BUILD_TIME_MS not provided');
  }

  if (bundleSizeKb !== null) {
    if (!checkThreshold('Bundle Size (KB)', bundleSizeKb, THRESHOLDS.bundleSizeKb)) {
      allPassed = false;
    }
  } else {
    console.log('  SKIP: BUNDLE_SIZE_KB not provided');
  }

  // Try to read benchmark-results.json if it exists
  try {
    const fs = require('fs');
    const path = require('path');
    const resultsPath = path.join(process.cwd(), 'benchmark-results.json');

    if (fs.existsSync(resultsPath)) {
      const results = JSON.parse(fs.readFileSync(resultsPath, 'utf-8'));

      if (results.testResults) {
        const totalDuration = results.testResults.reduce((sum, suite) => {
          return sum + (suite.duration || 0);
        }, 0);

        if (!checkThreshold('Test Suite Duration (ms)', totalDuration, THRESHOLDS.testSuiteMs)) {
          allPassed = false;
        }
      }

      // Report test counts
      if (results.numTotalTests !== undefined) {
        console.log(`\n  Total tests: ${results.numTotalTests}`);
        console.log(`  Passed: ${results.numPassedTests || 0}`);
        console.log(`  Failed: ${results.numFailedTests || 0}`);
      }
    }
  } catch {
    console.log('  INFO: No benchmark-results.json found (this is OK)');
  }

  console.log('');

  if (allPassed) {
    console.log('All benchmark checks passed.');
    process.exit(0);
  } else {
    console.error('FAILURE: One or more benchmark checks exceeded thresholds.');
    process.exit(1);
  }
}

main();
