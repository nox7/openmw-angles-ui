import { cpSync, readFileSync, writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const src = resolve(__dirname, 'dist/anglesui-docs/browser');
const dest = resolve(__dirname, '../docs');

console.log(`Copying ${src} -> ${dest}`);
cpSync(src, dest, { recursive: true, force: true });

const indexPath = resolve(dest, '../docs/index.html');

console.log(`Patching base href in ${indexPath}`);
const original = readFileSync(indexPath, 'utf-8');
const patched = original.replace('<base href="/">', '<base href="/openmw-angles-ui/">');
if (original === patched) {
  console.warn('Warning: <base href="/"> not found in index.html — no replacement made.');
} else {
  writeFileSync(indexPath, patched, 'utf-8');
  console.log('Done.');
}
