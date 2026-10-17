#!/usr/bin/env node
// Résume un export Firebase (export/database.json + export/photos) pour vérifier qu'il est complet.
// Usage : node scripts/check_export.js [export]
const fs = require('fs')
const path = require('path')

const dir = process.argv[2] || 'export'
const db = JSON.parse(fs.readFileSync(path.join(dir, 'database.json'), 'utf8'))

const count = (node) => (node ? Object.keys(node).length : 0)
const countNested = (node) =>
  node ? Object.values(node).reduce((n, v) => n + count(v), 0) : 0

console.log('database.json')
for (const key of Object.keys(db).sort()) {
  console.log(`  ${key.padEnd(20)} ${count(db[key])}`)
}
console.log(`  avis (comments)      ${countNested(db.comments)}`)
console.log(`  photos (images)      ${countNested(db.images)}`)

const walk = (d) =>
  fs.existsSync(d)
    ? fs.readdirSync(d, { withFileTypes: true }).flatMap((e) =>
        e.isDirectory() ? walk(path.join(d, e.name)) : [e.name]
      )
    : []
const files = walk(path.join(dir, 'photos'))
const thumbs = files.filter((f) => f.startsWith('thumb_')).length
console.log('photos/')
console.log(`  originaux            ${files.length - thumbs}`)
console.log(`  miniatures           ${thumbs}`)

const users = path.join(dir, 'users.json')
if (fs.existsSync(users)) {
  const list = JSON.parse(fs.readFileSync(users, 'utf8')).users || []
  const anonymous = list.filter((u) => !(u.providerUserInfo || []).length).length
  console.log('users.json')
  console.log(`  comptes              ${list.length} (dont ${anonymous} anonymes)`)
}
