// Run: node --test .deploy/keycloak/tests/navio-forms.test.mjs
// The sign-up checklist must agree with the server policy, or it either lets a
// rejected password through or blocks one Keycloak would accept.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const here = (path) => fileURLToPath(new URL(path, import.meta.url));
const source = readFileSync(here("../themes/navio/login/resources/js/navio-forms.js"), "utf8");
const context = vm.createContext({});
vm.runInContext(source, context);
const { evaluateNavioPassword, isNavioEmail } = context;

const deployScript = readFileSync(here("../../scripts/deploy.sh"), "utf8");
const policy = /passwordPolicy=(length\((\d+)\) and regexPattern\((.+)\) and notUsername and notEmail[^"]*)"/.exec(
  deployScript,
);

const passes = (password, email) => evaluateNavioPassword(password, email).every((rule) => rule.met);

test("the deployed policy still has the shape the checklist mirrors", () => {
  assert.ok(policy, "deploy.sh passwordPolicy changed; update navio-forms.js and this test together");
  assert.equal(Number(policy[2]), 8);
});

test("the checklist accepts exactly what the server regex and length accept", () => {
  // Java String.matches() semantics: the whole value must match.
  const serverRegex = new RegExp(`^(?:${policy[3]})$`);
  const minLength = Number(policy[2]);
  const samples = [
    "Passwor1", "pass@wo1", "abcdefg1!", "Password1", "pass word1", "สวัสดีa1xx",
    "abcdefg1", "ABCDEFG1", "Abcdefgh", "Pass1Ab", "password", "12345678", "", "PASSWORD1",
  ];
  for (const sample of samples) {
    const server = sample.length >= minLength && serverRegex.test(sample);
    assert.equal(passes(sample, ""), server, `disagrees with the server on ${JSON.stringify(sample)}`);
  }
});

test("a password equal to the email address is not accepted", () => {
  assert.equal(passes("Alex1@mail.com", "alex1@mail.com"), false);
  assert.equal(passes("Alex1@mail.com!", "alex1@mail.com"), true);
});

test("the email rule is left out where the form has no email field", () => {
  assert.deepEqual(
    [...evaluateNavioPassword("Passwor1").map((rule) => rule.key)],
    ["length", "lower", "number", "upperOrSymbol"],
  );
});

test("an empty password meets no rule", () => {
  assert.ok(evaluateNavioPassword("", "").every((rule) => !rule.met));
});

test("the email check never blocks an address Keycloak could accept", () => {
  for (const ok of ["name@example.com", "a.b+tag@sub.example.co.th", "x@localhost"]) {
    assert.equal(isNavioEmail(ok), true, ok);
  }
  for (const bad of ["", "not-an-email", "a b@example.com", "@example.com", "name@"]) {
    assert.equal(isNavioEmail(bad), false, bad);
  }
});
