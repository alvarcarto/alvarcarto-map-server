#!/bin/env node

const fs = require('fs');
const Mustache = require('mustache');

function main() {
  const templateFile = process.argv[1];
  const secretsFile = process.argv[2];
  const template = fs.readFileSync(templateFile, { encoding: 'utf8' });
  const secretsContent = fs.readFileSync(secretsFile, { encoding: 'utf8' });
  const secrets = JSON.parse(secretsContent);

  const newContent = Mustache.render(template, secrets);
  console.log(newContent);
}

main();

