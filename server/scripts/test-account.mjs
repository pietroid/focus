#!/usr/bin/env node
// test-account.mjs
//
// The account an E2E run signs in with, on the Firebase Auth emulator.
// e2e.sh creates focus.main.agent@gmail.com with the password named in
// app/env/e2e.json, and removes it at the end. The emulator starts empty on
// every run, so no two runs share a user.
//
//   node scripts/test-account.mjs create <email> [name]
//     prints {"uid", "email", "password"} as JSON on stdout
//   node scripts/test-account.mjs delete <email>
//     removes the user, and its Firestore user record when
//     FIRESTORE_EMULATOR_HOST is set
//
// Needs FIREBASE_AUTH_EMULATOR_HOST. It never touches a real project.

import { randomBytes } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const [command, email, name = 'Teste'] = process.argv.slice(2);
if (!['create', 'delete'].includes(command) || !email) {
  console.error('usage: test-account.mjs create|delete <email> [name]');
  process.exit(2);
}
if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error('Set FIREBASE_AUTH_EMULATOR_HOST. Test accounts only live on the emulator.');
  process.exit(2);
}

initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID ?? 'focus-local-dev' });
const auth = getAuth();

async function create() {
  // E2E_PASSWORD names it, as e2e.sh does. Random otherwise.
  const password = process.env.E2E_PASSWORD || randomBytes(18).toString('base64url');
  let uid;
  try {
    uid = (await auth.getUserByEmail(email)).uid;
    await auth.updateUser(uid, { password, displayName: name });
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
    uid = (await auth.createUser({ email, password, displayName: name, emailVerified: true })).uid;
  }
  process.stdout.write(JSON.stringify({ uid, email, password }) + '\n');
}

async function remove() {
  try {
    const { uid } = await auth.getUserByEmail(email);
    await auth.deleteUser(uid);
    if (process.env.FIRESTORE_EMULATOR_HOST) {
      await getFirestore().collection('users').doc(uid).delete();
    }
    process.stdout.write(JSON.stringify({ uid, deleted: true }) + '\n');
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
    process.stdout.write(JSON.stringify({ email, deleted: false }) + '\n');
  }
}

(command === 'create' ? create() : remove()).catch((error) => {
  console.error(error);
  process.exit(1);
});
