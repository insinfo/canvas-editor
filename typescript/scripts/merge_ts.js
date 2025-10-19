#!/usr/bin/env node
/**
 * scripts/merge_ts.js
 * 
 * Este script mescla todos os arquivos TypeScript (.ts) de um diretório em um único arquivo,
 * excluindo arquivos de definição (.d.ts). Útil para análise de código ou backup.
 * 
 * Características:
 * - Ignora pastas node_modules, .git, dist e build
 * - Preserva caminho relativo nos comentários
 * - Ordena arquivos alfabeticamente
 * - Adiciona separadores e comentários de origem
 * 
 * Uso: 
 *   node scripts/merge_ts.js [<sourceDir>] [<outFile>]
 * 
 * Argumentos:
 *   sourceDir - Diretório com arquivos .ts (opcional, default: C:\\MyTsProjects\\canvas-editor\\src)
 *   outFile   - Arquivo de saída (opcional, default: ./codigo_mesclado.ts.txt)
 * 
 * Exemplo:
 *   node scripts/merge_ts.js                             # usa diretórios padrão
 *   node scripts/merge_ts.js ./src ./merged.ts          # especifica entrada/saída
 *   node scripts/merge_ts.js -h                         # mostra ajuda
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const [, , dirArg, outArg] = process.argv;

const defaultSrc = 'C:\\MyTsProjects\\canvas-editor\\src';
const defaultOut = path.resolve(__dirname, 'codigo_mesclado.ts.txt');

const srcDir = dirArg ? path.resolve(dirArg) : defaultSrc;
const outFile = outArg ? path.resolve(outArg) : defaultOut;

function usage() {
  console.log('Usage: node scripts/merge_ts.js [<sourceDir>] [<outFile>]');
  console.log('Defaults:');
  console.log('  sourceDir -> ' + defaultSrc);
  console.log('  outFile   -> ' + defaultOut);
}

if (dirArg === '-h' || dirArg === '--help') {
  usage();
  process.exit(0);
}

async function collectTsFiles(dir) {
  const results = [];

  async function walk(current) {
    let entries;
    try {
      entries = await fs.promises.readdir(current, { withFileTypes: true });
    } catch (err) {
      console.error('Failed to read directory', current, err.message);
      return;
    }

    for (const entry of entries) {
      const full = path.join(current, entry.name);

      // Skip common heavy or irrelevant folders
      if (entry.isDirectory()) {
        const lname = entry.name.toLowerCase();
        if (lname === 'node_modules' || lname === '.git' || lname === 'dist' || lname === 'build') continue;
        await walk(full);
      } else if (entry.isFile()) {
        if (full.endsWith('.ts') && !full.endsWith('.d.ts')) {
          results.push(full);
        }
      }
    }
  }

  await walk(dir);
  return results.sort();
}

async function main() {
  try {
    const stats = await fs.promises.stat(srcDir);
    if (!stats.isDirectory()) {
      console.error('Source is not a directory:', srcDir);
      process.exit(2);
    }
  } catch (err) {
    console.error('Source directory not found:', srcDir);
    usage();
    process.exit(2);
  }

  // Remove output file if exists
  try {
    if (fs.existsSync(outFile)) {
      fs.unlinkSync(outFile);
    }
  } catch (err) {
    console.error('Failed to remove existing output file:', outFile, err.message);
    process.exit(3);
  }

  const files = await collectTsFiles(srcDir);
  if (!files.length) {
    console.log('No .ts files found in', srcDir);
    process.exit(0);
  }

  const outStream = fs.createWriteStream(outFile, { flags: 'a', encoding: 'utf8' });

  for (const file of files) {
    try {
      const rel = path.relative(srcDir, file);
      const content = await fs.promises.readFile(file, 'utf8');
      outStream.write('// Merged from ' + file + '\n');
      outStream.write('// Relative: ' + rel + '\n');
      outStream.write(content);
      outStream.write('\n\n');
    } catch (err) {
      console.error('Failed to read file', file, err.message);
    }
  }

  outStream.end(() => {
    console.log('Merged', files.length, '.ts files into', outFile);
  });
}

main().catch(err => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
